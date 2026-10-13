(straight-use-package 'evil)
(setq evil-want-C-u-scroll t)
(setq evil-want-keybinding nil)
(evil-mode)

(straight-use-package 'evil-collection)
(defun gus-prefix-translations (_mode mode-keymaps &rest _rest)
  (evil-collection-translate-key 'normal mode-keymaps
    (kbd "SPC") nil
    (kbd "C-SPC") (kbd "SPC"))
  (evil-collection-translate-key 'visual mode-keymaps
    (kbd "SPC") nil
    (kbd "C-SPC") (kbd "SPC")))
(add-hook 'evil-collection-setup-hook #'gus-prefix-translations)
(when (require 'evil-collection nil t)
  (evil-collection-init))

(straight-use-package 'evil-snipe)
(evil-snipe-mode)

(straight-use-package 'evil-easymotion)
(define-key evil-normal-state-map "m" nil)
(evilem-default-keybindings "m")
(define-key evil-normal-state-map "M" #'evil-set-marker)
(evil-define-key 'normal help-mode-map (kbd "SPC") nil)
 
(provide 'gus-evil)
