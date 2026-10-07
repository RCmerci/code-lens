;;; lens-input-source.el --- Foreground macOS input source policy -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'json)
(require 'lens-lsp)

(defgroup lens-input-source nil "System input sources for Code Lens." :group 'convenience)
(defcustom lens-input-source-english nil
  "Enabled English input-source ID, or nil to choose ABC/current English automatically."
  :type '(choice (const nil) string) :group 'lens-input-source)
(defcustom lens-input-source-chinese nil
  "Enabled Chinese input-source ID, or nil to use current/recent or the only Chinese source."
  :type '(choice (const nil) string) :group 'lens-input-source)
(defcustom lens-input-source-program nil
  "Guarded macism-backed helper, or nil to use the repository installation."
  :type '(choice (const nil) file) :group 'lens-input-source)
(defcustom lens-input-source-delay 0.05
  "Seconds to coalesce window/focus events before inspecting the system source."
  :type 'number :group 'lens-input-source)
(defvar lens-input-source--seen :initial)
(defvar lens-input-source--desired nil)
(defvar lens-input-source--job nil)
(defvar lens-input-source--process nil)
(defvar lens-input-source--timer nil)
(defvar lens-input-source--failed nil)
(defvar lens-input-source--recent-chinese nil)
(defvar lens-input-source-mode nil)

(defun lens-input-source-role ()
  "Classify the actual buffer mode, never a name or a generic terminal."
  (cond ((derived-mode-p 'codex-ide-session-mode) 'chinese)
        ((lens-eglot-language) 'english)))

(defun lens-input-source-focused-p ()
  "Require a visible, focused GUI frame; terminal focus cannot prove ownership."
  (and (eq system-type 'darwin) (not noninteractive)
       (display-graphic-p (selected-frame))
       (eq (frame-visible-p (selected-frame)) t)
       (eq (frame-focus-state (selected-frame)) t)))

(defun lens-input-source-context ()
  "Describe only the foreground selected window; other buffers preserve the source."
  (when (and (lens-input-source-focused-p)
             (not (window-minibuffer-p (selected-window))))
    (let ((buffer (window-buffer (selected-window))))
      (with-current-buffer buffer
        (when-let ((role (lens-input-source-role)))
          (list (selected-frame) (selected-window) buffer role
                lens-input-source-english lens-input-source-chinese))))))

(defun lens-input-source-target (role state)
  "Choose ROLE from enabled sources in STATE and remember an observed Chinese source."
  (let* ((sources (append (plist-get state :sources) nil))
         (current (plist-get state :current))
         (chinese (cl-remove-if-not
                   (lambda (source)
                     (cl-some (lambda (language) (string-prefix-p "zh" language))
                              (append (plist-get source :languages) nil))) sources))
         (english (cl-remove-if-not
                   (lambda (source)
                     (member "en" (append (plist-get source :languages) nil))) sources))
         (ids (mapcar (lambda (source) (plist-get source :id)) sources))
         (zh-ids (mapcar (lambda (source) (plist-get source :id)) chinese))
         (en-ids (mapcar (lambda (source) (plist-get source :id)) english))
         (explicit (if (eq role 'chinese) lens-input-source-chinese lens-input-source-english)))
    (unless (and (stringp current) sources)
      (error "Input-source helper returned incomplete system metadata"))
    (when (member current zh-ids) (setq lens-input-source--recent-chinese current))
    (cond
     (explicit
      (unless (member explicit ids)
        (user-error "Configured system input source is not enabled: %s" explicit))
      explicit)
     ((eq role 'english)
      (or (and (member "com.apple.keylayout.ABC" en-ids) "com.apple.keylayout.ABC")
          (and (member current en-ids) current)
          (and (member "com.apple.keylayout.US" en-ids) "com.apple.keylayout.US")
          (car en-ids)
          (user-error "No English system input source is enabled")))
     (t
      (or (and (member current zh-ids) current)
          (and (member lens-input-source--recent-chinese zh-ids) lens-input-source--recent-chinese)
          (and (= (length zh-ids) 1) (car zh-ids))
          (user-error "Choose lens-input-source-chinese from the enabled Chinese source IDs"))))))

(defun lens-input-source-valid-job-p ()
  (and lens-input-source-mode (not lens-input-source--failed)
       (equal (plist-get lens-input-source--job :context) lens-input-source--desired)
       (equal lens-input-source--desired (lens-input-source-context))))

(defun lens-input-source-finish ()
  "Finish one serialized job and schedule only a newer selected context."
  (let ((context (plist-get lens-input-source--job :context)))
    (setq lens-input-source--job nil)
    (when (and lens-input-source-mode lens-input-source--desired
               (not lens-input-source--failed)
               (not (equal context lens-input-source--desired)))
      (lens-input-source-schedule))))

(defun lens-input-source-fail (reason)
  "Stop automatic requests after a real error; mode re-enabling permits retry."
  (unless lens-input-source--failed
    (setq lens-input-source--failed reason)
    (message "Code Lens 系统输入源未切换：%s；修复后重新启用 lens-input-source-mode" reason))
  (lens-input-source-finish))

(defun lens-input-source-handle (phase code state)
  "Continue the current serialized PHASE only if its selected context is still valid."
  (condition-case failure
      (cond
       ((not (lens-input-source-valid-job-p)) (lens-input-source-finish))
       ((= code 3) (lens-input-source-finish)) ; Helper atomically rejected a background owner.
       ((not (= code 0)) (lens-input-source-fail (format "helper exit %s" code)))
       ((eq phase 'select) (lens-input-source-request 'verify '("--inspect")))
       ((not (and (listp state) (integerp (plist-get state :frontmost_pid))
                  (stringp (plist-get state :current)) (vectorp (plist-get state :sources))))
        (lens-input-source-fail "输入源工具返回无效系统状态"))
       ((not (equal (plist-get state :frontmost_pid) (emacs-pid)))
        (lens-input-source-finish))
       ((eq phase 'verify)
        (if (equal (plist-get state :current) (plist-get lens-input-source--job :target))
            (progn
              (lens-input-source-target (nth 3 lens-input-source--desired) state)
              (lens-input-source-finish))
          (lens-input-source-fail "系统输入源读回与目标不一致")))
       (t
        (let ((target (lens-input-source-target (nth 3 lens-input-source--desired) state)))
          (setf (plist-get lens-input-source--job :target) target)
          (if (equal target (plist-get state :current))
              (lens-input-source-finish)
            (lens-input-source-request 'select
                                       (list "--select" target "--owner-pid"
                                             (number-to-string (emacs-pid))))))))
    (error (lens-input-source-fail (error-message-string failure)))))

(defun lens-input-source-start-request (arguments callback)
  "Run one small system request asynchronously; never invoke a shell or send buffer text."
  (let* ((program (or lens-input-source-program
                      (expand-file-name ".local/tools/macism-3.1.1/bin/code-lens-input-source" lens-root)))
         (output (generate-new-buffer " *Code Lens input-source response*")))
    (unless (file-executable-p program)
      (kill-buffer output)
      (user-error "Input-source helper missing; run bin/bootstrap-input-source"))
    (condition-case failure
        (setq lens-input-source--process
              (make-process
               :name "Code Lens input-source" :buffer output :noquery t
               :command (cons program arguments) :connection-type 'pipe :coding 'utf-8-unix
               :sentinel
               (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (when (eq process lens-input-source--process)
                     (setq lens-input-source--process nil)
                     (let ((code (process-exit-status process)) state)
                       (when (and (= code 0) (equal arguments '("--inspect")))
                         (setq state (condition-case nil
                                         (with-current-buffer output
                                           (json-parse-string (buffer-string) :object-type 'plist
                                                              :array-type 'array :null-object nil
                                                              :false-object nil))
                                       (error nil))))
                       (funcall callback code state)))
                   (when (buffer-live-p output) (kill-buffer output))))))
      (error (kill-buffer output) (signal (car failure) (cdr failure))))))

(defun lens-input-source-request (phase arguments)
  (lens-input-source-start-request
   arguments (lambda (code state) (lens-input-source-handle phase code state))))

(defun lens-input-source-pump ()
  "Inspect once for the newest context; setter/readback requests are strictly serialized."
  (setq lens-input-source--timer nil)
  (when (and lens-input-source-mode (not lens-input-source--failed)
             (not lens-input-source--process) (not lens-input-source--job)
             lens-input-source--desired
             (equal lens-input-source--desired (lens-input-source-context)))
    (setq lens-input-source--job (list :context lens-input-source--desired))
    (condition-case failure
        (lens-input-source-request 'inspect '("--inspect"))
      (error (lens-input-source-fail (error-message-string failure))))))

(defun lens-input-source-schedule ()
  (when (timerp lens-input-source--timer) (cancel-timer lens-input-source--timer))
  (setq lens-input-source--timer (run-at-time lens-input-source-delay nil #'lens-input-source-pump)))

(defun lens-input-source-observe (&rest _)
  "Cheap event observer: unchanged windows never launch an external process."
  (when lens-input-source-mode
    (let ((context (lens-input-source-context)))
      (unless (equal context lens-input-source--seen)
        (setq lens-input-source--seen context lens-input-source--desired context)
        (when (timerp lens-input-source--timer)
          (cancel-timer lens-input-source--timer) (setq lens-input-source--timer nil))
        (when (and context (not lens-input-source--failed)) (lens-input-source-schedule))))))

(define-minor-mode lens-input-source-mode
  "Switch macOS system sources for foreground code/Codex chat buffers only."
  :global t :group 'lens-input-source
  (if lens-input-source-mode
      (progn
        (setq lens-input-source--seen :initial lens-input-source--failed nil)
        (add-hook 'window-buffer-change-functions #'lens-input-source-observe)
        (add-hook 'window-selection-change-functions #'lens-input-source-observe)
        (add-hook 'post-command-hook #'lens-input-source-observe)
        (add-function :after after-focus-change-function #'lens-input-source-observe)
        (lens-input-source-observe))
    (remove-hook 'window-buffer-change-functions #'lens-input-source-observe)
    (remove-hook 'window-selection-change-functions #'lens-input-source-observe)
    (remove-hook 'post-command-hook #'lens-input-source-observe)
    (remove-function after-focus-change-function #'lens-input-source-observe)
    (when (timerp lens-input-source--timer) (cancel-timer lens-input-source--timer))
    (setq lens-input-source--timer nil lens-input-source--desired nil lens-input-source--seen :initial)))

(provide 'lens-input-source)
