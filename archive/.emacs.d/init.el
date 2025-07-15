;; Make minor cosmetic and other adjustments that change emacs defaults
;; and don't require downloading packages
(require 'my-basics (concat user-emacs-directory "core/my-basics"))

;; On new install, bootsrap the straight package manager
;; Also install use-package and integrate it with straight
;; Now we can install packages with use-package and set straight
;; recipes with the :straight keyword.
(require 'my-package-system)

;; This is used to put the basic keybindings infrastructure in place.
;; For example, it downloads evil mode and general.el
(require 'my-keybinding-setup)

(require 'my-general-keybindings)

(require 'my-org)

(require 'my-org-ref)

(require 'my-completion)

(require 'my-prog)

(require 'my-doc-view)

(require 'my-image)

(require 'my-mail)

(require 'my-spelling)

(require 'my-navigation)

(require 'my-theme)

(require 'my-web)

(require 'my-lisp)

(require 'my-coding-challenge)

(require 'my-custom)

(require 'my-startup-message)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-names-vector
   ["#120a09" "#8D9298" "#798994" "#A89694" "#6D7A89" "#957A84" "#768BA2" "#fffbef"])
 '(custom-safe-themes
   (quote
    ("fa2b58bb98b62c3b8cf3b6f02f058ef7827a8e497125de0254f56e373abee088" default)))
 '(hl-todo-keyword-faces
   (quote
    (("TODO" . "#A89694")
     ("NEXT" . "#A89694")
     ("THEM" . "#768BA2")
     ("PROG" . "#6D7A89")
     ("OKAY" . "#6D7A89")
     ("DONT" . "#8D9298")
     ("FAIL" . "#8D9298")
     ("DONE" . "#aeb8be")
     ("NOTE" . "#A89694")
     ("KLUDGE" . "#A89694")
     ("HACK" . "#A89694")
     ("TEMP" . "#A89694")
     ("FIXME" . "#A89694")
     ("XXX+" . "#A89694")
     ("\\?\\?\\?+" . "#A89694"))))
 '(pdf-view-midnight-colors (quote ("#fffbef" . "#1e120f"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
