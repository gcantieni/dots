;; Keybindings are done in my-keybinding-setup with evil-org-mode

;; Files
(setq org-directory "~/Dropbox/Brain")
(setq org-link-file-path-type 'relative)
(setq org-default-notes-file (concat org-directory "/gtd.org"))
(setq org-agenda-files '("~/Dropbox/Brain/task.org"))
;(setq org-refile-targets '(("~/Dropbox/Brain/wiki/brown-2019.org" :maxlevel . 3)
;			   (nil :level . 1)))

(setq org-refile-targets '(("~/Dropbox/Brain/task.org" :todo . "PROJ")
			   ("~/Dropbox/Brain/think.org" :level . 1)))

;; Hooks
(remove-hook 'text-mode-hook #'turn-on-auto-fill)
(add-hook 'text-mode-hook 'turn-on-visual-line-mode)
(add-hook 'org-mode-hook #'org-indent-mode)

;; Aenda and TODO
(setq org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "PROJ(p)" "WAITING(w)" "SOMEDAY(s)" "|" "DONE(d)" "CANCELLED(c)")))

(setq org-capture-templates '(("t" "Todo [inbox]" entry
			       (file "task.org")
			       "* TODO %i%?")
			      ("p" "Project" entry
			       (file "task.org")
			       "* PROJ %i%?")
			      ("i" "Insight" entry
			       (file "task.org")
			       "* %i")
			      ("j" "Journal" entry
			       (file "think.org")
			       "* %? %t")))

(setq org-agenda-custom-commands
      '(("n" "Next" ((todo "NEXT")))
	("h" "HUD"
	 ((agenda "" ((org-agenda-span 1)))
	  (todo "NEXT")))
	("i" "Inbox"
	 ((tags-todo "-TODO+LEVEL=1/-SOMEDAY-WAITING-NEXT-PROJ")))
	("t" "Stuck" ((stuck "")))
	("d" "To delete"
	 ((todo "DONE")
	  (todo "CANCELLED")))))

(setq org-stuck-projects 
      '("-PROJ-TODO+LEVEL=1/-DONE-CANCELLED-SOMEDAY-WAITING" ("NEXT" "WAITING") nil ""))

(defun my-org-add-next-tag ()
  "Add the tag :next: at end of current line"
  (interactive)
  (org-set-tags-to ":next:"))

(use-package org-ql
  :defer nil
  :commands org-ql-block)

;; Archive commands
(setq org-archive-location "~/Dropbox/Brain/archive.org::")

(defun my-org-agenda-skip-all-siblings-but-first ()
  "Skip all but the first non-done entry."
  (let (should-skip-entry)
    (unless (org-current-is-todo)
      (setq should-skip-entry t))
    (save-excursion
      (while (and (not should-skip-entry) (org-goto-sibling t))
        (when (org-current-is-todo)
          (setq should-skip-entry t))))
    (when should-skip-entry
      (or (outline-next-heading)
          (goto-char (point-max))))))

(defun org-current-is-todo ()
  (string= "TODO" (org-get-todo-state)))

(use-package evil-org
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (add-hook 'evil-org-mode-hook
	    (lambda ()
	      (evil-org-set-key-theme)))
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (general-def
    :keymaps 'evil-org-mode-map
    :states '(normal motion)
    "A" nil))

(use-package worf
  :commands worf-goto)

(use-package toc-org
  :config
  (add-hook 'org-mode-hook 'toc-org-mode))

(use-package plain-org-wiki
  :init
  (setq plain-org-wiki-directory (concat org-directory "/wiki"))
  :commands plain-org-wiki)

;; ABC notation in org!
(use-package abc-mode
  :after org
  :config
  (org-babel-do-load-languages
    'org-babel-load-languages
    '((emacs-lisp . t)
      (org t)
      (abc t))))

;; Global org keybindings
(general-spc
 "os" 'org-store-link
 "oi" 'org-insert-link
 "oo"  'org-open-at-point
 "a"   'org-agenda
 "c"   'org-capture
 "w"   'plain-org-wiki
 "oc"  'my-complete-todo)

(defun my-org-insert-heading ()
  "Insert heading with newline."
  (interactive)
  (evil-append-line 1)
  (newline)
  (org-insert-heading))

(defun my-org-insert-todo ()
  "Insert a todo as a sub heading."
  (interactive)
  (my-org-insert-heading)
  (org-todo)
  (evil-append-line 1))

(defun my-org-make-heading ()
  "Make the current line a heading."
  (interactive)
  (save-excursion
    (evil-first-non-blank)
    (org-insert-heading)))

;; Local org keybindings
(general-def
  :keymaps 'org-mode-map
  :prefix ","
  :states 'normal
  "t" 'org-todo
  "i" 'my-org-insert-todo
  "ct" 'counsel-org-set-tags 
  "s" 'org-schedule
  "d" 'org-deadline
  "g" 'worf-goto
  "a" 'org-archive-subtree
  "r" 'org-refile
  "." 'org-time-stamp
  "e" 'org-export-dispatch
  "k" 'org-set-tags-command ;; mnemonic "keywords"
  "n" 'org-narrow-to-subtree
  "N" 'widen
  "h" 'my-org-insert-heading
  "H" 'my-org-make-heading)

;; TODO why doesn't this work??
(general-def
  :keymaps 'org-capture-mode-map
  :prefix ","
  :states '(normal motion)
  "c" 'org-capture-finalize
  "k" 'org-capture-kill
  "C-c C-c" nil
  "C-c C-k" nil)

;; Agenda map
(general-def
  :keymaps 'org-agenda-mode-map
  :states '(normal motion)
  "r" 'org-agenda-refile)

;; Overriding keybindings
(general-def
  :keymaps 'org-mode-map
  "M-h" 'org-metaleft
  "M-j" 'org-metadown
  "M-k" 'org-metaup
  "M-l" 'org-metaright)

(provide 'my-org)
