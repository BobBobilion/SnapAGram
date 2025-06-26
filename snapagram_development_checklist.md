R# DogWalk MVP Development Checklist

_Use `[x]` to mark completed tasks._

---

## Template Overview

This checklist provides a structured, granular approach to the DogWalk MVP development project. Each phase represents a focused development milestone for building a dog walker-client communication platform with GPS tracking, ephemeral messaging, and walker-owner matching capabilities.

---

## Phases Overview
- [ ] **Phase 1:** Environment & Data Models Foundation
- [ ] **Phase 2:** Role-Based Authentication & Onboarding
- [ ] **Phase 3:** GPS Tracking & Walk Sessions
- [ ] **Phase 4:** Walker-Owner Communication System
- [ ] **Phase 5:** Discovery & Matching Algorithm
- [ ] **Phase 6:** Review & Rating System
- [ ] **Phase 7:** Walk Stories & Profile Management
- [ ] **Phase 8:** Testing & Release Preparation

---

# Phase 1: Environment & Data Models Foundation (M0)
**Criteria:** Set up the technical foundation and data structures required for the dog walker platform.

### Feature 1.1: Environment Setup
- [x] Initialize and configure the Git repository.
- [x] Create and configure the Firebase project.
- [x] Enable Firestore, Firebase Storage, Firebase Authentication, and Firebase Realtime Database.
- [ ] Add Google Maps API key and configure Google Maps SDK for Flutter.
- [ ] Integrate location services and GPS tracking dependencies.

### Feature 1.2: Core Data Models
- [ ] Create `UserRole` enum (Walker, Owner) and role-based user model extensions.
- [ ] Implement `WalkerProfile` model with dog size preferences, availability, and service areas.
- [ ] Implement `OwnerProfile` model with dog information, location, and preferences.
- [ ] Create `WalkSession` model for GPS tracking, photos, and session management.
- [ ] Create `Review` model for walker ratings and comments.
- [ ] Create `WalkStory` model for walker walk posts with 24-hour expiration.

### Feature 1.3: Database Structure
- [ ] Design Firestore collections for users, walks, reviews, and stories.
- [ ] Design Realtime Database structure for live GPS tracking during walks.
- [ ] Set up Cloud Storage buckets for dog photos and walk pictures.
- [ ] Configure security rules for role-based data access.

---

# Phase 2: Role-Based Authentication & Onboarding (M1)
**Criteria:** Users can create accounts, select their role, and complete role-specific profile setup.

### Feature 2.1: Enhanced Authentication (F1)
- [ ] Modify existing authentication to include role selection during signup.
- [ ] Create `RoleSelectionScreen` with Walker vs Owner choice.
- [ ] Update `AuthService` to handle role-specific user creation.
- [ ] Ensure role-based routing after authentication.

### Feature 2.2: Walker Onboarding (F2)
- [ ] Create `WalkerOnboardingScreen` with multiple steps:
  - Personal information and profile photo
  - Dog size preferences (Small, Medium, Large) with multi-select chips
  - Walk duration options (15, 30, 45, 60+ minutes) with selection buttons
  - Availability schedule (Morning, Afternoon, Evening) with toggles
  - Service area/city selection
- [ ] Implement form validation and profile completion tracking.
- [ ] Save walker profile data to Firestore.

### Feature 2.3: Owner Onboarding (F2)
- [ ] Create `OwnerOnboardingScreen` with dog profile setup:
  - Dog photo upload with camera integration
  - Dog basic info (name, age, breed, gender)
  - Dog size category selection
  - Dog personality bio (500 character limit)
  - Owner location/city selection
  - Preferred walk duration
  - Special instructions for walkers
- [ ] Implement image upload to Cloud Storage for dog photos.
- [ ] Save owner profile data to Firestore.

### Feature 2.4: Profile Management Foundation
- [ ] Create role-aware profile viewing and editing capabilities.
- [ ] Implement profile completion status tracking.
- [ ] Add profile photo upload functionality for both roles.

---

# Phase 3: GPS Tracking & Walk Sessions (M2)
**Criteria:** Real-time GPS tracking during walks with live path drawing and photo sharing.

