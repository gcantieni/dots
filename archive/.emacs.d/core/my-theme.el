;; Themes
;; uncomment for a more 'home grown' solution
;;(defun refresh-theme ()
;;  (progn
;;    (load-theme 'base16-wal t)))
;;(refresh-theme)

;; Inherit theme from wal
(use-package ewal
  :demand t
  :straight (ewal
             :type git
             :files ("ewal.el" "palettes")
             :host gitlab
             :branch "develop"
             :repo "jjzmajic/ewal")
  :init
  (setq ewal-use-built-in-always-p nil
	ewal-use-built-in-on-failure-p t
	ewal-built-in-palette "tango-dark"
	ewal-wal-json-file "~/.config/wpg/templates/colors.json"))

(use-package ewal-spacemacs-themes
  :demand t
  :after ewal
  :config
  (load-theme 'ewal-spacemacs-modern-high-contrast t)
  (enable-theme 'ewal-spacemacs-modern-high-contrast))

(use-package all-the-icons)

(use-package all-the-icons-dired)

(provide 'my-theme)
