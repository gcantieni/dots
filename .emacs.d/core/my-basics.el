;; Custom paths
(add-to-list 'load-path (expand-file-name "core" user-emacs-directory))
(add-to-list 'custom-theme-load-path (expand-file-name "themes" user-emacs-directory))

;; Begone, bars!
(menu-bar-mode -1)
(tool-bar-mode -1)

(setq large-file-warning-threshold 100000000)

;; Don't backup in the current directory
(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))

;; Keep lots of history
(setq recentf-max-saved-items 5000)

;; Show the closing parentheses
(show-paren-mode)

;; Reload stuff sometimes
(defun my-reload-emacs-configuration ()
  (interactive)
  (load-file "~/.emacs.d/init.el"))

;; y or n is enough
(defalias 'yes-or-no-p #'y-or-n-p)

(provide 'my-basics)
