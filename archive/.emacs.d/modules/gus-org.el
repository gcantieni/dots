(add-hook 'org-mode-hook #'org-indent-mode)

(define-key gus-spc-map "os" #'org-store-link)
(define-key gus-spc-map "oi" #'org-insert-link)
(define-key gus-spc-map "oo" #'org-open-at-point)
(define-key gus-spc-map "a" #'org-agenda)
(define-key gus-spc-map "c" #'org-capture)
(define-key gus-spc-map "w" #'plain-org-wiki)

(with-eval-after-load "org"
  (setq org-directory "~/Dropbox/Brain"
        org-link-file-path-type 'relative
        org-default-notes-file (concat org-directory "/gtd.org")
        org-agenda-files '("~/Dropbox/Brain/task.org")
        org-refile-targets '(("~/Dropbox/Brain/task.org" :todo . "PROJ")
        		    ("~/Dropbox/Brain/think.org" :level . 1))
        org-todo-keywords '((sequence "TODO(t)"
				      "NEXT(n)"
				      "PROJ(p)"
				      "WAITING(w)"
				      "SOMEDAY(s)"
				      "|"
				      "DONE(d)"
				      "CANCELLED(c)"))
        org-archive-location "~/Dropbox/Brain/archive.org::"
	; Ricing
	org-hide-emphasis-markers t
	org-agenda-block-separator ""
	org-ellipsis " › "
	org-pretty-entities t
	org-fontify-whole-heading-line t
	org-fontify-done-headline t
	org-fontify-quote-and-verse-blocks t)

  (defun gus-org-insert-heading ()
    "Insert heading with newline."
    (interactive)
    (evil-append-line 1)
    (newline)
    (org-insert-heading))

  (defun gus-org-insert-todo ()
    "Insert a todo heading."
    (interactive)
    (gus-org-insert-heading)
    (org-todo)
    (evil-append-line 1))


  (defun gus-org-agenda-insert-sub-todo (&optional arg)
    "Add a time-stamped note to the entry at point."
    (interactive "P")
    ;(org-agenda-check-no-diary)
    (let* ((marker (or (org-get-at-bol 'org-marker)
		      (org-agenda-error)))
	  (buffer (marker-buffer marker))
	  (pos (marker-position marker))
	  (hdmarker (org-get-at-bol 'org-hd-marker))
	  (inhibit-read-only t))
      (with-current-buffer buffer
	(widen)
	(goto-char pos)
	(org-show-context 'agenda)
	(org-add-note))))

  (defvar gus-org-comma-map (make-sparse-keymap)
    "Local bindings for org mode prefixed by a comma")
  (define-key evil-motion-state-map "," nil)
  (evil-define-key 'normal org-mode-map "," gus-org-comma-map)
  (define-key gus-org-comma-map "t" #'org-todo)
  (define-key gus-org-comma-map "s" #'org-schedule)
  (define-key gus-org-comma-map "d" #'org-deadline)
  (define-key gus-org-comma-map "." #'org-time-stamp)
  (define-key gus-org-comma-map "e" #'org-export-dispatch)
  (define-key gus-org-comma-map "k" #'org-set-tags) ;"keywords"
  (define-key gus-org-comma-map "n" #'org-narrow-to-subtree)
  (define-key gus-org-comma-map "N" #'widen)
  (define-key gus-org-comma-map "i" #'gus-org-insert-todo)
  (define-key gus-org-comma-map "h" #'gus-org-insert-heading)
  (define-key gus-org-comma-map "c" #'org-toggle-checkbox)

  (define-key org-mode-map (kbd "M-h") #'org-metaleft)
  (define-key org-mode-map (kbd "M-j") #'org-metadown)
  (define-key org-mode-map (kbd "M-k") #'org-metaup)
  (define-key org-mode-map (kbd "M-l") #'org-metaright))

(with-eval-after-load "org-capture"
  (setq org-capture-templates '(("t" "Todo [inbox]" entry (file "task.org") "* TODO %i%?")
				("p" "Project" entry (file "task.org") "* PROJ %i%?")
				("j" "Journal" entry (file "think.org") "* %? %t"))))

;(straight-use-package 'org-ql)
;(setq org-agenda-custom-commands
;      '(("h" "Heads Up!"
;	 ((alltodo "" ((org-agenda-overriding-header "")
;		       (org-super-agenda-groups
;			'((:name "Next"
;				 :todo "NEXT"
;				 :order 1)
;			  (:name "Due Soon"
;				 :deadline future
;(with-eval-after-load "org-super-agenda" 
;(require 'org-ql)
(setq org-agenda-custom-commands
      '(("t" "Test" (org-ql-block (todo "TODO")))))

(setq org-stuck-projects 
      '("-PROJ-TODO+LEVEL=1/-DONE-CANCELLED-SOMEDAY-WAITING" ("NEXT" "WAITING") nil ""))
(setq org-agenda-custom-commands
      '(("g" "Super gus view"
         ((agenda "" ((org-agenda-span 'day)
                      (org-super-agenda-groups
                       '((:name "Deadlines"
                                :time-grid t
				:deadline future
                                :scheduled today
                                :order 1)))))
	  ;(stuck "")
          (alltodo "" ((org-agenda-overriding-header "")
                       (org-super-agenda-groups
                        '((:name "Inbox"
				 :todo "TODO")
			  (:name "Stuck"
				 :and (:todo "PROJ" :children nil))
			  (:name "Next to do"
                                 :todo "NEXT"
                                 :order 1)
                          (:name "Important"
                                 :tag "Important"
                                 :priority "A"
                                 :order 6)
                          (:name "Due Today"
                                 :deadline today
                                 :order 2)
                          (:name "Due Soon"
                                 :deadline future
                                 :order 8)
                          (:name "Overdue"
                                 :deadline past
                                 :order 2)
                          (:name "Assignments"
                                 :tag "Assignment"
                                 :order 10)
                          (:name "Issues"
                                 :tag "Issue"
                                 :order 12)
                          (:name "Projects"
                                 :tag "Project"
                                 :order 14)
                          (:name "Waiting"
                                 :todo "WAITING"
                                 :order 20)
                          (:name "Someday"
                                 :todo ("SOMEDAY" )
                                 :order 90)
                          (:discard (:tag ("Chore" "Routine" "Daily")))))))))))
;(defun gus-hud ()
;  (interactive)
;  (org-ql-search (org-agenda-files)
;    '(or (and (not (done))
;	      (deadline :from today :to 7)))
;    :title "Heads Up Display"
;    :super-groups '((:name "Coming up deadlines"
;			   :deadline future)
;		    (:name "Inbox")))

;(with-eval-after-load "org-agenda"
;  (setq org-agenda-custom-commands
;	'(("n" "Next" ((todo "NEXT")))
;	  ("h" "HUD" ((agenda "" ((org-agenda-span 1))) (todo "NEXT")))
;	  ("i" "Inbox" ((tags-todo "-TODO+LEVEL=1/-SOMEDAY-WAITING-NEXT-PROJ")))
;	  ("t" "Stuck" ((stuck "")))
;	  ("d" "To delete" ((todo "DONE") (todo "CANCELLED")))))

(straight-use-package 'org-super-agenda)
;(with-eval-after-load "org-agenda"
(add-hook 'org-agenda-mode-hook 'org-super-agenda-mode)
(with-eval-after-load "org-super-agenda"
  (define-key org-super-agenda-header-map "j" nil)
  (define-key org-super-agenda-header-map "k" nil))
;  (setq org-super-agenda-groups
;	'((:todo "PROJ"))))

(with-eval-after-load "org-capture"
  (evil-define-key 'normal org-capture-mode-map ",c" #'org-capture-finalize)
  (evil-define-key 'normal org-capture-mode-map ",k" #'org-capture-kill))

(straight-use-package 'evil-org) 
(with-eval-after-load "org"
  (add-hook 'org-mode-hook #'evil-org-mode)
  (add-hook 'evil-org-mode-hook
	    #'(lambda () (evil-org-set-key-theme)))
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (evil-define-key 'motion org-agenda-mode-map (kbd "SPC") nil))

(straight-use-package 'worf)

(straight-use-package 'plain-org-wiki)
(with-eval-after-load "plain-org-wiki"
  (require 'org)
  (setq plain-org-wiki-directory (concat org-directory "/wiki")))

(straight-use-package 'org-bullets)
(setq org-bullets-bullet-list '("•"))
(add-hook 'org-mode-hook #'(lambda () (org-bullets-mode 1)))

(provide 'gus-org)
