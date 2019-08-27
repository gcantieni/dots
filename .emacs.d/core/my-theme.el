;; Themes
;; uncomment for a more 'home grown' solution
;;(defun refresh-theme ()
;;  (progn
;;    (load-theme 'base16-wal t)))
;;(refresh-theme)

;; Inherit theme from wal
(use-package ewal
  :straight (ewal
             :type git
             :files ("ewal.el" "palettes")
             :host gitlab
             :branch "develop"
             :repo "jjzmajic/ewal"))

(use-package ewal-spacemacs-themes
  :config
  (load-theme 'ewal-spacemacs-modern t)
  (enable-theme 'ewal-spacemacs-modern))

(use-package all-the-icons)

(use-package all-the-icons-dired)

(provide 'my-theme)
