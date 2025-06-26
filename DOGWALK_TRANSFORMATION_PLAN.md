# 🐕 SnapAGram → DogWalk Transformation Plan

**Model:** Claude Sonnet 4  
**Last Updated:** December 2024

---

## 📊 CODEBASE ANALYSIS SUMMARY

### ✅ What Can Be Reused (80% of existing code):
- **Firebase Infrastructure** - Auth, Firestore, Storage setup ✓
- **Bottom Navigation Structure** - Perfect fit for new tab layout ✓
- **Chat System** - 95% reusable for walker-owner communication ✓
- **Story System** - Good foundation for walk stories ✓
- **Camera Implementation** - Excellent base for walk photo capture ✓
- **Service Architecture** - Well-structured, just needs new services ✓

### 🔄 What Needs Major Modification:
- **User Model** - Add role system and profile types
- **Authentication Flow** - Add role selection
- **Friends System** - Transform to walker-owner matching
- **Story Model** - Adapt for walk posts with location data

### 🆕 What Needs to Be Built:
- **GPS Tracking System** - Real-time location and path drawing
- **Matching Algorithm** - Location/preferences-based discovery
- **Review System** - Walker ratings and feedback
- **Walk Session Management** - Live tracking, photos, completion

---

## 🔧 TRANSFORMATION ROADMAP

### Phase 1: Dependencies & Infrastructure (Day 1-2)

#### 1.1 Add New Dependencies to pubspec.yaml:
```yaml
dependencies:
  # Existing dependencies stay...
  # ADD:
  google_maps_flutter: ^2.5.0
  firebase_database: ^10.3.0  # Realtime Database
  location: ^5.0.0
  geolocator: ^10.1.0
  flutter_rating_bar: ^4.0.1
  chips_choice: ^3.0.0
```

#### 1.2 Firebase Configuration:
- Enable Firebase Realtime Database
- Update Firestore security rules for new collections
- Configure Google Maps API key

---

### Phase 2: Data Models Transformation (Day 2-4)

#### 2.1 Transform UserModel (lib/models/user_model.dart):
```dart
enum UserRole { walker, owner }

class UserModel {
  // ... existing fields ...
  final UserRole role;                    // NEW
  final WalkerProfile? walkerProfile;     // NEW  
  final OwnerProfile? ownerProfile;       // NEW
  
  // RENAME: friends -> connections
  // RENAME: friendRequests -> connectionRequests
}
```

#### 2.2 Create New Models:

**lib/models/walker_profile.dart:**
```dart
class WalkerProfile {
  final String city;
  final List<DogSize> dogSizePreferences;
  final List<WalkDuration> walkDurations;
  final List<Availability> availability;
  final double averageRating;
  final int totalReviews;
  final List<WalkSummary> recentWalks;
}
```

**lib/models/owner_profile.dart:**
```dart
class OwnerProfile {
  final String dogName;
  final String dogPhotoUrl;
  final DogSize dogSize;
  final String dogBio;
  final String city;
  final List<WalkDuration> preferredDurations;
  final String specialInstructions;
}
```

**lib/models/walk_session.dart:**
```dart
class WalkSession {
  final String id;
  final String walkerId;
  final String ownerId;
  final WalkStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<LatLng> pathPoints;
  final List<String> photoUrls;
  final double? distance;
  final int? duration;
}
```

**lib/models/review.dart:**
```dart
class Review {
  final String id;
  final String walkSessionId;
  final String walkerId;
  final String ownerId;
  final int rating; // 1-5
  final String? comment;
  final DateTime createdAt;
}
```

#### 2.3 Adapt StoryModel for Walk Stories:
```dart
// ADD to existing StoryModel:
final String? walkSessionId;        // Link to walk
final String? location;             // City/area  
final int? walkDuration;            // In minutes
final double? walkDistance;         // In kilometers
final DogSize? dogSize;             // Size walked
```

---

### Phase 3: Authentication & Onboarding (Day 4-6)

#### 3.1 Create New Screens:
- `lib/screens/auth/role_selection_screen.dart` - Walker vs Owner choice
- `lib/screens/auth/walker_onboarding_screen.dart` - Multi-step walker setup
- `lib/screens/auth/owner_onboarding_screen.dart` - Dog profile creation

#### 3.2 Update Existing:
- `lib/screens/auth/signup_screen.dart` - Add role selection flow
- `lib/services/auth_service.dart` - Handle role-specific user creation

---

### Phase 4: Navigation & Screen Transformation (Day 6-8)

#### 4.1 Update HomeScreen Navigation (lib/screens/home/home_screen.dart):
```dart
// CHANGE tab labels:
'Explore' -> 'Stories'    // Walker walk posts
'Friends' -> 'Find'       // Matching system  
'Post' -> 'Camera'        // Walk photos
'Chats' -> 'Chats'        // Walker-owner convos
'Account' -> 'Profile'    // Role-specific
```

#### 4.2 Transform Screens:
- **lib/screens/explore/explore_screen.dart** → Show walker walk stories
- **lib/screens/friends/friends_screen.dart** → Discovery/matching interface
- **lib/screens/account/account_screen.dart** → Role-specific profiles

---

### Phase 5: GPS & Walk Tracking (Day 8-12)

