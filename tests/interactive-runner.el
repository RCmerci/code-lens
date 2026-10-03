;;; -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "tests/review-test.el" lens-root) nil t)
(add-hook
 'emacs-startup-hook
 (lambda ()
   (run-at-time
    0.1 nil
    (lambda ()
      (let ((report (or (getenv "CODE_LENS_TEST_REPORT")
                        (expand-file-name "docs/test-reports/completion-interactive.log" lens-root))))
        (make-directory (file-name-directory report) t)
        (condition-case failure
            (let ((stats (ert-run-tests-batch '(tag interactive))))
              (with-temp-file report
                (insert (format "Emacs %s; independent terminal startup\n" emacs-version))
                (insert (format "Real minibuffer tests: %s total, %s expected, %s unexpected\n"
                                (ert-stats-total stats)
                                (ert-stats-completed-expected stats)
                                (ert-stats-completed-unexpected stats)))
                (insert (format "Vertico=%S Marginalia=%S Fido=%S\n"
                                vertico-mode marginalia-mode fido-mode))
                (insert (lens-primary-package-summary)))
              (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1)))
          (error
           (with-temp-file report (insert (format "ERROR %S\n" failure)))
           (kill-emacs 1))))))))
