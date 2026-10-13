(straight-use-package 'flyspell)

(defun gus-text-mode-hook ()
  (turn-on-visual-line-mode)
  (flyspell-mode)
  (setq line-spacing 0.1))
;TODO try langtool for grammar analysis
;(add-hook 'markdown-mode-hook
;          (lambda () 
;             (add-hook 'after-save-hook 'langtool-check nil 'make-it-local)))
(evil-define-key 'normal text-mode-map ",f" #'flyspell-mode)
(remove-hook 'text-mode-hook #'turn-on-auto-fill)
(add-hook 'text-mode-hook #'gus-text-mode-hook)

(provide 'gus-text)
