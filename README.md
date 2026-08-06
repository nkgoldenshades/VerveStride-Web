# VerveStride - Flutter Fitness Application

A comprehensive fitness tracking application built with Flutter and Firebase.

## Features

- 🏃 Workout tracking with ML-powered pose detection
- 📊 Activity and nutrition logging
- 📅 Calendar-based progress tracking
- 🔥 Streak tracking and gamification
- 📱 Cross-platform support (Android, iOS, Web)
- 🔔 Smart notifications and reminders
- 💳 Payment integration with Razorpay
- 📈 Analytics and progress visualization

## Tech Stack

- **Frontend:** Flutter 3.4+
- **Backend:** Firebase (Auth, Firestore, Crashlytics, Cloud Functions)
- **ML:** TensorFlow Lite (MoveNet pose detection)
- **Local Database:** Isar
- **State Management:** Provider pattern
- **Ads:** Google AdMob

## Getting Started

### Prerequisites

- Flutter SDK 3.4.0 or higher
- Android Studio / Xcode
- Firebase account
- Java 17+

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nkgoldenshades/VerveStride.git
   cd vervestride
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration:**
   
   > ⚠️ **IMPORTANT:** Firebase configuration files are NOT included in this repository for security reasons.
   
   You need to create your own Firebase project and add the configuration files:
   
   - **Android:** Download `google-services.json` from Firebase Console and place it in `android/app/`
   - **iOS:** Download `GoogleService-Info.plist` and place it in `ios/Runner/`
   - **Web:** Add your Firebase config to `web/firebase-config.js`

4. **Generate Isar database files:**
   ```bash
   flutter pub run build_runner build
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

## Security

This project implements several security measures:

- Firebase App Check for API protection
- Secure storage for sensitive data
- Network security configuration
- Code obfuscation for release builds
- Proper permission handling

**Never commit:**
- `google-services.json`
- `GoogleService-Info.plist`
- Signing keys or keystores
- `.env` files

See [Security Audit Report](docs/security_audit_report.md) for details.

## Building for Production

### Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── auth/              # Authentication screens
├── models/            # Data models (Isar collections)
├── screens/           # UI screens
├── services/          # Business logic and API services
├── utils/             # Utilities and helpers
└── widgets/           # Reusable widgets
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is proprietary software. All rights reserved.

## Contact

For questions or support, please contact the development team.

---

**Built with ❤️ using Flutter**
