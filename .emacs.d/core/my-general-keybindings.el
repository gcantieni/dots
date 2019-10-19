;; Keybinding I don't know where to put

;; Global
(general-def
  "C-s" 'save-buffer
  "C-k" 'kill-this-buffer
  "C-=" 'text-scale-increase
  "C--" 'text-scale-decrease)


;; Swaps with evil mode
(general-def 'normal
  "a" #'evil-append-line
  "A" #'evil-append)

;; Insert state
(general-def 'insert
  "C-k" nil)
(general-def "M-k" nil)
; Abandoned (for now in favor of using M-k to mimic escape)
;(general-def
;  :keymaps 'evil-insert-state-map
;  (general-chord "kj") 'evil-normal-state
;  (general-chord "jk") 'evil-normal-state)

;; Global prefix
(general-spc
  "v" 'eval-buffer
  "hk" 'describe-key
  "hf" 'describe-function
  "hv" 'describe-variable
  "r" 'rename-buffer
  "`" 'eshell
  "~" 'shell
  "]" 'enlarge-window-horizontally
  "[" 'shrink-window-horizontally
  "i" 'imenu)

(provide 'my-general-keybindings)
