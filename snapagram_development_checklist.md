# Snapagram MVP Development Checklist

_Use `[x]` to mark completed tasks._

---

## Template Overview

This checklist provides a structured, granular approach to the Snapagram MVP development project. Each phase represents a focused development milestone. Tasks are ordered to manage dependencies effectively, ensuring that foundational components are built before features that rely on them.

---

## Phases Overview
- [ ] **Phase 1:** Environment & Project Foundation
- [ ] **Phase 2:** User Authentication & Application Shell
- [ ] **Phase 3:** Core Backend Services
- [ ] **Phase 4:** Social Graph & Friends Management
- [ ] **Phase 5:** Secure Messaging System
- [ ] **Phase 6:** Media Capture & Creation
- [ ] **Phase 7:** Media Editing & Augmentation
- [ ] **Phase 8:** Story Engine - Posting & Persistence
- [ ] **Phase 9:** Story Engine - Consumption & Interaction
- [ ] **Phase 10:** Notifications & Release Preparation

---

# Phase 1: Environment & Project Foundation (M0)
**Criteria:** Non-negotiable infrastructure and security setup. This phase ensures a stable and secure environment before any feature code is written.

### Feature 1.1: Version Control & CI
- [ ] Initialize and configure the Git repository.
- [ ] Establish a basic Continuous Integration (CI) pipeline to automate builds and unit tests for the Flutter application.

### Feature 1.2: Firebase Project Setup
- [ ] Create and configure the Firebase project.
- [ ] Enable and configure Firestore, Firebase Storage, Firebase Authentication, and Pub/Sub services.

### Feature 1.3: Project Security
- [ ] Integrate and enforce Firebase App Check to protect backend resources.
- [ ] Integrate the Play Integrity API to verify the authenticity of the app instance.
- [ ] Ensure no debug credentials or sensitive keys are included in production build configurations.

---

# Phase 2: User Authentication & Application Shell
**Criteria:** Enabling users to securely enter the app and see the basic structure.

### Feature 2.1: Authentication (F1)
- [ ] Implement the user sign-up and sign-in flow using Firebase's email and password method.
- [ ] Integrate Google Sign-In as an alternative authentication method.
- [ ] Upon successful registration, create a corresponding user profile document in Firestore.

### Feature 2.2: Application Shell & Navigation (Core Screens)
- [ ] Create the main application layout containing a bottom navigation bar using Flutter's `BottomNavigationBar` widget.
- [ ] Implement five tab items: "Explore," "Friends," "Post," "Chats," and "Account," each navigating to a placeholder screen using Flutter's Navigator or GoRouter.
- [ ] Style the central "Post" button as a raised, oversized Floating Action Button (FAB) per PRD specifications.
- [ ] Build the basic "Account" screen UI where users can view their profile info and sign out.

### Feature 2.3: User Data Compliance
- [ ] Implement a user-facing interface or backend endpoint for GDPR-compliant data export and account deletion requests.

---

# Phase 3: Core Backend Services
**Criteria:** Building the essential server-side logic required for dynamic content and security.

### Feature 3.1: Content TTL & Deletion Service (F7)
- [ ] Set up a Google Cloud Pub/Sub topic to receive messages containing a document ID and an expiresAt timestamp.
- [ ] Configure a Cloud Tasks queue to schedule deletion jobs based on messages from the Pub/Sub topic.
- [ ] Write and deploy a Cloud Function triggered by Cloud Tasks to delete the specified Firestore documents and their associated Cloud Storage files.

### Feature 3.2: End-to-End Encryption Foundation (F6)
- [ ] Integrate the libsodium library into the Flutter application (using a Dart FFI or a suitable plugin).
- [ ] Develop a core EncryptionService class with helper functions to encrypt and decrypt data payloads.
- [ ] Implement a secure mechanism for managing and backing up user encryption keys (e.g., Google-token encrypted key backup).

---

# Phase 4: Social Graph & Friends Management (F8)
**Criteria:** Allowing users to connect with each other, which is a prerequisite for most social features.

### Feature 4.1: User Discovery & Requests
- [ ] Implement a user search feature that allows finding others by their unique username.
- [ ] Develop the functionality to send, view, accept, and decline friend requests.

### Feature 4.2: Friends List
- [ ] Create a "Friends" list UI within the Friends tab or Account screen that displays the current user's accepted friends.

---

# Phase 5: Secure Messaging System (F4)
**Criteria:** Implementing private and group communication features.

