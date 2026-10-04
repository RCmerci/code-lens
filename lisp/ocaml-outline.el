;;; ocaml-outline.el --- Eglot-powered OCaml outline -*- lexical-binding: t; -*-
;; Vendored from the user's ~/.emacs.d/myown/ocaml-outline.el on 2026-10-04.
;; Original source SHA-256: 061ec7aec1dabe54cfccf1d76124200cc9dd069732c4bcf8e7e8a3f5a6e01316
;; Runtime loads this repository copy; the personal configuration is not required.

(require 'eglot)
(require 'button)
(require 'seq)
(require 'subr-x)


;;; ---------------------------------------------------------------------------
;;; State
;;; ---------------------------------------------------------------------------

(defvar-local ocaml-outline-source-buffer nil
  "Source buffer associated with this outline buffer.")

(defvar-local ocaml-outline-buffer nil
  "Outline buffer associated with this source buffer.")

(defvar-local ocaml-outline--entries nil
  "Symbols displayed by the current outline buffer.")

(defvar-local ocaml-outline--current-entry nil
  "Currently highlighted outline entry.")

(defvar-local ocaml-outline--highlight-overlay nil
  "Overlay used to highlight the current symbol.")

(defvar-local ocaml-outline--last-source-point nil
  "Last source point synchronized with the outline.")

(defconst ocaml-outline--line-count-gutter-width 5
  "Width of the source line count gutter.")


;;; ---------------------------------------------------------------------------
;;; Faces
;;; ---------------------------------------------------------------------------

(defface ocaml-outline-current-symbol
  '((t (:inherit highlight :extend t)))
  "Face used for the current symbol in OCaml Outline."
  :group 'ocaml-outline)


;;; ---------------------------------------------------------------------------
;;; Eglot symbol metadata
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--kind (name)
  "Return the LSP SymbolKind associated with NAME.

Recent Eglot versions store this in the `imenu-kind' text
property.  `breadcrumb-kind' is supported for compatibility with
older Eglot versions."
  (or (get-text-property 0 'imenu-kind name)
      (get-text-property 0 'breadcrumb-kind name)
      "Unknown"))


(defun ocaml-outline--region (name)
  "Return the source region associated with NAME.

The result is normally a cons cell:

    (BEG . END)

coming from the LSP DocumentSymbol range."
  (or (get-text-property 0 'imenu-region name)
      (get-text-property 0 'breadcrumb-region name)))


(defun ocaml-outline--kind-label (kind)
  "Translate generic LSP KIND into an OCaml-oriented label."
  (pcase kind
    ("Module"        "module")
    ("Namespace"     "module")
    ("Interface"     "module type")

    ("Struct"        "type")
    ("Enum"          "type")

    ("Class"         "class")
    ("Method"        "method")
    ("Property"      "property")

    ("Function"      "function")
    ("Variable"      "value")
    ("Constant"      "value")

    ("Constructor"   "ctor")
    ("EnumMember"    "ctor")

    ("Operator"      "operator")
    ("TypeParameter" "type param")

    ("Field"         "field")

    (_
     (downcase kind))))


;;; ---------------------------------------------------------------------------
;;; Jumping
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--jump (button)
  "Jump to the source location associated with BUTTON."
  (let ((buffer (button-get button 'source-buffer))
        (marker (button-get button 'source-marker)))

    (unless (and (buffer-live-p buffer)
                 (markerp marker)
                 (marker-buffer marker))
      (user-error "Source location no longer exists"))

    ;; Prefer an already visible source window.
    (if-let ((window (get-buffer-window buffer t)))
        (select-window window)
      (pop-to-buffer buffer))

    (goto-char marker)
    (recenter)))


;;; ---------------------------------------------------------------------------
;;; Building outline entries
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--source-line-count (source beg end)
  "Return the number of source lines covered by [BEG, END) in SOURCE."
  (let ((beg (if (markerp beg) (marker-position beg) beg))
        (end (if (markerp end) (marker-position end) end)))
    (if (>= beg end)
        0
      (with-current-buffer source
        (save-restriction
          (widen)
          (count-lines beg end))))))


(defun ocaml-outline--line-count-gutter (line-count)
  "Return the fixed-width gutter for LINE-COUNT."
  (if line-count
      (let ((text (number-to-string line-count)))
        (propertize
         (concat text
                 (make-string
                  (max 0
                       (- ocaml-outline--line-count-gutter-width
                          (length text)))
                  ?\s))
         'face 'shadow))
    (make-string ocaml-outline--line-count-gutter-width ?\s)))


(defun ocaml-outline--insert-entry (entry depth source &optional parent)
  "Insert one Imenu ENTRY recursively.

DEPTH is the nesting depth.
SOURCE is the original OCaml source buffer.
PARENT is the rendered parent entry, or nil for a root entry."
  (let* ((name (car entry))
         (value (cdr entry))

         ;; Eglot represents nested DocumentSymbols as nested Imenu
         ;; entries.
         (children
          (and (listp value)
               value))

         (kind
          (ocaml-outline--kind name))

         (label
          (ocaml-outline--kind-label kind))

         (region
          (ocaml-outline--region name))

         (valid-region
          (and region
               (number-or-marker-p (car region))
               (number-or-marker-p (cdr region))))

         (line-count
          (and (= depth 0)
               valid-region
               (ocaml-outline--source-line-count
                source
                (car region)
                (cdr region))))

         ;; Leaf entries may still have an ordinary Imenu position.
         (pos
          (or (car-safe region)
              (and (number-or-marker-p value)
                   value)))

         (indent
          (make-string (* depth 2) ?\s))

         (outline-beg
          (point))

         (toggle-marker nil)

         (rendered-entry nil))

    ;; Source line count gutter
    (insert
     (ocaml-outline--line-count-gutter line-count))

    ;; Indentation
    (insert indent)

    ;; Disclosure indicator
    (if children
        (setq toggle-marker
              (insert-text-button
               " "
               'display "▾"
               'follow-link t
               'help-echo "Collapse"
               'action #'ocaml-outline--toggle-button))

      (insert " "))

    (insert " ")

    ;; Kind label
    (insert
     (propertize
      (format "%-11s " label)
      'face 'font-lock-keyword-face))

    ;; Symbol name
    (if pos
        (insert-text-button
         (substring-no-properties name)

         'follow-link t

         'help-echo
         (format "%s — %s"
                 kind
                 (substring-no-properties name))

         'source-buffer source

         'source-marker
         (with-current-buffer source
           (copy-marker pos))

         'action
         #'ocaml-outline--jump)

      ;; No position: display as plain text.
      (insert
       (substring-no-properties name)))

    (insert "\n")

    ;; Register the tree, source, and outline ranges.
    ;;
    ;; This is what allows cursor-following without issuing another
    ;; LSP request.
    (let ((outline-end (point)))

      (setq rendered-entry
            (list
             :name
             (substring-no-properties name)

             :kind
             kind

             :depth
             depth

             :parent
             parent

             :has-children
             (and children t)

             :source-beg
             (when valid-region
               (with-current-buffer source
                 (copy-marker (car region))))

             :source-end
             (when valid-region
               (with-current-buffer source
                 (copy-marker (cdr region) t)))

             :outline-beg
             (copy-marker outline-beg)

             :outline-end
             (copy-marker outline-end)

             :toggle-marker
             toggle-marker))

      (when toggle-marker
        (button-put toggle-marker
                    'ocaml-outline-entry
                    rendered-entry))

      (push rendered-entry ocaml-outline--entries))

    ;; Children
    (when children
      (dolist (child children)
        (ocaml-outline--insert-entry
         child
         (1+ depth)
         source
         rendered-entry))

      (plist-put rendered-entry
                 :subtree-end
                 (copy-marker (point)))

      (ocaml-outline--collapse-entry rendered-entry))))


;;; ---------------------------------------------------------------------------
;;; Expanding and collapsing
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--entry-collapsed-p (entry)
  "Return non-nil when ENTRY currently hides its descendants."
  (when-let ((overlay (plist-get entry :fold-overlay)))
    (overlay-buffer overlay)))


(defun ocaml-outline--set-disclosure (entry collapsed)
  "Set ENTRY's disclosure indicator for COLLAPSED state."
  (when-let* ((marker (plist-get entry :toggle-marker))
              (button (button-at marker)))
    (let ((inhibit-read-only t))
      (button-put button 'display (if collapsed "▸" "▾"))
      (button-put button 'help-echo (if collapsed "Expand" "Collapse")))))


(defun ocaml-outline--expand-entry (entry)
  "Expand ENTRY if it is collapsed."
  (when-let ((overlay (plist-get entry :fold-overlay)))
    (delete-overlay overlay)
    (plist-put entry :fold-overlay nil)
    (ocaml-outline--set-disclosure entry nil)))


(defun ocaml-outline--collapse-entry (entry)
  "Collapse ENTRY by hiding all of its descendants."
  (let ((overlay
         (make-overlay (plist-get entry :outline-end)
                       (plist-get entry :subtree-end))))
    (overlay-put overlay 'invisible 'ocaml-outline)
    (overlay-put overlay 'ocaml-outline-fold t)
    (plist-put entry :fold-overlay overlay)
    (ocaml-outline--set-disclosure entry t)))


(defun ocaml-outline--entry-at-point ()
  "Return the rendered entry on the current line."
  (let ((line-beg (line-beginning-position)))
    (seq-find
     (lambda (entry)
       (= (plist-get entry :outline-beg) line-beg))
     ocaml-outline--entries)))


(defun ocaml-outline--toggle-button (button)
  "Toggle the outline entry represented by BUTTON."
  (ocaml-outline-toggle
   (button-get button 'ocaml-outline-entry)))


(defun ocaml-outline-toggle (&optional entry)
  "Toggle descendants of ENTRY or the entry on the current line."
  (interactive)
  (let ((entry (or entry
                   (ocaml-outline--entry-at-point))))
    (unless entry
      (user-error "No outline entry on this line"))

    (unless (plist-get entry :has-children)
      (user-error "Outline entry has no children"))

    (if (ocaml-outline--entry-collapsed-p entry)
        (ocaml-outline--expand-entry entry)
      (ocaml-outline--collapse-entry entry))))


(defun ocaml-outline--reveal-entry (entry)
  "Expand the ancestors hiding ENTRY."
  (let ((parent (plist-get entry :parent)))
    (while parent
      (ocaml-outline--expand-entry parent)
      (setq parent (plist-get parent :parent)))))


;;; ---------------------------------------------------------------------------
;;; Finding current source symbol
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--best-entry (source-point)
  "Return the most specific entry containing SOURCE-POINT.

If both a module and a function contain point, the function wins
because its source range is smaller."
  (let ((best nil)
        (best-size most-positive-fixnum)
        (best-depth -1))

    (dolist (entry ocaml-outline--entries)

      (let* ((beg-marker
              (plist-get entry :source-beg))

             (end-marker
              (plist-get entry :source-end))

             (depth
              (or (plist-get entry :depth)
                  0))

             (beg
              (and (markerp beg-marker)
                   (marker-position beg-marker)))

             (end
              (and (markerp end-marker)
                   (marker-position end-marker))))

        (when (and beg
                   end
                   (<= beg source-point)
                   (< source-point end))

          (let ((size (- end beg)))

            ;; Normally the smallest range is the deepest symbol.
            ;;
            ;; DEPTH is used as a tie-breaker in case two symbols
            ;; happen to have identical source ranges.
            (when (or (< size best-size)
                      (and (= size best-size)
                           (> depth best-depth)))

              (setq best entry
                    best-size size
                    best-depth depth))))))

    best))


;;; ---------------------------------------------------------------------------
;;; Highlighting
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--clear-highlight ()
  "Remove the current outline highlight."
  (when (overlayp ocaml-outline--highlight-overlay)
    (delete-overlay
     ocaml-outline--highlight-overlay))

  (setq ocaml-outline--highlight-overlay nil
        ocaml-outline--current-entry nil))


(defun ocaml-outline--show-entry (entry)
  "Highlight ENTRY and move point to its line in the outline buffer."
  (if (null entry)

      ;; Point isn't inside a known symbol.
      (ocaml-outline--clear-highlight)

    (ocaml-outline--reveal-entry entry)

    (let* ((beg-marker
            (plist-get entry :outline-beg))

           (end-marker
            (plist-get entry :outline-end))

           (beg
            (marker-position beg-marker))

           (end
            (marker-position end-marker)))

      (unless (eq entry ocaml-outline--current-entry)
        (setq ocaml-outline--current-entry entry)

        ;; Create overlay lazily.
        (unless (overlayp ocaml-outline--highlight-overlay)
          (setq ocaml-outline--highlight-overlay
                (make-overlay beg end))

          (overlay-put ocaml-outline--highlight-overlay
                       'face
                       'ocaml-outline-current-symbol)

          (overlay-put ocaml-outline--highlight-overlay
                       'priority
                       10))

        ;; Move existing overlay.
        (move-overlay ocaml-outline--highlight-overlay beg end))

      (goto-char beg)

      ;; Keep the cursor on the highlighted line.  Recenter only when
      ;; the entry was outside the visible portion of the outline.
      (when-let ((window
                  (get-buffer-window (current-buffer) t)))
        (let ((visible
               (pos-visible-in-window-p beg window)))
          (set-window-point window beg)

          (unless visible
            (with-selected-window window
              (recenter))))))))


(defun ocaml-outline--highlight-source-point (source-point)
  "Highlight the symbol containing SOURCE-POINT."
  (ocaml-outline--show-entry
   (ocaml-outline--best-entry
    source-point)))


;;; ---------------------------------------------------------------------------
;;; Source → outline synchronization
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--sync ()
  "Synchronize the outline with point in the source buffer.

This function is intended for `post-command-hook'."
  (when
      (and
       (buffer-live-p ocaml-outline-buffer)

       ;; Avoid unnecessary work for commands that don't move point.
       (not
        (equal
         (point)
         ocaml-outline--last-source-point)))

    (let ((source-point
           (point))

          (outline
           ocaml-outline-buffer))

      (setq
       ocaml-outline--last-source-point
       source-point)

      (with-current-buffer outline
        (ocaml-outline--highlight-source-point
         source-point)))))


;;; ---------------------------------------------------------------------------
;;; Refresh
;;; ---------------------------------------------------------------------------

(defun ocaml-outline-refresh ()
  "Rebuild the current OCaml outline from Eglot."
  (interactive)

  (unless
      (buffer-live-p
       ocaml-outline-source-buffer)

    (user-error
     "Source buffer no longer exists"))

  (let* ((source
          ocaml-outline-source-buffer)

         ;; This is the only place where we ask Eglot for a fresh
         ;; DocumentSymbol tree.
         (index
          (with-current-buffer source

            (unless
                (eglot-current-server)

              (user-error
               "Source buffer is not managed by Eglot"))

            (eglot-imenu))))

    (let ((inhibit-read-only t))

      ;; Reset state from the previous rendering.
      (ocaml-outline--clear-highlight)

      (remove-overlays nil nil 'ocaml-outline-fold t)

      (setq
       ocaml-outline--entries
       nil)

      (erase-buffer)

      ;; Header
      (insert
       (propertize
        (format "%s\n"
                (buffer-name source))
        'face 'bold))

      (insert "\n")

      ;; Symbols
      (dolist (entry index)
        (ocaml-outline--insert-entry
         entry
         0
         source))

      ;; Entries were accumulated using PUSH.  Their ordering doesn't
      ;; matter for matching, but reversing is nicer for debugging.
      (setq
       ocaml-outline--entries
       (nreverse
        ocaml-outline--entries))

      (goto-char
       (point-min)))

    ;; Record the source position without revealing its outline path.
    ;; The next actual source movement will synchronize normally.
    (let ((source-point
           (if-let ((window
                     (get-buffer-window
                      source
                      t)))

               (window-point window)

             (with-current-buffer source
               (point)))))

      (with-current-buffer source
        (setq
         ocaml-outline--last-source-point
         source-point)))))


;;; ---------------------------------------------------------------------------
;;; Cleanup
;;; ---------------------------------------------------------------------------

(defun ocaml-outline--cleanup ()
  "Detach the current outline from its source buffer."
  (let ((outline
         (current-buffer))

        (source
         ocaml-outline-source-buffer))

    (when
        (buffer-live-p source)

      (with-current-buffer source

        (when
            (eq ocaml-outline-buffer
                outline)

          (remove-hook
           'post-command-hook
           #'ocaml-outline--sync
           t)

          (setq
           ocaml-outline-buffer
           nil

           ocaml-outline--last-source-point
           nil))))))


(defun ocaml-outline--source-killed ()
  "Kill the outline buffer when its source buffer is killed."
  (when
      (buffer-live-p ocaml-outline-buffer)

    (kill-buffer
     ocaml-outline-buffer)))


;;; ---------------------------------------------------------------------------
;;; Major mode
;;; ---------------------------------------------------------------------------

(defvar ocaml-outline-mode-map
  (let ((map
         (make-sparse-keymap)))

    (set-keymap-parent
     map
     special-mode-map)

    (define-key
     map
     (kbd "g")
     #'ocaml-outline-refresh)

    (define-key
     map
     (kbd "q")
     #'quit-window)

    (define-key
     map
     (kbd "n")
     #'forward-button)

    (define-key
     map
     (kbd "p")
     #'backward-button)

    (define-key
     map
     (kbd "TAB")
     #'ocaml-outline-toggle)

    (define-key
     map
     (kbd "<tab>")
     #'ocaml-outline-toggle)

    map)
  "Keymap for `ocaml-outline-mode'.")


(define-derived-mode
  ocaml-outline-mode
  special-mode
  "OCaml-Outline"

  "Major mode for displaying OCaml symbols from Eglot."

  (setq-local
   truncate-lines
   t)

  (add-to-invisibility-spec
   'ocaml-outline)

  (add-hook
   'kill-buffer-hook
   #'ocaml-outline--cleanup
   nil
   t))


;;; ---------------------------------------------------------------------------
;;; Main command
;;; ---------------------------------------------------------------------------

(defun ocaml-outline ()
  "Show an Eglot-powered OCaml outline in a right side window."
  (interactive)

  (unless
      (eglot-current-server)

    (user-error
     "Current buffer is not managed by Eglot"))

  (let* ((source
          (current-buffer))

         (name
          (format
           "*OCaml Outline: %s*"
           (buffer-name source)))

         (outline
          (get-buffer-create
           name)))

    ;; -----------------------------------------------------------------------
    ;; Source setup
    ;; -----------------------------------------------------------------------

    (setq-local
     ocaml-outline-buffer
     outline)

    (setq-local
     ocaml-outline--last-source-point
     nil)

    ;; Avoid duplicate hooks if `ocaml-outline' is called repeatedly.
    (remove-hook
     'post-command-hook
     #'ocaml-outline--sync
     t)

    (add-hook
     'post-command-hook
     #'ocaml-outline--sync
     nil
     t)

    (remove-hook
     'kill-buffer-hook
     #'ocaml-outline--source-killed
     t)

    (add-hook
     'kill-buffer-hook
     #'ocaml-outline--source-killed
     nil
     t)

    ;; -----------------------------------------------------------------------
    ;; Outline setup
    ;; -----------------------------------------------------------------------

    (with-current-buffer outline

      (ocaml-outline-mode)

      (setq-local
       ocaml-outline-source-buffer
       source)

      (ocaml-outline-refresh))

    ;; -----------------------------------------------------------------------
    ;; Display
    ;; -----------------------------------------------------------------------

    (display-buffer-in-side-window
     outline
     '((side . right)
       (slot . 0)
       (window-width . 0.30)))))


(provide 'ocaml-outline)

;;; ocaml-outline.el ends here
