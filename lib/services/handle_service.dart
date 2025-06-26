import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:math';

part 'handle_service.g.dart';

@riverpod
HandleService handleService(HandleServiceRef ref) {
  return HandleService();
}

class HandleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _handlesCollection = _firestore.collection('handles');

  // Generate a unique handle from display name
  String _generateHandleFromName(String displayName) {
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
  Future<String> generateUniqueHandle(String displayName, {String? excludeUserId}) async {
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
  Future<bool> isHandleAvailable(String handle, {String? excludeUserId}) async {
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

  // Reserve a handle for a user
  Future<void> reserveHandle(String handle, String userId) async {
    try {
      await _handlesCollection.doc(handle.toLowerCase()).set({
        'uid': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to reserve handle: $e');
    }
  }

  // Release a handle (remove reservation)
  Future<void> releaseHandle(String handle) async {
    try {
      await _handlesCollection.doc(handle.toLowerCase()).delete();
    } catch (e) {
      throw Exception('Failed to release handle: $e');
    }
  }

  // Update handle for a user (atomic operation)
  Future<void> updateUserHandle(String userId, String oldHandle, String newHandle) async {
    try {
      // Add @ symbol if not present
      String fullHandle = newHandle.startsWith('@') ? newHandle : '@$newHandle';
      
      if (!await isHandleAvailable(fullHandle, excludeUserId: userId)) {
        throw Exception('Handle is already taken');
      }
      
      final batch = _firestore.batch();
      
      // Remove old handle
      if (oldHandle.isNotEmpty) {
        batch.delete(_handlesCollection.doc(oldHandle.toLowerCase()));
      }
      
      // Add new handle
      batch.set(_handlesCollection.doc(fullHandle.toLowerCase()), {
        'uid': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update handle: $e');
    }
  }

  // Get user ID by handle
  Future<String?> getUserIdByHandle(String handle) async {
    try {
      // Remove all leading @ and prepend a single @
      String cleanHandle = handle.replaceFirst(RegExp(r'^@+'), '');
      cleanHandle = '@$cleanHandle';
      
      final handleDoc = await _handlesCollection.doc(cleanHandle.toLowerCase()).get();
      if (!handleDoc.exists) return null;
      
      final data = handleDoc.data() as Map<String, dynamic>;
      return data['uid'] as String?;
    } catch (e) {
      throw Exception('Failed to get user ID by handle: $e');
    }
  }
} 