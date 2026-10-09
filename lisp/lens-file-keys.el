;;; lens-file-keys.el --- Keys scoped to file completion -*- lexical-binding: t; -*-
(require 'vertico)
(require 'subr-x)

(defun lens-file-completion-p ()
  "Return non-nil in a minibuffer completing the file category."
  (and (minibufferp)
       minibuffer-completion-table
       (eq 'file (completion-metadata-get
                  (completion-metadata (minibuffer-contents-no-properties)
                                       minibuffer-completion-table
                                       minibuffer-completion-predicate)
                  'category))))

(defun vertico-lens-file-enter ()
  "Insert the selected directory, or accept the selected file.
With no candidates, accept the input like RET, keeping directories open."
  (interactive)
  (unless (lens-file-completion-p)
    (user-error "This command requires file completion"))
  ;; The vertico- command prefix lets Vertico prepare fresh candidates even
  ;; when queued input caused its previous display update to be skipped.
  ;; Use the same public command as TAB, including its prompt-selection policy.
  (vertico-insert)
  (let ((path (minibuffer-contents-no-properties)))
    (unless (or (string-suffix-p "/" path)
                ;; A literal existing directory may lack its trailing slash.
                ;; Do not initiate a remote connection just to classify input.
                (and (not (equal path "")) (not (file-remote-p path))
                     (file-directory-p path)))
      (vertico-exit t))))

(defun lens-file-up ()
  "Remove the last path component from the minibuffer, retaining its parent.
Ignore point position and never delete any filesystem entity."
  (interactive)
  (unless (lens-file-completion-p)
    (user-error "This command requires file completion"))
  (let* ((path (minibuffer-contents-no-properties))
         (path (if (string-match-p "\\`~[^/]*/\\'" path)
                   (expand-file-name path) path))
         (remote (file-remote-p path))
         (parent (if (and remote (equal path (concat remote "/")))
                     path
                   (or (file-name-directory (directory-file-name path)) ""))))
    (delete-minibuffer-contents)
    (insert parent)))

(defun lens-file-keys-setup ()
  "Layer file keys over this minibuffer's existing completion map."
  (when (lens-file-completion-p)
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map (current-local-map))
      (keymap-set map "C-j" #'vertico-lens-file-enter)
      (keymap-set map "C-l" #'lens-file-up)
      (use-local-map map))))

;; Vertico installs its map first; leave its shared map and other prompts alone.
(add-hook 'minibuffer-setup-hook #'lens-file-keys-setup t)
(provide 'lens-file-keys)
