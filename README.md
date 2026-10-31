# Nagbell

Loud reminders you can't ignore. A small floating macOS window with one-tap timers ("Motor Off — 20 min", "Milk — 15 min"). When a timer is due, the window jumps to the front, a sound repeats, and a voice reads the reminder out loud until you press Done or Snooze.

Planned: an Android app that syncs timers with the Mac over home WiFi, so both ring at the same time.

## Requirements

- macOS 15+
- Swift 6 (Xcode or Command Line Tools)

## Build and run

```sh
./build-app.sh       # builds Nagbell.app and installs it to /Applications
open Nagbell.app
```

## Test

```sh
./test.sh            # wraps `swift test`; plain `swift test` works with full Xcode
```

## Data

Presets are stored in `~/Library/Application Support/Nagbell/presets.json`. A corrupt file is moved to `presets.json.bak`, never overwritten.

Custom alarm sounds: drop an `.aiff` into `~/Library/Sounds`.
