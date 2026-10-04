;;; lens-codex.el --- Current-file read-only Codex questions -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'project)
(require 'subr-x)
;; Set these before loading the package: no personal hook/config/server setup.
(setq codex-enable-hooks nil
      codex-enable-notifications nil
      codex-transcript-catch-up-on-stop nil
      codex-hooks-config-path (expand-file-name "codex-disabled-config.toml" user-emacs-directory)
      codex-hooks-json-path (expand-file-name "codex-disabled-hooks.json" user-emacs-directory)
      codex-transcript-sessions-directory (expand-file-name "codex-unused-transcripts/" user-emacs-directory)
      codex-terminal-backend 'app-server
      codex-sandbox-mode 'read-only
      codex-approval-policy 'on-request
      codex-full-auto nil)
(require 'codex)

(defcustom lens-codex-program "codex"
  "Existing Codex CLI executable; this profile never installs or logs it in."
  :type 'string :group 'codex)
(defconst lens-codex-prompt-templates
  '("给我当前文件<%s>中最重要的glossary的解释"
    "给我解释当前文件<%s>中最重要的几个类型和函数")
  "Preset questions, expanded with the source buffer's actual file name.")
(defvar lens-codex-launch-p nil)
(defvar lens-codex-initial-question nil)
(defvar-local lens-codex-pending-question nil)
(defvar-local lens-codex-session-p nil)

(defun lens-codex-source-context ()
  "Capture file, project, point, selection and current-file text before UI changes."
  (unless buffer-file-name (user-error "Code Lens: this buffer has no file; no question sent"))
  (let* ((file (expand-file-name buffer-file-name))
         (project (project-current nil (file-name-directory file))))
    (list :file file :root (file-name-as-directory
                           (file-truename (if project (project-root project) (file-name-directory file))))
          :line (line-number-at-pos) :column (current-column)
          :region (when (use-region-p) (list (region-beginning) (region-end)))
          :text (buffer-substring-no-properties (point-min) (point-max)))))

(defun lens-codex-question ()
  "Choose a preset question for the current file, then send it to read-only Codex."
  (interactive)
  (unless (and (bound-and-true-p lens-reading-mode) buffer-read-only (lens-eglot-language))
    (user-error "Code Lens: use c in a read-only Clojure/OCaml reading buffer"))
  (let* ((context (lens-codex-source-context))
         (file (plist-get context :file))
         (choices (mapcar (lambda (template) (format template (file-name-nondirectory file)))
                          lens-codex-prompt-templates))
         (question (completing-read "Codex 当前文件问题: " choices nil t))
         (prompt (format "只回答代码问题；不要修改文件、应用补丁、执行写操作或读取其他文件。\n%s\n\nProject: %s\nCurrent file: %s\nPosition: line %d, column %d\nSelection character bounds: %S\n\nCurrent-file buffer snapshot (including unsaved text):\n%s"
                         question (plist-get context :root) file
                         (plist-get context :line) (plist-get context :column)
                         (plist-get context :region) (plist-get context :text))))
    (lens-codex-dispatch context prompt)))

(defun lens-codex-session-settings ()
  "Mark only sessions launched by this adapter and keep asynchronous settings local."
  (when lens-codex-launch-p
    (setq-local lens-codex-session-p t)
    (setq-local lens-codex-pending-question lens-codex-initial-question)
    (setq-local codex-sandbox-mode 'read-only)
    (setq-local codex-approval-policy 'on-request)
    (setq-local codex-full-auto nil)))
(add-hook 'codex-start-hook #'lens-codex-session-settings)

(defun lens-codex-initialize-model (continue &rest args)
  "Select the server-advertised default before an owned QA thread starts.
This overrides only the session, leaving the user's CLI configuration alone."
  (if (not lens-codex-session-p) (apply continue args)
    (codex--app-server-send-request
     "model/list" '((limit . 50))
     (lambda (result error)
       (let* ((models (append (alist-get 'data result) nil))
              (model (or (cl-find-if (lambda (m) (eq (alist-get 'isDefault m) t)) models)
                         (car models)))
              (id (alist-get 'model model)))
         (if (or error (not (stringp id)))
             (progn
               (setq lens-codex-pending-question nil)
               (codex--app-server-insert-status "Code Lens: no advertised model available; no question sent"))
           (setq-local codex-model id)
           (setq-local codex-reasoning-effort (alist-get 'defaultReasoningEffort model))
           (apply continue args)))))))
(advice-add 'codex--app-server-after-initialize :around #'lens-codex-initialize-model)

(defun lens-codex-without-transcript-path (args)
  "Avoid reading private session transcripts when a fresh QA thread starts."
  (if (not lens-codex-session-p) args
    (let ((params (copy-tree (car args))))
      (setf (alist-get 'path (alist-get 'thread params)) nil)
      (cons params (cdr args)))))
(advice-add 'codex--app-server-thread-started :filter-args #'lens-codex-without-transcript-path)

(defun lens-codex-check-turn-permissions (&rest _)
  "Refuse QA turns unless the server confirms read-only and explicit approvals."
  (when lens-codex-session-p
    (let* ((settings codex--app-server-effective-permissions)
           (sandbox (alist-get 'sandboxPolicy settings))
           (kind (if (stringp sandbox) sandbox (alist-get 'type sandbox))))
      (unless (and (member kind '("readOnly" "read-only"))
                   (equal (alist-get 'approvalPolicy settings) "on-request"))
        (user-error "Code Lens: session has not confirmed read-only/on-request; no question sent")))))
(advice-add 'codex--app-server-send-turn-start :before #'lens-codex-check-turn-permissions)

(defun lens-codex-send-initial-question (&rest _)
  "Wait for confirmed thread/start permissions before sending the captured question.
The early thread/started notification may omit permission settings."
  (when (and lens-codex-session-p lens-codex-pending-question
             (assq 'approvalPolicy codex--app-server-effective-permissions)
             (assq 'sandboxPolicy codex--app-server-effective-permissions))
    (lens-codex-check-turn-permissions)
    (let ((prompt lens-codex-pending-question))
      (setq lens-codex-pending-question nil)
      (codex--send-command-to-buffer prompt (current-buffer)))))
(advice-add 'codex--app-server-thread-started :after #'lens-codex-send-initial-question)

(defun lens-codex-dispatch (context prompt)
  "Send PROMPT via the pinned package API, reusing only this adapter's QA session."
  (let* ((program (executable-find lens-codex-program))
         (root (plist-get context :root))
         (name (codex--buffer-name-for-directory root "lens-qa"))
         (buffer (get-buffer name)))
    (unless program
      (user-error "Code Lens: Codex CLI is missing from PATH; no question sent"))
    (unless (zerop (call-process program nil nil nil "login" "status"))
      (user-error "Code Lens: Codex CLI is not logged in; log in separately with codex login, then retry c"))
    (if (and buffer (codex--buffer-process-live-p buffer))
        (with-current-buffer buffer
          (unless lens-codex-session-p
            (user-error "Code Lens: this session is not an owned read-only QA session"))
          (lens-codex-check-turn-permissions)
          (codex--send-command-to-buffer prompt buffer)
          (pop-to-buffer buffer))
      (let ((codex-program program) (lens-codex-launch-p t)
            (lens-codex-initial-question prompt)
            (codex-terminal-backend 'app-server)
            (codex-sandbox-mode 'read-only) (codex-approval-policy 'on-request)
            (codex-full-auto nil) (codex-enable-hooks nil))
        (codex-start-session :directory root :instance-name "lens-qa"
                             :terminal-backend 'app-server)))))

(provide 'lens-codex)
