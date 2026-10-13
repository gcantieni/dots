(straight-use-package 'company)
(setq company-idle-delay 0.4)
(diminish 'company-mode " ❋")
(setq company-backends
      '((company-elisp
	 company-files
	 company-keywords
	 company-capf)
	(company-abbrev company-dabbrev)))
(add-hook 'after-init-hook #'global-company-mode)
(provide 'gus-company)