### Feature 5.1: Messaging UI & Direct Chat
- [ ] Build the UI for the "Chats" screen to list active conversations.
- [ ] Implement one-to-one messaging between friends, ensuring all messages are end-to-end encrypted using the EncryptionService from Phase 3.

### Feature 5.2: Group Chat & TTL
- [ ] Extend the messaging system to support group chats (≤ 10 users) with group key management.
- [ ] Add functionality for users to set a default Time-To-Live (TTL) on messages per-chat, which triggers the backend deletion service from Phase 3.

### Feature 5.3: Chat Security
- [ ] Implement screenshot detection within chat screens and log the event into the conversation history.

---

# Phase 6: Media Capture & Creation (F2)
**Criteria:** Building the camera-first experience for capturing content.

### Feature 6.1: Camera Interface
- [ ] Build the core camera interface that launches when the "Post" tab is tapped, providing a real-time preview using Flutter camera plugins.
- [ ] Implement photo capture functionality.
- [ ] Implement video capture functionality for clips up to 60 seconds long.

---

# Phase 7: Media Editing & Augmentation (F3)
**Criteria:** Providing users with tools to customize their captured media.

### Feature 7.1: Post-Capture Editing Screen
- [ ] Develop an editing screen that appears after media is captured.

### Feature 7.2: Image Adjustment Filters
- [ ] Implement basic adjustment filters: Brightness, Contrast, Saturation, Temperature/Warmth, Vignette, and Gaussian Blur using Flutter image processing libraries.
- [ ] Implement standard manipulation tools: Crop and Rotate.

### Feature 7.3: Artistic & Advanced Filters
- [ ] Implement a Sepia filter and a high-contrast Black & White filter.
- [ ] Create a "Pastelify" filter using a Lookup Table (LUT).
- [ ] Add a text overlay feature with basic font and color choices.
- [ ] Integrate a library for face-tracking to apply simple AR stickers to faces.

---

# Phase 8: Story Engine - Posting & Persistence (F5, Part 1)
**Criteria:** Handling the logic for creating, encrypting, and storing stories.

### Feature 8.1: Story Composer Flow
- [ ] Connect the Camera (Phase 6) and Editor (Phase 7) into a unified story composer flow.
- [ ] Add a UI toggle in the composer for the user to select story visibility: "Public" or "Friends-Only."

### Feature 8.2: Story Upload & Persistence
- [ ] If "Friends-Only" is selected, encrypt the media using the EncryptionService (Phase 3).
- [ ] Implement the logic to upload the final media to Firebase Storage.
- [ ] After upload, write a story document to the `/stories` collection in Firestore with all required fields (e.g., uid, isPublic, mediaURL, expiresAt, encryptedKey).
- [ ] Upon writing the document, publish a message to the Pub/Sub topic (Phase 3) to schedule the story's deletion in 24 hours.

---

# Phase 9: Story Engine - Consumption & Interaction (F5, Part 2)
**Criteria:** Building the user-facing feeds and interaction tools for viewing stories.

### Feature 9.1: Story Feeds
- [ ] Implement the "Explore" feed to display all public stories using an infinite scroll powered by paged Firestore queries.
- [ ] Implement the "Friends" feed to display stories from the user's friends (both public and friends-only).

### Feature 9.2: Story Viewer
- [ ] Create the full-screen story viewer UI, which opens on tap and is dismissible with a swipe-down gesture.
- [ ] For friends-only stories, implement the decryption logic before displaying the media.

### Feature 9.3: Story Interaction
- [ ] Add a heart icon to the story viewer and implement the logic to "like" a story (optimistic UI update + transactional Firestore increment).
- [ ] Implement a view counter that increments only once per unique viewer.
- [ ] Implement the "Share" functionality that copies a Firebase Dynamic Link for the story to the clipboard.

---

# Phase 10: Notifications & Release Preparation (M6)
**Criteria:** Adding final polish and preparing the app for a closed beta release.

### Feature 10.1: Push Notifications (F9)
- [ ] Integrate Firebase Cloud Messaging (FCM).
- [ ] Implement push notifications for incoming private/group messages and new friend requests.

### Feature 10.2: Metrics & Monitoring
- [ ] Set up a basic analytics dashboard (e.g., in Firebase) to track key success metrics like MAU, crash-free rate, and engagement.
- [ ] Ensure the app meets performance targets for cold-start time (≤ 3s) and bundle size (≤ 40 MB).