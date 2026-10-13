(straight-use-package 'counsel)

(evil-define-key 'normal global-map "/" #'swiper-isearch)
; Swiper means I need  to  reverse these for some reason
(evil-define-key 'motion global-map (kbd "n") #'evil-search-previous)
(evil-define-key 'motion global-map (kbd "N") #'evil-search-next)
(define-key gus-spc-map "p" #'counsel-yank-pop)
(define-key gus-spc-map "f" #'counsel-find-file)
(define-key gus-spc-map "x" #'counsel-M-x)
(define-key gus-spc-map "b" #'ivy-switch-buffer)
(define-key gus-spc-map "hf" #'counsel-describe-function)
(define-key gus-spc-map "hv" #'counsel-describe-variable)

(with-eval-after-load "ivy"
  (setq ivy-use-virtual-buffers t)
  (setq ivy-count-format "(%d/%d) ")
  (setq ivy-re-builders-alist
	'((t . ivy--regex-ignore-order)))
  (define-key ivy-minibuffer-map (kbd "C-j") #'ivy-next-line)
  (define-key ivy-switch-buffer-map (kbd "C-k") #'ivy-previous-line)
  (define-key ivy-minibuffer-map (kbd "C-k") #'ivy-previous-line))

(provide 'gus-completion)
