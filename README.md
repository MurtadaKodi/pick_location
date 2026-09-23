# Pick Location

A Flutter application for selecting a location on a map, viewing the route, and navigating from the current position to a chosen destination.

## Features

- Pick a location on the map
- Show the current location and selected destination
- Calculate a road-following route using OSRM
- Show a blue route line on the map
- Toggle route visibility on and off
- Follow the current location live while moving
- Rotate map direction based on heading
- Open navigation apps with destination details

## Requirements

- Flutter SDK
- Android Studio / Xcode depending on target platform
- Location permission enabled

## Setup

```bash
flutter pub get
```

## Run the app

```bash
flutter run
```

## Build APK

```bash
flutter build apk --release
```

The generated APK will be available in:

```bash
build/app/outputs/flutter-apk/app-release.apk
```

## Usage

1. Allow location access when prompted.
2. Select a point on the map or use the current location.
3. Tap the navigation button to show the route.
4. Tap again to hide the route.
5. Use the location button to follow your current position live while moving.
6. Choose a navigation app if prompted.

## Notes

- The app uses OpenStreetMap tiles and OSRM route geometry.
- The live follow mode keeps the camera centered on your current location while the position updates.
- External navigation opens in installed apps when available.
