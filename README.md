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

- Status item: `[Meeting name] in X time` (plain text), or a yellow pill when the meeting starts in under 10 minutes or is in progress.
- Hidden when there are no upcoming meetings (after access is granted).
- Click the item for details, **Open in Calendar**, or **Quit**.
