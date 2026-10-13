;; Evil, of course
(use-package evil
  :init
  (setq evil-want-C-u-scroll t)
  (setq evil-want-Y-yank-to-eol t)
  :config
  (define-key evil-normal-state-map "j" 'evil-next-visual-line)
  (define-key evil-normal-state-map "k" 'evil-previous-visual-line)
  (evil-mode 1))

(define-prefix-command 'my-prefix-map)

;; TODO make standard function for these and move them to their
;; own respective use-package blocks

;; Utils
(define-key my-prefix-map "x" 'counsel-M-x)
(define-key my-prefix-map "e" 'eval-buffer)
(define-key my-prefix-map ":" 'eval-expression)


;; Navigation
(define-key my-prefix-map "b" 'counsel-buffer-or-recentf)
(define-key my-prefix-map "f" 'counsel-find-file)
(define-key my-prefix-map "r" 'counsel-recentf)
(define-key my-prefix-map (kbd "TAB") 'other-window)

;; Windows
(define-key my-prefix-map (kbd "\\") 'split-window-right)
(define-key my-prefix-map (kbd "-") 'split-window-below)
(define-key my-prefix-map (kbd "1") 'delete-other-windows)
(define-key my-prefix-map (kbd "0") 'delete-window)

;; Org mode
(define-key my-prefix-map "oa" 'counsel-org-agenda-headlines)


(define-key evil-motion-state-map (kbd "SPC") 'my-prefix-map)

(provide 'my-keybindings)
