(defvar gus-maximize-window-width 100
  "Width that a window will be set to when maximized.")
(defvar gus-minimize-window-width 50
  "Width that a window will be set to when minimized.")

(defun gus-maximize-window ()
  "Maxmize current window."
  (interactive)
  (evil-window-set-width gus-maximize-window-width))

(defun gus-minimize-window ()
  "Minimize current window."
  (interactive)
  (evil-window-set-width gus-minimize-window-width))

(define-key gus-spc-map "M" #'gus-maximize-window)
(define-key gus-spc-map "m" #'gus-minimize-window)

(straight-use-package 'centaur-tabs)

(require 'centaur-tabs)
(centaur-tabs-mode t)
;(global-set-key (kbd "C-<prior>")  'centaur-tabs-backward)
;(global-set-key (kbd "C-<next>") 'centaur-tabs-forward)




(provide 'gus-window)
