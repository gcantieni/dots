
;; Color schemes
;; I use wal or wal-esque things so I like to synchronize
(use-package base16-theme)
;; colours generated dynamically by wal
(defun my/set-wal-colors () (setq base16-wal-colors
			       '(:base00 #0b0805
				 :base01 #3E2E12
				 :base02 #554439
				 :base03 #926337
				 :base04 #C37A3C
				 :base05 #966F49
				 :base06 #B18C5D
				 :base07 #e0c9a1
				 :base08 #309060
				 :base09 #6E4E32
				 :base0A #655449
				 :base0B #926337
				 :base0C #C37A3C
				 :base0D #966F49
				 :base0E #color14
				 :base0F #e0c9a1)))
(defvar base16-wal-colors nil All colors for base16-wal are defined here.)

(my/set-wal-colors)

(deftheme base16-wal)
(base16-theme-define 'base16-wal base16-wal-colors)
(provide-theme 'base16-wal)
(provide 'base16-wal)
