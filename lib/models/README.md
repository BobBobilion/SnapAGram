# SnapAGram Data Models Documentation

## Overview

The SnapAGram app uses four core data models that represent the main entities in the system. These models provide type-safe data structures with built-in validation, serialization, and utility methods.

## Table of Contents

1. [UserModel](#usermodel)
2. [StoryModel](#storymodel)
3. [MessageModel](#messagemodel)
4. [ChatModel](#chatmodel)
5. [Best Practices](#best-practices)
6. [Common Patterns](#common-patterns)

---

## UserModel

Represents a complete user profile with settings, friends, and activity tracking.

### Properties

```dart
class UserModel {
  final String uid;                              // Unique user identifier
  final String email;                            // User's email address
  final String displayName;                      // User's display name
  final String username;                         // Unique username
  final String? profilePictureUrl;               // Profile picture URL
  final String? bio;                             // User bio/description
  final DateTime createdAt;                      // Account creation date
  final DateTime lastSeen;                       // Last activity timestamp
  final bool isOnline;                           // Current online status
  final List<String> friends;                    // List of friend UIDs
  final List<String> friendRequests;             // Incoming friend requests
  final List<String> sentRequests;               // Outgoing friend requests
  final List<String> blockedUsers;               // Blocked user UIDs
  final Map<String, dynamic> notificationSettings; // Notification preferences
  final Map<String, dynamic> privacySettings;    // Privacy controls
  final String? publicKey;                       // Public encryption key
  final String? encryptedPrivateKey;             // Encrypted private key
  final Map<String, dynamic> chatDefaults;       // Default chat settings
  final int storiesCount;                        // Total stories posted
  final int friendsCount;                        // Total friends count
}
```

### Creating a UserModel

```dart
// Creating a new user (typically done during registration)
final user = UserModel(
  uid: 'user123',
  email: 'john.doe@example.com',
  displayName: 'John Doe',
  username: 'johndoe',
  profilePictureUrl: 'https://example.com/avatar.jpg',
  bio: 'Flutter developer and coffee enthusiast ☕',
  createdAt: DateTime.now(),
  lastSeen: DateTime.now(),
  isOnline: true,
);

// Converting to Firestore document
final userData = user.toMap();
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set(userData);
```

### Loading from Firestore

```dart
// Loading user from Firestore
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc('user123')
    .get();

if (doc.exists) {
  final user = UserModel.fromSnapshot(doc);
  print('User: ${user.displayName} (@${user.username})');
  print('Friends: ${user.friendsCount}');
  print('Online: ${user.isOnline}');
}
```

### Updating User Data

```dart
// Update user profile
final updatedUser = user.copyWith(
  displayName: 'John Smith',
  bio: 'Senior Flutter Developer 🚀',
  lastSeen: DateTime.now(),
);

// Update specific fields
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .update({
  'displayName': 'John Smith',
  'bio': 'Senior Flutter Developer 🚀',
  'lastSeen': Timestamp.fromDate(DateTime.now()),
});
```

### Working with Settings

```dart
// Update notification settings
final newNotificationSettings = {
  'newMessages': true,
  'friendRequests': true,
  'storyLikes': false,
  'soundEnabled': true,
  'quietHours': {
    'enabled': true,
    'startTime': '22:00',
    'endTime': '08:00',
  },
};

final updatedUser = user.copyWith(
  notificationSettings: newNotificationSettings,
);

// Update privacy settings
final newPrivacySettings = {
  'profileVisibility': 'friends',
  'storyVisibility': 'public',
  'allowFriendRequests': true,
  'showOnlineStatus': false,
};

final privateUser = user.copyWith(
  privacySettings: newPrivacySettings,
);
```

---

## StoryModel

Represents a story post with media, engagement tracking, and TTL management.

### Properties

```dart
enum StoryType { image, video }
enum StoryVisibility { public, friends }

class StoryModel {
  final String id;                               // Unique story identifier
  final String uid;                              // Creator's user ID
  final String creatorUsername;                  // Creator's username
  final String? creatorProfilePicture;           // Creator's profile picture
  final StoryType type;                          // Story media type
  final StoryVisibility visibility;              // Who can view the story
  final String mediaUrl;                         // Media file URL
  final String? thumbnailUrl;                    // Video thumbnail URL
  final String? caption;                         // Story caption/text
  final DateTime createdAt;                      // Creation timestamp
  final DateTime expiresAt;                      // Expiration timestamp
  final Map<String, dynamic> filters;            // Applied filters
  final List<String> viewedBy;                   // Users who viewed
  final List<String> likedBy;                    // Users who liked
  final int viewCount;                           // Total view count
  final int likeCount;                           // Total like count
  final int shareCount;                          // Total share count
  final bool isEncrypted;                        // Is content encrypted
  final String? encryptedKey;                    // Encryption key
  final List<String> allowedViewers;             // Allowed viewer UIDs
  final Map<String, dynamic> metadata;           // Additional metadata
}
```

### Creating a Story

```dart
// Create a public image story
final story = StoryModel(
  id: 'story123',
  uid: 'user123',
  creatorUsername: 'johndoe',
  creatorProfilePicture: 'https://example.com/avatar.jpg',
  type: StoryType.image,
  visibility: StoryVisibility.public,
  mediaUrl: 'https://example.com/story.jpg',
  caption: 'Beautiful sunset at the beach! 🌅',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(Duration(hours: 24)),
  filters: {
    'brightness': 1.2,
    'contrast': 1.1,
    'saturation': 1.3,
  },
);

// Create a friends-only encrypted story
final privateStory = StoryModel(
  id: 'story456',
  uid: 'user123',
  creatorUsername: 'johndoe',
  type: StoryType.video,
  visibility: StoryVisibility.friends,
  mediaUrl: 'https://example.com/encrypted_video.mp4',
  thumbnailUrl: 'https://example.com/thumbnail.jpg',
  caption: 'Private moment with friends 🎉',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(Duration(hours: 24)),
  isEncrypted: true,
  encryptedKey: 'encrypted_key_here',
  allowedViewers: ['friend1', 'friend2', 'friend3'],
);
```

### Story Utility Methods

```dart
// Check if story is expired
if (story.isExpired) {
  print('Story has expired and should be deleted');
}

// Check if user has viewed the story
if (story.hasUserViewed('user456')) {
  print('User has already viewed this story');
}

// Check if user has liked the story
if (story.hasUserLiked('user456')) {
  print('User has liked this story');
}

// Check if user can view the story
if (story.canUserView('user456')) {
  print('User is allowed to view this story');
}

// Get time remaining
print('Time remaining: ${story.timeRemainingText}');
// Output: "23h 45m" or "45m" or "30s" or "Expired"
```

### Updating Story Engagement

```dart
// User views a story
final viewedStory = story.copyWith(
  viewedBy: [...story.viewedBy, 'user456'],
  viewCount: story.viewCount + 1,
);

// User likes a story
final likedStory = story.copyWith(
  likedBy: [...story.likedBy, 'user456'],
  likeCount: story.likeCount + 1,
);

// User shares a story
final sharedStory = story.copyWith(
  shareCount: story.shareCount + 1,
);
```

---

## MessageModel

Represents a message in a chat with support for different types, TTL, and reactions.

### Properties

```dart
enum MessageType { text, image, video, snap, sticker, location, contact }
enum MessageStatus { sent, delivered, read, failed }

class MessageModel {
  final String id;                               // Unique message identifier
  final String chatId;                           // Parent chat ID
  final String senderId;                         // Sender's user ID
  final String senderUsername;                   // Sender's username
  final String? senderProfilePicture;            // Sender's profile picture
  final MessageType type;                        // Message type
  final String content;                          // Message content/URL
  final String? thumbnailUrl;                    // Media thumbnail
  final DateTime createdAt;                      // Creation timestamp
  final DateTime? expiresAt;                     // Expiration timestamp
  final MessageStatus status;                    // Delivery status
  final Map<String, DateTime> readBy;            // Read receipts
  final bool isEncrypted;                        // Is content encrypted
  final String? encryptedKey;                    // Encryption key
  final Map<String, dynamic> metadata;           // File info, duration, etc.
  final String? replyToMessageId;                // Reply reference
  final bool isDeleted;                          // Is message deleted
  final DateTime? deletedAt;                     // Deletion timestamp
  final List<String> deletedFor;                 // Users who deleted
  final Map<String, dynamic> reactions;          // Emoji reactions
  final bool allowScreenshot;                    // Screenshot permission
  final bool deleteAfterView;                    // Auto-delete after view
  final int viewCount;                           // View count (for snaps)
  final List<String> viewedBy;                   // Viewers (for snaps)
}
```

### Creating Messages

```dart
// Text message
final textMessage = MessageModel(
  id: 'msg123',
  chatId: 'chat456',
  senderId: 'user123',
  senderUsername: 'johndoe',
  senderProfilePicture: 'https://example.com/avatar.jpg',
  type: MessageType.text,
  content: 'Hey! How are you doing? 😊',
  createdAt: DateTime.now(),
  status: MessageStatus.sent,
);

// Image message
final imageMessage = MessageModel(
  id: 'msg124',
  chatId: 'chat456',
  senderId: 'user123',
  senderUsername: 'johndoe',
  type: MessageType.image,
  content: 'https://example.com/photo.jpg',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  createdAt: DateTime.now(),
  metadata: {
    'fileSize': 2048576, // 2MB
    'width': 1920,
    'height': 1080,
    'format': 'jpeg',
  },
);

// Disappearing snap message
final snapMessage = MessageModel(
  id: 'msg125',
  chatId: 'chat456',
  senderId: 'user123',
  senderUsername: 'johndoe',
  type: MessageType.snap,
  content: 'https://example.com/snap.jpg',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(Duration(seconds: 10)),
  deleteAfterView: true,
  allowScreenshot: false,
);

// Reply message
final replyMessage = MessageModel(
  id: 'msg126',
  chatId: 'chat456',
  senderId: 'user456',
  senderUsername: 'janedoe',
  type: MessageType.text,
  content: 'I\'m doing great, thanks for asking!',
  createdAt: DateTime.now(),
  replyToMessageId: 'msg123',
);
```

### Message Utility Methods

```dart
// Check if message is expired
if (message.isExpired) {
  print('Message has expired and should be deleted');
}

// Check if user has read the message
if (message.hasUserRead('user456')) {
  print('User has read this message');
}

// Check if user has viewed the snap
if (message.hasUserViewed('user456')) {
  print('User has viewed this snap');
}

// Check if message is deleted for user
if (message.isDeletedForUser('user456')) {
  print('Message is deleted for this user');
}

// Get time until expiration
final timeLeft = message.timeUntilExpiration;
if (timeLeft != null) {
  print('Time remaining: ${message.timeRemainingText}');
}

// Check message type
if (message.isSnap) {
  print('This is a snap message');
}

if (message.isMedia) {
  print('This is a media message (image or video)');
}
```

### Working with Reactions

```dart
// Add reaction
final reactions = Map<String, dynamic>.from(message.reactions);
reactions['❤️'] = [...(reactions['❤️'] ?? []), 'user456'];

final reactedMessage = message.copyWith(reactions: reactions);

// Get reaction count
final heartCount = message.getReactionCount('❤️');
print('Hearts: $heartCount');

// Check if user reacted
if (message.hasUserReacted('user456', '😂')) {
  print('User laughed at this message');
}
```

---

## ChatModel

Represents a chat conversation (direct or group) with member management and settings.

### Properties

```dart
enum ChatType { direct, group }

class ChatModel {
  final String id;                               // Unique chat identifier
  final ChatType type;                           // Chat type
  final String? name;                            // Group chat name
  final String? description;                     // Group description
  final String? avatarUrl;                       // Group avatar
  final List<String> participants;               // Participant UIDs
  final Map<String, String> participantNames;    // UID -> username mapping
  final Map<String, String> participantAvatars;  // UID -> avatar mapping
  final String? lastMessageId;                   // Last message ID
  final String? lastMessageContent;              // Last message preview
  final DateTime? lastMessageTime;               // Last message timestamp
  final String? lastMessageSenderId;             // Last sender ID
  final Map<String, DateTime> lastReadTime;      // UID -> last read time
  final Map<String, int> unreadCount;            // UID -> unread count
  final DateTime createdAt;                      // Chat creation time
  final DateTime updatedAt;                      // Last update time
  final String createdBy;                        // Creator's UID
  final Map<String, String> memberRoles;         // UID -> role mapping
  final bool isEncrypted;                        // Is chat encrypted
  final String? groupKey;                        // Group encryption key
  final Map<String, dynamic> chatSettings;       // Chat preferences
  final bool isActive;                           // Is chat active
  final bool isArchived;                         // Is chat archived
  final bool isMuted;                            // Is chat muted
  final List<String> pinnedMessages;             // Pinned message IDs
  final Map<String, dynamic> metadata;           // Additional metadata
}
```

### Creating Chats

```dart
// Direct chat
final directChat = ChatModel(
  id: 'chat123',
  type: ChatType.direct,
  participants: ['user123', 'user456'],
  participantNames: {
    'user123': 'johndoe',
    'user456': 'janedoe',
  },
  participantAvatars: {
    'user123': 'https://example.com/john.jpg',
    'user456': 'https://example.com/jane.jpg',
  },
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  createdBy: 'user123',
  isEncrypted: true,
);

// Group chat
final groupChat = ChatModel(
  id: 'chat456',
  type: ChatType.group,
  name: 'Flutter Developers',
  description: 'A group for Flutter enthusiasts',
  avatarUrl: 'https://example.com/group.jpg',
  participants: ['user123', 'user456', 'user789'],
  participantNames: {
    'user123': 'johndoe',
    'user456': 'janedoe',
    'user789': 'bobsmith',
  },
  memberRoles: {
    'user123': 'admin',
    'user456': 'member',
    'user789': 'member',
  },
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  createdBy: 'user123',
  isEncrypted: true,
);
```

### Chat Utility Methods

```dart
// Get chat display name for current user
final displayName = chat.getDisplayName('user123');
print('Chat name: $displayName');

// Get chat avatar for current user
final avatarUrl = chat.getChatAvatarUrl('user123');

// Get unread count for user
final unreadCount = chat.getUnreadCount('user456');
print('Unread messages: $unreadCount');

// Check permissions
if (chat.isUserAdmin('user123')) {
  print('User is admin');
}

if (chat.canUserAddMembers('user123')) {
  print('User can add members');
}

if (chat.canUserRemoveMembers('user123')) {
  print('User can remove members');
}

// Get other participant (for direct chats)
final otherUser = chat.getOtherParticipant('user123');
print('Chatting with: $otherUser');

// Check chat type
if (chat.isGroupChat) {
  print('This is a group chat with ${chat.memberCount} members');
} else {
  print('This is a direct chat');
}

// Check if user is participant
if (chat.isParticipant('user456')) {
  print('User is part of this chat');
}
```

### Updating Chat Data

```dart
// Update last message info
final updatedChat = chat.copyWith(
  lastMessageId: 'msg123',
  lastMessageContent: 'Hey everyone!',
  lastMessageTime: DateTime.now(),
  lastMessageSenderId: 'user456',
  updatedAt: DateTime.now(),
);

// Update unread count
final newUnreadCount = Map<String, int>.from(chat.unreadCount);
newUnreadCount['user123'] = (newUnreadCount['user123'] ?? 0) + 1;

final chatWithUnread = chat.copyWith(unreadCount: newUnreadCount);

// Add new member to group
final newParticipants = [...chat.participants, 'user999'];
final newParticipantNames = Map<String, String>.from(chat.participantNames);
newParticipantNames['user999'] = 'newuser';

final expandedChat = chat.copyWith(
  participants: newParticipants,
  participantNames: newParticipantNames,
);
```

---

## Best Practices

### 1. Data Validation

```dart
// Always validate data before creating models
String? validateUsername(String username) {
  if (username.isEmpty) return 'Username cannot be empty';
  if (username.length < 3) return 'Username must be at least 3 characters';
  if (username.length > 20) return 'Username must be less than 20 characters';
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  return null;
}

// Use validation before creating users
final usernameError = validateUsername('john_doe123');
if (usernameError != null) {
  throw Exception(usernameError);
}
```

### 2. Null Safety

```dart
// Always handle nullable fields properly
String getDisplayName(UserModel? user) {
  return user?.displayName ?? 'Unknown User';
}

String getProfilePicture(UserModel? user) {
  return user?.profilePictureUrl ?? 'assets/default_avatar.png';
}

// Safe navigation for nested properties
String getNotificationSound(UserModel user) {
  return user.notificationSettings['soundEnabled'] == true 
      ? 'default_sound.mp3' 
      : 'silent';
}
```

### 3. Immutability

```dart
// Always use copyWith for updates
UserModel updateUserBio(UserModel user, String newBio) {
  return user.copyWith(bio: newBio);
}

// Don't modify lists directly, create new ones
StoryModel addViewer(StoryModel story, String viewerId) {
  if (story.viewedBy.contains(viewerId)) return story;
  
  return story.copyWith(
    viewedBy: [...story.viewedBy, viewerId],
    viewCount: story.viewCount + 1,
  );
}
```

### 4. Error Handling

```dart
// Wrap model operations in try-catch blocks
Future<UserModel?> loadUserSafely(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    
    if (!doc.exists) return null;
    return UserModel.fromSnapshot(doc);
  } catch (e) {
    print('Error loading user: $e');
    return null;
  }
}

// Validate model data
bool isValidStory(StoryModel story) {
  if (story.mediaUrl.isEmpty) return false;
  if (story.createdAt.isAfter(DateTime.now())) return false;
  if (story.expiresAt.isBefore(story.createdAt)) return false;
  return true;
}
```

---

## Common Patterns

### 1. Stream Processing

```dart
// Transform model streams for UI
Stream<List<String>> getFriendNamesStream(String userId) {
  return UserDatabaseService.listenToUser(userId)
      .asyncMap((user) async {
        if (user == null || user.friends.isEmpty) return <String>[];
        
        final friends = await UserDatabaseService.getUsersByIds(user.friends);
        return friends.map((friend) => friend.displayName).toList();
      });
}
```

### 2. Model Conversion

```dart
// Convert models for API responses
Map<String, dynamic> userToApiResponse(UserModel user) {
  return {
    'id': user.uid,
    'username': user.username,
    'displayName': user.displayName,
    'avatar': user.profilePictureUrl,
    'isOnline': user.isOnline,
    'friendsCount': user.friendsCount,
    'storiesCount': user.storiesCount,
  };
}

// Convert for different UI contexts
class UserListItem {
  final String uid;
  final String name;
  final String? avatar;
  final bool isOnline;
  
  UserListItem.fromUser(UserModel user)
      : uid = user.uid,
        name = user.displayName,
        avatar = user.profilePictureUrl,
        isOnline = user.isOnline;
}
```

### 3. Caching and Performance

```dart
// Cache frequently accessed models
class ModelCache {
  static final Map<String, UserModel> _userCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  static UserModel? getCachedUser(String uid) {
    final timestamp = _cacheTimestamps[uid];
    if (timestamp == null || 
        DateTime.now().difference(timestamp) > Duration(minutes: 5)) {
      _userCache.remove(uid);
      _cacheTimestamps.remove(uid);
      return null;
    }
    return _userCache[uid];
  }
  
  static void cacheUser(UserModel user) {
    _userCache[user.uid] = user;
    _cacheTimestamps[user.uid] = DateTime.now();
  }
}
```

This documentation provides comprehensive guidance for working with SnapAGram's data models effectively and safely!
