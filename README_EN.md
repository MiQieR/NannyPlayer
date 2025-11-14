# Nanny Player (外婆音乐)

<div align="center">

<img src="img/app.png" width="200"/>

A minimalist music player designed for elderly-friendly devices, optimized for 480x320 resolution Android phones like `Coolpad Golden Century Y60`, `TCL T50N`, `Sunelan Q968`, `BIHEE A89`.

[![中文文档](https://img.shields.io/badge/docs-中文-blue.svg)](README.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green.svg)](https://www.android.com/)

[Features](#features) • [Screenshots](#screenshots) • [Usage](#usage) • [Installation](#installation) • [Development](#development)

</div>

## Features

### 🎯 Elderly-Friendly Design

- **Extra Large Buttons**: Play/Pause button size is 140x140 pixels, easy to tap for seniors
- **Simple Interface**: No complex features, direct access to player, intuitive operation
- **Large Font**: All text uses enlarged fonts (18-20px), easy to read
- **High Contrast**: Blue and white color scheme, clear and prominent
- **Auto Scrolling**: Long song names automatically scroll horizontally, never truncated

### 🕹️ Physical Key Support

Full support for Android Directional Buttons:

- **Center Key**: Play/Pause
- **Left Key**: Previous track
- **Right Key**: Next track
- **Up Key**: Volume up (+10% per press)
- **Down Key**: Volume down (-10% per press)

> Especially suitable for elderly phones with physical directional keys, such as `Jinshiji Y60`, `TCL T50N`, `Yiqing Q968`, `Baihe A89`

### 🎵 Core Playback Features

- **Playback Control**: Play/Pause, Previous, Next
- **Volume Control**: Adjust system volume with percentage display
- **Progress Display**: Real-time playback progress and total duration (00:00 / 00:00 format)
- **Playback Modes**:
  - Sequential Play: Loop playback in filename order
  - Shuffle Play: Random playback using Fisher-Yates shuffle algorithm

### 💾 Smart Storage Features

- **Resume Playback**: Auto-save playback progress, resume from last position on reopen
- **State Persistence**: Save playlist, current song, progress, shuffle mode state
- **Background Save**: Auto-pause and save progress when app goes to background

## Screenshots

### Main Interface
<div align="center">
<img src="img/screenshot.png" alt="Main Interface" width="300"/>
</div>

Clean and clear interface, optimized for 480x320 resolution:
- Top: Song name and playback time
- Middle: Extra large Play/Pause button
- Bottom: Previous/Next controls
- Bottom bar: Progress slider and settings entry

## Usage

### First Time Setup

1. Open the app and tap the "Settings" button at the bottom
2. Tap "Select Music Files" button
3. Select music files from device storage (multi-select supported)
4. Return after selection, music starts playing automatically

### Daily Operations

#### Touch Screen Controls
- **Play/Pause**: Tap the large circular button in the center
- **Switch Tracks**: Tap Previous/Next buttons below
- **Adjust Progress**: Drag the progress bar to desired position
- **Change Music**: Tap Settings button, reselect music files
- **Switch Mode**: Toggle "Shuffle Play" in Settings

#### Physical Key Controls
- **Play/Pause**: Press Center key
- **Previous Track**: Press Left key
- **Next Track**: Press Right key
- **Volume Up**: Press Up key
- **Volume Down**: Press Down key

### Automatic Features

- Auto-pause and save progress when exiting app
- Auto-resume to last played song and position when reopening
- Auto-play next track when current song finishes
- Auto-scroll display for long song names
- Auto-pause when app goes to background

## Installation

### Method 1: Install Pre-compiled APK (Recommended)

1. Download the latest APK from [Releases](https://github.com/MiQieR/NannyPlayer/releases) page
2. Transfer APK to Android device
3. Open APK file on device to install
4. May need to allow "Unknown Sources" in settings for first-time installation

### Method 2: Build from Source

**Prerequisites**
- Flutter SDK 3.9.2 or higher
- Android SDK (minSdkVersion: 21)
- Dart SDK

**Build Steps**

1. Clone repository
```bash
git clone https://github.com/MiQieR/NannyPlayer.git
cd NannyPlayer
```

2. Install dependencies
```bash
flutter pub get
```

3. Generate app icons
```bash
dart run flutter_launcher_icons
```

4. Build APK
```bash
flutter build apk --release
```

5. Generated APK located at `build/app/outputs/flutter-apk/app-release.apk`

## Development

### Tech Stack

| Technology | Version | Purpose |
|------|------|------|
| Flutter | ^3.9.2 | UI Framework |
| Dart | ^3.0.0 | Programming Language |
| just_audio | ^0.9.46 | High-quality audio playback engine |
| shared_preferences | ^2.5.3 | Local key-value storage |
| file_picker | ^8.1.6 | File picker |
| path_provider | ^2.1.5 | Path access |
| volume_controller | ^2.0.7 | System volume control |
| marquee | ^2.2.3 | Text scrolling display |
| flutter_launcher_icons | ^0.14.1 | App icon generation |

### Android Permissions

The app requires the following permissions:

```xml
<!-- Read audio files -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- Keep device awake during playback -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Background playback support -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### Core Architecture

**Single File Architecture**
- Entire app uses only one Dart file (`main.dart`)
- Contains 4 page classes: `NannyPlayerApp`, `PlayerPage`, `SettingsPage`, `AboutPage`
- Uses `StatefulWidget` for UI state management
- Uses `WidgetsBindingObserver` mixin to monitor app lifecycle

**State Management**
- Uses `setState()` for UI state updates
- Uses `SharedPreferences` for data persistence
- Uses Stream to monitor audio playback state

**Player Logic**
- Uses `AudioPlayer` class from `just_audio`
- Monitors `playerStateStream`, `positionStream`, `durationStream`
- Implements Fisher-Yates shuffle algorithm for random playback

### Code Standards

- Static analysis via `flutter analyze` (0 issues)
- Follows Dart official style guide
- Uses `flutter_lints ^5.0.0` for code linting

## Notes

1. **Permission Grant**: Storage permission required on first use to read music files
2. **Platform Support**: Android only, optimized for portrait devices
3. **Screen Size**: Interface optimized for 480x320 resolution, other resolutions may need adjustment
4. **Screen Orientation**: Locked to portrait mode, landscape not supported
5. **Audio Formats**: Supports all Android-supported audio formats (MP3, AAC, FLAC, etc.)
6. **File Selection**: Uses system file picker, supports batch selection of multiple files

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Issues and Pull Requests are welcome!

If you have suggestions or find bugs, please submit them on the [Issues](https://github.com/MiQieR/NannyPlayer/issues) page.

---

<div align="center">
Made with ❤️ for elderly users
</div>
