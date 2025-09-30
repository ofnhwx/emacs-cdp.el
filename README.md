# emacs-cdp

Control Chrome/Chromium browser from Emacs using Chrome DevTools Protocol (CDP).

## Features

- **Browser Control**: Connect to and control Chrome tabs directly from Emacs
- **Key Forwarding**: Send keyboard input from Emacs to Chrome
- **Tab Management**: Select, create, and switch between Chrome tabs
- **Page Control**: Reload pages and insert text programmatically
- **Minor Mode**: Convenient key-send mode for seamless browser interaction

## Requirements

- Emacs 30.1 or later
- `websocket` package (available from MELPA)
- Chrome or Chromium browser

## Installation

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/ofnhwx/emacs-cdp.git
```

2. Add to your Emacs configuration:
```elisp
(add-to-list 'load-path "/path/to/emacs-cdp")
(require 'emacs-cdp)
```

### Package Installation

Install `websocket` dependency:
```elisp
(package-install 'websocket)
```

## Setup

### Start Chrome with Remote Debugging

Chrome must be started with remote debugging enabled:

```bash
# Default port 9222
google-chrome --remote-debugging-port=9222

# With custom user profile
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
```

Or use the built-in command from Emacs:
```elisp
M-x emacs-cdp-start-chrome
```

## Usage

### Basic Connection

1. **Connect to a Chrome tab**:
   ```elisp
   M-x emacs-cdp-select-tab
   ```
   Select a tab from the list of open Chrome tabs.

2. **Create and connect to a new tab**:
   ```elisp
   M-x emacs-cdp-new-tab
   ```

### Key Send Mode

Enable the minor mode to forward keys to Chrome:

```elisp
M-x emacs-cdp-mode          ; Enable CDP control mode
```

When CDP mode is active:
- All keys are sent to the connected Chrome tab (except special key combinations)
- `C-g` exits CDP mode
- `C-c C-s` selects a different tab
- `C-c C-t` creates a new tab
- `C-c C-r` reloads the page
- `C-c C-i` inserts text
- `C-c C-n` navigates to URL

### Commands

| Command | Key Binding | Description |
|---------|-------------|-------------|
| `emacs-cdp-select-tab` | `C-c C-s` (in CDP mode) | Select and connect to a Chrome tab |
| `emacs-cdp-new-tab` | `C-c C-t` (in CDP mode) | Create and connect to a new tab |
| `emacs-cdp-reload-page` | `C-c C-r` (in CDP mode) | Reload the current page |
| `emacs-cdp-insert-text` | `C-c C-i` (in CDP mode) | Insert text via minibuffer prompt |
| `emacs-cdp-navigate` | `C-c C-n` (in CDP mode) | Navigate to URL |
| `emacs-cdp-start-chrome` | - | Start Chrome with remote debugging |
| `emacs-cdp-mode` | - | Toggle CDP control mode |

### Configuration

Customize the package behavior:

```elisp
;; Chrome executable path (default: "google-chrome-stable")
(setq emacs-cdp-chrome-executable "chromium")

;; Remote debugging port (default: 9222)
(setq emacs-cdp-debug-port 9222)

;; Chrome profile directory (nil for temporary)
(setq emacs-cdp-profile-directory "~/.config/chrome-debug")

;; Enable debug logging
(setq emacs-cdp-debug t)
```

#### Configuration for Evil Users

If you use Evil, you can configure a hook to automatically switch to Emacs state when `emacs-cdp-mode` is enabled:

```elisp
(add-hook 'emacs-cdp-mode-hook
          (lambda ()
            (when (bound-and-true-p evil-mode)
              (if emacs-cdp-mode
                  ;; When CDP mode is enabled: switch to Emacs state
                  (evil-emacs-state)
                ;; When CDP mode is disabled: return to Normal state
                (evil-normal-state)))))
```

## Example Workflow

```elisp
;; Start Chrome with debugging
(emacs-cdp-start-chrome)

;; Connect to a tab
(emacs-cdp-select-tab)

;; Enable CDP mode
(emacs-cdp-mode 1)

;; Now all keys are sent to Chrome (except C-c combinations)
;; Use C-c commands for control:
;; C-c C-r to reload page
;; C-c C-i to insert text
;; C-c C-n to navigate to URL
;; C-g to exit CDP mode

;; Or use individual commands
(emacs-cdp-reload-page)
(emacs-cdp-insert-text)  ; Prompts for text to insert
(emacs-cdp-navigate)     ; Prompts for URL
```

## Key Mapping

The package automatically maps Emacs key sequences to Chrome key codes:

- `RET` → `Enter`
- `TAB` → `Tab`
- `ESC` → `Escape`
- `C-` → Control modifier
- `M-` → Alt modifier
- `S-` → Shift modifier
- Arrow keys, Page Up/Down, Home/End are supported

## Troubleshooting

1. **Cannot connect to Chrome**:
   - Ensure Chrome is running with `--remote-debugging-port=9222`
   - Check if the port is accessible: `curl http://localhost:9222/json`

2. **Keys not being sent**:
   - Verify connection with `(emacs-cdp-connected-p)`
   - Enable debug mode: `(setq emacs-cdp-debug t)`

3. **Connection drops**:
   - Chrome may close WebSocket connections after inactivity
   - Reconnect with `emacs-cdp-select-tab`

## License

GPL-3.0. See the file header for details.

## Author

ofnhwx

## Contributing

Issues and pull requests are welcome at [GitHub](https://github.com/ofnhwx/emacs-cdp).
