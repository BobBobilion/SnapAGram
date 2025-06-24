# SnapAGram Backend System Documentation

## Overview

The SnapAGram backend system is a comprehensive, real-time data management solution built on Firebase. It provides a complete backend for a social media app with stories, messaging, and friend management features.

## Architecture

### Core Components

1. **Models** (`/models/`)
   - `UserModel` - User profile and settings
   - `StoryModel` - Stories with TTL and engagement tracking
   - `MessageModel` - Messages with encryption and TTL support
   - `ChatModel` - Direct and group chats

2. **Services** (`/services/`)
   - `AuthService` - Authentication and user management
   - `UserDatabaseService` - User operations and friend management
   - `StoryDatabaseService` - Story creation, viewing, and management
   - `ChatDatabaseService` - Messaging and chat management
   - `AppServiceManager` - Centralized service management

## Quick Start

### 1. Initialize the Service Manager

```dart
// In your main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize service manager
  final serviceManager = AppServiceManager();
  await serviceManager.initialize();
  
  runApp(MyApp());
}
```

### 2. Access Services

```dart
// Get the singleton instance
final serviceManager = AppServiceManager();

// Check authentication status
if (serviceManager.isAuthenticated) {
  print('User is logged in: ${serviceManager.currentUser?.username}');
}
```

## Usage Examples

### Authentication

```dart
final authService = AppServiceManager().auth;

// Sign up
try {
  await authService.signUpWithEmailAndPassword(
    email: 'user@example.com',
    password: 'password123',
    displayName: 'John Doe',
    username: 'johndoe',
  );
} catch (e) {
  print('Sign up error: $e');
}

// Sign in
try {
  await authService.signInWithEmailAndPassword('user@example.com', 'password123');
} catch (e) {
  print('Sign in error: $e');
}

// Google Sign-In
try {
  await authService.signInWithGoogle(username: 'johndoe');
} catch (e) {
  print('Google sign in error: $e');
}
```

### User Management

```dart
final serviceManager = AppServiceManager();

// Search users
final users = await serviceManager.searchUsers('john');

// Send friend request
await serviceManager.sendFriendRequest('user_id_here');

// Accept friend request
await serviceManager.acceptFriendRequest('sender_user_id');

// Get friends list
final friends = await serviceManager.getCurrentUserFriends();

// Listen to friends updates
serviceManager.getCurrentUserFriendsStream().listen((friends) {
  print('Friends updated: ${friends.length} friends');
});
```

### Stories

```dart
final serviceManager = AppServiceManager();

// Create a story
final storyId = await serviceManager.createStory(
  type: StoryType.image,
  visibility: StoryVisibility.public,
  mediaUrl: 'https://example.com/image.jpg',
  caption: 'My awesome day!',
  filters: {'brightness': 1.2, 'contrast': 1.1},
);

// Get public stories
final publicStories = await serviceManager.getPublicStories();

// Get friends' stories
final friendsStories = await serviceManager.getFriendsStories();

// View a story
await serviceManager.viewStory(storyId);

// Like a story
await serviceManager.likeStory(storyId);

// Listen to public stories
serviceManager.getPublicStoriesStream().listen((stories) {
  print('Public stories updated: ${stories.length} stories');
});
```

### Messaging

```dart
final serviceManager = AppServiceManager();

// Create direct chat
final chatId = await serviceManager.createDirectChat('other_user_id');

// Create group chat
final groupChatId = await serviceManager.createGroupChat(
  name: 'My Group',
  participantIds: ['user1', 'user2', 'user3'],
  description: 'A fun group chat',
);

// Send message
final messageId = await serviceManager.sendMessage(
  chatId: chatId,
  type: MessageType.text,
  content: 'Hello there!',
);

// Send disappearing message
final snapMessageId = await serviceManager.sendMessage(
  chatId: chatId,
  type: MessageType.snap,
  content: 'https://example.com/snap.jpg',
  expiresAt: DateTime.now().add(Duration(seconds: 10)),
  deleteAfterView: true,
);

// Get chat messages
final messages = await serviceManager.getChatMessages(chatId);

// Mark messages as read
await serviceManager.markMessagesAsRead(chatId);

// Listen to chat messages
serviceManager.getChatMessagesStream(chatId).listen((messages) {
  print('New messages: ${messages.length}');
});

// Listen to user's chats
serviceManager.getCurrentUserChatsStream().listen((chats) {
  print('Chats updated: ${chats.length}');
});
```

