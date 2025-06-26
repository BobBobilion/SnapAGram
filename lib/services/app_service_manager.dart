import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/story_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'auth_service.dart';
import 'user_database_service.dart';
import 'story_database_service.dart';
import 'chat_database_service.dart';
import 'storage_service.dart';

final appServiceManagerProvider = Provider<AppServiceManager>((ref) {
  return AppServiceManager(ref);
});

/// Centralized service manager for the SnapAGram app
/// Provides easy access to all backend services and manages app-wide operations
class AppServiceManager extends ChangeNotifier {
  final ProviderRef ref;

  AppServiceManager(this.ref);

  // Getters for services
  AuthService get auth => ref.read(authServiceProvider);
  
  // Current user shortcuts
  UserModel? get currentUser => auth.userModel;
  String? get currentUserId => auth.user?.uid;
  bool get isAuthenticated => auth.isAuthenticated;

  // Initialize the service manager
  Future<void> initialize() async {
    try {
      // Listen to auth changes
      auth.addListener(_onAuthStateChanged);
      
      print('AppServiceManager: Initialized successfully');
    } catch (e) {
      print('AppServiceManager: Failed to initialize - $e');
      throw Exception('Failed to initialize app services: $e');
    }
  }

  void _onAuthStateChanged() {
    notifyListeners();
  }

  // Dispose resources
  @override
  void dispose() {
    auth.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  // User Operations
  Future<List<UserModel>> searchUsers(String query) async {
    return await UserDatabaseService.searchUsers(query);
  }

  Future<List<UserModel>> getAllUsers() async {
    return await UserDatabaseService.getAllUsers();
  }

  Future<List<String>> getAllHandles() async {
    return await UserDatabaseService.getAllHandles();
  }

  Future<List<Map<String, String>>> getAllUserIdentifiers() async {
    return await UserDatabaseService.getAllUserIdentifiers();
  }

  Future<UserModel?> getUserById(String userId) async {
    return await UserDatabaseService.getUserById(userId);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    return await UserDatabaseService.getUserByHandle(username);
  }

  Future<List<UserModel>> getCurrentUserConnections() async {
    if (currentUserId == null) return [];
    return await UserDatabaseService.getUserConnections(currentUserId!);
  }

  Future<List<UserModel>> getConnectionRequests() async {
    if (currentUserId == null) return [];
    return await UserDatabaseService.getConnectionRequests(currentUserId!);
  }

  Future<void> sendConnectionRequest(String targetUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.sendConnectionRequest(currentUserId!, targetUserId);
  }

  Future<void> acceptConnectionRequest(String fromUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.acceptConnectionRequest(currentUserId!, fromUserId);
  }

  Future<void> rejectConnectionRequest(String fromUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.rejectConnectionRequest(currentUserId!, fromUserId);
  }

  Future<void> removeConnection(String connectionId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.removeConnection(currentUserId!, connectionId);
  }

  // Legacy methods for backward compatibility
  @deprecated
  Future<List<UserModel>> getCurrentUserFriends() async {
    return getCurrentUserConnections();
  }

  @deprecated
  Future<List<UserModel>> getFriendRequests() async {
    return getConnectionRequests();
  }

  @deprecated
  Future<void> sendFriendRequest(String targetUserId) async {
    return sendConnectionRequest(targetUserId);
  }

  @deprecated
  Future<void> acceptFriendRequest(String fromUserId) async {
    return acceptConnectionRequest(fromUserId);
  }

  @deprecated
  Future<void> rejectFriendRequest(String fromUserId) async {
    return rejectConnectionRequest(fromUserId);
  }

  @deprecated
  Future<void> removeFriend(String friendId) async {
    return removeConnection(friendId);
  }

  Future<void> blockUser(String userIdToBlock) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.blockUser(currentUserId!, userIdToBlock);
  }

  Future<void> fixConnectionsCount(String userId) async {
    await UserDatabaseService.fixConnectionsCount(userId);
  }

