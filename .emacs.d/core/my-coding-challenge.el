(use-package leetcode
  :commands leetcode
  :config
  (general-def 'normal 'leetcode--problems-mode-map "RET" 'leetcode-show-current-problem))
(provide 'my-coding-challenge)
