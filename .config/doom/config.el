;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq user-full-name "Gus Cantieni"
      user-mail-address "gus.cantieni@gmail.com")

(setq doom-theme 'doom-nord)

(setq display-line-numbers-type 'relative
      compile-command "make")

(setq org-directory "~/notes/")
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
      "," #'consult-buffer)

(map! :nv "," nil)
(setq doom-localleader-key ",")

(after! lsp
  (map! :map lsp-mode-map
        :nvim "M-p" nil)
  (require 'dap-cpptools))

(after! org
  (setq org-agenda-files (quote ("~/notes/" "~/notes/work-journal/")))

  (setq org-todo-keywords
        (quote ((sequence "TODO(t)" "NEXT(n)" "PROJ(p)" "|" "DONE(d@/!)")
                (sequence "WAIT(w@/!)" "SOMEDAY(s)" "|" "CANCELLED(c@/!)"))))

  (setq org-archive-location
        (format-time-string "~/notes/archive/%Y.org::"))

  (setq org-stuck-projects '("+project/PROJ" ("NEXT") ("note") ""))

  (setq org-capture-templates
       (quote (("i" "inbox" entry (file+headline "~/notes/notes.org" "Inbox")
                "* %?\n%U\n%a\n")
               ("t" "today" entry (file+headline "~/notes/notes.org" "Tickler")
                "* NEXT %?\n  SCHEDULED: <%(format-time-string \"%Y-%m-%d\")>\n")
               ("p" "project" entry (file+headline "~/notes/notes.org" "Projects")
                "* %? :project:\n%U\n%a\n")
               ("c" "customization" entry (file+headline "~/notes/notes.org" "Customizations")
                "* TODO %? :easyfun:\n%U\n")
               ("m" "Mr Testy" entry (file+headline "~/notes/notes.org" "Mr Testy")
                "* NEXT %? %u\n")
               ("l" "Liaison request" entry (file+headline "~/notes/notes.org" "Liaison")
                "* NEXT %? %u\n")
               ("h" "Habit" entry (file+headline "~/notes/notes.org" "Habits")
                "* NEXT %?\n%U\n%a\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+1d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: NEXT\n:END:\n")
               ("f" "Flashcard (org-drill)" entry (file+headline "~/notes/flashcards.org" "Ab Initio flashcards")
                "* Item :drill:\n%?\n** Answer\n" :empty-lines 1)
               ("g" "hide1cloze flashcard (org-drill)" entry (file+headline "~/notes/flashcards.org" "Ab Initio flashcards")
                "* Item :drill:\n:PROPERTIES:\n:DRILL_CARD_TYPE: hide1cloze\n:END:\n%?\n" :empty-lines 1)
               ("2" "2-sided flashcard (org-drill)" entry (file+headline "~/notes/flashcards.org" "Ab Initio flashcards")
                 "* Item :drill:\n:PROPERTIES:\n:DRILL_CARD_TYPE: twosided\n:END:\n** Front\n%?\n** Back\n" :empty-lines 1))))

  (setq org-modules '(org-bibtex
                      ;; my additions
                      org-drill))

  (setq org-agenda-custom-commands
        '((" " "Agenda"
           ((agenda ""
                    ((org-agenda-skip-function '(org-agenda-skip-entry-if 'tag "drill"))
                     (org-agenda-span 'day)))  ;; The default agenda for today/week

            (tags-todo "-easyfun/+NEXT"
                       ((org-agenda-overriding-header "Tasks")))

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
