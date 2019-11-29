(straight-use-package 'treemacs)
(require 'treemacs)

(straight-use-package 'treemacs-evil)
(require 'treemacs-evil)

(define-key gus-spc-map "t" #'treemacs)

(provide 'gus-tree)