### Feature 3.1: GPS Integration (F3)
- [ ] Integrate Google Maps Flutter plugin for map display.
- [ ] Implement location permission handling and GPS accuracy checks.
- [ ] Create location service for real-time GPS coordinate collection.
- [ ] Set up Firebase Realtime Database for live location streaming.
- [ ] Implement offline GPS tracking with local storage and sync.

### Feature 3.2: Walk Session Management (F6)
- [ ] Create `WalkSessionService` for managing active walk states.
- [ ] Implement "Start Walk" functionality for walkers from chat conversations.
- [ ] Create live GPS tracking with 5-second update intervals.
- [ ] Build path drawing functionality with smooth curve interpolation.
- [ ] Implement walk session persistence and history.

### Feature 3.3: Live Map Interface
- [ ] Create `LiveWalkMapScreen` for owners to view walker's real-time location.
- [ ] Implement real-time path drawing on the map as walker moves.
- [ ] Add map controls (zoom, center on walker, toggle path visibility).
- [ ] Handle GPS connection issues with graceful fallbacks.
- [ ] Optimize battery usage during tracking sessions.

### Feature 3.4: Walk Photo Sharing
- [ ] Integrate camera functionality for walkers during walks.
- [ ] Implement instant photo sharing to owner via chat during walks.
- [ ] Create photo gallery for walk session documentation.
- [ ] Add photo timestamp and location metadata.

---

# Phase 4: Walker-Owner Communication System (M3)
**Criteria:** Secure messaging between walkers and owners with ephemeral media and walk coordination.

### Feature 4.1: Enhanced Chat System (F5)
- [ ] Modify existing chat system for walker-owner specific conversations.
- [ ] Implement walk-specific chat context (pre-walk, during-walk, post-walk).
- [ ] Add walk session integration to chat interface.
- [ ] Implement TTL for sensitive messages and photos.

### Feature 4.2: Walk Coordination Features
- [ ] Add "Start Walk" button in walker's chat view with specific owner.
- [ ] Create walk status indicators in chat (scheduled, active, completed).
- [ ] Implement automatic walk completion notifications.
- [ ] Add walk duration tracking and display in chat.

### Feature 4.3: Photo Gallery Integration
- [ ] Create walk photo galleries within conversations.
- [ ] Implement photo viewing with full-screen modal.
- [ ] Add photo deletion and management features.
- [ ] Integrate walk photos into post-walk review flow.

---

# Phase 5: Discovery & Matching Algorithm (M4)
**Criteria:** Walker-Owner discovery system with location, preferences, and rating-based matching.

### Feature 5.1: Find Screen Foundation (F4)
- [ ] Transform existing Friends screen into role-aware Find screen.
- [ ] Create separate interfaces for walkers (find owners) and owners (find walkers).
- [ ] Implement basic search functionality with username lookup.
- [ ] Add connection request system for walker-owner matching.

### Feature 5.2: Matching Algorithm Implementation
- [ ] Implement location-based filtering (same city).
- [ ] Create dog size compatibility matching.
- [ ] Add availability schedule overlap detection.
- [ ] Build scoring system based on distance, rating, and experience.
- [ ] Implement result ranking and display.

### Feature 5.3: Profile Discovery Cards
- [ ] Create walker profile cards showing ratings, experience, and availability.
- [ ] Implement owner profile cards with dog information and preferences.
- [ ] Add swipe-to-connect or tap-to-connect functionality.
- [ ] Create detailed profile view screens for discovery.

### Feature 5.4: Connection Management
- [ ] Implement connection request system (replace friend requests).
- [ ] Create connection approval/decline workflow.
- [ ] Add connection status management and removal.
- [ ] Implement connection history and management screen.

---

# Phase 6: Review & Rating System (M5)
**Criteria:** Post-walk review system with ratings, comments, and profile integration.

### Feature 6.1: Review Collection System (F7)
- [ ] Create automatic review prompt when owner opens chat after walk completion.
- [ ] Design review interface with 1-5 star rating and comment field.
- [ ] Implement review submission with walk session linking.
- [ ] Add review editing and deletion capabilities (within time limit).

### Feature 6.2: Rating Aggregation & Display
- [ ] Implement rating calculation and averaging for walker profiles.
- [ ] Create review display components for walker profiles.
- [ ] Add review sorting and filtering options.
- [ ] Implement review privacy controls (anonymize owner names).

