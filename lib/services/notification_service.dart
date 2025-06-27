import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';
import 'chat_database_service.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream to listen to unread message count for current user
  static Stream<int> getUnreadMessageCountStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          int totalUnread = 0;
          for (final doc in snapshot.docs) {
            final chat = ChatModel.fromSnapshot(doc);
            totalUnread += chat.getUnreadCount(userId);
          }
          return totalUnread;
        });
  }
  
  // Get total unread count for user
  static Future<int> getUnreadMessageCount(String userId) async {
    if (userId.isEmpty) return 0;
    
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final chat = ChatModel.fromSnapshot(doc);
        totalUnread += chat.getUnreadCount(userId);
      }
      return totalUnread;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
  
  // Mark all messages as read for a specific chat
  static Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      await ChatDatabaseService.markMessagesAsRead(chatId, userId);
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }
  
  // Mark all messages as read for all user's chats
  static Future<void> markAllChatsAsRead(String userId) async {
    try {
      final chats = await ChatDatabaseService.getUserChats(userId);
      for (final chat in chats) {
        if (chat.getUnreadCount(userId) > 0) {
          await ChatDatabaseService.markMessagesAsRead(chat.id, userId);
        }
      }
    } catch (e) {
      print('Error marking all chats as read: $e');
    }
  }
}

// Riverpod providers for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final unreadMessageCountProvider = StreamProvider<int>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.user?.uid ?? '';
  return NotificationService.getUnreadMessageCountStream(userId);
});

final unreadMessageCountFutureProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.user?.uid ?? '';
  return await NotificationService.getUnreadMessageCount(userId);
}); 