import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryType { image, video }
enum StoryVisibility { public, friends }

class StoryModel {
  final String id;
  final String uid; // creator's uid
  final String creatorUsername;
  final String? creatorProfilePicture;
  final StoryType type;
  final StoryVisibility visibility;
  final String mediaUrl;
  final String? thumbnailUrl; // for videos
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic> filters; // applied filters
  final List<String> viewedBy; // list of uids
  final List<String> likedBy; // list of uids
  final int viewCount;
  final int likeCount;
  final int shareCount;
  final bool isEncrypted; // true for friends-only stories
  final String? encryptedKey; // encryption key for friends-only stories
  final List<String> allowedViewers; // uids who can view (for friends-only)
  final Map<String, dynamic> metadata; // additional data

  StoryModel({
    required this.id,
    required this.uid,
    required this.creatorUsername,
    this.creatorProfilePicture,
    required this.type,
    required this.visibility,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.filters = const {},
    this.viewedBy = const [],
    this.likedBy = const [],
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.isEncrypted = false,
    this.encryptedKey,
    this.allowedViewers = const [],
    this.metadata = const {},
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'creatorUsername': creatorUsername,
      'creatorProfilePicture': creatorProfilePicture,
      'type': type.name,
      'visibility': visibility.name,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'filters': filters,
      'viewedBy': viewedBy,
      'likedBy': likedBy,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'isEncrypted': isEncrypted,
      'encryptedKey': encryptedKey,
      'allowedViewers': allowedViewers,
      'metadata': metadata,
    };
  }

  // Create from Firestore document
  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      creatorUsername: map['creatorUsername'] ?? '',
      creatorProfilePicture: map['creatorProfilePicture'],
      type: StoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StoryType.image,
      ),
      visibility: StoryVisibility.values.firstWhere(
        (e) => e.name == map['visibility'],
        orElse: () => StoryVisibility.public,
      ),
      mediaUrl: map['mediaUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      caption: map['caption'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(Duration(hours: 24)),
      filters: Map<String, dynamic>.from(map['filters'] ?? {}),
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
      likedBy: List<String>.from(map['likedBy'] ?? []),
      viewCount: map['viewCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      shareCount: map['shareCount'] ?? 0,
      isEncrypted: map['isEncrypted'] ?? false,
      encryptedKey: map['encryptedKey'],
      allowedViewers: List<String>.from(map['allowedViewers'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory StoryModel.fromSnapshot(DocumentSnapshot snapshot) {
    return StoryModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  // Copy with changes
  StoryModel copyWith({
    String? creatorUsername,
    String? creatorProfilePicture,
    String? mediaUrl,
    String? thumbnailUrl,
    String? caption,
    DateTime? expiresAt,
    Map<String, dynamic>? filters,
    List<String>? viewedBy,
    List<String>? likedBy,
    int? viewCount,
    int? likeCount,
    int? shareCount,
    String? encryptedKey,
    List<String>? allowedViewers,
    Map<String, dynamic>? metadata,
  }) {
    return StoryModel(
      id: id,
      uid: uid,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      creatorProfilePicture: creatorProfilePicture ?? this.creatorProfilePicture,
      type: type,
      visibility: visibility,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      filters: filters ?? this.filters,
      viewedBy: viewedBy ?? this.viewedBy,
      likedBy: likedBy ?? this.likedBy,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      isEncrypted: isEncrypted,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      allowedViewers: allowedViewers ?? this.allowedViewers,
      metadata: metadata ?? this.metadata,
    );
  }

  // Check if story is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Check if user has viewed this story
  bool hasUserViewed(String userId) => viewedBy.contains(userId);

  // Check if user has liked this story
  bool hasUserLiked(String userId) => likedBy.contains(userId);

  // Check if user can view this story
  bool canUserView(String userId) {
    if (visibility == StoryVisibility.public) return true;
    if (uid == userId) return true; // creator can always view
    return allowedViewers.contains(userId);
  }

  // Get time until expiration
  Duration get timeUntilExpiration => expiresAt.difference(DateTime.now());

  // Get formatted time remaining
  String get timeRemainingText {
    final duration = timeUntilExpiration;
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else if (duration.inSeconds > 0) {
      return '${duration.inSeconds}s';
    } else {
      return 'Expired';
    }
  }

  @override
  String toString() {
    return 'StoryModel(id: $id, uid: $uid, type: $type, visibility: $visibility)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 