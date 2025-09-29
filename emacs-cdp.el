;;; emacs-cdp.el --- Control Chrome via CDP from Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2025 ofnhwx

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; Author: ofnhwx
;; Version: 0.1
;; Package-Requires: ((emacs "30.1") (websocket "1.12"))
;; URL: https://github.com/ofnhwx/emacs-cdp
;; Keywords: tools, convenience, browser

;;; Commentary:

;; This package provides an interface to control Chrome/Chromium browsers
;; from Emacs using the Chrome DevTools Protocol (CDP).
;;
;; Features:
;; - Connect to and control Chrome tabs
;; - Send keyboard input from Emacs to Chrome
;; - Tab management (select, create, switch)
;; - Page control (reload, insert text)
;; - Simple minor mode for direct key forwarding
;;
;; Usage:
;; 1. Start Chrome with remote debugging:
;;    chrome --remote-debugging-port=9222
;;    or use M-x emacs-cdp-start-chrome
;;
;; 2. Connect to a tab:
;;    M-x emacs-cdp-select-tab
;;
;; 3. Enable key forwarding:
;;    M-x emacs-cdp-mode
;;    All keystrokes will be sent to Chrome
;;    C-g to exit the mode

;;; Code:

(require 'json)
(require 'websocket)
(require 'seq)
(require 'subr-x)

;;;; Custom variables
(defgroup emacs-cdp nil
  "Emacs interface for Chrome DevTools Protocol."
  :group 'tools)

(defcustom emacs-cdp-debug-port 9222
  "Chrome remote debugging port."
  :type 'integer
  :group 'emacs-cdp)

(defcustom emacs-cdp-chrome-executable "google-chrome-stable"
  "Path to Chrome/Chromium executable."
  :type 'string
  :group 'emacs-cdp)

(defcustom emacs-cdp-profile-directory nil
  "Chrome profile directory.  nil = temporary directory."
  :type '(choice (const nil) directory)
  :group 'emacs-cdp)

(defcustom emacs-cdp-debug nil
  "When non-nil, log CDP messages to *Messages*."
  :type 'boolean
  :group 'emacs-cdp)

(defcustom emacs-cdp-new-tab-url "https://www.google.com"
  "Default URL for new tabs."
  :type 'string
  :group 'emacs-cdp)

;;;; State variables
(defvar emacs-cdp-websocket nil
  "Current WebSocket connection to Chrome tab.")

(defvar emacs-cdp-current-tab nil
  "Currently selected Chrome tab alist.")


;;;; Connection helpers
(defun emacs-cdp-connected-p ()
  "Return t if a WebSocket connection to Chrome exists."
  (and emacs-cdp-websocket (websocket-openp emacs-cdp-websocket)))

(defun emacs-cdp-send-command (ws method &optional params)
  "Send CDP METHOD with PARAMS (alist) via WebSocket WS."
  (unless (and ws (websocket-openp ws))
    (user-error "CDP not connected"))
  (let ((msg (json-encode `(("id" . ,(random 100000))
                            ("method" . ,method)
                            ("params" . ,params)))))
    (when emacs-cdp-debug
      (message "CDP -> %s" msg))
    (websocket-send-text ws msg)))

(defun emacs-cdp-send (method &optional params)
  "Send CDP METHOD with PARAMS using current connection."
  (emacs-cdp-with-connection
   (lambda (ws)
     (emacs-cdp-send-command ws method params))))

(defun emacs-cdp-with-connection (func)
  "Ensure CDP WebSocket is connected, then call FUNC with ws."
  (unless (emacs-cdp-connected-p)
    (emacs-cdp-select-tab)
    (unless (emacs-cdp-connected-p)
      (user-error "No tab selected or connection failed")))
  (funcall func emacs-cdp-websocket))

;;;; HTTP helpers
(defun emacs-cdp-http-get (url)
  "Fetch URL content as string."
  (with-temp-buffer
    (url-insert-file-contents url)
    (buffer-string)))

(defun emacs-cdp-http-put (url)
  "Send PUT request to URL and return response."
  (let ((url-request-method "PUT"))
    (with-current-buffer (url-retrieve-synchronously url)
      (goto-char (point-min))
      (search-forward "\n\n")
      (buffer-substring (point) (point-max)))))

;;;; Tab management
(defun emacs-cdp-list-tabs ()
  "Return a list of open tabs as alists."
  (condition-case nil
      (let* ((url (format "http://localhost:%d/json" emacs-cdp-debug-port))
             (tabs-json (emacs-cdp-http-get url))
             (parsed (json-parse-string tabs-json :object-type 'alist)))
        (seq-map (lambda (tab-entry)
                   `((id . ,(alist-get 'id tab-entry))
                     (title . ,(alist-get 'title tab-entry))
                     (url . ,(alist-get 'url tab-entry))
                     (ws-url . ,(alist-get 'webSocketDebuggerUrl tab-entry))
                     (attached . ,(alist-get 'attached tab-entry))))
                 parsed))
    (error
     (user-error "Cannot connect to Chrome.  Start Chrome with: chrome --remote-debugging-port=%d"
                 emacs-cdp-debug-port))))

(defun emacs-cdp-connect-tab (tab &optional on-connected)
  "Connect to Chrome TAB via CDP, activate it, and update current tab.
Optional ON-CONNECTED function is called after connection is established."
  (when (emacs-cdp-connected-p)
    (websocket-close emacs-cdp-websocket))
  (condition-case err
      (progn
        (setq emacs-cdp-websocket
              (websocket-open
               (alist-get 'ws-url tab)
               :on-open (lambda (ws)
                          (when emacs-cdp-debug
                            (message "CDP WebSocket opened"))
                          ;; Activate tab after connection is established
                          (emacs-cdp-send-command ws
                                                  "Target.activateTarget"
                                                  `(("targetId" . ,(alist-get 'id tab))))
                          ;; Call optional callback after connection is fully established
                          (when on-connected
                            (funcall on-connected)))
               :on-message (lambda (_ws frame)
                             (when emacs-cdp-debug
                               (message "CDP <- %s" (websocket-frame-payload frame))))
               :on-close (lambda (ws)
                           (when (eq ws emacs-cdp-websocket)
                             (setq emacs-cdp-websocket nil)
                             (message "CDP disconnected")))
               :on-error (lambda (_ws type err)
                           (setq emacs-cdp-websocket nil)
                           (message "CDP error: %s %s" type err))))
        (setq emacs-cdp-current-tab tab))
    (error
     (message "CDP connect failed: %s" err)
     nil)))

;;;; Key sending implementation
(defvar emacs-cdp-key-map
  '((:key "<backspace>" :key-value "Backspace" :key-code 8)
    (:key "<delete>" :key-value "Delete" :key-code 46)
    (:key "<down>" :key-value "ArrowDown" :key-code 40)
    (:key "<end>" :key-value "End" :key-code 35)
    (:key "<escape>" :key-value "Escape" :key-code 27)
    (:key "<home>" :key-value "Home" :key-code 36)
    (:key "<left>" :key-value "ArrowLeft" :key-code 37)
    (:key "<next>" :key-value "PageDown" :key-code 34)
    (:key "<prior>" :key-value "PageUp" :key-code 33)
    (:key "<return>" :key-value "Enter" :key-code 13)
    (:key "<right>" :key-value "ArrowRight" :key-code 39)
    (:key "<tab>" :key-value "Tab" :key-code 9)
    (:key "<up>" :key-value "ArrowUp" :key-code 38)
    (:key "SPC" :key-value " " :key-code 32))
  "Mapping from Emacs key names to Chrome key values.")

(defun emacs-cdp-parse-key (key-desc)
  "Parse KEY-DESC into modifiers and key for Chrome."
  (let ((modifiers 0)
        (key key-desc))
    ;; Parse modifiers and key
    (cond
     ;; Single character - no modifiers
     ((= (length key-desc) 1)
      (setq key key-desc))
     ;; Multi-character - check for modifier patterns
     ((string-match "^\\([CMSs]-\\)*\\(.\\)$" key-desc)
      (let ((mod-part (match-string 1 key-desc))
            (key-part (match-string 2 key-desc)))
        (setq key key-part)
        ;; Parse modifiers
        (when mod-part
          (when (string-match-p "C-" mod-part) (setq modifiers (logior modifiers 2))) ; Control
          (when (string-match-p "M-" mod-part) (setq modifiers (logior modifiers 1))) ; Alt
          (when (string-match-p "S-" mod-part) (setq modifiers (logior modifiers 8))) ; Shift
          (when (string-match-p "s-" mod-part) (setq modifiers (logior modifiers 4)))))) ; Meta
     ;; Special keys like <return>, <backspace>
     (t (setq key key-desc)))
    ;; Map key name
    (let ((mapped-key (seq-find (lambda (entry) (string= (plist-get entry :key) key))
                                emacs-cdp-key-map)))
      (when emacs-cdp-debug
        (message "Key parse: '%s' -> key='%s' %s" key-desc key (if mapped-key "mapped" "unmapped")))
      (list modifiers mapped-key))))

(defun emacs-cdp-send-key (key-desc)
  "Send KEY-DESC to Chrome via dispatchKeyEvent."
  (let* ((parsed (emacs-cdp-parse-key key-desc))
         (modifiers (car parsed))
         (key-info (cadr parsed))
         (chrome-key (plist-get key-info :key-value))
         (vkey (plist-get key-info :key-code))
         (params `(("type" . "keyDown")
                   ("key" . ,(or chrome-key key-desc))
                   ("modifiers" . ,modifiers))))
    (when emacs-cdp-debug
      (message "Send key: chrome-key='%s' vkey=%s" chrome-key vkey))
    (when vkey
      (push `("windowsVirtualKeyCode" . ,vkey) params))
    ;; Add text for printable characters
    (let ((text-char (or chrome-key key-desc)))
      (when (and text-char (= (length text-char) 1) (>= (aref text-char 0) 32))
        (when emacs-cdp-debug
          (message "Adding text parameter: '%s'" text-char))
        (push `("text" . ,text-char) params)))
    ;; Send key down
    (emacs-cdp-send "Input.dispatchKeyEvent" params)
    ;; Send key up (create new params to avoid modifying original)
    (let ((keyup-params (copy-alist params)))
      (setf (alist-get "type" keyup-params nil nil #'string=) "keyUp")
      (emacs-cdp-send "Input.dispatchKeyEvent" keyup-params))))

;;;; Minor modes
(defvar emacs-cdp-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [t] #'emacs-cdp-key-handler)
    (define-key map (kbd "C-c C-s") #'emacs-cdp-select-tab)
    (define-key map (kbd "C-c C-t") #'emacs-cdp-new-tab)
    (define-key map (kbd "C-c C-r") #'emacs-cdp-reload-page)
    (define-key map (kbd "C-c C-i") #'emacs-cdp-insert-text)
    (define-key map (kbd "C-c C-n") #'emacs-cdp-navigate)
    (define-key map (kbd "C-g") (lambda () (interactive) (emacs-cdp-mode -1)))
    map)
  "Keymap for Chrome CDP control mode.")

(define-minor-mode emacs-cdp-mode
  "Chrome DevTools Protocol control mode.
When enabled, all keystrokes are sent to Chrome via CDP."
  :lighter " CDP"
  :keymap emacs-cdp-mode-map
  (if emacs-cdp-mode
      (when (and (bound-and-true-p evil-mode) (bound-and-true-p evil-state))
        (setq emacs-cdp--previous-evil-state evil-state)
        (evil-emacs-state))
    (when (and (boundp 'emacs-cdp--previous-evil-state) emacs-cdp--previous-evil-state)
      (funcall (intern (format "evil-%s-state" emacs-cdp--previous-evil-state)))
      (setq emacs-cdp--previous-evil-state nil))))

(defun emacs-cdp-key-handler ()
  "Handle key events in key-send mode."
  (interactive)
  (if (minibufferp)
      (let ((key (this-command-keys-vector)))
        (setq unread-command-events (append key unread-command-events)))
    (let* ((key-sequence (this-command-keys-vector))
           (key-desc (key-description key-sequence)))
      (emacs-cdp-send-key key-desc))))

;;;; Interactive commands
;; Connection management
(defun emacs-cdp-select-tab ()
  "Prompt user to select a Chrome tab and connect."
  (interactive)
  (when-let* ((tabs (emacs-cdp-list-tabs))
              (tab-alist (mapcar (lambda (tab) (cons (alist-get 'title tab) tab)) tabs))
              (selection (completing-read "Select tab: " tab-alist nil t))
              (tab (cdr (assoc selection tab-alist))))
    (prog1 (emacs-cdp-connect-tab tab)
      (message "Connected to tab"))))

(defun emacs-cdp-new-tab ()
  "Create new Chrome tab and connect to it."
  (interactive)
  (condition-case err
      (let* ((url (format "http://localhost:%d/json/new" emacs-cdp-debug-port))
             (response (emacs-cdp-http-put url)))
        (when emacs-cdp-debug
          (message "New tab response: %s" response))
        (when-let* ((tab-info (json-parse-string response :object-type 'alist))
                    (tab-id (alist-get 'id tab-info))
                    (new-tab (seq-find (lambda (tab)
                                         (string= (alist-get 'id tab) tab-id))
                                       (emacs-cdp-list-tabs))))
          (emacs-cdp-connect-tab
           new-tab
           (lambda ()
             (emacs-cdp-send "Page.navigate" `(("url" . ,emacs-cdp-new-tab-url)))
             (message "Created and connected to new tab")))))
    (error
     (message "Failed to create new tab: %s" err))))

(defun emacs-cdp-start-chrome ()
  "Start Chrome with remote debugging enabled."
  (interactive)
  (let ((profile-dir (or emacs-cdp-profile-directory
                         (make-temp-file "chrome-debug-" t))))
    (start-process "chrome-debug" nil emacs-cdp-chrome-executable
                   (format "--remote-debugging-port=%d" emacs-cdp-debug-port)
                   (format "--user-data-dir=%s" profile-dir)
                   "--no-first-run")
    (message "Chrome started on port %d" emacs-cdp-debug-port)))

;; Page control
(defun emacs-cdp-reload-page ()
  "Reload the current Chrome page."
  (interactive)
  (emacs-cdp-send "Page.reload"))

(defun emacs-cdp-insert-text ()
  "Insert text to Chrome via minibuffer."
  (interactive)
  (let ((text (read-string "Text to insert: ")))
    (emacs-cdp-send "Input.insertText" `(("text" . ,text)))))

(defun emacs-cdp-navigate (url)
  "Navigate current tab to URL."
  (interactive "sURL: ")
  (emacs-cdp-send "Page.navigate" `(("url" . ,url))))

;;;; Initialization

;; No global keybindings - use emacs-cdp-mode instead

(provide 'emacs-cdp)
;;; emacs-cdp.el ends here
