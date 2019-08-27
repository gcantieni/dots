;; Make minor cosmetic and other adjustments that change emacs defaults
;; and don't require downloading packages
(require 'my-basics (concat user-emacs-directory "core/my-basics"))

;; On new install, bootsrap the straight package manager
;; Also install use-package and integrate it with straight
;; Now we can install packages with use-package and set straight
;; recipes with the :straight keyword.
(require 'my-package-system)

(require 'my-keybindings)

(require 'my-theme)

(require 'my-org)

(require 'my-completion)

(require 'my-web)
