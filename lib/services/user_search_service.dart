import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_model.dart';

part 'user_search_service.g.dart';

@riverpod
UserSearchService userSearchService(UserSearchServiceRef ref) {
  return UserSearchService();
}

class UserSearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');

  // Search users by handle and display name
  Future<List<UserModel>> searchUsers(String query) async {
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

  // Advanced search with filters
  Future<List<UserModel>> searchUsersWithFilters({
    required String query,
    String? role,
    bool? isOnline,
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty) return [];
      
      Query searchQuery = _usersCollection;
      
      // Apply role filter if specified
      if (role != null && role.isNotEmpty) {
        searchQuery = searchQuery.where('role', isEqualTo: role);
      }
      
      // Apply online status filter if specified
      if (isOnline != null) {
        searchQuery = searchQuery.where('isOnline', isEqualTo: isOnline);
      }
      
      // Convert query to lowercase for case-insensitive search
      String lowerQuery = query.toLowerCase();
      String handleQuery = '@' + lowerQuery.replaceFirst(RegExp(r'^@+'), '');
      
      // Search by handle first
      final handleResults = await searchQuery
          .where('handle', isGreaterThanOrEqualTo: handleQuery)
          .where('handle', isLessThanOrEqualTo: handleQuery + '\uf8ff')
          .limit(limit)
          .get();

      List<UserModel> results = handleResults.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();

      // If we need more results, search by display name
      if (results.length < limit) {
        final remainingLimit = limit - results.length;
        final displayNameResults = await searchQuery
            .where('displayName', isGreaterThanOrEqualTo: lowerQuery)
            .where('displayName', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
            .limit(remainingLimit)
            .get();

        final displayNameUsers = displayNameResults.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .toList();

        // Add unique results
        for (final user in displayNameUsers) {
          if (!results.any((existing) => existing.uid == user.uid)) {
            results.add(user);
          }
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search users with filters: $e');
    }
  }

  // Search users by location (if location data is available)
  Future<List<UserModel>> searchUsersByLocation({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? role,
    int limit = 20,
  }) async {
    try {
      // This would require GeoFirestore or similar for efficient geo queries
      // For now, we'll return a basic implementation that can be enhanced later
      Query searchQuery = _usersCollection;
      
      if (role != null && role.isNotEmpty) {
        searchQuery = searchQuery.where('role', isEqualTo: role);
      }
      
      final snapshot = await searchQuery.limit(limit).get();
      
      return snapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users by location: $e');
    }
  }

  // Get trending or popular users (based on connections count)
  Future<List<UserModel>> getTrendingUsers({int limit = 10}) async {
    try {
      final snapshot = await _usersCollection
          .orderBy('connectionsCount', descending: true)
          .where('isOnboardingComplete', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trending users: $e');
    }
  }

  // Get recently joined users
  Future<List<UserModel>> getRecentUsers({int limit = 10}) async {
    try {
      final snapshot = await _usersCollection
          .orderBy('createdAt', descending: true)
          .where('isOnboardingComplete', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent users: $e');
    }
  }

  // Search users by multiple criteria
  Future<List<UserModel>> advancedSearch({
    String? query,
    String? role,
    bool? isOnline,
    int? minConnections,
    int? maxConnections,
    DateTime? joinedAfter,
    DateTime? joinedBefore,
    int limit = 20,
  }) async {
    try {
      Query searchQuery = _usersCollection;
      
      // Apply filters
      if (role != null && role.isNotEmpty) {
        searchQuery = searchQuery.where('role', isEqualTo: role);
      }
      
      if (isOnline != null) {
        searchQuery = searchQuery.where('isOnline', isEqualTo: isOnline);
      }
      
      if (minConnections != null) {
        searchQuery = searchQuery.where('connectionsCount', isGreaterThanOrEqualTo: minConnections);
      }
      
      if (maxConnections != null) {
        searchQuery = searchQuery.where('connectionsCount', isLessThanOrEqualTo: maxConnections);
      }
      
      if (joinedAfter != null) {
        searchQuery = searchQuery.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(joinedAfter));
      }
      
      if (joinedBefore != null) {
        searchQuery = searchQuery.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(joinedBefore));
      }
      
      // If query is provided, we need to handle it separately due to Firestore limitations
      if (query != null && query.isNotEmpty) {
        // For now, apply other filters and then filter by query in memory
        // In a production app, you'd want to use a dedicated search service like Algolia
        final snapshot = await searchQuery.limit(limit * 2).get(); // Get more to filter
        
        final allResults = snapshot.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .toList();
        
        final lowerQuery = query.toLowerCase();
        final filteredResults = allResults.where((user) {
          return user.handle.toLowerCase().contains(lowerQuery) ||
                 user.displayName.toLowerCase().contains(lowerQuery);
        }).take(limit).toList();
        
        return filteredResults;
      } else {
        final snapshot = await searchQuery.limit(limit).get();
        return snapshot.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .toList();
      }
    } catch (e) {
      throw Exception('Failed to perform advanced search: $e');
    }
  }
} 