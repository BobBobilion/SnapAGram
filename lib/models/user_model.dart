import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'walker_profile.dart';
import 'owner_profile.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String handle;
  final String? profilePictureUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  // DogWalk: Changed from friends to connections
  final List<String> connections; // walker-owner connections
  final List<String> connectionRequests; // incoming connection requests
  final List<String> sentRequests; // outgoing connection requests
  final List<String> blockedUsers;
  final Map<String, dynamic> notificationSettings;
  final Map<String, dynamic> privacySettings;
  final String? publicKey; // for E2EE
  final String? encryptedPrivateKey; // encrypted with user's password
  final Map<String, dynamic> chatDefaults; // default TTL settings
  final int storiesCount;
  final int connectionsCount; // renamed from friendsCount
  // DogWalk: New role system
  final UserRole role;
  final WalkerProfile? walkerProfile;
  final OwnerProfile? ownerProfile;
  final bool isOnboardingComplete;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.handle,
    this.profilePictureUrl,
    this.bio,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.connections = const [],
    this.connectionRequests = const [],
    this.sentRequests = const [],
    this.blockedUsers = const [],
    this.notificationSettings = const {},
    this.privacySettings = const {},
    this.publicKey,
    this.encryptedPrivateKey,
    this.chatDefaults = const {},
    this.storiesCount = 0,
    this.connectionsCount = 0,
    required this.role,
    this.walkerProfile,
    this.ownerProfile,
    this.isOnboardingComplete = false,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'handle': handle,
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'connections': connections,
      'connectionRequests': connectionRequests,
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
      'connectionsCount': connectionsCount,
      'role': role.name,
      'walkerProfile': walkerProfile?.toMap(),
      'ownerProfile': ownerProfile?.toMap(),
      'isOnboardingComplete': isOnboardingComplete,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      handle: map['handle'] ?? '',
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] ?? false,
      connections: List<String>.from(map['connections'] ?? map['friends'] ?? []), // backward compatibility
      connectionRequests: List<String>.from(map['connectionRequests'] ?? map['friendRequests'] ?? []),
      sentRequests: List<String>.from(map['sentRequests'] ?? []),
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      notificationSettings: Map<String, dynamic>.from(map['notificationSettings'] ?? {}),
      privacySettings: Map<String, dynamic>.from(map['privacySettings'] ?? {}),
      publicKey: map['publicKey'],
      encryptedPrivateKey: map['encryptedPrivateKey'],
      chatDefaults: Map<String, dynamic>.from(map['chatDefaults'] ?? {}),
      storiesCount: map['storiesCount'] ?? 0,
      connectionsCount: map['connectionsCount'] ?? map['friendsCount'] ?? 0,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.owner, // default to owner if not set
      ),
      walkerProfile: map['walkerProfile'] != null 
          ? WalkerProfile.fromMap(map['walkerProfile']) 
          : null,
      ownerProfile: map['ownerProfile'] != null 
          ? OwnerProfile.fromMap(map['ownerProfile']) 
          : null,
      isOnboardingComplete: map['isOnboardingComplete'] ?? false,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  // Copy with changes
  UserModel copyWith({
    String? displayName,
    String? handle,
    String? profilePictureUrl,
    String? bio,
    DateTime? lastSeen,
    bool? isOnline,
    List<String>? connections,
    List<String>? connectionRequests,
    List<String>? sentRequests,
    List<String>? blockedUsers,
    Map<String, dynamic>? notificationSettings,
    Map<String, dynamic>? privacySettings,
    String? publicKey,
    String? encryptedPrivateKey,
    Map<String, dynamic>? chatDefaults,
    int? storiesCount,
    int? connectionsCount,
    UserRole? role,
    WalkerProfile? walkerProfile,
    OwnerProfile? ownerProfile,
    bool? isOnboardingComplete,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      connections: connections ?? this.connections,
      connectionRequests: connectionRequests ?? this.connectionRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacySettings: privacySettings ?? this.privacySettings,
      publicKey: publicKey ?? this.publicKey,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      chatDefaults: chatDefaults ?? this.chatDefaults,
      storiesCount: storiesCount ?? this.storiesCount,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      role: role ?? this.role,
      walkerProfile: walkerProfile ?? this.walkerProfile,
      ownerProfile: ownerProfile ?? this.ownerProfile,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }

  // DogWalk-specific getters
  bool get isWalker => role == UserRole.walker;
  bool get isOwner => role == UserRole.owner;
  
  String get roleText => role == UserRole.walker ? 'Walker' : 'Owner';
  
  bool get hasCompleteProfile {
    if (!isOnboardingComplete) return false;
    if (isWalker && walkerProfile == null) return false;
    if (isOwner && ownerProfile == null) return false;
    return true;
  }

  String? get city {
    if (isWalker) return walkerProfile?.city;
    if (isOwner) return ownerProfile?.city;
    return null;
  }

  double? get rating {
    if (isWalker) return walkerProfile?.averageRating;
    return null;
  }

  int? get totalReviews {
    if (isWalker) return walkerProfile?.totalReviews;
    return null;
  }

  // Default settings
  static Map<String, dynamic> _defaultNotificationSettings() {
    return {
      'newMessages': true,
      'connectionRequests': true,
      'walkRequests': true,
      'walkUpdates': true,
      'reviews': true,
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
      'profileVisibility': 'public', // 'public', 'connections', 'private'
      'showOnlineStatus': true,
      'showLastSeen': true,
      'allowConnectionRequests': true,
      'allowMessageRequests': true,
      'showLocation': true, // for matching algorithm
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
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, handle: $handle, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
} 