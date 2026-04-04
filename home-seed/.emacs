;; Turn off menu bar and splash screen, highlight trailing whitespace
(menu-bar-mode -1)
(setq inhibit-splash-screen t)
(setq-default show-trailing-whitespace t)
(setq-default column-number-mode t)

;; Preserve terminal position on scroll, move to top only if scrolling to top
(setq scroll-preserve-screen-position t)
(setq scroll-error-top-bottom t)

;; Truncate long lines visually instead of wrapping them (cycle with M-$)
(setq-default truncate-lines t)

;; Except visually wrap text files by default
(add-hook 'text-mode-hook #'visual-line-mode)

;; Be sensible about tabs, add trailing newline on writes
(setq-default indent-tabs-mode nil)
(setq-default require-final-newline t)

;; Don't use any VC backends; if using, edit symlinked files directly
(setq vc-handled-backends nil)
(setq vc-follow-symlinks nil)

(defun write-file-confirm-name ()
  "Like write-file, but with full abbreviated filename in prompt."
  (interactive
   (let* ((old-file-name
           (if buffer-file-name (abbreviate-file-name buffer-file-name) ""))
          (new-file-name
           (read-file-name "Write file: "
                           default-directory
                           buffer-file-name
                           nil  ; mismatch
                           old-file-name)))
     (write-file new-file-name (not (string= old-file-name new-file-name))))))