  Future<void> fixAllConnectionsCounts() async {
    await UserDatabaseService.fixAllConnectionsCounts();
  }

  // Legacy methods for backward compatibility
  @deprecated
  Future<void> fixFriendsCount(String userId) async {
    return fixConnectionsCount(userId);
  }

  @deprecated
  Future<void> fixAllFriendsCounts() async {
    return fixAllConnectionsCounts();
  }

  // Story Operations
  Future<String> createStory({
    required StoryType type,
    required StoryVisibility visibility,
    required String mediaUrl,
    String? thumbnailUrl,
    String? caption,
    Map<String, dynamic> filters = const {},
    bool isEncrypted = false,
    String? encryptedKey,
    List<String> allowedViewers = const [],
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    String finalMediaUrl = mediaUrl;
    
    // If mediaUrl is a local file path, upload it to Firebase Storage first
    if (!mediaUrl.startsWith('http')) {
      try {
        print('AppServiceManager: Uploading local image to Firebase Storage...');
        final File imageFile = File(mediaUrl);
        
        if (await imageFile.exists()) {
          finalMediaUrl = await StorageService.uploadStoryImage(imageFile, currentUserId!);
          print('AppServiceManager: Image uploaded successfully - $finalMediaUrl');
          
          // Clean up local file after successful upload
          try {
            await imageFile.delete();
            print('AppServiceManager: Local image file deleted');
          } catch (e) {
            print('AppServiceManager: Warning - Could not delete local file: $e');
          }
        } else {
          throw Exception('Local image file does not exist: $mediaUrl');
        }
      } catch (e) {
        print('AppServiceManager: Failed to upload image - $e');
        throw Exception('Failed to upload image: $e');
      }
    }
    
    return await StoryDatabaseService.createStory(
      uid: currentUserId!,
      type: type,
      visibility: visibility,
      mediaUrl: finalMediaUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      filters: filters,
      isEncrypted: isEncrypted,
      encryptedKey: encryptedKey,
      allowedViewers: allowedViewers,
    );
  }
  
  /// Create story directly from file (convenience method)
  Future<String> createStoryFromFile({
    required File imageFile,
    required StoryType type,
    required StoryVisibility visibility,
    String? caption,
    Map<String, dynamic> filters = const {},
    bool isEncrypted = false,
    String? encryptedKey,
    List<String> allowedViewers = const [],
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      print('AppServiceManager: Creating story from file...');
      
      // Upload image to Firebase Storage
      final String mediaUrl = await StorageService.uploadStoryImage(imageFile, currentUserId!);
      print('AppServiceManager: Image uploaded successfully - $mediaUrl');
      
      // Create story with the uploaded URL
      final String storyId = await StoryDatabaseService.createStory(
        uid: currentUserId!,
        type: type,
        visibility: visibility,
        mediaUrl: mediaUrl,
        caption: caption,
        filters: filters,
        isEncrypted: isEncrypted,
        encryptedKey: encryptedKey,
        allowedViewers: allowedViewers,
      );
      
      // Clean up local file after successful story creation
      try {
        await imageFile.delete();
        print('AppServiceManager: Local image file deleted');
      } catch (e) {
        print('AppServiceManager: Warning - Could not delete local file: $e');
      }
      
      return storyId;
    } catch (e) {
      print('AppServiceManager: Failed to create story from file - $e');
      throw Exception('Failed to create story: $e');
    }
  }

  Future<List<StoryModel>> getPublicStories({int limit = 20}) async {
    return await StoryDatabaseService.getPublicStories(userId: currentUserId, limit: limit);
  }

  Future<List<StoryModel>> getFriendsStories({int limit = 20}) async {
    if (currentUserId == null) return [];
    return await StoryDatabaseService.getFriendsStories(currentUserId!, limit: limit);
  }

  Future<List<StoryModel>> getCurrentUserStories() async {
    if (currentUserId == null) return [];
    return await StoryDatabaseService.getUserStories(currentUserId!);
  }

  Future<void> viewStory(String storyId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await StoryDatabaseService.viewStory(storyId, currentUserId!);
  }

  Future<void> likeStory(String storyId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await StoryDatabaseService.likeStory(storyId, currentUserId!);
  }

  Future<void> shareStory(String storyId) async {
    await StoryDatabaseService.shareStory(storyId);
  }

  Future<void> updateStoryCaption(String storyId, String caption) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await StoryDatabaseService.updateStoryCaption(storyId, currentUserId!, caption);
  }

