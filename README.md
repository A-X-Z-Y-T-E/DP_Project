# Vital Monitor

Vital Monitor is a cross-platform Flutter application for real-time health monitoring using Bluetooth Low Energy (BLE) devices (such as STM32WB55). The app provides live heart rate and calorie tracking, visualizes health data with interactive graphs, and securely stores user data in Firebase. It is designed for both end-users and developers interested in BLE health solutions.

---

## Features

- **User Authentication:** Secure login with Firebase.
- **Bluetooth Device Discovery:** Scan and connect to STM32WB55 and other BLE health devices.
- **Real-Time Health Monitoring:** Live heart rate and calorie data streaming from the device.
- **Sensor Contact & Position Detection:** Visual feedback for sensor placement and contact status.
- **Interactive Data Visualization:** Beautiful, responsive charts for heart rate and calories (using fl_chart).
- **Health History:** View and analyze historical health data.
- **Cloud Storage:** All readings are stored in Firebase for persistence and analysis.
- **Modern UI:** Clean, intuitive interface with dark mode support.
- **Extensible Architecture:** Modular codebase for easy feature expansion.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Dart SDK](https://dart.dev/get-dart)
- [Firebase Project](https://console.firebase.google.com/)
- BLE-capable device (e.g., STM32WB55)

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/yourusername/vital_monitor.git
   cd vital_monitor
   ```

2. **Install dependencies:**
   ```sh
   flutter pub get
   ```

3. **Configure Firebase:**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Ensure your `firebase_options.dart` is generated and present.

4. **Run the app:**
   ```sh
   flutter run
   ```

---

## Project Structure

```
lib/
├── controllers/         # State management and business logic (GetX)
│   └── bluetooth_controller.dart
├── views/               # UI pages (Home, Device Details, Health Monitor, etc.)
├── widgets/             # Reusable UI components
├── utils/               # Utility functions and helpers
├── services/            # BLE and Firebase service classes
├── main.dart            # App entry point
└── firebase_options.dart
```

---

## BLE Protocol

- **Device Discovery:** Uses `flutter_blue_plus` to scan for BLE devices.
- **Connection:** Connects to STM32WB55 and discovers services/characteristics.
- **Data Format:** Receives heart rate and calorie data as characteristic notifications.
- **Sensor Location:** Reads sensor position and contact status for visualization.

---

## Firebase Integration

- **Authentication:** Email/password login via Firebase Auth.
- **Data Storage:** Health readings are stored in Firestore under each user's document.
- **Security:** Follows Firebase security rules for data privacy.

---

## Customization

- **Add More Metrics:** Extend `bluetooth_controller.dart` to handle additional health data (e.g., SpO2, temperature).
- **UI Themes:** Modify styles in `views/` and `widgets/` for branding.
- **Notifications:** Integrate push notifications for health alerts.

---

## Contributing

Contributions are welcome! Please open issues or submit pull requests for improvements and bug fixes.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/)
- [fl_chart](https://pub.dev/packages/fl_chart)
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)
- STM32WB55 BLE reference

---

**For questions or support, please contact [siddhanthpvashist@gmail.com].**
