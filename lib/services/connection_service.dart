import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_model.dart';
import 'user_service.dart';

part 'connection_service.g.dart';

@riverpod
ConnectionService connectionService(ConnectionServiceRef ref) {
  return ConnectionService(ref.watch(userServiceProvider));
}

class ConnectionService {
  final UserService _userService;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');

  ConnectionService(this._userService);

  // Send connection request
  Future<void> sendConnectionRequest(String currentUserId, String targetUserId) async {
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

  // Accept connection request
  Future<void> acceptConnectionRequest(String currentUserId, String fromUserId) async {
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

  // Reject connection request
  Future<void> rejectConnectionRequest(String currentUserId, String fromUserId) async {
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

  // Remove connection
  Future<void> removeConnection(String currentUserId, String connectionId) async {
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
  Future<void> blockUser(String currentUserId, String userIdToBlock) async {
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

  // Get user's connections
  Future<List<UserModel>> getUserConnections(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user == null || user.connections.isEmpty) return [];
      
      return await _userService.getUsersByIds(user.connections);
    } catch (e) {
      throw Exception('Failed to get user connections: $e');
    }
  }

  // Get connection requests
  Future<List<UserModel>> getConnectionRequests(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user == null || user.connectionRequests.isEmpty) return [];
      
      return await _userService.getUsersByIds(user.connectionRequests);
    } catch (e) {
      throw Exception('Failed to get connection requests: $e');
    }
  }

  // Listen to connections updates
  Stream<List<UserModel>> listenToConnections(String userId) {
    return _usersCollection.doc(userId).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return [];
      
      final user = UserModel.fromSnapshot(snapshot);
      if (user.connections.isEmpty) return [];
      
      return await _userService.getUsersByIds(user.connections);
    });
  }

  // Fix connections count by recalculating from connections array
  Future<void> fixConnectionsCount(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
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
  Future<void> fixAllConnectionsCounts() async {
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

  // Check if current user is connected to another user
  bool isConnectedTo(UserModel? currentUser, String userId) {
    return currentUser?.connections.contains(userId) ?? false;
  }

  // Check if current user has a pending request to another user
  bool hasPendingRequestTo(UserModel? currentUser, String userId) {
    return currentUser?.sentRequests.contains(userId) ?? false;
  }

  // Check if current user has received a request from another user
  bool hasRequestFrom(UserModel? currentUser, String userId) {
    return currentUser?.connectionRequests.contains(userId) ?? false;
  }

  // Legacy method names for backward compatibility (will be removed)
  @deprecated
  Future<void> sendFriendRequest(String currentUserId, String targetUserId) async {
    return sendConnectionRequest(currentUserId, targetUserId);
  }

  @deprecated
  Future<void> acceptFriendRequest(String currentUserId, String fromUserId) async {
    return acceptConnectionRequest(currentUserId, fromUserId);
  }

  @deprecated
  Future<void> rejectFriendRequest(String currentUserId, String fromUserId) async {
    return rejectConnectionRequest(currentUserId, fromUserId);
  }

  @deprecated
  Future<void> removeFriend(String currentUserId, String friendId) async {
    return removeConnection(currentUserId, friendId);
  }

  @deprecated
  Future<List<UserModel>> getUserFriends(String userId) async {
    return getUserConnections(userId);
  }

  @deprecated
  Future<List<UserModel>> getFriendRequests(String userId) async {
    return getConnectionRequests(userId);
  }

  @deprecated
  Stream<List<UserModel>> listenToFriends(String userId) {
    return listenToConnections(userId);
  }

  @deprecated
  Future<void> fixFriendsCount(String userId) async {
    return fixConnectionsCount(userId);
  }

  @deprecated
  Future<void> fixAllFriendsCounts() async {
    return fixAllConnectionsCounts();
  }
} 