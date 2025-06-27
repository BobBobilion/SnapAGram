import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'user_database_service.dart';

class ChatDatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static final CollectionReference _chatsCollection = _firestore.collection('chats');
  static final CollectionReference _messagesCollection = _firestore.collection('messages');

  // Create direct chat
  static Future<String> createDirectChat(String userId1, String userId2) async {
    try {
      // Check if chat already exists
      final existingChat = await getDirectChat(userId1, userId2);
      if (existingChat != null) return existingChat.id;

      final users = await UserDatabaseService.getUsersByIds([userId1, userId2]);
      if (users.length != 2) throw Exception('One or both users not found');

      final now = DateTime.now();
      final chatId = _chatsCollection.doc().id;

      final chat = ChatModel(
        id: chatId,
        type: ChatType.direct,
        participants: [userId1, userId2],
        participantNames: {
          userId1: users.firstWhere((u) => u.uid == userId1).handle,
          userId2: users.firstWhere((u) => u.uid == userId2).handle,
        },
        participantAvatars: {
          userId1: users.firstWhere((u) => u.uid == userId1).profilePictureUrl ?? '',
          userId2: users.firstWhere((u) => u.uid == userId2).profilePictureUrl ?? '',
        },
        createdAt: now,
        updatedAt: now,
        createdBy: userId1,
        isEncrypted: true, // Direct chats are encrypted by default
      );

      await _chatsCollection.doc(chatId).set(chat.toMap());
      return chatId;
    } catch (e) {
      throw Exception('Failed to create direct chat: $e');
    }
  }

  // Create group chat
  static Future<String> createGroupChat({
    required String creatorId,
    required String name,
    required List<String> participantIds,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      if (participantIds.length > 10) {
        throw Exception('Group chats are limited to 10 members');
      }

      // Include creator in participants if not already
      if (!participantIds.contains(creatorId)) {
        participantIds.add(creatorId);
      }

      final users = await UserDatabaseService.getUsersByIds(participantIds);
      if (users.length != participantIds.length) {
        throw Exception('Some users not found');
      }

      final now = DateTime.now();
      final chatId = _chatsCollection.doc().id;

      final participantNames = <String, String>{};
      final participantAvatars = <String, String>{};
      final memberRoles = <String, String>{};

      for (final user in users) {
        participantNames[user.uid] = user.handle;
        participantAvatars[user.uid] = user.profilePictureUrl ?? '';
        memberRoles[user.uid] = user.uid == creatorId ? 'admin' : 'member';
      }

      final chat = ChatModel(
        id: chatId,
        type: ChatType.group,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        participants: participantIds,
        participantNames: participantNames,
        participantAvatars: participantAvatars,
        memberRoles: memberRoles,
        createdAt: now,
        updatedAt: now,
        createdBy: creatorId,
        isEncrypted: true, // Group chats are encrypted
      );

      await _chatsCollection.doc(chatId).set(chat.toMap());
      return chatId;
    } catch (e) {
      throw Exception('Failed to create group chat: $e');
    }
  }

  // Get direct chat between two users
  static Future<ChatModel?> getDirectChat(String userId1, String userId2) async {
    try {
      final snapshot = await _chatsCollection
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: userId1)
          .get();

      for (final doc in snapshot.docs) {
        final chat = ChatModel.fromSnapshot(doc);
        if (chat.participants.contains(userId2)) {
          return chat;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get direct chat: $e');
    }
  }

  // Get chat by ID
  static Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return ChatModel.fromSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get chat: $e');
    }
  }

  // Get user's chats
  static Future<List<ChatModel>> getUserChats(String userId) async {
    try {
      final snapshot = await _chatsCollection
          .where('participants', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ChatModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user chats: $e');
    }
  }

  // Send message
  static Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required MessageType type,
    required String content,
    String? thumbnailUrl,
    DateTime? expiresAt,
    String? replyToMessageId,
    bool allowScreenshot = true,
    bool deleteAfterView = false,
  }) async {
    try {
      // Get chat to verify sender is participant
      final chat = await getChatById(chatId);
      if (chat == null || !chat.isParticipant(senderId)) {
        throw Exception('Chat not found or access denied');
      }

      // Get sender info
      final sender = await UserDatabaseService.getUserById(senderId);
      if (sender == null) throw Exception('Sender not found');

      final now = DateTime.now();
      final messageId = _messagesCollection.doc().id;

      final message = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        senderUsername: sender.handle,
        senderProfilePicture: sender.profilePictureUrl,
        type: type,
        content: content,
        thumbnailUrl: thumbnailUrl,
        createdAt: now,
        expiresAt: expiresAt,
        isEncrypted: chat.isEncrypted,
        replyToMessageId: replyToMessageId,
        allowScreenshot: allowScreenshot,
        deleteAfterView: deleteAfterView,
      );

      final batch = _firestore.batch();

      // Create message document
      batch.set(_messagesCollection.doc(messageId), message.toMap());

      // Update chat with last message info
      final unreadCount = <String, int>{};
      for (final participantId in chat.participants) {
        if (participantId != senderId) {
          unreadCount[participantId] = (chat.unreadCount[participantId] ?? 0) + 1;
        }
      }

      batch.update(_chatsCollection.doc(chatId), {
        'lastMessageId': messageId,
        'lastMessageContent': _getMessagePreview(type, content),
        'lastMessageTime': Timestamp.fromDate(now),
        'lastMessageSenderId': senderId,
        'updatedAt': Timestamp.fromDate(now),
        'unreadCount': unreadCount,
      });

      await batch.commit();
      return messageId;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get chat messages
  static Future<List<MessageModel>> getChatMessages(
    String chatId, {
    DocumentSnapshot? lastDocument,
    int limit = 50,
  }) async {
    try {
      Query query = _messagesCollection
          .where('chatId', isEqualTo: chatId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MessageModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get chat messages: $e');
    }
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final batch = _firestore.batch();

      // Update chat to reset unread count
      batch.update(_chatsCollection.doc(chatId), {
        'unreadCount.$userId': 0,
        'lastReadTime.$userId': Timestamp.fromDate(DateTime.now()),
      });

      // Mark recent unread messages as read
      final messagesSnapshot = await _messagesCollection
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isNotEqualTo: userId)
          .orderBy('senderId')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      for (final doc in messagesSnapshot.docs) {
        final message = MessageModel.fromSnapshot(doc);
        if (!message.hasUserRead(userId)) {
          batch.update(doc.reference, {
            'readBy.$userId': Timestamp.fromDate(DateTime.now()),
            'status': 'read',
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  // Add reaction to message
  static Future<void> addReaction(String messageId, String userId, String emoji) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'reactions.$emoji': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to add reaction: $e');
    }
  }

  // Remove reaction from message
  static Future<void> removeReaction(String messageId, String userId, String emoji) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'reactions.$emoji': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  // Delete message
  static Future<void> deleteMessage(String messageId, String userId, {bool forEveryone = false}) async {
    try {
      if (forEveryone) {
        // Delete for everyone (only sender can do this)
        await _messagesCollection.doc(messageId).update({
          'isDeleted': true,
          'deletedAt': Timestamp.fromDate(DateTime.now()),
          'content': 'This message was deleted',
        });
      } else {
        // Delete for self only
        await _messagesCollection.doc(messageId).update({
          'deletedFor': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Add member to group chat
  static Future<void> addMemberToGroup(String chatId, String memberId, String addedBy) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null || !chat.canUserAddMembers(addedBy)) {
        throw Exception('Permission denied or chat not found');
      }

      if (chat.participants.length >= 10) {
        throw Exception('Group chat is full (max 10 members)');
      }

      final newMember = await UserDatabaseService.getUserById(memberId);
      if (newMember == null) throw Exception('User not found');

      await _chatsCollection.doc(chatId).update({
        'participants': FieldValue.arrayUnion([memberId]),
        'participantNames.$memberId': newMember.handle,
        'participantAvatars.$memberId': newMember.profilePictureUrl ?? '',
        'memberRoles.$memberId': 'member',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  // Remove member from group chat
  static Future<void> removeMemberFromGroup(String chatId, String memberId, String removedBy) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null || !chat.canUserRemoveMembers(removedBy)) {
        throw Exception('Permission denied or chat not found');
      }

      if (chat.createdBy == memberId) {
        throw Exception('Cannot remove the group creator');
      }

      await _chatsCollection.doc(chatId).update({
        'participants': FieldValue.arrayRemove([memberId]),
        'participantNames.$memberId': FieldValue.delete(),
        'participantAvatars.$memberId': FieldValue.delete(),
        'memberRoles.$memberId': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  // Update group chat info
  static Future<void> updateGroupInfo(
    String chatId,
    String userId, {
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null || !chat.isUserAdmin(userId)) {
        throw Exception('Permission denied or chat not found');
      }

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

      await _chatsCollection.doc(chatId).update(updates);
    } catch (e) {
      throw Exception('Failed to update group info: $e');
    }
  }

  // Listen to chat messages stream
  static Stream<List<MessageModel>> listenToChatMessages(String chatId, {int limit = 50}) {
    return _messagesCollection
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromSnapshot(doc))
            .toList());
  }

  // Listen to user's chats stream
  static Stream<List<ChatModel>> listenToUserChats(String userId) {
    return _chatsCollection
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromSnapshot(doc))
            .toList());
  }

  // Listen to specific chat stream
  static Stream<ChatModel?> listenToChat(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ChatModel.fromSnapshot(snapshot);
    });
  }

  // Get message preview for different types
  static String _getMessagePreview(MessageType type, String content) {
    switch (type) {
      case MessageType.text:
        return content.length > 50 ? '${content.substring(0, 50)}...' : content;
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.snap:
        return '⚡ Snap';
      case MessageType.sticker:
        return '😀 Sticker';
      case MessageType.location:
        return '📍 Location';
      case MessageType.contact:
        return '👤 Contact';
    }
  }
} 