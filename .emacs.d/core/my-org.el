(use-package toc-org
  :config
  (add-hook 'org-mode-hook 'toc-org-mode))

(remove-hook 'text-mode-hook #'turn-on-auto-fill)
(add-hook 'text-mode-hook 'turn-on-visual-line-mode)

(setq org-capture-templates '(("t" "Todo [inbox]" entry
                               (file+headline (concat org-directory "/tasks.org") "Inbox")
                               "* TODO %i%?")))
;;                              ("T" "Tickler" entry
;;                               (file+headline "~/gtd/tickler.org" "Tickler")
;;                               "* %i%? \n %U")))

(setq org-directory "~/Brain")
(setq org-default-notes-file (concat org-directory "/task.org"))


;; ABC notation in org!
(use-package abc-mode)

(org-babel-do-load-languages
  'org-babel-load-languages
  '(
    (emacs-lisp . t)
    (org t)
    (abc t)))

;; Keybindings
;; My org mode task management options
(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key (kbd "C-c c") 'org-capture)

(global-unset-key (kbd "M-l"))
(evil-define-key '(insert motion) (kbd "M-l") org-mode-map 'org-metaright)

(add-hook 'org-mode-hook #'org-indent-mode)

(setq org-link-file-path-type 'relative)

(provide 'my-org)
