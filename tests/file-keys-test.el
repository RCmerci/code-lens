;;; file-keys-test.el --- Buffer and file minibuffer keys -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(unless (ert-test-boundp 'lens-isolated-runtime)
  (load (expand-file-name "tests/review-test.el" lens-root) nil t))

(ert-deftest lens-kill-current-buffer-without-selection ()
  (let ((buffer (generate-new-buffer " *lens-kill*")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buffer)
          (should (eq (key-binding (kbd "C-x k")) #'lens-source-quit))
          (execute-kbd-macro (kbd "C-x k"))
          (should-not (buffer-live-p buffer))
          (should-not (active-minibuffer-window)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest lens-kill-current-buffer-preserves-query-functions ()
  (let ((buffer (generate-new-buffer " *lens-veto*")) queried)
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buffer)
          (setq-local kill-buffer-query-functions
                      (list (lambda () (setq queried t) nil)))
          (should (eq (key-binding (kbd "C-x k")) #'lens-source-quit))
          (call-interactively (key-binding (kbd "C-x k")))
          (should queried)
          (should (buffer-live-p buffer)))
      (with-current-buffer buffer (setq kill-buffer-query-functions nil))
      (kill-buffer buffer))))

(ert-deftest lens-file-keys-help-and-map-isolation ()
  (should-not (eq (keymap-lookup vertico-map "C-j") 'vertico-lens-file-enter))
  (should-not (eq (keymap-lookup minibuffer-local-map "C-l") 'lens-file-up))
  (let ((text (lens-help-text)))
    (should (string-match-p "C-x k.*当前 buffer" text))
    (should (string-match-p "C-j.*目录.*文件" text))
    (should (string-match-p "C-l.*路径" text))))

(defmacro lens-file-keys-fixture (&rest body)
  "Evaluate BODY in a temporary directory, without starting language servers."
  `(let* ((directory (file-name-as-directory (make-temp-file "lens-file-keys-" t)))
          (default-directory directory)
          (lens-eglot-auto-start nil)
          (file (expand-file-name "子目录/空间 文件.txt" directory)))
     (unwind-protect
         (progn
           (make-directory (file-name-directory file) t)
           (with-temp-file file (insert "saved fixture\n"))
           ,@body)
       (dolist (buffer (buffer-list))
         (when-let ((name (buffer-file-name buffer)))
           (when (string-prefix-p directory name)
             (with-current-buffer buffer (set-buffer-modified-p nil))
             (kill-buffer buffer))))
       (delete-directory directory t))))

(defun lens-file-keys-read (reader keys probes)
  "Run READER using KEYS; each F8 runs the next assertion in PROBES."
  (let ((old (keymap-lookup (current-global-map) "C-c C-t")) result)
    (unwind-protect
        (progn
          (keymap-global-set "C-c C-t"
                             (lambda () (interactive) (setq result (funcall reader))))
          (minibuffer-with-setup-hook
              (:append
               (lambda ()
                 (when minibuffer-completing-file-name
                   (should (eq (key-binding (kbd "C-j")) 'vertico-lens-file-enter))
                   (should (eq (key-binding (kbd "C-l")) 'lens-file-up)))
                 (let ((map (make-sparse-keymap)))
                   (set-keymap-parent map (current-local-map))
                   (keymap-set map "<f8>"
                               (lambda () (interactive)
                                 (should probes)
                                 (funcall (pop probes))))
                   (use-local-map map))))
            (condition-case nil
                (execute-kbd-macro (vconcat (kbd "C-c C-t") keys))
              (quit (setq quit-flag nil))))
          (should-not probes)
          (should-not (active-minibuffer-window))
          result)
      (keymap-global-set "C-c C-t" old))))

(ert-deftest lens-file-keys-interactive-directory-then-file ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (lens-file-keys-fixture
   (save-window-excursion
     (lens-file-keys-read
      (lambda () (let ((default-directory directory)) (call-interactively #'find-file)))
      (vconcat "子" (kbd "C-j <f8>") "空间" (kbd "C-j"))
      (list (lambda ()
              (should (eq (key-binding (kbd "C-j")) 'vertico-lens-file-enter))
              (should (eq (key-binding (kbd "C-l")) 'lens-file-up))
              (should (equal (minibuffer-contents-no-properties)
                             (expand-file-name "子目录/" directory))))))
     (should (equal (buffer-file-name) file))
     (should (equal (buffer-string) "saved fixture\n")))))

(ert-deftest lens-file-keys-interactive-selected-candidate ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (lens-file-keys-fixture
   (with-temp-file (expand-file-name "子目录/another.txt" directory) (insert "second"))
   ;; Use public navigation commands and TAB to observe the selected candidate,
   ;; then C-j must accept that exact selection, rather than the first match.
   (let (selected)
     (let ((result
            (lens-file-keys-read
             (lambda () (read-file-name "File: " directory))
             (vconcat "子目录/" (kbd "C-n C-n TAB <f8> C-j"))
             (list (lambda () (setq selected (minibuffer-contents-no-properties)))))))
       (should (equal result selected))
       (should (file-regular-p result))))))

(ert-deftest lens-file-keys-interactive-up-path-boundaries ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (lens-file-keys-fixture
   (dolist (entry `((,file . ,(file-name-directory file))
                    (,(file-name-directory file) . ,directory)
                    ("/" . "/") ("" . "")
                    ("relative" . "") ("relative/" . "")
                    ("relative/leaf" . "relative/")
                    ("~/" . ,(file-name-directory (directory-file-name (expand-file-name "~/"))))))
     (lens-file-keys-read
      (lambda () (read-file-name "File: " directory))
      (kbd "<f8> C-l <f8> C-g")
      (list (lambda () (delete-minibuffer-contents) (insert (car entry))
              ;; C-l always removes the last component, even with point earlier.
              (goto-char (minibuffer-prompt-end)))
            (lambda () (should (equal (minibuffer-contents-no-properties) (cdr entry)))))))
   (should (file-exists-p file))
   (should (file-directory-p (file-name-directory file)))))

(ert-deftest lens-file-keys-interactive-no-candidates-and-directory-input ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (lens-file-keys-fixture
   (let ((result (lens-file-keys-read
                    (lambda () (read-file-name "File: " directory))
                    (vconcat "new.txt" (kbd "C-j")) nil)))
       (should (equal result (expand-file-name "new.txt" directory)))
     (should-not (file-exists-p result)))
   ;; Use a genuine empty file-category table for literal directory input;
   ;; real directories otherwise have selectable children rather than no match.
   (dolist (input (list "/" (file-name-directory file)
                         (directory-file-name (file-name-directory file))))
       (lens-file-keys-read
        (lambda ()
          (completing-read
           "Empty file table: "
           (lambda (input predicate action)
             (if (eq action 'metadata)
                 '(metadata (category . file))
               (complete-with-action action nil input predicate)))))
        (kbd "<f8> C-j <f8> C-g")
        (list (lambda () (delete-minibuffer-contents) (insert input)
                (should-not (all-completions input minibuffer-completion-table
                                             minibuffer-completion-predicate)))
              (lambda ()
                (should (file-directory-p (minibuffer-contents-no-properties)))))))))

(ert-deftest lens-file-keys-interactive-nonfile-and-codex-scope ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (dolist (reader (list (lambda () (read-string "Text: "))
                       (lambda () (completing-read "Codex question: " '("prompt one" "prompt two")))))
    (should
     (equal "prompt one"
            (lens-file-keys-read
             reader (vconcat "prompt one" (kbd "<f8> C-l C-j"))
             (list (lambda ()
                     (should-not (eq (key-binding (kbd "C-j")) 'vertico-lens-file-enter))
                     (should-not (eq (key-binding (kbd "C-l")) 'lens-file-up)))))))))

(ert-deftest lens-kill-current-buffer-interactive-unsaved-file ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (lens-file-keys-fixture
   (save-window-excursion
     (switch-to-buffer (find-file-noselect file))
     (insert "unsaved")
     (let ((buffer (current-buffer)) (text (buffer-string)))
       (should (eq (key-binding (kbd "C-x k")) #'lens-source-quit))
       (execute-kbd-macro (kbd "C-x k n"))
       (should (buffer-live-p buffer))
       (should (buffer-modified-p))
       (should (equal text (buffer-string)))
       (should (equal "saved fixture\n"
                      (with-temp-buffer (insert-file-contents file) (buffer-string))))))))

(ert-deftest lens-kill-current-buffer-interactive-active-process ()
  :tags '(interactive file-keys-interactive)
  (skip-unless (not noninteractive))
  (let* ((buffer (generate-new-buffer " *lens-process*"))
         (process (start-process "lens-query" buffer "/bin/cat")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buffer)
          (should (eq (key-binding (kbd "C-x k")) #'lens-source-quit))
       (execute-kbd-macro (kbd "C-x k n"))
          (should (buffer-live-p buffer))
          (should (process-live-p process)))
      (set-process-query-on-exit-flag process nil)
      (delete-process process)
      (kill-buffer buffer))))
