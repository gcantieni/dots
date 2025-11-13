;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq user-full-name "Gus Cantieni"
      user-mail-address "gus.cantieni@gmail.com")

(setq doom-theme 'modus-operandi-tinted
      doom-font "JetBrainsMonoNL Nerd Font-12")

;(setq doom-font "CaskaydiaMono Nerd Font-18.0")

;; Smartparens was giving me grief
(remove-hook 'doom-first-buffer-hook #'smartparens-global-mode)

(setq ;display-line-numbers-type 'relative
 compile-command "make")

(setq org-directory "~/notes/")

(add-to-list 'default-frame-alist '(fullscreen . maximized))

;; Unbindings
(map! :map vterm-mode-map
      "M-p" nil)

;; Global default keybindings
(map! "M-o" #'other-window
      "M-p" #'+popup/other
      "C-/" #'+vterm/toggle
      :leader
      "1" #'delete-other-windows
      "2" #'split-window-below
      "3" #'split-window-right
      "0" #'+workspace/close-window-or-workspace
      "," #'consult-buffer
      "/" #'rg)

;; There's some intens popup rules we can use to customize popups.
;(after! vterm
;  (set-popup-rule! "*doom:vterm-popup:main" :size 0.25 :vslot -4 :select t :quit nil :ttl 0 :side 'right))


;; attempt at getting the cursor to look right in the term
;; see: https://github.com/akermu/emacs-libvterm/issues/313
(use-package vterm
  :config
  (advice-add #'vterm--redraw :after (lambda (&rest args) (evil-refresh-cursor evil-state)))
  (add-hook 'vterm-mode-hook (lambda () (display-line-numbers-mode -1))))

(map! :nv "," nil)
(setq doom-localleader-key ",")


;; TODO: check if this worked
(after! mhtml
  (map! :map html-mode-map "M-o" nil))

(after! lsp
  (map! :map lsp-mode-map
        :nm "g r" #'lsp-find-references ; TODO: why doesn't this work?
        :nvim "M-p" nil)
  (require 'dap-cpptools)
  (setq rustic-format-on-save t))
                                        ;(setq lsp-format-buffer-on-save '("dart")))

(add-hook! 'prog-mode-hook #'which-function-mode)

(after! org
  (setq org-agenda-files (quote ("~/notes/" "~/notes/work-journal/")))

  (setq org-todo-keywords
        (quote ((sequence "TODO(t)" "NEXT(n)" "PROJ(p)" "|" "DONE(d@/!)")
                (sequence "WAIT(w@/!)" "SOMEDAY(s)" "|" "CANCELLED(c@/!)"))))

  (setq org-archive-location
        (format-time-string "~/notes/archive/%Y.org::"))

  (setq org-stuck-projects '("+project/PROJ" ("NEXT") ("note") ""))

  (setq org-capture-templates
       (quote (("i" "Inbox" entry (file+headline "~/notes/notes.org" "Inbox")
                "* %?\n%U\n%a\n")
               ("t" "Today" entry (file+headline "~/notes/notes.org" "Tickler")
                "* NEXT %?\n  SCHEDULED: <%(format-time-string \"%Y-%m-%d\")>\n")
               ("p" "Project" entry (file+headline "~/notes/notes.org" "Projects")
                "* PROJ %? :project:\n%U\n")
               ("c" "Customization" entry (file+headline "~/notes/notes.org" "Customizations")
                "* TODO %? :easyfun:\n%U\n")
               ("m" "Mr Testy" entry (file+headline "~/notes/notes.org" "Mr Testy")
                "* NEXT %? %u\n- link:\n- box:\n- path\n")
               ("l" "Liaison request" entry (file+headline "~/notes/notes.org" "Liaison")
                "* NEXT %? %u\n")
               ("f" "Flashcard (org-drill)" entry (file+headline "~/notes/flashcards.org" "Ab Initio flashcards")
                "* Item :drill:\n%?\n** Answer\n" :empty-lines 1))))

  (setq org-modules '(org-bibtex
                      ;; my additions
                      org-drill))

  (setq org-agenda-custom-commands
        '((" " "Agenda"
           ((agenda ""
                    ((org-agenda-span 'day)
                     (org-agenda-start-day nil)))  ;; The default agenda for today/week

            (tags-todo "-easyfun/+NEXT"
                       ((org-agenda-overriding-header "Tasks")))

            (todo "WAIT" ((org-agenda-overriding-header "Waiting tasks")))

            (tags-todo "+easyfun/+NEXT"
                       ((org-agenda-overriding-header "Low energy/fallback tasks")))))

          ("n" "Next"
           ((tags-todo "-easyfun/+NEXT"
                       ((org-agenda-overriding-header "Tasks")))

            (tags-todo "+easyfun/+NEXT"
                       ((org-agenda-overriding-header "Low energy/fallback tasks")))))

          ("p" "Projects"
           ((tags-todo "+project/PROJ")))

          ("r" "Review"
           ((stuck)
            (tags "-SCHEDULED=\"<\"+TODO=\"WAIT\"" ((org-agenda-overriding-header "Unsheduled waiting tasks")))
            (tags-todo "-easyfun/+TODO" ((org-agenda-overriding-header "Tasks inbox")))
            (tags-todo "+easyfun/+TODO" ((org-agenda-overriding-header "Easyfun inbox")))
            (todo "WAIT" ((org-agenda-overriding-header "Waiting tasks")))
            (tags-todo "-project/+SOMEDAY" ((org-agenda-overriding-header "Someday tasks")))
            (tags-todo "+project/+SOMEDAY" ((org-agenda-overriding-header "Someday projects")))))

          ("s" "Someday"
           ((tags-todo "-project/+SOMEDAY" ((org-agenda-overriding-header "Someday tasks")))
            (tags-todo "+project/+SOMEDAY" ((org-agenda-overriding-header "Someday projects")))))))
  (map! "C-c c" #'org-capture)
  (map! "C-c a" #'org-agenda)
  (map! :map org-mode-map
        :localleader
        :desc "Insert structured block" "," #'org-insert-structure-template))

(use-package! org-journal
  :after org
  :config
  (setq org-journal-dir "~/notes/work-journal")
  (setq org-journal-file-type 'yearly)
  (setq org-journal-file-format "%Y.org")
  :bind
  (("C-c j" . org-journal-new-entry)))

(use-package! org-drill
  :after org
  :init
  (defun gc-org-drill ()
    """jump to my flashcard file and start a drill session."""
    (interactive)
    (find-file "~/notes/flashcards.org")
    (org-drill))

  :bind
  ("C-c d" . gc-org-drill))

                                        ;(after! p4
                                        ;  (map! "SPC x e" #'p4-edit))


(use-package! p4)
                                        ; I could also bind this on the cpp localleader key
(map! :leader
      "x" nil ; Need to unbding before it can be rebound TODO: make my own prefix map
      :desc "p4" "x p" p4-prefix-map
      :desc "p4 diff" "=" #'p4-diff)

(use-package! direnv
  :config
  (direnv-mode))

(use-package! anki-editor)

(after! anki-editor
  (map! :leader
        :prefix ("x f" . "flashcard")
        :desc "anki flashcard" "a" #'anki-editor-insert-note
        "p" #'anki-editor-push-new-notes))
