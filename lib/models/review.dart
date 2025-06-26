import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String walkSessionId;
  final String walkerId;
  final String ownerId;
  final String ownerName; // display name for the review
  final String? ownerPhotoUrl;
  final String dogName;
  final int rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final Map<String, dynamic> walkDetails; // duration, distance, photos count
  final List<String> tags; // helpful, punctual, caring, etc.
  final bool isAnonymous; // hide owner name/photo
  final String? walkerResponse; // walker can respond to reviews
  final DateTime? walkerResponseDate;

  Review({
    required this.id,
    required this.walkSessionId,
    required this.walkerId,
    required this.ownerId,
    required this.ownerName,
    this.ownerPhotoUrl,
    required this.dogName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.walkDetails = const {},
    this.tags = const [],
    this.isAnonymous = false,
    this.walkerResponse,
    this.walkerResponseDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walkSessionId': walkSessionId,
      'walkerId': walkerId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhotoUrl': ownerPhotoUrl,
      'dogName': dogName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isEdited': isEdited,
      'walkDetails': walkDetails,
      'tags': tags,
      'isAnonymous': isAnonymous,
      'walkerResponse': walkerResponse,
      'walkerResponseDate': walkerResponseDate != null ? Timestamp.fromDate(walkerResponseDate!) : null,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      walkSessionId: map['walkSessionId'] ?? '',
      walkerId: map['walkerId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerPhotoUrl: map['ownerPhotoUrl'],
      dogName: map['dogName'] ?? '',
      rating: map['rating'] ?? 1,
      comment: map['comment'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isEdited: map['isEdited'] ?? false,
      walkDetails: Map<String, dynamic>.from(map['walkDetails'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
      isAnonymous: map['isAnonymous'] ?? false,
      walkerResponse: map['walkerResponse'],
      walkerResponseDate: (map['walkerResponseDate'] as Timestamp?)?.toDate(),
    );
  }

  factory Review.fromSnapshot(DocumentSnapshot snapshot) {
    return Review.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  Review copyWith({
    int? rating,
    String? comment,
    DateTime? updatedAt,
    bool? isEdited,
    List<String>? tags,
    bool? isAnonymous,
    String? walkerResponse,
    DateTime? walkerResponseDate,
  }) {
    return Review(
      id: id,
      walkSessionId: walkSessionId,
      walkerId: walkerId,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerPhotoUrl: ownerPhotoUrl,
      dogName: dogName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      walkDetails: walkDetails,
      tags: tags ?? this.tags,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      walkerResponse: walkerResponse ?? this.walkerResponse,
      walkerResponseDate: walkerResponseDate ?? this.walkerResponseDate,
    );
  }

  // Getters for formatted display
  String get ratingText => '$rating/5 stars';
  
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String get displayName {
    if (isAnonymous) return 'Anonymous';
    return ownerName;
  }

  String? get displayPhotoUrl {
    if (isAnonymous) return null;
    return ownerPhotoUrl;
  }

  bool get hasComment => comment != null && comment!.isNotEmpty;
  bool get hasTags => tags.isNotEmpty;
  bool get hasWalkerResponse => walkerResponse != null && walkerResponse!.isNotEmpty;
  
  // Check if review can be edited (within 24 hours)
  bool get canBeEdited {
    final now = DateTime.now();
    final timeDifference = now.difference(createdAt);
    return timeDifference.inHours < 24;
  }

  // Get star display (★★★★☆)
  String get starDisplay {
    const filledStar = '★';
    const emptyStar = '☆';
    return filledStar * rating + emptyStar * (5 - rating);
  }

  // Check if this is a positive review
  bool get isPositive => rating >= 4;
  bool get isNegative => rating <= 2;
  bool get isNeutral => rating == 3;
} 