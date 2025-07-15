(use-package ace-window)

;; Let's try ivy mode (counsel brings in ivy and swiper as dependencies)
(use-package counsel
  :config
  (ivy-mode)
  (setq ivy-height 10)
  (setq ivy-use-virtual-buffers t)
  (setq ivy-count-format "%d/%d ")  ;; Use recentf and bookmarks
  (general-def 'ivy-mode-map "C-j" 'ivy-next-line "C-k" 'ivy-previous-line)
  (ivy-set-actions
   'counsel-switch-buffer
   '(("j" switch-to-buffer-other-window "other window")
     ("r" counsel-find-file-as-root "open as root"))))   

(general-spc
  "x" 'counsel-M-x
  "b" 'counsel-switch-buffer
  "B" 'counsel-switch-buffer-other-window
  "f" 'counsel-find-file
  "F" 'find-file-other-window

  ;; windows
  "\\" 'split-window-right
  "-" 'split-window-below
  "1" 'delete-other-windows
  "0" 'delete-window)

;; Easily switch windows
(general-def '(insert motion) "C-o" nil)
(general-def '(insert normal motion) '(help-mode-map dired-mode-map wdired-mode-map) "C-o" nil)
(general-def 'dired-mode-map "C-o" 'ace-window)
(general-def "C-o" 'ace-window)

(provide 'my-navigation)
