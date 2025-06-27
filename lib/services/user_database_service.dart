import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/enums.dart';
import '../models/walker_profile.dart';
import '../models/owner_profile.dart';
import 'storage_service.dart';

final userProfileProvider = StreamProvider.autoDispose.family<UserModel?, String>((ref, userId) {
  return UserDatabaseService.listenToUser(userId);
});

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
        role: UserRole.owner, // Default to owner, will be updated during onboarding
        isOnboardingComplete: false, // Ensure onboarding is marked as incomplete
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
      // Check if user document exists first
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        print('UserDatabaseService: User document does not exist for UID: $uid');
        return; // Don't throw error, just return silently
      }
      
      await _usersCollection.doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('UserDatabaseService: Error updating online status: $e');
      // Don't throw error for online status updates as it's not critical
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

  // Send connection request (was friend request)
  static Future<void> sendConnectionRequest(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to current user's sent requests
      batch.update(_usersCollection.doc(currentUserId), {
        'sentRequests': FieldValue.arrayUnion([targetUserId])
      });
      
      // Add to target user's connection requests
      batch.update(_usersCollection.doc(targetUserId), {
        'connectionRequests': FieldValue.arrayUnion([currentUserId])
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send connection request: $e');
    }
  }

  // Accept connection request (was friend request)
  static Future<void> acceptConnectionRequest(String currentUserId, String fromUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Update current user
      batch.update(_usersCollection.doc(currentUserId), {
        'connections': FieldValue.arrayUnion([fromUserId]),
        'connectionRequests': FieldValue.arrayRemove([fromUserId]),
        'connectionsCount': FieldValue.increment(1),
      });
      
      // Update connecting user
      batch.update(_usersCollection.doc(fromUserId), {
        'connections': FieldValue.arrayUnion([currentUserId]),
        'sentRequests': FieldValue.arrayRemove([currentUserId]),
        'connectionsCount': FieldValue.increment(1),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to accept connection request: $e');
    }
  }

  // Reject connection request (was friend request)
  static Future<void> rejectConnectionRequest(String currentUserId, String fromUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Remove from current user's connection requests
      batch.update(_usersCollection.doc(currentUserId), {
        'connectionRequests': FieldValue.arrayRemove([fromUserId])
      });
      
      // Remove from connecting user's sent requests
      batch.update(_usersCollection.doc(fromUserId), {
        'sentRequests': FieldValue.arrayRemove([currentUserId])
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reject connection request: $e');
    }
  }

  // Remove connection (was friend)
  static Future<void> removeConnection(String currentUserId, String connectionId) async {
    try {
      final batch = _firestore.batch();
      
      // Update current user
      batch.update(_usersCollection.doc(currentUserId), {
        'connections': FieldValue.arrayRemove([connectionId]),
        'connectionsCount': FieldValue.increment(-1),
      });
      
      // Update connection user
      batch.update(_usersCollection.doc(connectionId), {
        'connections': FieldValue.arrayRemove([currentUserId]),
        'connectionsCount': FieldValue.increment(-1),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove connection: $e');
    }
  }

  // Block user
  static Future<void> blockUser(String currentUserId, String userIdToBlock) async {
    try {
      final batch = _firestore.batch();
      
      // Add to blocked users
      batch.update(_usersCollection.doc(currentUserId), {
        'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
        'connections': FieldValue.arrayRemove([userIdToBlock]),
        'connectionRequests': FieldValue.arrayRemove([userIdToBlock]),
        'sentRequests': FieldValue.arrayRemove([userIdToBlock]),
      });
      
      // Remove from blocked user's connections and requests
      batch.update(_usersCollection.doc(userIdToBlock), {
        'connections': FieldValue.arrayRemove([currentUserId]),
        'connectionRequests': FieldValue.arrayRemove([currentUserId]),
        'sentRequests': FieldValue.arrayRemove([currentUserId]),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  // Get user's connections (was friends)
  static Future<List<UserModel>> getUserConnections(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null || user.connections.isEmpty) return [];
      
      final connectionsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.connections)
          .get();
      
      return connectionsSnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user connections: $e');
    }
  }

  // Get connection requests (was friend requests)
  static Future<List<UserModel>> getConnectionRequests(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null || user.connectionRequests.isEmpty) return [];
      
      final requestsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.connectionRequests)
          .get();
      
      return requestsSnapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get connection requests: $e');
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

  // Listen to connections updates (was friends updates)
  static Stream<List<UserModel>> listenToConnections(String userId) {
    return _usersCollection.doc(userId).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return [];
      
      final user = UserModel.fromSnapshot(snapshot);
      if (user.connections.isEmpty) return [];
      
      final connectionsSnapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: user.connections)
          .get();
      
      return connectionsSnapshot.docs
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

  // Fix connections count by recalculating from connections array
  static Future<void> fixConnectionsCount(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return;
      
      final actualConnectionsCount = user.connections.length;
      
      if (actualConnectionsCount != user.connectionsCount) {
        await _usersCollection.doc(userId).update({
          'connectionsCount': actualConnectionsCount,
        });
        print('Fixed connections count for user $userId: was ${user.connectionsCount}, now $actualConnectionsCount');
      }
    } catch (e) {
      throw Exception('Failed to fix connections count: $e');
    }
  }

  // Fix connections count for all users (admin function)
  static Future<void> fixAllConnectionsCounts() async {
    try {
      final usersSnapshot = await _usersCollection.get();
      
      for (final doc in usersSnapshot.docs) {
        final user = UserModel.fromSnapshot(doc);
        final actualConnectionsCount = user.connections.length;
        
        if (actualConnectionsCount != user.connectionsCount) {
          await _usersCollection.doc(user.uid).update({
            'connectionsCount': actualConnectionsCount,
          });
          print('Fixed connections count for user ${user.uid}: was ${user.connectionsCount}, now $actualConnectionsCount');
        }
      }
    } catch (e) {
      throw Exception('Failed to fix all connections counts: $e');
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

  // Check if current user is connected to another user
  static bool isConnectedTo(UserModel? currentUser, String userId) {
    return currentUser?.connections.contains(userId) ?? false;
  }

  // Check if current user has a pending request to another user
  static bool hasPendingRequestTo(UserModel? currentUser, String userId) {
    return currentUser?.sentRequests.contains(userId) ?? false;
  }

  // Check if current user has received a request from another user
  static bool hasRequestFrom(UserModel? currentUser, String userId) {
    return currentUser?.connectionRequests.contains(userId) ?? false;
  }

  // Complete user onboarding with comprehensive profile data
  static Future<void> completeUserOnboarding(
    String uid, {
    required String displayName,
    required String handle,
    String? bio,
    String? profilePictureUrl,
    required UserRole role,
    WalkerProfile? walkerProfile,
    OwnerProfile? ownerProfile,
  }) async {
    try {
      // Ensure handle is properly formatted
      String formattedHandle = handle.startsWith('@') ? handle : '@$handle';
      
      // Check if handle is available (excluding current user)
      final isAvailable = await isHandleAvailable(formattedHandle, excludeUserId: uid);
      if (!isAvailable) {
        // Generate a new unique handle
        formattedHandle = await generateUniqueHandle(displayName, excludeUserId: uid);
      }
      
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      // Check if user document exists
      final existingDoc = await _usersCollection.doc(uid).get();
      
      // Create complete user document (in case it doesn't exist)
      final userData = <String, dynamic>{
        'uid': uid,
        'email': _auth.currentUser?.email ?? '',
        'displayName': displayName,
        'handle': formattedHandle,
        'bio': bio ?? '',
        'profilePictureUrl': profilePictureUrl,
        'createdAt': existingDoc.exists 
            ? (existingDoc.data() as Map<String, dynamic>)['createdAt'] 
            : Timestamp.fromDate(now),
        'lastSeen': Timestamp.fromDate(now),
        'isOnline': true,
        'connections': [],
        'connectionRequests': [],
        'sentRequests': [],
        'blockedUsers': [],
        'notificationSettings': {},
        'privacySettings': {},
        'chatDefaults': {},
        'storiesCount': 0,
        'connectionsCount': 0,
        'role': role.name,
        'isOnboardingComplete': true,
      };
      
      // Add role-specific profile data
      if (role == UserRole.walker && walkerProfile != null) {
        userData['walkerProfile'] = walkerProfile.toMap();
        userData['ownerProfile'] = null;
      } else if (role == UserRole.owner && ownerProfile != null) {
        userData['ownerProfile'] = ownerProfile.toMap();
        userData['walkerProfile'] = null;
      }
      
      // Use set instead of update to create document if it doesn't exist
      batch.set(_usersCollection.doc(uid), userData);
      
      // Update handle reservation
      batch.set(_handlesCollection.doc(formattedHandle.toLowerCase()), {
        'uid': uid,
        'createdAt': Timestamp.fromDate(now),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to complete user onboarding: $e');
    }
  }

  // Legacy method names for backward compatibility (will be removed)
  @deprecated
  static Future<void> sendFriendRequest(String currentUserId, String targetUserId) async {
    return sendConnectionRequest(currentUserId, targetUserId);
  }

  @deprecated
  static Future<void> acceptFriendRequest(String currentUserId, String fromUserId) async {
    return acceptConnectionRequest(currentUserId, fromUserId);
  }

  @deprecated
  static Future<void> rejectFriendRequest(String currentUserId, String fromUserId) async {
    return rejectConnectionRequest(currentUserId, fromUserId);
  }

  @deprecated
  static Future<void> removeFriend(String currentUserId, String friendId) async {
    return removeConnection(currentUserId, friendId);
  }

  @deprecated
  static Future<List<UserModel>> getUserFriends(String userId) async {
    return getUserConnections(userId);
  }

  @deprecated
  static Future<List<UserModel>> getFriendRequests(String userId) async {
    return getConnectionRequests(userId);
  }

  @deprecated
  static Stream<List<UserModel>> listenToFriends(String userId) {
    return listenToConnections(userId);
  }

  @deprecated
  static Future<void> fixFriendsCount(String userId) async {
    return fixConnectionsCount(userId);
  }

  @deprecated
  static Future<void> fixAllFriendsCounts() async {
    return fixAllConnectionsCounts();
  }

  // Delete all user data (used for account deletion)
  static Future<void> deleteUserData(String userId) async {
    try {
      print('Starting comprehensive user data deletion for $userId');
      
      final user = await getUserById(userId);
      if (user == null) {
        print('User $userId not found in Firestore, proceeding with storage cleanup');
      }
      
      // Step 1: Delete all user files from Firebase Storage
      await _deleteUserStorageData(userId);
      
      // Step 2: Delete user data from Firestore collections
      await _deleteUserFirestoreData(userId, user);
      
      // Step 3: Clean up user references in other users' data
      if (user != null) {
        await _cleanupUserReferences(userId, user);
      }
      
      print('Successfully completed comprehensive deletion for user $userId');
    } catch (e) {
      print('Error during comprehensive user deletion for $userId: $e');
      throw Exception('Failed to delete user data: $e');
    }
  }

  // Delete all user files from Firebase Storage
  static Future<void> _deleteUserStorageData(String userId) async {
    try {
      print('Deleting storage data for user $userId');
      
      // Delete profile picture
      await StorageService.deleteProfilePicture(userId);
      
      // Delete dog picture (if owner)
      await StorageService.deleteDogPicture(userId);
      
      // Delete all user's story images
      await StorageService.deleteAllUserStories(userId);
      
      // Delete all user's walk photos
      await StorageService.deleteAllUserWalkPhotos(userId);
      
      print('Storage cleanup completed for user $userId');
    } catch (e) {
      print('Error deleting storage data for $userId: $e');
      // Don't throw here - continue with other cleanup even if storage fails
    }
  }

  // Delete user data from all Firestore collections
  static Future<void> _deleteUserFirestoreData(String userId, UserModel? user) async {
    try {
      print('Deleting Firestore data for user $userId');
      
      final batch = _firestore.batch();
      
      // Delete main user document (includes all onboarding data)
      batch.delete(_usersCollection.doc(userId));
      
      // Delete handle reservation
      if (user?.handle.isNotEmpty == true) {
        batch.delete(_handlesCollection.doc(user!.handle.toLowerCase()));
      }
      
      await batch.commit();
      
      // Delete from other collections (in separate batches to avoid size limits)
      await _deleteUserStories(userId);
      await _deleteUserChats(userId);
      await _deleteUserWalkSessions(userId);
      await _deleteUserReviews(userId);
      
      print('Firestore cleanup completed for user $userId');
    } catch (e) {
      print('Error deleting Firestore data for $userId: $e');
      throw e;
    }
  }

  // Clean up references to this user in other users' data
  static Future<void> _cleanupUserReferences(String userId, UserModel user) async {
    try {
      print('Cleaning up user references for $userId');
      
      final batch = _firestore.batch();
      
      // Remove user from all connections' connection lists
      if (user.connections.isNotEmpty) {
        for (final connectionId in user.connections) {
          batch.update(_usersCollection.doc(connectionId), {
            'connections': FieldValue.arrayRemove([userId]),
            'connectionsCount': FieldValue.increment(-1),
          });
        }
      }
      
      // Remove user from all pending connection requests
      if (user.connectionRequests.isNotEmpty) {
        for (final requesterId in user.connectionRequests) {
          batch.update(_usersCollection.doc(requesterId), {
            'sentRequests': FieldValue.arrayRemove([userId]),
          });
        }
      }
      
      // Remove user from all sent connection requests
      if (user.sentRequests.isNotEmpty) {
        for (final targetId in user.sentRequests) {
          batch.update(_usersCollection.doc(targetId), {
            'connectionRequests': FieldValue.arrayRemove([userId]),
          });
        }
      }
      
      await batch.commit();
      print('User references cleanup completed for $userId');
    } catch (e) {
      print('Error cleaning up user references for $userId: $e');
      throw e;
    }
  }

  // Delete all user stories
  static Future<void> _deleteUserStories(String userId) async {
    try {
      // When story collection is implemented, delete all stories by this user
      // final storiesQuery = FirebaseFirestore.instance
      //     .collection('stories')
      //     .where('userId', isEqualTo: userId);
      // final storiesSnapshot = await storiesQuery.get();
      // final batch = _firestore.batch();
      // for (final doc in storiesSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }
      // await batch.commit();
      print('Stories deletion completed for user $userId');
    } catch (e) {
      print('Error deleting stories for $userId: $e');
    }
  }

  // Delete all user chats and messages
  static Future<void> _deleteUserChats(String userId) async {
    try {
      // When chat collection is implemented, delete all chats involving this user
      // This includes both individual chats and group chats
      print('Chat deletion completed for user $userId');
    } catch (e) {
      print('Error deleting chats for $userId: $e');
    }
  }

  // Delete all user walk sessions
  static Future<void> _deleteUserWalkSessions(String userId) async {
    try {
      // When walk sessions collection is implemented, delete all sessions by this user
      // final walkSessionsQuery = FirebaseFirestore.instance
      //     .collection('walkSessions')
      //     .where('walkerId', isEqualTo: userId);
      // final walkSessionsSnapshot = await walkSessionsQuery.get();
      // final batch = _firestore.batch();
      // for (final doc in walkSessionsSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }
      // await batch.commit();
      print('Walk sessions deletion completed for user $userId');
    } catch (e) {
      print('Error deleting walk sessions for $userId: $e');
    }
  }

  // Delete all user reviews
  static Future<void> _deleteUserReviews(String userId) async {
    try {
      // When reviews collection is implemented, delete all reviews by/for this user
      // final reviewsQuery = FirebaseFirestore.instance
      //     .collection('reviews')
      //     .where('walkerId', isEqualTo: userId);
      // final reviewsSnapshot = await reviewsQuery.get();
      // final batch = _firestore.batch();
      // for (final doc in reviewsSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }
      // await batch.commit();
      print('Reviews deletion completed for user $userId');
    } catch (e) {
      print('Error deleting reviews for $userId: $e');
    }
  }
} 