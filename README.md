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

- Status item: shows `[Meeting name] in X time` (calendar icon) for the next actionable meeting. While you are in a meeting, the bar rolls forward to the following event after a short join grace (~2 minutes). Yellow pill when a featured meeting starts in under 10 minutes, or during that join grace for a meeting that just started.
- Hidden when there are no upcoming meetings (after access is granted).
- Click the item for details, **Open in Calendar**, or **Quit**.