#### 5.1 Create GPS Services:
```dart
// lib/services/location_service.dart
class LocationService {
  static Future<Position> getCurrentPosition();
  static Stream<Position> getPositionStream();
  static Future<bool> requestLocationPermission();
}

// lib/services/walk_session_service.dart
class WalkSessionService {
  static Future<String> startWalk(String ownerId);
  static Future<void> updateWalkLocation(String sessionId, LatLng point);
  static Future<void> endWalk(String sessionId);
  static Stream<WalkSession> getWalkSessionStream(String sessionId);
}
```

#### 5.2 Create Map Integration:
- `lib/screens/walks/live_walk_map_screen.dart` - Real-time GPS tracking
- `lib/widgets/walk_path_widget.dart` - Smooth path drawing

#### 5.3 Update Existing:
- **Camera Screen** - Add "Start Walk" functionality
- **Chat Screen** - Add live location sharing during walks

---

### Phase 6: Matching & Discovery (Day 12-15)

#### 6.1 Create Matching Service:
```dart
// lib/services/matching_service.dart
class MatchingService {
  static Future<List<UserModel>> findMatches(UserModel currentUser) {
    // 1. Filter by location (same city)
    // 2. Filter by dog size compatibility  
    // 3. Check availability overlap
    // 4. Score by rating, experience
    // 5. Return top 20 matches
  }
}
```

#### 6.2 Create Discovery UI:
- `lib/screens/discovery/find_screen.dart` - Matching interface
- `lib/widgets/profile_card_widget.dart` - Walker/Owner profile cards

---

### Phase 7: Review System (Day 15-17)

#### 7.1 Create Review Components:
- `lib/screens/reviews/post_walk_review_screen.dart` - Post-walk rating
- `lib/services/review_database_service.dart` - Review management
- `lib/widgets/rating_widget.dart` - Star rating components

---

### Phase 8: Profile Management (Day 17-19)

#### 8.1 Create Role-Specific Profiles:
- `lib/screens/profiles/walker_profile_screen.dart` - Walk history & ratings
- `lib/screens/profiles/owner_profile_screen.dart` - Dog info & preferences

---

### Phase 9: Service Integration (Day 19-21)

#### 9.1 Update Services:
- **AppServiceManager** - Add new service integrations
- **Database Services** - Add role-based operations
- **Chat Services** - Add walk session integration

---

## 🗂️ FILE TRANSFORMATION SUMMARY

### Files to Modify (12 files):
- `lib/models/user_model.dart` - Add role system
- `lib/models/story_model.dart` - Add walk data
- `lib/screens/home/home_screen.dart` - Update navigation
- `lib/screens/friends/friends_screen.dart` - Transform to find screen
- `lib/screens/explore/explore_screen.dart` - Show walk stories
- `lib/screens/auth/signup_screen.dart` - Add role selection
- `lib/services/app_service_manager.dart` - Add new services
- `lib/services/auth_service.dart` - Role-based creation
- `pubspec.yaml` - Add dependencies
- Plus 3 minor updates

### Files to Create (25+ new files):
**Models (4):** walker_profile.dart, owner_profile.dart, walk_session.dart, review.dart  
**Screens (8):** Role selection, onboarding (2), GPS maps, reviews, profiles (2), discovery  
**Services (5):** GPS, matching, reviews, walk sessions, location  
**Widgets (8):** Rating, profile cards, map components, walk tracking UI

### Files to Keep As-Is (85% of codebase):
- `lib/main.dart` - No changes needed
- All chat-related files - Minimal changes
- Most camera functionality - Minor additions only
- Database infrastructure - Extend, don't replace
- UI components and utilities - Reuse existing

---

## 📱 IMPLEMENTATION PRIORITY

### 🔴 Critical (Must Complete First):
1. ✅ User role system and onboarding  
2. ✅ Basic GPS tracking infrastructure  
3. ✅ Walker-owner chat transformation  
4. ✅ Profile management for both roles

### 🟡 Important (Phase 2):
1. Matching algorithm implementation
2. Review system  
3. Walk session management
4. Live GPS tracking with maps

### 🟢 Nice-to-Have (Phase 3):
1. Advanced map features
2. Offline GPS support  
3. Performance optimizations
4. Additional UI polish

---

## 🚀 QUICK START COMMANDS

```bash
# 1. Add dependencies
flutter pub add google_maps_flutter firebase_database location geolocator flutter_rating_bar chips_choice

# 2. Generate boilerplate
# Use your preferred code generation tools

# 3. Update Firebase
# Enable Realtime Database in Firebase Console
# Add Google Maps API key to android/app/src/main/AndroidManifest.xml

# 4. Start with Phase 1
# Begin with user role transformation
```

---

## 💡 TECHNICAL NOTES

### Database Structure Changes:
```
Firestore Collections:
/users/{uid}
  - role: 'walker' | 'owner'
  - walkerProfile: {...} | null
  - ownerProfile: {...} | null

/walkSessions/{sessionId}
  - walkerId, ownerId, status, photos[]

/reviews/{reviewId}
  - walkerId, ownerId, rating, comment

/connections/{connectionId}
  - walkerId, ownerId, status

Realtime Database:
/activeWalks/{sessionId}
  - currentLocation: {lat, lng}
  - path: [{lat, lng, timestamp}]
```

### Key Architectural Decisions:
- **Reuse existing chat system** for walker-owner communication
- **Extend story system** for walk posts instead of rebuilding
- **Firebase Realtime DB** for GPS tracking (low latency)
- **Firestore** for everything else (rich queries)
- **Role-based profiles** within single user collection

---

This plan maintains 80% of your existing codebase while systematically transforming it into a specialized dog walker platform. The modular approach allows for incremental development and testing at each phase. 