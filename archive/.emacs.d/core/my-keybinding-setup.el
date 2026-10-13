;; Called keybinding setup primarily because I don't do all my keybindings in here
;; Rather, I make the infrasructure to do later keybinding magic

;; Evil, of course
(use-package evil
  :demand t
  :init
  (setq evil-want-C-u-scroll t)
  (setq evil-want-Y-yank-to-eol t)
  (setq evil-emacs-state-modes nil)
  (setq evil-motion-state-modes nil)
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  :config
  ;; use normal everywhere
  (setq evil-normal-state-modes (append evil-emacs-state-modes
					evil-normal-state-modes))
  (define-key evil-normal-state-map "j" 'evil-next-visual-line)
  (define-key evil-normal-state-map "k" 'evil-previous-visual-line)
  (evil-mode 1))

(use-package evil-surround
  :demand t
  :after evil
  :config
  (global-evil-surround-mode 1))

;; Want a unified setup
;; Note: see my-org for evil org mode
(use-package evil-collection
  :defer nil
  :after evil
  :config
  (evil-collection-init)
  (push 'lispy evil-collection-mode-list)
  (evil-collection-init 'lispy))


;; Greatly simplifies keybindings
(use-package general)

(use-package key-chord
  :init
  ;(setq key-chord-two-keys-delay 0.5)
  (key-chord-mode 1))

(general-create-definer general-spc
  :states '(normal motion)
  :keymaps 'override
  :prefix "SPC")

(provide 'my-keybinding-setup)
