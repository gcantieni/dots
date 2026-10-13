(use-package emmet-mode
  :init
  (setq emmet-move-cursor-between-quotes t)

  :config
  (add-hook 'sgml-mode-hook 'emmet-mode) ;; Auto-start on any markup modes
  (add-hook 'css-mode-hook  'emmet-mode)) ;; enable Emmet's css abbreviation.

(use-package company
  :hook (prog-mode . company-mode)
  :init
  (setq company-backends
	'((company-files
	   company-keywords
	   company-capf
	   company-dabbrev-code
	   company-etags
	   company-dabbrev)))
  (setq company-idle-delay 0.3))

; TODO use more
(use-package yasnippet
  :init (yas-global-mode))

(use-package lsp-mode
  :hook ((js-mode css-mode python-mode) . lsp)
  :commands lsp)

(use-package flycheck
  :init (global-flycheck-mode)
  (setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))
  (general-spc "en" 'flycheck-next-error))
  ;:config

(use-package lsp-ui
  :after lsp
  :hook (lsp-mode . lsp-ui-mode))

(use-package company-lsp
  :after company
  :config (push 'company-lsp company-backends))

(use-package company-jedi)

(provide 'my-completion)

