import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, snap, sticker, location, contact }
enum MessageStatus { sent, delivered, read, failed }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderUsername;
  final String? senderProfilePicture;
  final MessageType type;
  final String content; // text content or media URL
  final String? thumbnailUrl; // for images/videos
  final DateTime createdAt;
  final DateTime? expiresAt; // for TTL messages
  final MessageStatus status;
  final Map<String, DateTime> readBy; // uid -> read timestamp
  final bool isEncrypted;
  final String? encryptedKey;
  final Map<String, dynamic> metadata; // additional data like file size, duration, etc.
  final String? replyToMessageId;
  final bool isDeleted;
  final DateTime? deletedAt;
  final List<String> deletedFor; // uids who deleted this message
  final Map<String, dynamic> reactions; // emoji -> list of uids
  final bool allowScreenshot;
  final bool deleteAfterView;
  final int viewCount;
  final List<String> viewedBy;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderUsername,
    this.senderProfilePicture,
    required this.type,
    required this.content,
    this.thumbnailUrl,
    required this.createdAt,
    this.expiresAt,
    this.status = MessageStatus.sent,
    this.readBy = const {},
    this.isEncrypted = false,
    this.encryptedKey,
    this.metadata = const {},
    this.replyToMessageId,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedFor = const [],
    this.reactions = const {},
    this.allowScreenshot = true,
    this.deleteAfterView = false,
    this.viewCount = 0,
    this.viewedBy = const [],
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderProfilePicture': senderProfilePicture,
      'type': type.name,
      'content': content,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'status': status.name,
      'readBy': readBy.map((uid, timestamp) => MapEntry(uid, Timestamp.fromDate(timestamp))),
      'isEncrypted': isEncrypted,
      'encryptedKey': encryptedKey,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedFor': deletedFor,
      'reactions': reactions,
      'allowScreenshot': allowScreenshot,
      'deleteAfterView': deleteAfterView,
      'viewCount': viewCount,
      'viewedBy': viewedBy,
    };
  }

  // Create from Firestore document
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      senderProfilePicture: map['senderProfilePicture'],
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      readBy: (map['readBy'] as Map<String, dynamic>?)?.map(
        (uid, timestamp) => MapEntry(uid, (timestamp as Timestamp).toDate()),
      ) ?? {},
      isEncrypted: map['isEncrypted'] ?? false,
      encryptedKey: map['encryptedKey'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      replyToMessageId: map['replyToMessageId'],
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      reactions: Map<String, dynamic>.from(map['reactions'] ?? {}),
      allowScreenshot: map['allowScreenshot'] ?? true,
      deleteAfterView: map['deleteAfterView'] ?? false,
      viewCount: map['viewCount'] ?? 0,
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory MessageModel.fromSnapshot(DocumentSnapshot snapshot) {
    return MessageModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  // Copy with changes
  MessageModel copyWith({
    String? senderUsername,
    String? senderProfilePicture,
    String? content,
    String? thumbnailUrl,
    DateTime? expiresAt,
    MessageStatus? status,
    Map<String, DateTime>? readBy,
    String? encryptedKey,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    bool? isDeleted,
    DateTime? deletedAt,
    List<String>? deletedFor,
    Map<String, dynamic>? reactions,
    bool? allowScreenshot,
    bool? deleteAfterView,
    int? viewCount,
    List<String>? viewedBy,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      type: type,
      content: content ?? this.content,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      isEncrypted: isEncrypted,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      metadata: metadata ?? this.metadata,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedFor: deletedFor ?? this.deletedFor,
      reactions: reactions ?? this.reactions,
      allowScreenshot: allowScreenshot ?? this.allowScreenshot,
      deleteAfterView: deleteAfterView ?? this.deleteAfterView,
      viewCount: viewCount ?? this.viewCount,
      viewedBy: viewedBy ?? this.viewedBy,
    );
  }

  // Check if message is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Check if user has read this message
  bool hasUserRead(String userId) => readBy.containsKey(userId);

  // Check if user has viewed this message (for snaps)
  bool hasUserViewed(String userId) => viewedBy.contains(userId);

  // Check if user deleted this message
  bool isDeletedForUser(String userId) => deletedFor.contains(userId);

  // Get time until expiration
  Duration? get timeUntilExpiration {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }

  // Get formatted time remaining
  String? get timeRemainingText {
    final duration = timeUntilExpiration;
    if (duration == null) return null;
    
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

  // Check if message is a snap type
  bool get isSnap => type == MessageType.snap;

  // Check if message is media
  bool get isMedia => type == MessageType.image || type == MessageType.video;

  // Get reaction count for specific emoji
  int getReactionCount(String emoji) {
    if (!reactions.containsKey(emoji)) return 0;
    return (reactions[emoji] as List).length;
  }

  // Check if user reacted with specific emoji
  bool hasUserReacted(String userId, String emoji) {
    if (!reactions.containsKey(emoji)) return false;
    return (reactions[emoji] as List).contains(userId);
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, chatId: $chatId, senderId: $senderId, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 