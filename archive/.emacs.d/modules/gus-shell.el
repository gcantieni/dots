(defun gus-clear-shell ()
  (interactive)
  (let ((comint-buffer-maximum-size 0))
    (comint-truncate-buffer)))
(define-key shell-mode-map (kbd "C-l") #'gus-clear-shell)

(defvar gus-shell-width 60
  "Initial window width for shell.")

(defun gus-shell-mode-hook ()
  (evil-window-set-width gus-shell-width))

(add-hook 'shell-mode-hook #'gus-shell-mode-hook)

(provide 'gus-shell)
