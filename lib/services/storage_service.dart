import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: "snapagram-ac74f.firebasestorage.app"
  );
  
  /// Upload image to Firebase Storage and return the download URL
  static Future<String> uploadStoryImage(File imageFile, String userId) async {
    try {
      // Generate unique filename
      final String fileName = 'story_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'stories/$userId/$fileName';
      
      print('StorageService: Attempting to upload to bucket: ${_storage.bucket}');
      print('StorageService: File path: $filePath');
      print('StorageService: User ID: $userId');
      print('StorageService: Local file exists: ${await imageFile.exists()}');
      
      // Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      print('StorageService: Current user: ${currentUser?.uid}');
      print('StorageService: User authenticated: ${currentUser != null}');
      
      if (currentUser == null) {
        throw Exception('User not authenticated for storage upload');
      }
      
      // Create reference to Firebase Storage
      final Reference ref = _storage.ref().child(filePath);
      
      // Upload file
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Image uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading image - $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  /// Upload user profile picture
  static Future<String> uploadProfilePicture(String userId, File imageFile) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final String filePath = 'profiles/$fileName';
      
      final Reference ref = _storage.ref().child(filePath);
      
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'type': 'profile_picture',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Profile picture uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading profile picture - $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Upload dog picture for owner profile
  static Future<String> uploadDogPicture(String userId, File imageFile) async {
    try {
      final String fileName = 'dog_$userId.jpg';
      final String filePath = 'dogs/$fileName';
      
      final Reference ref = _storage.ref().child(filePath);
      
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'type': 'dog_picture',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Dog picture uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading dog picture - $e');
      throw Exception('Failed to upload dog picture: $e');
    }
  }
  
  /// Upload video story (for future use)
  static Future<String> uploadStoryVideo(File videoFile, String userId) async {
    try {
      final String fileName = 'video_${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = 'stories/$userId/$fileName';
      
      final Reference ref = _storage.ref().child(filePath);
      
      final UploadTask uploadTask = ref.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'type': 'video_story',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Video uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading video - $e');
      throw Exception('Failed to upload video: $e');
    }
  }
  
  /// Delete file from Firebase Storage
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('StorageService: File deleted successfully - $downloadUrl');
    } catch (e) {
      print('StorageService: Error deleting file - $e');
      // Don't throw error for deletion failures as it's not critical
    }
  }
  
  /// Upload image from bytes (for processed images)
  static Future<String> uploadImageFromBytes(
    Uint8List imageBytes, 
    String userId, 
    String fileExtension,
  ) async {
    try {
      final String fileName = 'story_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String filePath = 'stories/$userId/$fileName';
      
      final Reference ref = _storage.ref().child(filePath);
      
      final UploadTask uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: fileExtension == 'png' ? 'image/png' : 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Image bytes uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading image bytes - $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  /// Upload chat image to Firebase Storage and return the download URL
  static Future<String> uploadChatImage(File imageFile, String userId) async {
    try {
      // Generate unique filename
      final String fileName = 'chat_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'chats/$userId/$fileName';
      
      print('StorageService: Attempting to upload chat image to bucket: ${_storage.bucket}');
      print('StorageService: File path: $filePath');
      print('StorageService: User ID: $userId');
      print('StorageService: Local file exists: ${await imageFile.exists()}');
      
      // Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      print('StorageService: Current user: ${currentUser?.uid}');
      print('StorageService: User authenticated: ${currentUser != null}');
      
      if (currentUser == null) {
        throw Exception('User not authenticated for storage upload');
      }
      
      // Create reference to Firebase Storage
      final Reference ref = _storage.ref().child(filePath);
      
      // Upload file
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'type': 'chat_image',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Chat image uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading chat image - $e');
      throw Exception('Failed to upload chat image: $e');
    }
  }

  /// Upload chat image from bytes (for processed images)
  static Future<String> uploadChatImageFromBytes(
    Uint8List imageBytes, 
    String userId, 
    String fileExtension,
  ) async {
    try {
      final String fileName = 'chat_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String filePath = 'chats/$userId/$fileName';
      
      print('StorageService: Uploading chat image from bytes to: $filePath');
      
      final Reference ref = _storage.ref().child(filePath);
      
      final UploadTask uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: fileExtension == 'png' ? 'image/png' : 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'type': 'chat_image',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('StorageService: Chat image bytes uploaded successfully - $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('StorageService: Error uploading chat image bytes - $e');
      throw Exception('Failed to upload chat image: $e');
    }
  }

  /// Get storage usage for a user
  static Future<int> getUserStorageUsage(String userId) async {
    try {
      final Reference userRef = _storage.ref().child('stories/$userId');
      final ListResult result = await userRef.listAll();
      
      int totalSize = 0;
      for (Reference ref in result.items) {
        final FullMetadata metadata = await ref.getMetadata();
        totalSize += metadata.size ?? 0;
      }
      
      return totalSize;
    } catch (e) {
      print('StorageService: Error getting storage usage - $e');
      return 0;
    }
  }

  // ================== DELETION METHODS FOR ACCOUNT CLEANUP ==================

  /// Delete user's profile picture
  static Future<void> deleteProfilePicture(String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final String filePath = 'profiles/$fileName';
      final Reference ref = _storage.ref().child(filePath);
      await ref.delete();
      print('StorageService: Profile picture deleted successfully for user $userId');
    } catch (e) {
      print('StorageService: Error deleting profile picture for $userId - $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Delete user's dog picture
  static Future<void> deleteDogPicture(String userId) async {
    try {
      final String fileName = 'dog_$userId.jpg';
      final String filePath = 'dogs/$fileName';
      final Reference ref = _storage.ref().child(filePath);
      await ref.delete();
      print('StorageService: Dog picture deleted successfully for user $userId');
    } catch (e) {
      print('StorageService: Error deleting dog picture for $userId - $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Delete all user's story images
  static Future<void> deleteAllUserStories(String userId) async {
    try {
      final Reference storiesRef = _storage.ref().child('stories/$userId');
      final ListResult result = await storiesRef.listAll();
      
      // Delete all items in the user's stories folder
      for (Reference ref in result.items) {
        try {
          await ref.delete();
          print('StorageService: Deleted story file ${ref.name}');
        } catch (e) {
          print('StorageService: Error deleting story file ${ref.name} - $e');
        }
      }
      
      print('StorageService: All stories deleted for user $userId');
    } catch (e) {
      print('StorageService: Error deleting stories for $userId - $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Delete all user's walk photos
  static Future<void> deleteAllUserWalkPhotos(String userId) async {
    try {
      final Reference walkPhotosRef = _storage.ref().child('walk_photos/$userId');
      final ListResult result = await walkPhotosRef.listAll();
      
      // Delete all items in the user's walk photos folder
      for (Reference ref in result.items) {
        try {
          await ref.delete();
          print('StorageService: Deleted walk photo ${ref.name}');
        } catch (e) {
          print('StorageService: Error deleting walk photo ${ref.name} - $e');
        }
      }
      
      print('StorageService: All walk photos deleted for user $userId');
    } catch (e) {
      print('StorageService: Error deleting walk photos for $userId - $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Delete all user's chat images
  static Future<void> deleteAllUserChatImages(String userId) async {
    try {
      final Reference chatImagesRef = _storage.ref().child('chats/$userId');
      final ListResult result = await chatImagesRef.listAll();
      
      // Delete all items in the user's chat images folder
      for (Reference ref in result.items) {
        try {
          await ref.delete();
          print('StorageService: Deleted chat image ${ref.name}');
        } catch (e) {
          print('StorageService: Error deleting chat image ${ref.name} - $e');
        }
      }
      
      print('StorageService: All chat images deleted for user $userId');
    } catch (e) {
      print('StorageService: Error deleting chat images for $userId - $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Delete ALL user data from storage (comprehensive cleanup)
  static Future<void> deleteAllUserData(String userId) async {
    try {
      print('StorageService: Starting comprehensive storage deletion for user $userId');
      
      // Delete profile picture
      await deleteProfilePicture(userId);
      
      // Delete dog picture
      await deleteDogPicture(userId);
      
      // Delete all stories
      await deleteAllUserStories(userId);
      
      // Delete all walk photos
      await deleteAllUserWalkPhotos(userId);
      
      // Delete all chat images
      await deleteAllUserChatImages(userId);
      
      print('StorageService: Comprehensive storage deletion completed for user $userId');
    } catch (e) {
      print('StorageService: Error during comprehensive deletion for $userId - $e');
      // Don't throw - this allows other cleanup to continue
    }
  }
} 