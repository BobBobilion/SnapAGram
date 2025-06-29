import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String reviewerId; // User who left the review
  final String reviewerName;
  final String reviewerProfilePictureUrl;
  final String targetUserId; // User being reviewed
  final double rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;
  final bool wasAiGenerated; // Track if review was AI-generated or user-written
  final String? aiSuggestion; // Store original AI suggestion for reference

  Review({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerProfilePictureUrl,
    required this.targetUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.wasAiGenerated = false,
    this.aiSuggestion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerProfilePictureUrl': reviewerProfilePictureUrl,
      'targetUserId': targetUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'wasAiGenerated': wasAiGenerated,
      'aiSuggestion': aiSuggestion,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map, String documentId) {
    return Review(
      id: documentId,
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      reviewerProfilePictureUrl: map['reviewerProfilePictureUrl'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      rating: _parseDoubleValue(map['rating']) ?? 0.0,
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      wasAiGenerated: map['wasAiGenerated'] ?? false,
      aiSuggestion: map['aiSuggestion'],
    );
  }

  // Helper method to safely parse double values from Firestore
  static double? _parseDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  factory Review.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Review.fromMap(data, snapshot.id);
  }
}

class ReviewSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingBreakdown; // {5: 10, 4: 5, 3: 2, 2: 1, 1: 0}
  final DateTime lastUpdated;

  ReviewSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingBreakdown,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    // Convert rating breakdown keys to strings for Firestore compatibility
    final ratingBreakdownForStorage = <String, dynamic>{};
    ratingBreakdown.forEach((key, value) {
      ratingBreakdownForStorage[key.toString()] = value;
    });

    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingBreakdown': ratingBreakdownForStorage,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory ReviewSummary.fromMap(Map<String, dynamic> map) {
    final ratingBreakdown = <int, int>{};
    if (map['ratingBreakdown'] != null) {
      final breakdown = map['ratingBreakdown'] as Map<String, dynamic>;
      breakdown.forEach((key, value) {
        try {
          // Parse key to int (handles string keys from Firestore)
          final intKey = int.parse(key.toString());
          
          // Convert value to int (handles various number types)
          int intValue;
          if (value is int) {
            intValue = value;
          } else if (value is double) {
            intValue = value.round();
          } else if (value is String) {
            intValue = int.parse(value);
          } else {
            intValue = 0; // fallback
          }
          
          ratingBreakdown[intKey] = intValue;
        } catch (e) {
          print('Error parsing rating breakdown entry $key: $value - $e');
          // Skip invalid entries
        }
      });
    }

    return ReviewSummary(
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalReviews: _parseIntValue(map['totalReviews']) ?? 0,
      ratingBreakdown: ratingBreakdown,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  String get formattedRating => averageRating.toStringAsFixed(1);
  
  bool get hasReviews => totalReviews > 0;

  // Helper method to safely parse integer values from Firestore
  static int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class AiReviewSuggestion {
  final double suggestedRating;
  final String suggestedComment;
  final List<String> conversationHighlights;
  final List<String> imageAnalysis;
  final String analysisReasoning;

  AiReviewSuggestion({
    required this.suggestedRating,
    required this.suggestedComment,
    required this.conversationHighlights,
    required this.imageAnalysis,
    required this.analysisReasoning,
  });

  factory AiReviewSuggestion.fromMap(Map<String, dynamic> map) {
    return AiReviewSuggestion(
      suggestedRating: (map['suggestedRating'] ?? 3.0).toDouble(),
      suggestedComment: map['suggestedComment'] ?? '',
      conversationHighlights: List<String>.from(map['conversationHighlights'] ?? []),
      imageAnalysis: List<String>.from(map['imageAnalysis'] ?? []),
      analysisReasoning: map['analysisReasoning'] ?? '',
    );
  }
} 