# ClipboardManager

A lightweight macOS menu bar app for managing your clipboard history. Copy anything — text, images, links, files — and instantly find and re-paste it.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Clipboard history** — automatically captures text, rich text, images, screenshots, links, and files
- **Instant search** — full-text search across your entire history
- **Type filters** — quickly filter by Text, Images, Links, Files, or Screenshots
- **Categories** — organize items into custom categories (Work, Personal, Real Estate, and more)
- **Pin & Favorite** — keep important items always accessible
- **Global hotkey** — open the panel from anywhere with `⌘ ⇧ V`
- **Privacy first** — all data stored locally in SQLite; password managers are automatically excluded
- **Keyboard navigation** — arrow keys to browse, Return to paste, Escape to dismiss

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (to build from source)

## Installation

### Build from Source

```bash
git clone https://github.com/bendahanmoshe/clipboard-manager-mac.git
cd clipboard-manager-mac
open ClipboardManager.xcodeproj
```

Then press `⌘R` in Xcode to build and run.

## Usage

1. **Launch** the app — a clipboard icon appears in the menu bar (top-right of screen)
2. **Click the icon** or press `⌘ ⇧ V` to open the panel
3. **Search** your history or use the type filter tabs
4. **Single-click** an item to preview it; **double-click** to paste instantly
5. **Assign to a category** by selecting an item and using the category menu in the preview panel

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ ⇧ V` | Open / close panel |
| `↑ / ↓` | Navigate items |
| `Return` | Paste selected item |
| `Escape` | Close panel |

## Privacy

- Clipboard data never leaves your machine
- Password managers (1Password, Bitwarden, Keychain Access) are excluded by default
- Monitoring can be paused at any time from the menu bar icon or the sidebar

## Project Structure

```
Sources/ClipboardManager/
├── main.swift                  # App entry point
├── AppDelegate.swift           # Menu bar setup, panel, hotkey
├── Models/
│   ├── ClipboardItem.swift     # Data model & types
│   └── ClipboardCategory.swift # Category model
├── ViewModels/
│   └── ClipboardViewModel.swift
├── Views/
│   ├── MainPanelView.swift
│   ├── SidebarView.swift
│   ├── ClipboardListView.swift
│   ├── ClipboardRowView.swift
│   ├── PreviewPanelView.swift
│   ├── SearchBarView.swift
│   └── SettingsView.swift
├── Services/
│   ├── ClipboardMonitor.swift  # NSPasteboard polling
│   ├── StorageService.swift    # SQLite persistence
│   ├── HotkeyService.swift     # Global hotkey (Carbon)
│   └── PasteService.swift      # Programmatic paste
└── Resources/
    └── Info.plist
```

## License

MIT