(defun delete-window-or-kill-buffer ()
  "If there are multiple windows, call delete-window to delete the current
window. If there are buffers other than those named like *foo* or TAGS, call
kill-buffer to kill the current buffer. Otherwise, exit cleanly."
  (interactive)
  (if (window-parent)
      (delete-window)
    (let ((interesting-buffer-list
           (cl-remove-if
            (lambda (name)
              (or (string-prefix-p " " name)
                  (and (string-prefix-p "*" name)
                       (string-suffix-p "*" name))
                  (member name '("TAGS"))))
            (mapcar 'buffer-name (buffer-list)))))
      (if (> (length interesting-buffer-list) 1)
          (kill-buffer)
        (save-buffers-soft-exit)))))

(defun set-major-mode (token)
  "Manually set major mode, either by mode name, extension, or to default."
  (interactive "MSet major mode: ")
  (if (> (length token) 0)
      ;; If a function token-mode exists, just run it
      (let ((mode-func (or (intern-soft (concat token "-mode"))
                           (intern-soft token))))
        (if (functionp mode-func)
            (funcall mode-func)
          ;; Otherwise, try to find an auto-mode for extension .token
          (let ((auto-mode-pair
                 (or (assoc token auto-mode-alist)
                     (assoc (concat "\\." token) auto-mode-alist)
                     (assoc (concat "\\." token "\\'") auto-mode-alist))))
            (if auto-mode-pair
                (funcall (cdr auto-mode-pair))
              (message (concat "No major mode matching: " token))))))
    ;; If no mode was entered, try to reset to default
    (message "Resetting major mode to default")
    (normal-mode)))

(defun save-buffers-soft-exit (&optional ignored)
  "Prompt to save any unsaved buffers, then exit either by disconnecting any
current client, or by killing the session, if not in a client. Do not double
confirm on exit (https://stackoverflow.com/a/6764804)."
  (interactive)
  (if (and (boundp 'server-clients) (> (length server-clients) 0))
      (server-save-buffers-kill-terminal nil)
    (save-some-buffers nil t)
    (kill-emacs)))

(defun goto-line-relative (line)
  "Go to LINE, counting from 1, as with goto-line, but move relative to the
current line if LINE is prefixed with a plus (+) or minus (-) sign."
  (interactive "MGoto line: ")
  (if (> (length line) 0)
      (if (or (string-prefix-p "+" line) (string-prefix-p "-" line))
          (goto-line (+ (line-number-at-pos) (string-to-number line)))
        (goto-line (string-to-number line)))))

(defun quit-isearch (&optional override-fn default-fn)
  "If isearch-string is non-empty, exit isearch-mode and optionally run an
overridden replacement command. If isearch-string is non-empty, and a default
command is provided, run that default command."
  (interactive)
  (if (and default-fn (> (length isearch-string) 0))
      (call-interactively default-fn)
    (isearch-done)
    (isearch-clean-overlays)
    (when override-fn (call-interactively override-fn))))

(defun isearch-clear ()
  "Clear the current isearch-string without exiting isearch-mode."
  (interactive)
  (setq isearch-string "")
  (setq isearch-message "")
  (isearch-update))

(defun query-replace-regexp-from-isearch ()
  "Switch from isearch to query-replace-regexp if isearch-string is empty."
  (interactive)
  (quit-isearch 'query-replace-regexp 'isearch-repeat-backward))

(defun goto-line-relative-from-isearch ()
  "Switch from isearch to goto-line-relative if isearch-string is empty."
  (interactive)
  (quit-isearch 'goto-line-relative))

(defun end-of-buffer-from-isearch ()
  "Switch from isearch to end-of-buffer if isearch-string is empty."
  (interactive)
  (quit-isearch 'end-of-buffer))

(defun beginning-of-buffer-from-isearch ()
  "Switch from isearch to beginning-of-buffer if isearch-string is empty."
  (interactive)
  (quit-isearch 'beginning-of-buffer))

(defun cycle-word-wrap-mode ()
  "Cycle through truncate lines, wrap lines, and wrap at word boundaries."
  (interactive)
  (if word-wrap
      (progn (message "Truncate lines (default)")
             (visual-line-mode nil)
             (setq word-wrap nil)
             (setq truncate-lines t))
    (if truncate-lines
        (progn (message "Wrap lines")
               (setq truncate-lines nil))
      (message "Wrap at word boundaries")
      (visual-line-mode t))))

(defun shell-command-to-buffer (command &optional arg)
  "Run shell-command-on-region if region active, shell-command otherwise."
  (interactive
   (list (read-from-minibuffer "Shell command: " nil nil nil 'shell-command-history)
         current-prefix-arg))
  (if (use-region-p)
      (shell-command-on-region (region-beginning) (region-end) command t t)
    (shell-command command t)))

;; Keybindings for GNU Nano users
(global-set-key (kbd "C-^") 'set-mark-command)
(global-set-key (kbd "C-@") 'forward-word)
(global-set-key (kbd "C-k") 'kill-whole-line)
(global-set-key (kbd "C-o") 'write-file-confirm-name)
(global-set-key (kbd "C-u") 'clipboard-yank)
(global-set-key (kbd "C-w") 'isearch-forward-regexp)
(global-set-key (kbd "C-y") 'scroll-down-command)
(global-set-key (kbd "C-x 0") 'delete-window-or-kill-buffer)
(global-set-key (kbd "C-x 8") 'display-fill-column-indicator-mode)
(global-set-key (kbd "C-x m") 'set-major-mode)
(global-set-key (kbd "C-x C-c") 'save-buffers-soft-exit)
(global-set-key (kbd "C-x C-x") 'save-buffers-soft-exit)
(define-key minibuffer-local-map (kbd "C-c") 'abort-recursive-edit)
(define-key isearch-mode-map (kbd "C-c") 'quit-isearch)
(define-key isearch-mode-map (kbd "C-k") 'isearch-clear)
(define-key isearch-mode-map (kbd "C-r") 'query-replace-regexp-from-isearch)
(define-key isearch-mode-map (kbd "C-t") 'goto-line-relative-from-isearch)
(define-key isearch-mode-map (kbd "C-v") 'end-of-buffer-from-isearch)
(define-key isearch-mode-map (kbd "C-y") 'beginning-of-buffer-from-isearch)
(define-key isearch-mode-map (kbd "DEL") 'isearch-del-char)
(define-key query-replace-map (kbd "C-c") 'quit)
(define-key query-replace-map (kbd "C-x") 'quit)
(global-set-key (kbd "M-$") 'cycle-word-wrap-mode)
(global-set-key (kbd "M-|") 'shell-command-to-buffer)

;; With active region, allow easy shell filter, quit, and delete/kill region
(defvar active-region-mode-map (let ((map (make-sparse-keymap))) map))
(define-minor-mode active-region-mode
  "Toggle active region mode."
  :init-value nil
  :lighter " Region"
  :keymap active-region-mode-map
  :group 'active-region)
(add-hook 'activate-mark-hook (lambda () (active-region-mode 1)))
(add-hook 'deactivate-mark-hook (lambda () (active-region-mode -1)))
(define-key active-region-mode-map (kbd "|") 'shell-command-to-buffer)
(define-key active-region-mode-map (kbd "C-c") 'keyboard-quit)
(define-key active-region-mode-map (kbd "C-d") 'delete-region)
(define-key active-region-mode-map (kbd "C-g") 'keyboard-quit)
(define-key active-region-mode-map (kbd "C-k") 'kill-region)

;; Silence bell on normal quit (https://www.emacswiki.org/emacs/AlarmBell#toc6)
(setq ring-bell-function
      (lambda ()
        (unless
            (memq this-command
                  '(isearch-abort
                    abort-recursive-edit
                    exit-minibuffer
                    keyboard-quit))
          (ding))))

;; Put Emacs autosave files in tmp (https://www.emacswiki.org/emacs/AutoSave)
(setq backup-directory-alist `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t)))

;; Enable "leuven" custom theme, allow lexical-binding for Emacs 23
(custom-set-variables
 '(custom-enabled-themes (quote (leuven)))
 '(safe-local-variable-values (quote ((lexical-binding . t)))))
(custom-set-faces)
