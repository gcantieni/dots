(straight-use-package 'flycheck)
;(straight-use-package 'smartparens)
;(require 'smartparens-config)

(setq-default flycheck-disabled-checkers '(emacs-lisp emacs-lisp-checkdoc))
(defun gus-prog-mode-hook ()
  (display-line-numbers-mode)
  (flycheck-mode))
  ;(smartparens-mode))
(add-hook 'prog-mode-hook #'gus-prog-mode-hook)
(provide 'gus-prog)

