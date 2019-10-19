(use-package lispy
  :config
  (general-def 'lispy-mode-map
    "M-o" nil
    "." nil))

(use-package racket-mode
  :config
  (general-def
    :keymaps 'racket-mode-map
    :states 'normal
    :prefix ","
    "r" 'racket-run))

(provide 'my-lisp)
