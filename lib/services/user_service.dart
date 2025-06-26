import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_model.dart';
import '../models/enums.dart';
import '../models/walker_profile.dart';
import '../models/owner_profile.dart';
import 'handle_service.dart';

part 'user_service.g.dart';

@riverpod
UserService userService(UserServiceRef ref) {
  return UserService(ref.watch(handleServiceProvider));
}

class UserService {
  final HandleService _handleService;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');

  UserService(this._handleService);

  // Create user profile after authentication
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    String? profilePictureUrl,
  }) async {
    try {
      // Generate unique handle
      final handle = await _handleService.generateUniqueHandle(displayName);

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
      await _handleService.reserveHandle(handle, uid);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Get user by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Get user by handle
  Future<UserModel?> getUserByHandle(String handle) async {
    try {
      final userId = await _handleService.getUserIdByHandle(handle);
      if (userId == null) return null;
      return await getUserById(userId);
    } catch (e) {
      throw Exception('Failed to get user by handle: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _usersCollection.doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update online status
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      // Check if user document exists first
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        print('UserService: User document does not exist for UID: $uid');
        return; // Don't throw error, just return silently
      }
      
      await _usersCollection.doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('UserService: Error updating online status: $e');
      // Don't throw error for online status updates as it's not critical
    }
  }

  // Get multiple users by IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
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
  Stream<UserModel?> listenToUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromSnapshot(snapshot);
    });
  }

  // Update notification settings
  Future<void> updateNotificationSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _usersCollection.doc(userId).update({
        'notificationSettings': settings,
      });
    } catch (e) {
      throw Exception('Failed to update notification settings: $e');
    }
  }

  // Update privacy settings
  Future<void> updatePrivacySettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _usersCollection.doc(userId).update({
        'privacySettings': settings,
      });
    } catch (e) {
      throw Exception('Failed to update privacy settings: $e');
    }
  }

  // Update handle
  Future<void> updateHandle(String userId, String newHandle) async {
    try {
      final user = await getUserById(userId);
      if (user == null) throw Exception('User not found');
      
      // Update handle reservation
      await _handleService.updateUserHandle(userId, user.handle, newHandle);
      
      // Update user document
      await _usersCollection.doc(userId).update({
        'handle': newHandle.startsWith('@') ? newHandle : '@$newHandle',
      });
    } catch (e) {
      throw Exception('Failed to update handle: $e');
    }
  }

  // Complete user onboarding with comprehensive profile data
  Future<void> completeUserOnboarding(
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
      final isAvailable = await _handleService.isHandleAvailable(formattedHandle, excludeUserId: uid);
      if (!isAvailable) {
        // Generate a new unique handle
        formattedHandle = await _handleService.generateUniqueHandle(displayName, excludeUserId: uid);
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
      await _handleService.reserveHandle(formattedHandle, uid);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to complete user onboarding: $e');
    }
  }

  // Migrate existing user to have a handle (for backward compatibility)
  Future<void> migrateUserToHandle(String userId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) throw Exception('User not found');
      
      // If user already has a handle, no need to migrate
      if (user.handle.isNotEmpty) return;
      
      // Generate handle from display name
      final handle = await _handleService.generateUniqueHandle(user.displayName);
      
      final batch = _firestore.batch();
      
      // Add handle to user document
      batch.update(_usersCollection.doc(userId), {
        'handle': handle,
      });
      
      // Reserve handle
      await _handleService.reserveHandle(handle, userId);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to migrate user to handle: $e');
    }
  }

  // Get all users (for debugging)
  Future<List<UserModel>> getAllUsers() async {
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
  Future<List<String>> getAllHandles() async {
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
  Future<List<Map<String, String>>> getAllUserIdentifiers() async {
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
} 