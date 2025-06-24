import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String? profilePictureUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final List<String> friends;
  final List<String> friendRequests; // incoming requests
  final List<String> sentRequests; // outgoing requests
  final List<String> blockedUsers;
  final Map<String, dynamic> notificationSettings;
  final Map<String, dynamic> privacySettings;
  final String? publicKey; // for E2EE
  final String? encryptedPrivateKey; // encrypted with user's password
  final Map<String, dynamic> chatDefaults; // default TTL settings
  final int storiesCount;
  final int friendsCount;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    this.profilePictureUrl,
    this.bio,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.friends = const [],
    this.friendRequests = const [],
    this.sentRequests = const [],
    this.blockedUsers = const [],
    this.notificationSettings = const {},
    this.privacySettings = const {},
    this.publicKey,
    this.encryptedPrivateKey,
    this.chatDefaults = const {},
    this.storiesCount = 0,
    this.friendsCount = 0,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'friends': friends,
      'friendRequests': friendRequests,
      'sentRequests': sentRequests,
      'blockedUsers': blockedUsers,
      'notificationSettings': notificationSettings.isNotEmpty 
          ? notificationSettings 
          : _defaultNotificationSettings(),
      'privacySettings': privacySettings.isNotEmpty 
          ? privacySettings 
          : _defaultPrivacySettings(),
      'publicKey': publicKey,
      'encryptedPrivateKey': encryptedPrivateKey,
      'chatDefaults': chatDefaults.isNotEmpty 
          ? chatDefaults 
          : _defaultChatSettings(),
      'storiesCount': storiesCount,
      'friendsCount': friendsCount,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      username: map['username'] ?? '',
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] ?? false,
      friends: List<String>.from(map['friends'] ?? []),
      friendRequests: List<String>.from(map['friendRequests'] ?? []),
      sentRequests: List<String>.from(map['sentRequests'] ?? []),
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      notificationSettings: Map<String, dynamic>.from(map['notificationSettings'] ?? {}),
      privacySettings: Map<String, dynamic>.from(map['privacySettings'] ?? {}),
      publicKey: map['publicKey'],
      encryptedPrivateKey: map['encryptedPrivateKey'],
      chatDefaults: Map<String, dynamic>.from(map['chatDefaults'] ?? {}),
      storiesCount: map['storiesCount'] ?? 0,
      friendsCount: map['friendsCount'] ?? 0,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  // Copy with changes
  UserModel copyWith({
    String? displayName,
    String? username,
    String? profilePictureUrl,
    String? bio,
    DateTime? lastSeen,
    bool? isOnline,
    List<String>? friends,
    List<String>? friendRequests,
    List<String>? sentRequests,
    List<String>? blockedUsers,
    Map<String, dynamic>? notificationSettings,
    Map<String, dynamic>? privacySettings,
    String? publicKey,
    String? encryptedPrivateKey,
    Map<String, dynamic>? chatDefaults,
    int? storiesCount,
    int? friendsCount,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacySettings: privacySettings ?? this.privacySettings,
      publicKey: publicKey ?? this.publicKey,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      chatDefaults: chatDefaults ?? this.chatDefaults,
      storiesCount: storiesCount ?? this.storiesCount,
      friendsCount: friendsCount ?? this.friendsCount,
    );
  }

  // Default settings
  static Map<String, dynamic> _defaultNotificationSettings() {
    return {
      'newMessages': true,
      'friendRequests': true,
      'storyLikes': false,
      'storyShares': false,
      'soundEnabled': true,
      'vibrationEnabled': true,
      'quietHours': {
        'enabled': false,
        'startTime': '22:00',
        'endTime': '08:00',
      },
    };
  }

  static Map<String, dynamic> _defaultPrivacySettings() {
    return {
      'profileVisibility': 'friends', // 'public', 'friends', 'private'
      'storyVisibility': 'friends', // 'public', 'friends'
      'allowFriendRequests': true,
      'allowMessageRequests': true,
      'showOnlineStatus': true,
      'showLastSeen': true,
      'allowStoriesScreenshot': true,
      'allowMessagesScreenshot': true,
    };
  }

  static Map<String, dynamic> _defaultChatSettings() {
    return {
      'defaultTTL': 24, // hours
      'deleteAfterView': false,
      'allowScreenshots': true,
      'allowSaving': false,
    };
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
} 