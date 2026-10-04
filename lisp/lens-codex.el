;;; lens-codex.el --- Saved project-file questions via Codex IDE -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'project)
(require 'subr-x)
;; No editor-context injection, tool bridge/server, new login, or implicit write access.
(setq codex-ide-model "gpt-6.1-sol"
      codex-ide-reasoning-effort "high"
      codex-ide-sandbox-mode "read-only"
      codex-ide-approval-policy "on-request"
      codex-ide-emacs-context-policy nil
      codex-ide-session-baseline-prompt nil
      codex-ide-enable-emacs-tool-bridge nil
      codex-ide-want-mcp-bridge nil)
(require 'codex-ide)
(defcustom lens-codex-program "codex"
  "Existing CLI executable; this profile does not install or log it in."
  :type 'string :group 'codex-ide)
(defconst lens-codex-prompt-templates
  '("给我当前文件<%s>中最重要的glossary的解释"
    "给我解释当前文件<%s>中最重要的几个类型和函数")
  "Preset questions expanded with the captured project's relative file path.")
(defvar lens-codex-launch-p nil)
(defvar lens-codex-sessions (make-hash-table :test 'equal))
(defvar lens-codex-permissions (make-hash-table :test 'eq))

(defun lens-codex-source-context ()
  "Capture the source and its saved local file's project-relative path before UI changes."
  (unless buffer-file-name (user-error "Code Lens: this buffer has no file; no question sent"))
  (when (file-remote-p buffer-file-name)
    (user-error "Code Lens: Codex QA supports saved local project files only"))
  (unless (and (file-regular-p buffer-file-name) (file-readable-p buffer-file-name))
    (user-error "Code Lens: save this file to disk before asking Codex; nothing saved or sent"))
  (let* ((file (file-truename buffer-file-name))
         (project (project-current nil (file-name-directory buffer-file-name))))
    (unless project
      (user-error "Code Lens: this file has no recognized project; no question sent"))
    (let ((root (file-name-as-directory (file-truename (project-root project)))))
      (unless (file-in-directory-p file root)
        (user-error "Code Lens: this file is outside the project (including symlink targets); no question sent"))
      (list :buffer (current-buffer) :project project :file file :root root
            :relative-file (file-relative-name file root) :modified (buffer-modified-p)))))

(defun lens-codex-question ()
  "Choose a preset for a project file; Codex reads its saved version from disk."
  (interactive)
  (unless (and (bound-and-true-p lens-reading-mode) buffer-read-only (lens-eglot-language))
    (user-error "Code Lens: use c in a read-only Clojure/OCaml reading buffer"))
  (let* ((context (lens-codex-source-context))
         (file (plist-get context :relative-file))
         (choices (mapcar (lambda (template) (format template file)) lens-codex-prompt-templates))
         (question (completing-read
                    (if (plist-get context :modified)
                        "Codex 当前文件问题（有未保存修改；仅读磁盘版本）: "
                      "Codex 当前文件问题: ") choices nil t))
         (prompt (format "从会话的项目根工作目录读取下面指定的项目内文件，按磁盘已保存版本回答。只回答代码问题；不要修改文件、应用补丁、执行写操作或读取其他文件。\n%s" question)))
    (prog1 (lens-codex-dispatch context prompt)
      (when (plist-get context :modified)
        (message "Code Lens: 不会保存或发送未保存修改；Codex 只读取磁盘已保存版本")))))

(defun lens-codex-owned-session-p (session)
  "Return non-nil only for this adapter's exact project session object."
  (and (codex-ide-session-p session)
       (eq session (gethash (file-name-as-directory (codex-ide-session-directory session))
                           lens-codex-sessions))))

(defun lens-codex-session-event (event session _payload)
  "Mark new QA sessions and apply only their read-only permission overrides.
Model/effort use Code Lens defaults; later explicit session overrides remain intact."
  (when (and (eq event 'created) lens-codex-launch-p)
    (puthash (file-name-as-directory (codex-ide-session-directory session)) session lens-codex-sessions)
    (codex-ide-config-set-session-value 'sandbox-mode "read-only" session)
    (codex-ide-config-set-session-value 'approval-policy "on-request" session)))
(add-hook 'codex-ide-session-event-hook #'lens-codex-session-event)

(defun lens-codex-confirm-thread (request session method params)
  "Check the pinned protocol's thread/start reply before any source question is sent."
  (let ((result (funcall request session method params)))
    (when (and (lens-codex-owned-session-p session) (equal method "thread/start"))
      (let* ((sandbox (or (alist-get 'sandboxPolicy result) (alist-get 'sandbox result)))
             (kind (if (stringp sandbox) sandbox (alist-get 'type sandbox)))
             (cwd (alist-get 'cwd (alist-get 'thread result)))
             (root (file-name-as-directory (codex-ide-session-directory session))))
        (unless (and (member kind '("readOnly" "read-only"))
                     (equal (alist-get 'approvalPolicy result) "on-request")
                     (stringp cwd) (equal root (file-name-as-directory (file-truename cwd))))
          (user-error "Code Lens: server has not confirmed this project's read-only/on-request session; no question sent"))
        (puthash session t lens-codex-permissions)))
    result))
(advice-add 'codex-ide--request-sync :around #'lens-codex-confirm-thread)

(defun lens-codex-check-session (session root)
  "Refuse wrong-project or unconfirmed sessions and changed permission settings."
  (unless (and (lens-codex-owned-session-p session) (gethash session lens-codex-permissions)
               (equal root (file-name-as-directory (file-truename (codex-ide-session-directory session))))
               (equal (codex-ide-config-effective-value 'sandbox-mode session) "read-only")
               (equal (codex-ide-config-effective-value 'approval-policy session) "on-request"))
    (user-error "Code Lens: QA session project/permissions do not match; no question sent")))

(defun lens-codex-buffer-name (directory)
  "Give QA buffers distinct names even when two projects share a basename."
  (format "*codex-ide-qa:%s*" (abbreviate-file-name (file-truename directory))))

(defun lens-codex-dispatch (context prompt)
  "Start through `codex-ide' and submit to its exact session via the public API."
  (let* ((program (executable-find lens-codex-program))
         (root (plist-get context :root))
         (session (gethash root lens-codex-sessions)))
    (unless program (user-error "Code Lens: Codex CLI is missing from PATH; no question sent"))
    (unless (zerop (call-process program nil nil nil "login" "status"))
      (user-error "Code Lens: CLI is not logged in; run codex login separately, then retry c"))
    (unless (and session (process-live-p (codex-ide-session-process session))
                 (buffer-live-p (codex-ide-session-buffer session)))
      ;; A temporary root buffer prevents a switched minibuffer target from changing the project.
      (with-temp-buffer
        (setq default-directory root)
        (let ((codex-ide-cli-path program) (lens-codex-launch-p t)
              (codex-ide-buffer-name-function #'lens-codex-buffer-name)
              (codex-ide-want-mcp-bridge nil) (codex-ide-enable-emacs-tool-bridge nil))
          (setq session (codex-ide)))))
    (lens-codex-check-session session root)
    (when (codex-ide-session-current-turn-id session)
      (user-error "Code Lens: QA is still answering; wait before sending another file question"))
    (codex-ide-transcript-submit-prompt-to-session session prompt :suppress-context t)
    (pop-to-buffer (codex-ide-session-buffer session))
    (codex-ide-session-buffer session)))

(provide 'lens-codex)
