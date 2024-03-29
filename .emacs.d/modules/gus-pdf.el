(straight-use-package 'pdf-tools)
(setq-default pdf-view-display-size 'fit-page)
(pdf-loader-install)
(defvar gus-scroll-width 30)
(defun gus-pdf-down ()
  (interactive)
  (evil-collection-pdf-view-next-line-or-next-page gus-scroll-width))
(defun gus-pdf-up ()
  (interactive)
  (evil-collection-pdf-view-previous-line-or-previous-page gus-scroll-width))
(evil-define-key 'normal pdf-view-mode-map (kbd "SPC") nil)
(evil-define-key 'motion image-mode-map (kbd "SPC") nil)
(evil-define-key 'normal pdf-view-mode-map "d" #'gus-pdf-down)
(evil-define-key 'normal pdf-view-mode-map "u" #'gus-pdf-up)
(evil-define-key 'normal pdf-view-mode-map ",m" #'pdf-view-midnight-minor-mode)
(provide 'gus-pdf)
