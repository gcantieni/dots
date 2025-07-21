;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/notes/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.



;; Global default keybindings
(map! "M-o" #'other-window
      :leader
      "1" #'delete-other-windows
      "2" #'split-window-below
      "3" #'split-window-right
      "0" #'+workspace/close-window-or-workspace)

;; TODO: doesn't seem to work
(map! :nv "," nil)
(setq doom-localleader-key ",")

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
  (map! "C-c a" #'org-agenda))

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
      :desc "p4" "x p" p4-prefix-map)
