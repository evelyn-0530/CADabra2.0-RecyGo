# RecyGo App

## Description

This folder contains the Flutter app source code for the RecyGo smart recycling system.

The app connects users to the correct RecyGo bin, tracks recycling activity, updates reward points, shows mission progress, and allows users to redeem reward cards after collecting enough points.

## Main Features

- User login
- Bin QR code scanning
- Connection to selected RecyGo bin
- Reward points display
- Mission progress tracking
- Reward card redemption
- Firebase Authentication
- Firebase Firestore integration

## Folder Structure

```text
RecyGo_App/
├── README.md
├── assets/
│   └── logo.jpg
├── lib/
│   ├── main.dart
│   ├── app_state.dart
│   ├── firebase_options.dart
│   ├── home_page.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── qr_scanner_screen.dart
│   ├── missions_page.dart
│   ├── splash_screen.dart
│   └── services/
│       └── firestore_service.dart
├── pubspec.yaml
└── pubspec.lock
```

## Main Files

### `main.dart`

Initializes Firebase and starts the Flutter app.

### `app_state.dart`

Manages app data such as:

- User points
- Connected bin
- Mission progress
- Reward redemption
- Waste event updates

### `firebase_options.dart`

Stores Firebase configuration for the Flutter app.

### `home_page.dart`

Main dashboard page showing:

- Current reward points
- Connected bin status
- Badges
- Active mission
- Reward cards
- QR scan button

### `login_screen.dart`

Allows users to log in using Firebase Authentication.

### `register_screen.dart`

Provides a registration screen interface.

### `qr_scanner_screen.dart`

Uses the camera to scan the RecyGo bin QR code.

### `missions_page.dart`

Displays the list of recycling missions and progress.

### `splash_screen.dart`

Checks the authentication state and redirects users to the correct screen.

### `services/firestore_service.dart`

Handles Firestore database functions, including:

- Saving user data
- Saving waste events
- Awarding points
- Reading reward rules

## Required Packages

The app uses the following Flutter packages:

```text
firebase_core
firebase_auth
cloud_firestore
mobile_scanner
provider
cupertino_icons
```

These dependencies are listed in `pubspec.yaml`.

## How to Run

1. Install Flutter SDK.
2. Open this folder in VS Code or Android Studio.
3. Run the following command:

```bash
flutter pub get
```

4. Connect a device or open an emulator.
5. Run the app:

```bash
flutter run
```

## Assets

The app uses the RecyGo logo:

```text
assets/logo.jpg
```

This asset is registered in `pubspec.yaml`.

## Firebase Note

This app uses Firebase Authentication and Cloud Firestore.

Firebase configuration is included in:

```text
lib/firebase_options.dart
```

Private Firebase admin key files are not included for security reasons.

Do not upload:

```text
firebase_key.json
serviceAccountKey.json
.env
```

## App Workflow

1. User opens the app.
2. User logs in.
3. User scans the bin QR code.
4. App connects the user to the selected RecyGo bin.
5. Waste sorting activity is recorded.
6. Reward points are updated.
7. Mission progress increases.
8. User can redeem reward cards after collecting enough points.

## Purpose in RecyGo System

The app encourages recycling participation by turning correct recycling behavior into a reward-based system. It helps users track their contribution and makes recycling more engaging.
