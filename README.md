# SnapAGram - Flutter Firebase Authentication App

A beautiful and modern Flutter application with Firebase authentication, featuring both email/password and Google Sign-In, with a clean UI and smooth user experience.

## Features

- 🔐 **Firebase Authentication**
  - Email and password sign up/sign in
  - **Google Sign-In integration**
  - Secure authentication state management
  - Automatic session persistence
  - Password validation and error handling

- 🎨 **Modern UI/UX**
  - Clean and intuitive design
  - Google Fonts integration
  - Responsive layout
  - Loading states and error handling
  - Beautiful animations and transitions
  - User profile display with Google profile pictures

- 📱 **Cross-Platform**
  - Works on Android, iOS, Web, and Desktop
  - Consistent experience across platforms

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Firebase project with Authentication enabled
- Google Cloud Console project with OAuth 2.0 configured
- Android Studio / VS Code

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd snapagram
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

The app is already configured with your Firebase project. The configuration is located in:
- `lib/firebase_options.dart`

### 4. Google Sign-In Setup

#### Firebase Console Setup:
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Email/Password" provider
3. Enable "Google" provider
4. Add your authorized domains

#### Google Cloud Console Setup:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to APIs & Services → Credentials
4. Create OAuth 2.0 Client ID for your platforms:
   - **Web**: Add your domain to authorized origins
   - **Android**: Add your package name and SHA-1 fingerprint
   - **iOS**: Add your bundle identifier

### 5. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── services/
│   └── auth_service.dart     # Authentication service (Email + Google)
└── screens/
    ├── auth/
    │   ├── login_screen.dart    # Login screen with Google Sign-In
    │   └── signup_screen.dart   # Sign up screen with Google Sign-In
    └── home/
        └── home_screen.dart     # Home screen with user profile
```

## Authentication Flow

1. **App Launch**: The app checks for existing authentication state
2. **Login Screen**: Users can sign in with:
   - Email and password
   - **Google Sign-In**
3. **Sign Up Screen**: New users can create accounts with:
   - Email and password
   - **Google Sign-In**
4. **Home Screen**: Authenticated users see the main app interface with:
   - User profile information
   - Google profile picture (if signed in with Google)
   - Authentication method indicator
5. **Sign Out**: Users can sign out from the home screen

## Dependencies

- `firebase_core`: Firebase core functionality
- `firebase_auth`: Firebase authentication
- `google_sign_in`: Google Sign-In integration
- `cloud_firestore`: Firestore database (for future features)
- `provider`: State management
- `google_fonts`: Custom fonts
- `flutter_svg`: SVG support

## Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication with:
   - Email/Password provider
   - **Google provider**
3. Add your app to the Firebase project
4. Download and add the configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS

## Google Sign-In Configuration

### Web Configuration:
- Add your domain to authorized origins in Google Cloud Console
- The web client ID is already configured in the app

### Android Configuration:
- Add your package name to OAuth 2.0 client
- Add SHA-1 fingerprint to Firebase project settings
- Update `android/app/build.gradle` with your package name

### iOS Configuration:
- Add your bundle identifier to OAuth 2.0 client
- Update `ios/Runner/Info.plist` with URL schemes

## Features to Add

- [ ] Password reset functionality
- [ ] Apple Sign-In (for iOS)
- [ ] Facebook Sign-In
- [ ] User profile management
- [ ] Photo upload and storage
- [ ] Real-time messaging
- [ ] Push notifications

## Troubleshooting

### Google Sign-In Issues:
1. **"Sign-in was cancelled"**: This is normal when user cancels the sign-in flow
2. **"Network error"**: Check internet connection and Firebase configuration
3. **"Invalid credential"**: Ensure OAuth 2.0 client is properly configured

### Common Issues:
- Make sure all Firebase providers are enabled
- Verify OAuth 2.0 client IDs are correct
- Check that authorized domains are properly configured

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

If you encounter any issues or have questions, please open an issue on GitHub.

---

**Note**: Make sure to enable both Email/Password and Google authentication in your Firebase project settings before testing the app. 