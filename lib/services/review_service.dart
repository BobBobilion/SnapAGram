import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../models/user_model.dart';
import 'user_database_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get reviews for a specific user
  Stream<List<Review>> getUserReviews(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromSnapshot(doc))
          .toList();
    });
  }

  // Get reviews written by a specific user
  Stream<List<Review>> getReviewsByUser(String reviewerId) {
    return _firestore
        .collectionGroup('reviews')
        .where('reviewerId', isEqualTo: reviewerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromSnapshot(doc))
          .toList();
    });
  }

  // Submit a new review
  Future<void> submitReview({
    required String reviewerId,
    required String reviewerName,
    required String reviewerProfilePictureUrl,
    required String targetUserId,
    required double rating,
    required String comment,
    bool wasAiGenerated = false,
    String? aiSuggestion,
  }) async {
    print('📝 [REVIEW] Starting review submission...');
    print('📝 [REVIEW] Reviewer: $reviewerId');
    print('📝 [REVIEW] Target: $targetUserId');
    print('📝 [REVIEW] Rating: $rating');
    
    final batch = _firestore.batch();

    // Create the review document
    final reviewRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('reviews')
        .doc();

    print('📝 [REVIEW] Created review reference: ${reviewRef.id}');

    final review = Review(
      id: reviewRef.id,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerProfilePictureUrl: reviewerProfilePictureUrl,
      targetUserId: targetUserId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
      wasAiGenerated: wasAiGenerated,
      aiSuggestion: aiSuggestion,
    );

    batch.set(reviewRef, review.toMap());
    print('📝 [REVIEW] Added review to batch');

    // Update the user's review summary
    print('📝 [REVIEW] Updating review summary...');
    await _updateUserReviewSummary(targetUserId, batch);
    print('📝 [REVIEW] Review summary updated');

    print('📝 [REVIEW] Committing batch...');
    await batch.commit();
    print('📝 [REVIEW] ✅ Review submitted successfully!');
  }

  // Calculate and update user's review summary
  Future<void> _updateUserReviewSummary(String userId, [WriteBatch? batch]) async {
    print('📊 [SUMMARY] Calculating review summary for user: $userId');
    
    final useExistingBatch = batch != null;
    final currentBatch = batch ?? _firestore.batch();

    // Get all reviews for this user
    final reviewsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('reviews')
        .get();

    final reviews = reviewsSnapshot.docs
        .map((doc) => Review.fromSnapshot(doc))
        .toList();

    print('📊 [SUMMARY] Found ${reviews.length} total reviews');

    if (reviews.isEmpty) {
      // No reviews, set empty summary
      print('📊 [SUMMARY] No reviews found, setting empty summary');
      final userRef = _firestore.collection('users').doc(userId);
      currentBatch.update(userRef, {
        'reviewSummary': null,
      });
    } else {
      // Calculate summary
      final totalReviews = reviews.length;
      final totalRating = reviews.fold<double>(0, (sum, review) => sum + review.rating);
      final averageRating = totalRating / totalReviews;

      print('📊 [SUMMARY] Total reviews: $totalReviews');
      print('📊 [SUMMARY] Average rating: ${averageRating.toStringAsFixed(2)}');

      // Calculate rating breakdown
      final ratingBreakdown = <int, int>{
        1: 0, 2: 0, 3: 0, 4: 0, 5: 0,
      };

      for (final review in reviews) {
        final roundedRating = review.rating.round();
        ratingBreakdown[roundedRating] = (ratingBreakdown[roundedRating] ?? 0) + 1;
      }

      print('📊 [SUMMARY] Rating breakdown: $ratingBreakdown');

      final reviewSummary = ReviewSummary(
        averageRating: averageRating,
        totalReviews: totalReviews,
        ratingBreakdown: ratingBreakdown,
        lastUpdated: DateTime.now(),
      );

      final userRef = _firestore.collection('users').doc(userId);
      currentBatch.update(userRef, {
        'reviewSummary': reviewSummary.toMap(),
      });
      
      print('📊 [SUMMARY] Added summary update to batch');
    }

    if (!useExistingBatch) {
      print('📊 [SUMMARY] Committing summary batch...');
      await currentBatch.commit();
      print('📊 [SUMMARY] ✅ Summary updated successfully!');
    } else {
      print('📊 [SUMMARY] Summary added to existing batch');
    }
  }

  // Check if a user can review another user
  Future<bool> canUserReview(String reviewerId, String targetUserId) async {
    try {
      // Users cannot review themselves
      if (reviewerId == targetUserId) return false;

      // Get both users' data
      final reviewerDoc = await _firestore.collection('users').doc(reviewerId).get();
      final targetDoc = await _firestore.collection('users').doc(targetUserId).get();

      if (!reviewerDoc.exists || !targetDoc.exists) return false;

      final reviewer = UserModel.fromSnapshot(reviewerDoc);
      final target = UserModel.fromSnapshot(targetDoc);

      // Users must be connected to review each other
      if (!reviewer.connections.contains(targetUserId)) return false;
      if (!target.connections.contains(reviewerId)) return false;

      // Check if user has already reviewed this person
      final existingReviewQuery = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('reviews')
          .where('reviewerId', isEqualTo: reviewerId)
          .limit(1)
          .get();

      // Users can only review once
      return existingReviewQuery.docs.isEmpty;
    } catch (e) {
      print('Error checking review eligibility: $e');
      return false;
    }
  }

  // Get a specific review
  Future<Review?> getReview(String targetUserId, String reviewId) async {
    try {
      final reviewDoc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('reviews')
          .doc(reviewId)
          .get();

      if (reviewDoc.exists) {
        return Review.fromSnapshot(reviewDoc);
      }
      return null;
    } catch (e) {
      print('Error getting review: $e');
      return null;
    }
  }

  // Get review stats for a user
  Future<ReviewSummary?> getReviewSummary(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['reviewSummary'] != null) {
        return ReviewSummary.fromMap(userData['reviewSummary']);
      }

      // If no summary exists, calculate it
      await _updateUserReviewSummary(userId);
      
      // Fetch updated user data
      final updatedDoc = await _firestore.collection('users').doc(userId).get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      
      if (updatedData['reviewSummary'] != null) {
        return ReviewSummary.fromMap(updatedData['reviewSummary']);
      }

      return null;
    } catch (e) {
      print('Error getting review summary: $e');
      return null;
    }
  }

  // Get review summary stream that updates in real-time
  Stream<ReviewSummary?> getReviewSummaryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((userDoc) {
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null || userData['reviewSummary'] == null) {
        return null;
      }

      try {
        return ReviewSummary.fromMap(userData['reviewSummary']);
      } catch (e) {
        print('Error parsing review summary: $e');
        return null;
      }
    });
  }

  // Batch recalculate all user review summaries (admin function)
  Future<void> recalculateAllReviewSummaries() async {
    final usersSnapshot = await _firestore.collection('users').get();
    
    for (final userDoc in usersSnapshot.docs) {
      try {
        await _updateUserReviewSummary(userDoc.id);
        print('Updated review summary for user: ${userDoc.id}');
      } catch (e) {
        print('Error updating review summary for user ${userDoc.id}: $e');
      }
    }
  }

  // Search reviews by rating
  Future<List<Review>> getReviewsByRating(String userId, int rating) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .where('rating', isGreaterThanOrEqualTo: rating)
          .where('rating', isLessThan: rating + 1)
          .orderBy('rating')
          .orderBy('createdAt', descending: true)
          .get();

      return reviewsSnapshot.docs
          .map((doc) => Review.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print('Error getting reviews by rating: $e');
      return [];
    }
  }

  // Get recent reviews across the platform (for admin/moderation)
  Future<List<Review>> getRecentReviews({int limit = 50}) async {
    try {
      final reviewsSnapshot = await _firestore
          .collectionGroup('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return reviewsSnapshot.docs
          .map((doc) => Review.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print('Error getting recent reviews: $e');
      return [];
    }
  }

  // Delete a review
  Future<void> deleteReview(String targetUserId, String reviewId) async {
    try {
      // Delete the review document first
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      // Then update the user's review summary after deletion
      await _updateUserReviewSummary(targetUserId);
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  // Check if current user can delete a specific review
  Future<bool> canUserDeleteReview(String currentUserId, Review review) async {
    // Only the reviewer can delete their own review
    return currentUserId == review.reviewerId;
  }

  // Public method to force recalculation of review summary
  Future<void> forceRecalculateReviewSummary(String userId) async {
    print('🔄 [FORCE-RECALC] Forcing review summary recalculation for user: $userId');
    await _updateUserReviewSummary(userId);
    print('🔄 [FORCE-RECALC] Review summary recalculation completed');
  }

  // Diagnostic method to verify review submission
  Future<void> diagnoseReviewSubmission(String targetUserId) async {
    try {
      print('🔧 [DIAGNOSIS] Checking review data for user: $targetUserId');
      
      // Get reviews directly from Firestore
      final reviewsSnapshot = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      print('🔧 [DIAGNOSIS] Found ${reviewsSnapshot.docs.length} reviews in Firestore');
      
      for (final doc in reviewsSnapshot.docs) {
        final review = Review.fromSnapshot(doc);
        print('🔧 [DIAGNOSIS] Review ${review.id}: ${review.rating} stars by ${review.reviewerName}');
      }
      
      // Check review summary in user document
      final userDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['reviewSummary'] != null) {
          final summary = ReviewSummary.fromMap(userData['reviewSummary']);
          print('🔧 [DIAGNOSIS] Review summary: ${summary.averageRating} (${summary.totalReviews} reviews)');
        } else {
          print('🔧 [DIAGNOSIS] ❌ No review summary found in user document');
        }
      } else {
        print('🔧 [DIAGNOSIS] ❌ User document not found');
      }
    } catch (e) {
      print('🔧 [DIAGNOSIS] Error during diagnosis: $e');
    }
  }
} 