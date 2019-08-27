;; Let's try ivy mode (counsel brings in ivy and swiper as dependencies)
(use-package counsel
  :config
  (ivy-mode 1)
  (setq ivy-height 10))



(provide 'my-completion)