  Future<void> updateStoryVisibility(String storyId, StoryVisibility visibility) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await StoryDatabaseService.updateStoryVisibility(storyId, currentUserId!, visibility);
  }

  Future<void> deleteStory(String storyId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      // Get the story first to obtain the media URL
      final story = await StoryDatabaseService.getStoryById(storyId);
      
      // Delete from database first
      await StoryDatabaseService.deleteStory(storyId, currentUserId!);
      
      // Then delete the image from Firebase Storage if it exists
      if (story != null && story.mediaUrl.startsWith('http')) {
        try {
          await StorageService.deleteFile(story.mediaUrl);
          print('AppServiceManager: Story image deleted from storage');
        } catch (e) {
          print('AppServiceManager: Warning - Could not delete image from storage: $e');
          // Don't fail the whole operation if storage deletion fails
        }
      }
    } catch (e) {
      print('AppServiceManager: Failed to delete story - $e');
      throw Exception('Failed to delete story: $e');
    }
  }

  Future<List<StoryModel>> searchStories(String query) async {
    if (currentUserId == null) return [];
    return await StoryDatabaseService.searchStories(query, currentUserId!);
  }

  // Chat Operations
  Future<String> createDirectChat(String otherUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    return await ChatDatabaseService.createDirectChat(currentUserId!, otherUserId);
  }

  Future<String> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? description,
    String? avatarUrl,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    return await ChatDatabaseService.createGroupChat(
      creatorId: currentUserId!,
      name: name,
      participantIds: participantIds,
      description: description,
      avatarUrl: avatarUrl,
    );
  }

  Future<List<ChatModel>> getCurrentUserChats() async {
    if (currentUserId == null) return [];
    return await ChatDatabaseService.getUserChats(currentUserId!);
  }

  Future<ChatModel?> getChatById(String chatId) async {
    return await ChatDatabaseService.getChatById(chatId);
  }

  Future<String> sendMessage({
    required String chatId,
    required MessageType type,
    required String content,
    String? thumbnailUrl,
    DateTime? expiresAt,
    String? replyToMessageId,
    bool allowScreenshot = true,
    bool deleteAfterView = false,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    return await ChatDatabaseService.sendMessage(
      chatId: chatId,
      senderId: currentUserId!,
      type: type,
      content: content,
      thumbnailUrl: thumbnailUrl,
      expiresAt: expiresAt,
      replyToMessageId: replyToMessageId,
      allowScreenshot: allowScreenshot,
      deleteAfterView: deleteAfterView,
    );
  }

  Future<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) async {
    return await ChatDatabaseService.getChatMessages(chatId, limit: limit);
  }

  Future<void> markMessagesAsRead(String chatId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.markMessagesAsRead(chatId, currentUserId!);
  }

  Future<void> addReactionToMessage(String messageId, String emoji) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.addReaction(messageId, currentUserId!, emoji);
  }

  Future<void> removeReactionFromMessage(String messageId, String emoji) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.removeReaction(messageId, currentUserId!, emoji);
  }

  Future<void> deleteMessage(String messageId, {bool forEveryone = false}) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.deleteMessage(messageId, currentUserId!, forEveryone: forEveryone);
  }

  Future<void> addMemberToGroup(String chatId, String memberId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.addMemberToGroup(chatId, memberId, currentUserId!);
  }

  Future<void> removeMemberFromGroup(String chatId, String memberId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.removeMemberFromGroup(chatId, memberId, currentUserId!);
  }

  Future<void> updateGroupInfo(
    String chatId, {
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await ChatDatabaseService.updateGroupInfo(
      chatId,
      currentUserId!,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
    );
  }

  // Stream subscriptions for real-time updates
  Stream<UserModel?> get currentUserStream {
    return auth.userStream;
  }

  Stream<List<UserModel>> getCurrentUserConnectionsStream() {
    if (currentUserId == null) return Stream.value([]);
    return UserDatabaseService.listenToConnections(currentUserId!);
  }

  @deprecated
  Stream<List<UserModel>> getCurrentUserFriendsStream() {
    return getCurrentUserConnectionsStream();
  }

  Stream<List<StoryModel>> getPublicStoriesStream({int limit = 20}) {
    return StoryDatabaseService.listenToPublicStories(limit: limit);
  }

  Stream<List<StoryModel>> getFriendsStoriesStream({int limit = 20}) {
    if (currentUserId == null) return Stream.value([]);
    return StoryDatabaseService.listenToFriendsStories(currentUserId!, limit: limit);
  }

  Stream<List<StoryModel>> getCurrentUserStoriesStream() {
    if (currentUserId == null) return Stream.value([]);
    return StoryDatabaseService.listenToUserStories(currentUserId!);
  }

  Stream<List<ChatModel>> getCurrentUserChatsStream() {
    if (currentUserId == null) return Stream.value([]);
    return ChatDatabaseService.listenToUserChats(currentUserId!);
  }

  Stream<List<MessageModel>> getChatMessagesStream(String chatId, {int limit = 50}) {
    return ChatDatabaseService.listenToChatMessages(chatId, limit: limit);
  }

  Stream<ChatModel?> getChatStream(String chatId) {
    return ChatDatabaseService.listenToChat(chatId);
  }

  // Settings Operations
  Future<void> updateNotificationSettings(Map<String, dynamic> settings) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.updateNotificationSettings(currentUserId!, settings);
  }

  Future<void> updatePrivacySettings(Map<String, dynamic> settings) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    await UserDatabaseService.updatePrivacySettings(currentUserId!, settings);
  }

  // Utility Methods
  bool canUserViewStory(StoryModel story) {
    if (currentUserId == null) return false;
    return story.canUserView(currentUserId!);
  }

  bool hasUserViewedStory(StoryModel story) {
    if (currentUserId == null) return false;
    return story.hasUserViewed(currentUserId!);
  }

  bool hasUserLikedStory(StoryModel story) {
    if (currentUserId == null) return false;
    return story.hasUserLiked(currentUserId!);
  }

  bool isCurrentUserConnected(String userId) {
    return currentUser?.connections.contains(userId) ?? false;
  }

  bool hasReceivedConnectionRequestFrom(String userId) {
    return currentUser?.connectionRequests.contains(userId) ?? false;
  }

  // Legacy methods for backward compatibility
  @deprecated
  bool isCurrentUserFriend(String userId) {
    return isCurrentUserConnected(userId);
  }

  @deprecated
  bool hasReceivedFriendRequestFrom(String userId) {
    return hasReceivedConnectionRequestFrom(userId);
  }

  bool hasSentFriendRequestTo(String userId) {
    return currentUser?.sentRequests.contains(userId) ?? false;
  }

  bool hasBlockedUser(String userId) {
    return currentUser?.blockedUsers.contains(userId) ?? false;
  }

  // App lifecycle methods
  Future<void> onAppResume() async {
    if (currentUserId != null) {
      await UserDatabaseService.updateOnlineStatus(currentUserId!, true);
    }
  }

  Future<void> onAppPause() async {
    if (currentUserId != null) {
      await UserDatabaseService.updateOnlineStatus(currentUserId!, false);
    }
  }
} 