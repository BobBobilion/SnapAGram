## Gemini CLI Ruleset for SnapAGram Flutter Development

STAY EXTREMELY FOCUSED ON THE TASK AT HAND.

### General Behavioral Guidelines

* Always read and understand the entire file before making any modifications. Avoid piecemeal edits without full context.
* Stick to the current task or user prompt. Do not add extra features or files unless explicitly instructed.
* Preserve existing logic unless instructed otherwise. Don't refactor or optimize code unprompted.
* Maintain a consistent Dart/Flutter coding style as defined in the `analysis_options.yaml` or Google's Dart style guide.
* **STOP RUNNING THE PROJECT** - The project is already running, do not suggest or execute `flutter run` commands.

### File Safety and Change Control

* Do not overwrite existing files blindly.
  * When editing a file, parse the entire structure and update only relevant parts.
  * If replacing a file, show a diff or warning before applying.
* Never modify the following files unless explicitly asked:
  * `firebase_options.dart`
  * `google-services.json`
  * `ios/Runner/GoogleService-Info.plist`
  * `pubspec.yaml` (unless dependency update is explicitly requested)
  * `.gitignore`
  * `.env` or environment-specific config files
  * `android/app/libs/deepar.aar` (AR effects library)
  * `assets/effects/` directory (DeepAR effect files)
* Avoid any direct changes to production Firebase rules or indexes.
  * Example: Do not modify `firestore.rules` or `firestore.indexes.json` unless explicitly prompted.

### SnapAGram-Specific Safety Measures

* **AR Effects Protection**: Never modify or delete files in `assets/effects/` directory - these are DeepAR effect files critical for the app's AR functionality.
* **Camera & Media Safety**: Be extremely careful when modifying camera-related code in `lib/screens/camera/` - this affects core app functionality.
* **Story System**: Preserve the ephemeral story system logic - stories should expire after 24 hours.
* **User Roles**: Maintain the distinction between walkers and owners in the role system.
* **GPS Tracking**: Be cautious with location services - ensure battery optimization and privacy compliance.
* **DeepAR Integration**: Do not modify DeepAR plugin integration without understanding the AR effect system.

### Dangerous Command Restrictions

Gemini must avoid using or generating these commands unless explicitly prompted:

* `flutter clean` (can disrupt local cache/build unexpectedly)
* `flutter run` (project is already running)
* `rm`, `rm -rf`, or `del` commands
* `git push` or `git reset` commands
* `firebase deploy` or `firebase use` (risk of affecting production)
* Shell commands that delete or modify folders (`mv`, `cp -r`, etc.)
* Any commands that might affect the running development server

### Code Editing Practices

* For UI files (`.dart`):
  * Maintain widget tree structure and indentation.
  * Avoid over-nesting unless using `builder` or `children` patterns.
  * Use `const` constructors where applicable for performance.
  * Follow the existing screen organization in `lib/screens/`.
* For Firebase logic:
  * Use `await` and `try/catch` when calling `Firestore`, `Auth`, or `Storage`.
  * Wrap any asynchronous operations in `FutureBuilder`, `StreamBuilder`, or custom state management handlers.
* For form and input validation:
  * Always validate using `TextFormField` + validators.
  * Never skip form checks unless instructed.
* For camera and media handling:
  * Ensure proper permission handling for camera and storage access.
  * Maintain the existing photo/video editing workflow.

### Dependency Management

* Only install packages that are stable and production-ready.
  * Avoid pre-release or beta plugins unless asked.
  * Prefer official Firebase plugins: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, etc.
  * Be cautious with AR-related dependencies - maintain DeepAR compatibility.
* Do not remove existing dependencies. Add only what's required for the task.
* **Critical Dependencies to Preserve**:
  * `deepar_flutter_plus` - AR effects system
  * `google_maps_flutter` - GPS tracking
  * `location` and `geolocator` - Location services
  * `firebase_database` - Real-time GPS data

### Testing and Stability

* Do not modify or remove test files (`*_test.dart`) unless requested.
* All generated logic should be null-safe, performant, and avoid memory leaks (especially in `dispose()`).
* Ensure new services or widgets are stateless unless they manage their own state explicitly.
* Test camera functionality thoroughly when making changes.

### Project Architecture Awareness

* Respect the existing folder structure:
  * `lib/models/` - Data models (user_model, story_model, etc.)
  * `lib/services/` - Business logic and external integrations
  * `lib/screens/` - UI screens organized by feature
  * `lib/providers/` - State management
  * `lib/widgets/` - Reusable UI components
  * `lib/utils/` - Utility functions and theme
* Use consistent naming conventions:
  * camelCase for variables/functions
  * PascalCase for classes/widgets
  * snake_case for filenames
* Maintain the role-based system (Walker vs Owner) throughout the codebase.

### SnapAGram Feature Preservation

* **Stories System**: Maintain 24-hour expiration logic for walk stories
* **GPS Tracking**: Preserve real-time location sharing during walks
* **AR Effects**: Keep DeepAR integration intact for face filters and effects
* **Chat System**: Maintain ephemeral messaging with TTL enforcement
* **Review System**: Preserve walker rating and review functionality
* **Role-Based UI**: Keep walker/owner specific interfaces

### Task Completion Policy

* At the end of each task, Gemini should:
  * Verify that all modified files still compile
  * Provide a summary of changes made
  * List files that were created, updated, or deleted
  * **DO NOT suggest commits** unless explicitly requested by the user
  * Focus on task completion and next steps rather than version control

