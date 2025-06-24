import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'user_database_service.dart';

class StoryDatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static final CollectionReference _storiesCollection = _firestore.collection('stories');
  static final CollectionReference _storyViewsCollection = _firestore.collection('story_views');

  // Create a new story
  static Future<String> createStory({
    required String uid,
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
    try {
      final user = await UserDatabaseService.getUserById(uid);
      if (user == null) throw Exception('User not found');

      final now = DateTime.now();
      final expiresAt = now.add(Duration(hours: 24)); // 24-hour TTL
      
      final storyId = _storiesCollection.doc().id;
      final story = StoryModel(
        id: storyId,
        uid: uid,
        creatorUsername: user.username,
        creatorProfilePicture: user.profilePictureUrl,
        type: type,
        visibility: visibility,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        createdAt: now,
        expiresAt: expiresAt,
        filters: filters,
        isEncrypted: isEncrypted,
        encryptedKey: encryptedKey,
        allowedViewers: allowedViewers,
      );

      final batch = _firestore.batch();
      
      // Create story document
      batch.set(_storiesCollection.doc(storyId), story.toMap());
      
      // Update user's stories count
      batch.update(_firestore.collection('users').doc(uid), {
        'storiesCount': FieldValue.increment(1),
      });
      
      await batch.commit();
      
      return storyId;
    } catch (e) {
      throw Exception('Failed to create story: $e');
    }
  }

  // Get story by ID
  static Future<StoryModel?> getStoryById(String storyId) async {
    try {
      final doc = await _storiesCollection.doc(storyId).get();
      if (!doc.exists) return null;
      return StoryModel.fromSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get story: $e');
    }
  }

  // Get public stories (Explore feed)
  static Future<List<StoryModel>> getPublicStories({
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = _storiesCollection
          .where('visibility', isEqualTo: 'public')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => StoryModel.fromSnapshot(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get public stories: $e');
    }
  }

  // Get friends' stories (Friends feed)
  static Future<List<StoryModel>> getFriendsStories(
    String userId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      final user = await UserDatabaseService.getUserById(userId);
      if (user == null || user.friends.isEmpty) return [];

      Query query = _storiesCollection
          .where('uid', whereIn: user.friends)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final stories = snapshot.docs.map((doc) => StoryModel.fromSnapshot(doc)).toList();
      
      // Filter out stories that user can't view
      return stories.where((story) => story.canUserView(userId)).toList();
    } catch (e) {
      throw Exception('Failed to get friends stories: $e');
    }
  }

  // Get user's own stories
  static Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      final snapshot = await _storiesCollection
          .where('uid', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => StoryModel.fromSnapshot(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get user stories: $e');
    }
  }

  // View a story
  static Future<void> viewStory(String storyId, String viewerId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null || story.isExpired) return;
      
      if (story.hasUserViewed(viewerId)) return; // Already viewed
      
      final batch = _firestore.batch();
      
      // Update story document
      batch.update(_storiesCollection.doc(storyId), {
        'viewedBy': FieldValue.arrayUnion([viewerId]),
        'viewCount': FieldValue.increment(1),
      });
      
      // Create view record for analytics
      final viewId = '${storyId}_${viewerId}';
      batch.set(_storyViewsCollection.doc(viewId), {
        'storyId': storyId,
        'viewerId': viewerId,
        'viewedAt': Timestamp.fromDate(DateTime.now()),
        'storyCreatorId': story.uid,
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to view story: $e');
    }
  }

  // Like a story
  static Future<void> likeStory(String storyId, String userId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null || story.isExpired) return;
      
      if (story.hasUserLiked(userId)) {
        // Unlike
        await _storiesCollection.doc(storyId).update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        await _storiesCollection.doc(storyId).update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw Exception('Failed to like story: $e');
    }
  }

  // Share a story (increment share count)
  static Future<void> shareStory(String storyId) async {
    try {
      await _storiesCollection.doc(storyId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to share story: $e');
    }
  }

  // Delete a story
  static Future<void> deleteStory(String storyId, String userId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null) return;
      
      // Only the creator can delete their story
      if (story.uid != userId) {
        throw Exception('You can only delete your own stories');
      }
      
      final batch = _firestore.batch();
      
      // Delete story document
      batch.delete(_storiesCollection.doc(storyId));
      
      // Update user's stories count
      batch.update(_firestore.collection('users').doc(userId), {
        'storiesCount': FieldValue.increment(-1),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete story: $e');
    }
  }

  // Get story viewers
  static Future<List<UserModel>> getStoryViewers(String storyId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null || story.viewedBy.isEmpty) return [];
      
      return await UserDatabaseService.getUsersByIds(story.viewedBy);
    } catch (e) {
      throw Exception('Failed to get story viewers: $e');
    }
  }

  // Get story likes
  static Future<List<UserModel>> getStoryLikes(String storyId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null || story.likedBy.isEmpty) return [];
      
      return await UserDatabaseService.getUsersByIds(story.likedBy);
    } catch (e) {
      throw Exception('Failed to get story likes: $e');
    }
  }

  // Clean up expired stories (usually called by a cloud function)
  static Future<void> cleanupExpiredStories() async {
    try {
      final now = DateTime.now();
      final expiredSnapshot = await _storiesCollection
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      if (expiredSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      
      for (final doc in expiredSnapshot.docs) {
        final story = StoryModel.fromSnapshot(doc);
        
        // Delete story document
        batch.delete(doc.reference);
        
        // Update user's stories count
        batch.update(_firestore.collection('users').doc(story.uid), {
          'storiesCount': FieldValue.increment(-1),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cleanup expired stories: $e');
    }
  }

  // Search stories by caption or creator
  static Future<List<StoryModel>> searchStories(String query, String userId) async {
    try {
      if (query.isEmpty) return [];
      
      // Search public stories by caption
      final captionSnapshot = await _storiesCollection
          .where('visibility', isEqualTo: 'public')
          .where('caption', isGreaterThanOrEqualTo: query)
          .where('caption', isLessThanOrEqualTo: query + '\uf8ff')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .limit(20)
          .get();

      // Search by creator username
      final creatorSnapshot = await _storiesCollection
          .where('visibility', isEqualTo: 'public')
          .where('creatorUsername', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('creatorUsername', isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .limit(20)
          .get();

      final stories = <StoryModel>[];
      final storyIds = <String>{};
      
      // Combine results and avoid duplicates
      for (final doc in [...captionSnapshot.docs, ...creatorSnapshot.docs]) {
        final story = StoryModel.fromSnapshot(doc);
        if (!storyIds.contains(story.id) && story.canUserView(userId)) {
          stories.add(story);
          storyIds.add(story.id);
        }
      }
      
      return stories;
    } catch (e) {
      throw Exception('Failed to search stories: $e');
    }
  }

  // Listen to public stories stream
  static Stream<List<StoryModel>> listenToPublicStories({int limit = 20}) {
    return _storiesCollection
        .where('visibility', isEqualTo: 'public')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StoryModel.fromSnapshot(doc))
            .toList());
  }

  // Listen to friends' stories stream
  static Stream<List<StoryModel>> listenToFriendsStories(String userId, {int limit = 20}) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userSnapshot) async {
      if (!userSnapshot.exists) return <StoryModel>[];
      
      final user = UserModel.fromSnapshot(userSnapshot);
      if (user.friends.isEmpty) return <StoryModel>[];

      final snapshot = await _storiesCollection
          .where('uid', whereIn: user.friends)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final stories = snapshot.docs.map((doc) => StoryModel.fromSnapshot(doc)).toList();
      return stories.where((story) => story.canUserView(userId)).toList();
    });
  }

  // Listen to user's own stories stream
  static Stream<List<StoryModel>> listenToUserStories(String userId) {
    return _storiesCollection
        .where('uid', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StoryModel.fromSnapshot(doc))
            .toList());
  }

  // Get story analytics (for creator)
  static Future<Map<String, dynamic>> getStoryAnalytics(String storyId, String creatorId) async {
    try {
      final story = await getStoryById(storyId);
      if (story == null || story.uid != creatorId) {
        throw Exception('Story not found or access denied');
      }

      // Get view details
      final viewsSnapshot = await _storyViewsCollection
          .where('storyId', isEqualTo: storyId)
          .orderBy('viewedAt', descending: true)
          .get();

      final viewers = await UserDatabaseService.getUsersByIds(story.viewedBy);
      final likers = await UserDatabaseService.getUsersByIds(story.likedBy);

      return {
        'story': story,
        'totalViews': story.viewCount,
        'totalLikes': story.likeCount,
        'totalShares': story.shareCount,
        'viewers': viewers,
        'likers': likers,
        'viewDetails': viewsSnapshot.docs.map((doc) => doc.data()).toList(),
        'engagementRate': story.viewCount > 0 
            ? (story.likeCount / story.viewCount * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      throw Exception('Failed to get story analytics: $e');
    }
  }
} 