(use-package rainbow-mode
  :config
  (define-globalized-minor-mode global-rainbow-mode
                                rainbow-mode (lambda () (rainbow-mode 1)))
  (global-rainbow-mode 1))

(provide 'my-web)
