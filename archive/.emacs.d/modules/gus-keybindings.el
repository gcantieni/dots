(define-key global-map (kbd "C-k") nil)
(define-key evil-insert-state-map (kbd "C-k") nil)

(defvar gus-spc-map (make-sparse-keymap)
  "Keymap for global keybindings.  Intended to be prefixed by space.")
(define-minor-mode gus-spc-mode
  "Global mode to give precidence to gus-spc-map over others"
  :global t)
(gus-spc-mode)
(evil-make-intercept-map (evil-get-auxiliary-keymap gus-spc-map 'normal t t) 'normal)
(evil-make-intercept-map (evil-get-auxiliary-keymap gus-spc-map 'visual t t) 'visual)

; Unbind all maps where space is bound
(evil-define-key 'normal special-mode-map (kbd "SPC") nil)
(evil-define-key 'normal debugger-mode-map (kbd "SPC") nil)
(evil-define-key 'normal messages-buffer-mode-map (kbd "SPC") nil)
(evil-define-key 'normal dired-mode-map (kbd "SPC") nil)
(evil-define-key 'normal image-mode-map (kbd "SPC") nil)
;(define-key compilation-mode-map (kbd "SPC") nil) ; causes crash for some reason

(define-key evil-normal-state-map (kbd "SPC") gus-spc-map)
(define-key evil-motion-state-map (kbd "SPC") gus-spc-map)
(define-key gus-spc-map "0" #'delete-window)
(define-key gus-spc-map "1" #'delete-other-windows)
(define-key gus-spc-map "-" #'split-window-below)
(define-key gus-spc-map "\\" #'split-window-right)
(define-key gus-spc-map "`" #'eshell)
(define-key gus-spc-map "~" #'shell)
(define-key gus-spc-map "v" #'eval-buffer)
(define-key gus-spc-map "r" #'revert-buffer)
(define-key gus-spc-map "i" #'counsel-imenu)

;(define-key gus-spc-map (kbd "<tab>") #'switch-to-prev-buffer)

(define-key evil-normal-state-map "j" #'evil-next-visual-line)
(define-key evil-normal-state-map "k" #'evil-previous-visual-line)
(define-key evil-normal-state-map "a" #'evil-append-line)
(define-key evil-normal-state-map "A" #'evil-append)
(define-key evil-normal-state-map (kbd "<tab>") #'indent-for-tab-command)

(define-key global-map (kbd "M-o") #'other-window)
(define-key global-map (kbd "C-s") #'save-buffer)

(provide 'gus-keybindings)
