;;; -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "tests/codex-test.el" lens-root) nil t)
(load (expand-file-name "tests/embark-test.el" lens-root) nil t)
(load (expand-file-name "tests/navigation-display-test.el" lens-root) nil t)
(load (expand-file-name "tests/ocaml-outline-test.el" lens-root) nil t)
(load (expand-file-name "tests/merlin-test.el" lens-root) nil t)
(load (expand-file-name "tests/input-source-test.el" lens-root) nil t)
(add-hook
 'emacs-startup-hook
 (lambda ()
   (run-at-time
    0.1 nil
    (lambda ()
      (let ((selector (cond ((getenv "CODE_LENS_INPUT_SOURCE_ONLY") '(tag input-source-interactive))
                            ((getenv "CODE_LENS_MERLIN_ONLY") '(tag merlin-interactive))
                            ((getenv "CODE_LENS_OUTLINE_ONLY") '(tag outline-interactive))
                            ((getenv "CODE_LENS_NAVIGATION_ONLY") '(tag navigation-interactive))
                            (t '(tag interactive))))
            (report (or (getenv "CODE_LENS_TEST_REPORT")
                        (expand-file-name "docs/test-reports/completion-interactive.log" lens-root))))
        (make-directory (file-name-directory report) t)
        (condition-case failure
            (let ((stats (ert-run-tests-batch selector)))
              (with-temp-file report
                (insert (format "Emacs %s; independent terminal startup\n" emacs-version))
                (insert (format "Real minibuffer tests: %s total, %s expected, %s unexpected\n"
                                (ert-stats-total stats)
                                (ert-stats-completed-expected stats)
                                (ert-stats-completed-unexpected stats)))
                (insert (format "Vertico=%S Marginalia=%S Fido=%S\n"
                                vertico-mode marginalia-mode fido-mode))
                (insert "No external Codex question sent by these tests.\n")
                (insert (lens-primary-package-summary))
                (dolist (test (ert-select-tests selector t))
                  (let ((result (ert-test-most-recent-result test)))
                    (when (ert-test-failed-p result)
                      (insert (format "FAILED %s: %S\n" (ert-test-name test) (ert-test-failed-condition result)))))))
              (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1)))
          (error
           (with-temp-file report (insert (format "ERROR %S\n" failure)))
           (kill-emacs 1))))))))