### Real-time Updates

```dart
final serviceManager = AppServiceManager();

// Listen to current user changes
serviceManager.currentUserStream.listen((user) {
  if (user != null) {
    print('User updated: ${user.username}');
    print('Friends count: ${user.friendsCount}');
    print('Stories count: ${user.storiesCount}');
  }
});

// Listen to specific chat
serviceManager.getChatStream(chatId).listen((chat) {
  if (chat != null) {
    print('Chat updated: ${chat.name}');
    print('Unread count: ${chat.getUnreadCount(serviceManager.currentUserId!)}');
  }
});
```

## Data Models

### UserModel
- Complete user profile with settings
- Friends and blocked users management
- Notification and privacy settings
- Online status and activity tracking

### StoryModel
- Support for images and videos
- Public and friends-only visibility
- 24-hour TTL with automatic cleanup
- View and like tracking
- Encryption support for private stories

### MessageModel
- Multiple message types (text, image, video, snap, etc.)
- TTL and delete-after-view support
- Read receipts and reactions
- Encryption support
- Reply and reaction functionality

### ChatModel
- Direct and group chats (up to 10 members)
- Member role management
- Chat settings and permissions
- Unread count tracking
- Last message preview

## Security Features

- **Authentication**: Firebase Auth with email/password and Google Sign-In
- **Authorization**: User-based access control for all operations
- **Encryption**: Built-in support for E2EE messages and private stories
- **Data Validation**: Comprehensive input validation and sanitization
- **Privacy Controls**: Granular privacy settings per user

## Real-time Features

- **Live Updates**: All data streams update in real-time
- **Online Presence**: Track user online/offline status
- **Message Status**: Real-time message delivery and read receipts
- **Story Views**: Live view and like counts
- **Friend Activity**: Real-time friend request notifications

## Error Handling

All service methods include comprehensive error handling with descriptive error messages:

```dart
try {
  await serviceManager.sendFriendRequest('user_id');
} catch (e) {
  // Handle specific errors
  if (e.toString().contains('User not found')) {
    // Show user not found message
  } else if (e.toString().contains('Already friends')) {
    // Show already friends message
  } else {
    // Show generic error
  }
}
```

## Performance Optimization

- **Pagination**: Built-in pagination for large data sets
- **Caching**: Firebase automatically caches frequently accessed data
- **Batch Operations**: Atomic batch writes for consistency
- **Stream Management**: Automatic stream cleanup and management
- **Query Optimization**: Efficient Firestore queries with proper indexing

## Best Practices

1. **Always check authentication** before performing operations
2. **Use streams for real-time updates** instead of polling
3. **Handle errors gracefully** with user-friendly messages
4. **Implement proper cleanup** for streams and listeners
5. **Use batch operations** for multiple related updates
6. **Respect TTL settings** for messages and stories
7. **Implement proper offline handling** with Firebase's offline persistence

## Database Structure

```
/users/{userId}
  - uid, email, username, displayName
  - friends[], friendRequests[], sentRequests[]
  - notificationSettings{}, privacySettings{}
  - isOnline, lastSeen, storiesCount, friendsCount

/usernames/{username}
  - uid, createdAt

/stories/{storyId}
  - uid, type, visibility, mediaUrl
  - viewedBy[], likedBy[], viewCount, likeCount
  - createdAt, expiresAt, isEncrypted

/chats/{chatId}
  - type, participants[], participantNames{}
  - lastMessage*, unreadCount{}, memberRoles{}
  - isEncrypted, chatSettings{}

/messages/{messageId}
  - chatId, senderId, type, content
  - readBy{}, reactions{}, expiresAt
  - isEncrypted, allowScreenshot, deleteAfterView

/story_views/{viewId}
  - storyId, viewerId, viewedAt, storyCreatorId
```

This backend system provides a solid foundation for building a comprehensive social media app with all the features specified in the SnapAGram PRD. 