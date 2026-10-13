(setq doc-view-resolution 100)
;(setq doc-view-fit-width-to-window t)
(use-package pdf-tools
  :init
  ; will load pdf-tools ass soon as a pdf file is loaded
  (pdf-loader-install)
  ;; open pdfs scaled to fit page
  (setq-default pdf-view-display-size 'fit-page)
  ;; automatically annotate highlights
  (setq pdf-annot-activate-created-annotations t))

(provide 'my-doc-view)
