import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Create a fake story
  final fakeStory = {
    'id': 'test_story_${DateTime.now().millisecondsSinceEpoch}',
    'uid': 'test_user_123', // You can replace with an actual user ID
    'creatorUsername': 'testuser',
    'creatorProfilePicture': null,
    'type': 'image', // or 'video'
    'visibility': 'public', // or 'friends'
    'mediaUrl': 'https://picsum.photos/400/600', // Random placeholder image
    'thumbnailUrl': null,
    'caption': 'This is a test story from the backend! 🚀',
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
    'filters': {
      'brightness': 1.0,
      'contrast': 1.0,
      'saturation': 1.0,
    },
    'viewedBy': [],
    'likedBy': [],
    'viewCount': 0,
    'likeCount': 0,
    'shareCount': 0,
    'isEncrypted': false,
    'encryptedKey': null,
    'allowedViewers': [],
    'metadata': {
      'fileSize': 1024000, // 1MB
      'width': 400,
      'height': 600,
      'format': 'jpeg',
    },
  };

  try {
    // Add the story to Firestore
    await FirebaseFirestore.instance
        .collection('stories')
        .doc(fakeStory['id'] as String)
        .set(fakeStory);
    
    print('✅ Fake story added successfully!');
    print('Story ID: ${fakeStory['id']}');
    print('Caption: ${fakeStory['caption']}');
    print('Created at: ${fakeStory['createdAt']}');
    print('Expires at: ${fakeStory['expiresAt']}');
    
  } catch (e) {
    print('❌ Error adding fake story: $e');
  }
  
  // Close the app
  await Firebase.app().delete();
} 