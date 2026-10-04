#!/usr/bin/env python3
"""Install reviewed, locked package sources without native or byte compilation."""
import hashlib
import io
import tarfile
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.local' / 'downloads'
lock = json.loads((ROOT / 'packages.lock.json').read_text())
if lock['format'] != 1:
    raise SystemExit('Unsupported package lock format')
CACHE.mkdir(parents=True, exist_ok=True)
paths = []
for package in lock['packages']:
    url = package['url']
    if not any(url.startswith(source) for source in lock['sources']):
        raise SystemExit(f'Unexpected package source: {url}')
    path = CACHE / package.get('filename', url.rsplit('/', 1)[-1])
    if not path.exists():
        print(f'Downloading {package["name"]} {package["version"]}', flush=True)
        with urllib.request.urlopen(url, timeout=40) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != package['sha256']:
            raise SystemExit(f'Checksum mismatch: {url}')
        path.write_bytes(data)
    if hashlib.sha256(path.read_bytes()).hexdigest() != package['sha256']:
        raise SystemExit(f'Checksum mismatch: {path}; remove this cached file and retry')
    if package.get('format') == 'github-tar.gz':
        # Repackage only reviewed Codex modules from the verified immutable archive.
        prefix = f"codex-{package['revision']}/"
        target = CACHE / f"codex-{package['version']}.tar"
        modules = ('codex.el', 'codex-app-server.el', 'codex-eat.el', 'codex-vterm.el')
        with tarfile.open(path, 'r:gz') as source, tarfile.open(target, 'w') as output:
            files = {name: source.extractfile(prefix + name).read() for name in modules}
            files['codex-pkg.el'] = b'(define-package "codex" "0.4.0" "Emacs integration for OpenAI Codex CLI" \'((emacs "28.1") (transient "0.9.3") (inheritenv "0.2") (eat "0.9.4")))\n'
            for name, data in files.items():
                info = tarfile.TarInfo(f"codex-{package['version']}/{name}")
                info.size, info.mode, info.mtime = len(data), 0o644, 0
                output.addfile(info, io.BytesIO(data))
        path = target
    paths.append(str(path))
emacs = os.environ.get('CODE_LENS_EMACS') or shutil.which('emacs')
if not emacs:
    emacs = next((p for p in ('/Applications/Emacs 2.app/Contents/MacOS/Emacs',
                              '/Applications/Emacs.app/Contents/MacOS/Emacs')
                  if Path(p).is_file()), None)
if not emacs:
    raise SystemExit('Emacs 29.1+ required; set CODE_LENS_EMACS')
env = dict(os.environ, CODE_LENS_ROOT=str(ROOT))
subprocess.run([emacs, '-Q', '--batch', '--load', str(ROOT / 'early-init.el'),
                '--load', str(ROOT / 'lisp' / 'lens-bootstrap.el'), '--', *paths],
               check=True, env=env)
print('Bootstrap complete. Run bin/check, then bin/code-lens (or bin/code-lens -nw).')
