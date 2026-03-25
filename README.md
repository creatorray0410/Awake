# Awake ☕

A simple, lightweight macOS menu bar utility that prevents your Mac from sleeping. Inspired by [Lungo](https://sindresorhus.com/lungo).

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Download

Download the latest DMG from the [Releases](https://github.com/creatorray0410/Awake/releases) page.

## Features

- **One-click toggle** — Activate/deactivate sleep prevention from the menu bar
- **Timer mode** — Set a timer (10min, 30min, 1h, 2h, 4h, 8h) to automatically deactivate
- **Two prevention modes**
  - *Display & System*: Prevents both display and system sleep
  - *System Only*: Keeps system running but allows display to sleep
- **Native SF Symbols** — Uses macOS system icons (coffee cup)
- **Countdown display** — Shows remaining time in the menu bar when timer is active
- **Lightweight** — Pure Swift, no dependencies, minimal resource usage (~15MB RAM)
- **No Dock icon** — Runs as a menu bar-only app

## Screenshots

After launching, Awake lives in your menu bar:

- ☕ **Filled cup** = Awake is active (your Mac won't sleep)
- 💤 **Empty cup** = Awake is inactive (normal sleep behavior)

Click the icon to see the menu with all options.

## How It Works

Awake uses the macOS **IOKit Power Management API** (`IOPMAssertionCreateWithName`) to create power assertions that prevent the system from sleeping. This is the exact same mechanism used by:

- macOS built-in `caffeinate` command
- Professional apps like Lungo, Amphetamine, etc.

The core implementation is remarkably simple — just a single API call:

```swift
IOPMAssertionCreateWithName(
    kIOPMAssertionTypePreventUserIdleDisplaySleep as NSString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    "Awake is keeping your Mac awake" as NSString,
    &assertionID
)
```

## Build from Source

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

### Build

```bash
git clone https://github.com/creatorray0410/Awake.git
cd Awake
./build.sh
```

Or manually:

```bash
cd Awake
mkdir -p Awake.app/Contents/MacOS Awake.app/Contents/Resources
iconutil -c icns Resources/AppIcon.iconset -o Awake.app/Contents/Resources/AppIcon.icns
cp Resources/Info.plist Awake.app/Contents/Info.plist
swiftc Sources/main.swift \
    -o Awake.app/Contents/MacOS/Awake \
    -framework AppKit \
    -framework IOKit \
    -target arm64-apple-macosx13.0
```

### Run

```bash
open Awake/Awake.app
```

### Install

```bash
cp -r Awake/Awake.app /Applications/
```

## Project Structure

```
Awake/
├── Awake/
│   ├── Sources/
│   │   └── main.swift          # Complete source code (single file)
│   ├── Resources/
│   │   ├── Info.plist           # App configuration
│   │   ├── AppIcon.iconset/     # Icon source files
│   │   └── AppIcon.png          # Original icon image
│   └── Awake.app/               # Built app bundle (not in git)
├── build.sh                     # Build script
├── create-dmg.sh                # DMG creation script
├── LICENSE                      # MIT License
└── README.md                    # This file
```

## License

MIT License — see [LICENSE](LICENSE) for details.
