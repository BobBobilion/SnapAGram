import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/user_model.dart';

class UserDatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  static final CollectionReference _usersCollection = _firestore.collection('users');
  static final CollectionReference _handlesCollection = _firestore.collection('handles');

  // Generate a unique handle from display name
  static String _generateHandleFromName(String displayName) {
    // Convert to lowercase and replace spaces with hyphens
    String baseHandle = displayName.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Remove special characters except spaces and hyphens
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-') // Replace multiple hyphens with single hyphen
        .trim();
    
    // Remove leading/trailing hyphens
    baseHandle = baseHandle.replaceAll(RegExp(r'^-+|-+$'), '');
    
    // If empty after cleaning, use 'user'
    if (baseHandle.isEmpty) {
      baseHandle = 'user';
    }
    
    return baseHandle;
  }

  // Generate a unique handle with random numbers
  static Future<String> generateUniqueHandle(String displayName, {String? excludeUserId}) async {
    String baseHandle = _generateHandleFromName(displayName);
    String handle = '@$baseHandle';
    
    // Check if base handle is available
    if (await isHandleAvailable(handle, excludeUserId: excludeUserId)) {
      return handle;
    }
    
    // Try with random numbers
    final random = Random();
    int attempts = 0;
    const maxAttempts = 100;
    
    while (attempts < maxAttempts) {
      int randomNumber = random.nextInt(9999) + 1; // 1-9999
      handle = '@$baseHandle-$randomNumber';
      
      if (await isHandleAvailable(handle, excludeUserId: excludeUserId)) {
        return handle;
      }
      
      attempts++;
    }
    
    // If still not available, use timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    handle = '@$baseHandle-$timestamp';
    
    return handle;
  }

  // Check if handle is available
  static Future<bool> isHandleAvailable(String handle, {String? excludeUserId}) async {
    try {
      final doc = await _handlesCollection.doc(handle.toLowerCase()).get();
      if (!doc.exists) return true;
      
      // If we're excluding a specific user, check if this handle belongs to them
      if (excludeUserId != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['uid'] == excludeUserId) {
          return true; // Handle belongs to the current user, so it's available
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Create user profile after authentication
  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    String? profilePictureUrl,
  }) async {
    try {
      // Generate unique handle
      final handle = await generateUniqueHandle(displayName);

      final now = DateTime.now();
      final user = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        handle: handle,
        profilePictureUrl: profilePictureUrl,
        createdAt: now,
        lastSeen: now,
        isOnline: true,
      );

      // Use batch write for atomic operation
      final batch = _firestore.batch();
      
      // Create user document
      batch.set(_usersCollection.doc(uid), user.toMap());

      // Reserve handle
      batch.set(_handlesCollection.doc(handle.toLowerCase()), {
        'uid': uid,
        'createdAt': Timestamp.fromDate(now),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Get user by UID
  static Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Get user by handle
  static Future<UserModel?> getUserByHandle(String handle) async {
    try {
      // Remove all leading @ and prepend a single @
      String cleanHandle = handle.replaceFirst(RegExp(r'^@+'), '');
      cleanHandle = '@$cleanHandle';
      
      final handleDoc = await _handlesCollection.doc(cleanHandle.toLowerCase()).get();
      if (!handleDoc.exists) return null;
      
      final data = handleDoc.data() as Map<String, dynamic>;
      return await getUserById(data['uid']);
    } catch (e) {
      throw Exception('Failed to get user by handle: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _usersCollection.doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update online status
  static Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _usersCollection.doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update online status: $e');
    }
  }

  // Search users by handle and display name
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      
      // Convert query to lowercase for case-insensitive search
      String lowerQuery = query.toLowerCase();
      // Remove all leading @ and prepend a single @
      String handleQuery = '@' + lowerQuery.replaceFirst(RegExp(r'^@+'), '');
      print('[DEBUG] Searching for handle prefix: $handleQuery');
      final handleQuerySnapshot = await _usersCollection
          .where('handle', isGreaterThanOrEqualTo: handleQuery)
          .where('handle', isLessThanOrEqualTo: handleQuery + '\uf8ff')
          .limit(20)
          .get();

      print('[DEBUG] Firestore returned ${handleQuerySnapshot.docs.length} docs for handle prefix search');

      List<UserModel> results = handleQuerySnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();

      // If we don't have enough results, also search by display name
      if (results.length < 10) {
        final displayNameQuery = await _usersCollection
            .where('displayName', isGreaterThanOrEqualTo: lowerQuery)
            .where('displayName', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
            .limit(10)
            .get();

        print('[DEBUG] Firestore returned ${displayNameQuery.docs.length} docs for displayName prefix search');

        final displayNameResults = displayNameQuery.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .toList();

        // Combine results and remove duplicates
        for (final user in displayNameResults) {
          if (!results.any((existing) => existing.uid == user.uid)) {
            results.add(user);
          }
        }
      }

      print('[DEBUG] Returning ${results.length} total search results');
      return results;
    } catch (e) {
      print('[DEBUG] Exception in searchUsers: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Get all users (for debugging)
  static Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _usersCollection
          .orderBy('handle')
          .limit(100)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  // Get all handles (for debugging)
  static Future<List<String>> getAllHandles() async {
    try {
      final querySnapshot = await _usersCollection
          .orderBy('handle')
          .limit(100)
          .get();

      return querySnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['handle'] as String)
          .toList();
    } catch (e) {
      throw Exception('Failed to get all handles: $e');
    }
  }

  // Get all users with handle and display name (for debugging)
  static Future<List<Map<String, String>>> getAllUserIdentifiers() async {
    try {
      final querySnapshot = await _usersCollection
          .orderBy('handle')
          .limit(100)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'handle': data['handle'] as String,
          'displayName': data['displayName'] as String,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all user identifiers: $e');
    }
  }

  // Send friend request
  static Future<void> sendFriendRequest(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to current user's sent requests
      batch.update(_usersCollection.doc(currentUserId), {
        'sentRequests': FieldValue.arrayUnion([targetUserId])
      });
      
      // Add to target user's friend requests
      batch.update(_usersCollection.doc(targetUserId), {
        'friendRequests': FieldValue.arrayUnion([currentUserId])
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  // Accept friend request
  static Future<void> acceptFriendRequest(String currentUserId, String fromUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Update current user
      batch.update(_usersCollection.doc(currentUserId), {
        'friends': FieldValue.arrayUnion([fromUserId]),
        'friendRequests': FieldValue.arrayRemove([fromUserId]),
        'friendsCount': FieldValue.increment(1),
      });
      
      // Update friend user
      batch.update(_usersCollection.doc(fromUserId), {
        'friends': FieldValue.arrayUnion([currentUserId]),
        'sentRequests': FieldValue.arrayRemove([currentUserId]),
        'friendsCount': FieldValue.increment(1),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  // Reject friend request
  static Future<void> rejectFriendRequest(String currentUserId, String fromUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Remove from current user's friend requests
      batch.update(_usersCollection.doc(currentUserId), {
        'friendRequests': FieldValue.arrayRemove([fromUserId])
      });
      
      // Remove from friend user's sent requests
      batch.update(_usersCollection.doc(fromUserId), {
        'sentRequests': FieldValue.arrayRemove([currentUserId])
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reject friend request: $e');
    }
  }

  // Remove friend
  static Future<void> removeFriend(String currentUserId, String friendId) async {
    try {
      final batch = _firestore.batch();
      
      // Update current user
      batch.update(_usersCollection.doc(currentUserId), {
        'friends': FieldValue.arrayRemove([friendId]),
        'friendsCount': FieldValue.increment(-1),
      });
      
      // Update friend user
      batch.update(_usersCollection.doc(friendId), {
        'friends': FieldValue.arrayRemove([currentUserId]),
        'friendsCount': FieldValue.increment(-1),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove friend: $e');
    }
  }

  // Block user
  static Future<void> blockUser(String currentUserId, String userIdToBlock) async {
    try {
      final batch = _firestore.batch();
      
      // Add to blocked users
      batch.update(_usersCollection.doc(currentUserId), {
        'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
        'friends': FieldValue.arrayRemove([userIdToBlock]),
        'friendRequests': FieldValue.arrayRemove([userIdToBlock]),
        'sentRequests': FieldValue.arrayRemove([userIdToBlock]),
      });
      
      // Remove from blocked user's friends and requests
      batch.update(_usersCollection.doc(userIdToBlock), {
        'friends': FieldValue.arrayRemove([currentUserId]),
        'friendRequests': FieldValue.arrayRemove([currentUserId]),
        'sentRequests': FieldValue.arrayRemove([currentUserId]),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  // Get user's friends
  static Future<List<UserModel>> getUserFriends(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null || user.friends.isEmpty) return [];
      
      final friendsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.friends)
          .get();
      
      return friendsSnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user friends: $e');
    }
  }

  // Get friend requests
  static Future<List<UserModel>> getFriendRequests(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null || user.friendRequests.isEmpty) return [];
      
      final requestsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.friendRequests)
          .get();
      
      return requestsSnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get friend requests: $e');
    }
  }

  // Get multiple users by IDs
  static Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];
      
      final snapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: userIds)
          .get();
      
      return snapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users by IDs: $e');
    }
  }

  // Listen to user changes
  static Stream<UserModel?> listenToUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromSnapshot(snapshot);
    });
  }

  // Listen to friends updates
  static Stream<List<UserModel>> listenToFriends(String userId) {
    return _usersCollection.doc(userId).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return [];
      
      final user = UserModel.fromSnapshot(snapshot);
      if (user.friends.isEmpty) return [];
      
      final friendsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.friends)
          .get();
      
      return friendsSnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    });
  }

  // Update notification settings
  static Future<void> updateNotificationSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _usersCollection.doc(userId).update({
        'notificationSettings': settings,
      });
    } catch (e) {
      throw Exception('Failed to update notification settings: $e');
    }
  }

  // Update privacy settings
  static Future<void> updatePrivacySettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _usersCollection.doc(userId).update({
        'privacySettings': settings,
      });
    } catch (e) {
      throw Exception('Failed to update privacy settings: $e');
    }
  }

  // Update handle
  static Future<void> updateHandle(String userId, String newHandle) async {
    try {
      // Add @ symbol if not present
      String fullHandle = newHandle.startsWith('@') ? newHandle : '@$newHandle';
      
      if (!await isHandleAvailable(fullHandle, excludeUserId: userId)) {
        throw Exception('Handle is already taken');
      }
      
      final user = await getUserById(userId);
      if (user == null) throw Exception('User not found');
      
      final batch = _firestore.batch();
      
      // Remove old handle
      batch.delete(_handlesCollection.doc(user.handle.toLowerCase()));
      
      // Add new handle
      batch.set(_handlesCollection.doc(fullHandle.toLowerCase()), {
        'uid': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Update user document
      batch.update(_usersCollection.doc(userId), {
        'handle': fullHandle,
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update handle: $e');
    }
  }

  // Fix friends count by recalculating from friends array
  static Future<void> fixFriendsCount(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return;
      
      final actualFriendsCount = user.friends.length;
      
      if (actualFriendsCount != user.friendsCount) {
        await _usersCollection.doc(userId).update({
          'friendsCount': actualFriendsCount,
        });
        print('Fixed friends count for user $userId: was ${user.friendsCount}, now $actualFriendsCount');
      }
    } catch (e) {
      throw Exception('Failed to fix friends count: $e');
    }
  }

  // Fix friends count for all users (admin function)
  static Future<void> fixAllFriendsCounts() async {
    try {
      final usersSnapshot = await _usersCollection.get();
      
      for (final doc in usersSnapshot.docs) {
        final user = UserModel.fromSnapshot(doc);
        final actualFriendsCount = user.friends.length;
        
        if (actualFriendsCount != user.friendsCount) {
          await _usersCollection.doc(user.uid).update({
            'friendsCount': actualFriendsCount,
          });
          print('Fixed friends count for user ${user.uid}: was ${user.friendsCount}, now $actualFriendsCount');
        }
      }
    } catch (e) {
      throw Exception('Failed to fix all friends counts: $e');
    }
  }

  // Migrate existing user to have a handle (for backward compatibility)
  static Future<void> migrateUserToHandle(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) throw Exception('User not found');
      
      // If user already has a handle, no need to migrate
      if (user.handle.isNotEmpty) return;
      
      // Generate handle from display name
      final handle = await generateUniqueHandle(user.displayName);
      
      final batch = _firestore.batch();
      
      // Add handle to user document
      batch.update(_usersCollection.doc(userId), {
        'handle': handle,
      });
      
      // Reserve handle
      batch.set(_handlesCollection.doc(handle.toLowerCase()), {
        'uid': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to migrate user to handle: $e');
    }
  }
} 