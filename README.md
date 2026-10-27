# Calenbar

Menu bar app for macOS that shows your next calendar meeting from the calendars synced in Calendar.app.

## Requirements

- macOS 14 or later
- Xcode 27 (or recent Xcode with macOS 14 SDK)

## Build

```bash
cd "/Users/ivan/Desktop/Cursor projects/calenbar"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Calenbar.xcodeproj \
  -scheme Calenbar \
  -configuration Debug \
  build
```

Open `Calenbar.xcodeproj` in Xcode, choose destination **My Mac**, and run (⌘R). Grant **Full Calendar Access** when prompted.

If Xcode reports an architecture mismatch, use **Product → Clean Build Folder**, then build again. The target is configured for **macOS** / **Standard Architectures** (`arm64` on Apple Silicon).

## Behavior

- Status item: shows the relevant meeting name with a time phrase (calendar icon). Phrases: `in X min` / `in X h Y min` for the next event, `X min left` while a long meeting is in progress, and **Join now** (blue capsule) when the next event starts in 2 minutes or less, or for the first 5 minutes after a meeting with a video link starts. While a meeting is running and the next one is more than 15 minutes away, the bar shows time remaining on the current event; at 15 minutes or less until the next event, it switches to the next event’s countdown. Yellow pill when **Join now** is shown or the displayed countdown is under 10 minutes. Left click joins only when **Join now** is shown; otherwise click opens the menu (**Join** remains in the menu during the 10-minute early-join window when a link is available).
- Hidden when there are no upcoming meetings (after access is granted).
- Click the item for a menu with **Next event** (Join / Dismiss when available, then **View event**), **Today** (the day’s events), and **Quit**. When **Join now** is shown, the menu includes **Dismiss** to switch to the next schedule phrase (countdown or time remaining); dismissal uses the same suppression window as joining from Calenbar (through 5 minutes after that event’s start).
