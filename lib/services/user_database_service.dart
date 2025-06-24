import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserDatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  static final CollectionReference _usersCollection = _firestore.collection('users');
  static final CollectionReference _usernamesCollection = _firestore.collection('usernames');

  // Create user profile after authentication
  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String username,
    String? profilePictureUrl,
  }) async {
    try {
      // Check if username is available
      if (!await _isUsernameAvailable(username)) {
        throw Exception('Username is already taken');
      }

      final now = DateTime.now();
      final user = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        username: username,
        profilePictureUrl: profilePictureUrl,
        createdAt: now,
        lastSeen: now,
        isOnline: true,
      );

      // Use batch write for atomic operation
      final batch = _firestore.batch();
      
      // Create user document
      batch.set(_usersCollection.doc(uid), user.toMap());
      
      // Reserve username
      batch.set(_usernamesCollection.doc(username.toLowerCase()), {
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

  // Get user by username
  static Future<UserModel?> getUserByUsername(String username) async {
    try {
      final usernameDoc = await _usernamesCollection.doc(username.toLowerCase()).get();
      if (!usernameDoc.exists) return null;
      
      final data = usernameDoc.data() as Map<String, dynamic>;
      return await getUserById(data['uid']);
    } catch (e) {
      throw Exception('Failed to get user by username: $e');
    }
  }

  // Check if username is available
  static Future<bool> _isUsernameAvailable(String username) async {
    try {
      final doc = await _usernamesCollection.doc(username.toLowerCase()).get();
      return !doc.exists;
    } catch (e) {
      return false;
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

  // Search users by username
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];
      
      // Search by username (case-insensitive)
      final querySnapshot = await _usersCollection
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
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

  // Update username
  static Future<void> updateUsername(String userId, String newUsername) async {
    try {
      if (!await _isUsernameAvailable(newUsername)) {
        throw Exception('Username is already taken');
      }
      
      final user = await getUserById(userId);
      if (user == null) throw Exception('User not found');
      
      final batch = _firestore.batch();
      
      // Remove old username
      batch.delete(_usernamesCollection.doc(user.username.toLowerCase()));
      
      // Add new username
      batch.set(_usernamesCollection.doc(newUsername.toLowerCase()), {
        'uid': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Update user document
      batch.update(_usersCollection.doc(userId), {
        'username': newUsername,
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update username: $e');
    }
  }
} 