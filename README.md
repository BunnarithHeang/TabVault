# TabVault

A native macOS app that lets you view, copy, and export all open tabs from your browsers — across every window — in one place.

## Features

- **Multi-browser support** — Safari, Google Chrome, Brave, Arc, Microsoft Edge, Opera, Vivaldi, Chromium, Orion
- **Window tab bar** — when viewing a specific browser, filter tabs by window (Window 1, Window 2, …) or view all at once
- **Live refresh** — tabs update automatically every 2 seconds while the app is in focus
- **Copy URLs** — click any row or use the copy button to copy a single URL to clipboard
- **Copy All** — copy all visible URLs (title + URL) to clipboard in one click
- **Export to file** — save the current tab list as a `.txt` file
- **Permission guidance** — clear in-app prompts if macOS Automation access hasn't been granted

## Requirements

- macOS 13 Ventura or later

## Supported Browsers

| Browser | Supported |
|---|---|
| Safari | ✅ |
| Google Chrome | ✅ |
| Brave Browser | ✅ |
| Arc | ✅ |
| Microsoft Edge | ✅ |
| Opera | ✅ |
| Vivaldi | ✅ |
| Chromium | ✅ |
| Orion | ✅ |
| Chrome Canary | ✅ |

## Download

Go to the [Releases](../../releases) page and download the latest `TabVault.dmg`.

1. Open the DMG and drag **TabVault.app** to your Applications folder
2. On first launch, right-click the app → **Open** → **Open** to bypass the Gatekeeper warning (unsigned build)
3. Grant **Automation** permission when prompted

> Alternatively, you can remove the quarantine flag in Terminal:
> ```bash
> xattr -cr /Applications/TabVault.app
> ```


## macOS Permissions

TabVault uses AppleScript to read tab information from browsers. macOS requires **Automation** permission to be granted for each browser you want to read.

On first launch, macOS will prompt you automatically. If you decline or want to manage permissions later:

1. Open **System Settings → Privacy & Security → Automation**
2. Find **TabVault** and enable the toggle for each browser

## Privacy

All data stays on your machine. TabVault makes no network requests and does not store or transmit any tab data.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Built by [Bunnarith Heang](https://github.com/BunnarithHeang).
