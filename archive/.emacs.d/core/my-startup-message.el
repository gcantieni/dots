;; put fortune in scratch buffer

(setq inhibit-startup-screen t)

(add-hook 'after-init-hook 'org-agenda-list)

(setq initial-scratch-message
      (format 
       ";; %s\n\n" 
       (replace-regexp-in-string  
    	"\n" "\n;; " ; comment each line
    	(replace-regexp-in-string 
    	 "\n$" ""    ; remove trailing linebreak
    	 (shell-command-to-string "fortune")))))

;(setq initial-buffer-choice
;      "/home/gus/Brain/now.org")
(provide 'my-startup-message)
