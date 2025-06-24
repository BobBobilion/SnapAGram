import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { direct, group }

class ChatModel {
  final String id;
  final ChatType type;
  final String? name; // for group chats
  final String? description; // for group chats
  final String? avatarUrl; // for group chats
  final List<String> participants; // list of uids
  final Map<String, String> participantNames; // uid -> username
  final Map<String, String> participantAvatars; // uid -> avatar URL
  final String? lastMessageId;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, DateTime> lastReadTime; // uid -> last read timestamp
  final Map<String, int> unreadCount; // uid -> unread count
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // uid of creator
  final Map<String, String> memberRoles; // uid -> role (admin, member)
  final bool isEncrypted;
  final String? groupKey; // encryption key for group chats
  final Map<String, dynamic> chatSettings; // TTL, permissions, etc.
  final bool isActive;
  final bool isArchived;
  final bool isMuted;
  final List<String> pinnedMessages;
  final Map<String, dynamic> metadata;

  ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    required this.participants,
    this.participantNames = const {},
    this.participantAvatars = const {},
    this.lastMessageId,
    this.lastMessageContent,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.lastReadTime = const {},
    this.unreadCount = const {},
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.memberRoles = const {},
    this.isEncrypted = false,
    this.groupKey,
    this.chatSettings = const {},
    this.isActive = true,
    this.isArchived = false,
    this.isMuted = false,
    this.pinnedMessages = const [],
    this.metadata = const {},
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'participants': participants,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessageId': lastMessageId,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'lastReadTime': lastReadTime.map((uid, timestamp) => MapEntry(uid, Timestamp.fromDate(timestamp))),
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'memberRoles': memberRoles,
      'isEncrypted': isEncrypted,
      'groupKey': groupKey,
      'chatSettings': chatSettings.isNotEmpty ? chatSettings : _defaultChatSettings(),
      'isActive': isActive,
      'isArchived': isArchived,
      'isMuted': isMuted,
      'pinnedMessages': pinnedMessages,
      'metadata': metadata,
    };
  }

  // Create from Firestore document
  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] ?? '',
      type: ChatType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ChatType.direct,
      ),
      name: map['name'],
      description: map['description'],
      avatarUrl: map['avatarUrl'],
      participants: List<String>.from(map['participants'] ?? []),
      participantNames: Map<String, String>.from(map['participantNames'] ?? {}),
      participantAvatars: Map<String, String>.from(map['participantAvatars'] ?? {}),
      lastMessageId: map['lastMessageId'],
      lastMessageContent: map['lastMessageContent'],
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: map['lastMessageSenderId'],
      lastReadTime: (map['lastReadTime'] as Map<String, dynamic>?)?.map(
        (uid, timestamp) => MapEntry(uid, (timestamp as Timestamp).toDate()),
      ) ?? {},
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      memberRoles: Map<String, String>.from(map['memberRoles'] ?? {}),
      isEncrypted: map['isEncrypted'] ?? false,
      groupKey: map['groupKey'],
      chatSettings: Map<String, dynamic>.from(map['chatSettings'] ?? {}),
      isActive: map['isActive'] ?? true,
      isArchived: map['isArchived'] ?? false,
      isMuted: map['isMuted'] ?? false,
      pinnedMessages: List<String>.from(map['pinnedMessages'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory ChatModel.fromSnapshot(DocumentSnapshot snapshot) {
    return ChatModel.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  // Copy with changes
  ChatModel copyWith({
    String? name,
    String? description,
    String? avatarUrl,
    List<String>? participants,
    Map<String, String>? participantNames,
    Map<String, String>? participantAvatars,
    String? lastMessageId,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, DateTime>? lastReadTime,
    Map<String, int>? unreadCount,
    DateTime? updatedAt,
    Map<String, String>? memberRoles,
    String? groupKey,
    Map<String, dynamic>? chatSettings,
    bool? isActive,
    bool? isArchived,
    bool? isMuted,
    List<String>? pinnedMessages,
    Map<String, dynamic>? metadata,
  }) {
    return ChatModel(
      id: id,
      type: type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      participantAvatars: participantAvatars ?? this.participantAvatars,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      memberRoles: memberRoles ?? this.memberRoles,
      isEncrypted: isEncrypted,
      groupKey: groupKey ?? this.groupKey,
      chatSettings: chatSettings ?? this.chatSettings,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get chat display name
  String getDisplayName(String currentUserId) {
    if (type == ChatType.group) {
      return name ?? 'Group Chat';
    } else {
      // For direct chats, show the other participant's name
      final otherParticipant = participants.firstWhere(
        (uid) => uid != currentUserId,
        orElse: () => '',
      );
      return participantNames[otherParticipant] ?? 'Unknown User';
    }
  }

  // Get chat avatar URL
  String? getChatAvatarUrl(String currentUserId) {
    if (type == ChatType.group) {
      return avatarUrl;
    } else {
      // For direct chats, show the other participant's avatar
      final otherParticipant = participants.firstWhere(
        (uid) => uid != currentUserId,
        orElse: () => '',
      );
      return participantAvatars[otherParticipant];
    }
  }

  // Get unread count for user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }

  // Check if user is admin
  bool isUserAdmin(String userId) {
    return memberRoles[userId] == 'admin';
  }

  // Check if user can add members
  bool canUserAddMembers(String userId) {
    if (type == ChatType.direct) return false;
    return isUserAdmin(userId) || createdBy == userId;
  }

  // Check if user can remove members
  bool canUserRemoveMembers(String userId) {
    if (type == ChatType.direct) return false;
    return isUserAdmin(userId) || createdBy == userId;
  }

  // Get other participant (for direct chats)
  String? getOtherParticipant(String currentUserId) {
    if (type == ChatType.group) return null;
    return participants.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );
  }

  // Check if chat is group chat
  bool get isGroupChat => type == ChatType.group;

  // Get member count
  int get memberCount => participants.length;

  // Check if user is participant
  bool isParticipant(String userId) => participants.contains(userId);

  // Default chat settings
  static Map<String, dynamic> _defaultChatSettings() {
    return {
      'defaultTTL': 24, // hours
      'deleteAfterView': false,
      'allowScreenshots': true,
      'allowSaving': false,
      'allowAddMembers': true,
      'allowRemoveMembers': false,
      'allowEditGroupInfo': false,
      'autoDeleteMessages': false,
      'autoDeleteDuration': 168, // hours (1 week)
    };
  }

  @override
  String toString() {
    return 'ChatModel(id: $id, type: $type, participants: ${participants.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 