### Feature 6.3: Review Management
- [ ] Create review moderation and reporting system.
- [ ] Implement review response functionality for walkers.
- [ ] Add review history screens for both walkers and owners.
- [ ] Create review analytics and insights for walkers.

---

# Phase 7: Walk Stories & Profile Management (M6)
**Criteria:** Walker walk stories with 24-hour expiration and comprehensive profile management.

### Feature 7.1: Walk Stories System (F8)
- [ ] Transform existing Stories screen for walker walk posts.
- [ ] Create walk story composition with photo, location, and walk details.
- [ ] Implement 24-hour automatic story expiration.
- [ ] Create story feed with infinite scroll for all users.
- [ ] Add story viewing with engagement metrics.

### Feature 7.2: Walker Profile Portfolios (F9)
- [ ] Create comprehensive walker profile screens with walk history.
- [ ] Implement "recent walks" display (3 featured cards + 10 list items).
- [ ] Add rating and review aggregation display.
- [ ] Create walker availability and preferences showcase.
- [ ] Implement profile editing and management for walkers.

### Feature 7.3: Owner Profile Management (F9)
- [ ] Create owner profile screens with dog information.
- [ ] Implement dog profile editing and photo management.
- [ ] Add walk history viewing for owners.
- [ ] Create owner preferences and settings management.

### Feature 7.4: Walk History & Analytics (F10)
- [ ] Implement comprehensive walk history for walkers.
- [ ] Create walk statistics and performance metrics.
- [ ] Add walk export functionality for record keeping.
- [ ] Implement walk history filtering and search.

---

# Phase 8: Testing & Release Preparation (M7)
**Criteria:** App testing, optimization, and Play Store preparation for beta release.

### Feature 8.1: Performance Optimization
- [ ] Optimize GPS tracking for battery efficiency.
- [ ] Implement efficient map rendering and caching.
- [ ] Optimize image loading and caching for photos.
- [ ] Test and optimize app performance under various network conditions.

### Feature 8.2: User Experience Polish
- [ ] Implement loading states and error handling for all features.
- [ ] Add user onboarding tutorials and help screens.
- [ ] Create comprehensive user flow testing.
- [ ] Implement accessibility features and screen reader support.

### Feature 8.3: Security & Privacy
- [ ] Implement location data encryption and automatic deletion.
- [ ] Add privacy settings and data control options.
- [ ] Implement secure photo sharing and storage.
- [ ] Create GDPR compliance features (data export/deletion).

### Feature 8.4: Beta Testing & Analytics
- [ ] Set up Firebase Analytics for user behavior tracking.
- [ ] Implement crash reporting and error monitoring.
- [ ] Create beta testing group and feedback collection system.
- [ ] Set up performance monitoring and alerts.

### Feature 8.5: Play Store Preparation
- [ ] Create app screenshots and store listing materials.
- [ ] Write app description focusing on dog walker-owner communication.
- [ ] Set up closed beta testing on Google Play Console.
- [ ] Implement app signing and release configuration.
- [ ] Create privacy policy and terms of service.

---

## Additional Considerations

### Dependencies to Add:
```yaml
dependencies:
  google_maps_flutter: ^2.5.0
  location: ^5.0.0
  firebase_database: ^10.3.0
  geolocator: ^10.1.0
  image_picker: ^1.0.0
  cached_network_image: ^3.3.0
  flutter_rating_bar: ^4.0.1
  chips_choice: ^3.0.0
```

### Database Collections Structure:
```
/users/{uid}
  - role: 'walker' | 'owner'
  - walkerProfile: {...} | null
  - ownerProfile: {...} | null

/walkSessions/{sessionId}
  - walkerId, ownerId, status, startTime, endTime
  - photos: [], duration, distance

/reviews/{reviewId}
  - walkerId, ownerId, walkSessionId
  - rating, comment, createdAt

/walkStories/{storyId}
  - walkerId, photos, location, duration
  - createdAt, expiresAt

/connections/{connectionId}
  - walkerId, ownerId, status, createdAt
```

### Realtime Database Structure:
```
/activeWalks/{sessionId}
  - currentLocation: {lat, lng, timestamp}
  - path: [{lat, lng, timestamp}]
  - status: 'active' | 'paused' | 'ended'
```