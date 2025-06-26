import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class WalkSummary {
  final String id;
  final String ownerId;
  final String dogName;
  final String? dogPhotoUrl;
  final DateTime walkDate;
  final int durationMinutes;
  final double? distance;
  final List<String> photoUrls;
  final String? location;

  WalkSummary({
    required this.id,
    required this.ownerId,
    required this.dogName,
    this.dogPhotoUrl,
    required this.walkDate,
    required this.durationMinutes,
    this.distance,
    this.photoUrls = const [],
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'dogName': dogName,
      'dogPhotoUrl': dogPhotoUrl,
      'walkDate': Timestamp.fromDate(walkDate),
      'durationMinutes': durationMinutes,
      'distance': distance,
      'photoUrls': photoUrls,
      'location': location,
    };
  }

  factory WalkSummary.fromMap(Map<String, dynamic> map) {
    return WalkSummary(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      dogName: map['dogName'] ?? '',
      dogPhotoUrl: map['dogPhotoUrl'],
      walkDate: (map['walkDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: map['durationMinutes'] ?? 0,
      distance: map['distance']?.toDouble(),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      location: map['location'],
    );
  }
}

class WalkerProfile {
  final String city;
  final List<DogSize> dogSizePreferences;
  final List<WalkDuration> walkDurations;
  final List<Availability> availability;
  final double averageRating;
  final int totalReviews;
  final List<WalkSummary> recentWalks;
  final String? bio;
  final bool isAvailable;
  final DateTime? lastActiveDate;
  final Map<String, dynamic> serviceArea; // coordinates for service area
  final double? pricePerWalk;

  WalkerProfile({
    required this.city,
    this.dogSizePreferences = const [],
    this.walkDurations = const [],
    this.availability = const [],
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.recentWalks = const [],
    this.bio,
    this.isAvailable = true,
    this.lastActiveDate,
    this.serviceArea = const {},
    this.pricePerWalk,
  });

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'dogSizePreferences': dogSizePreferences.map((e) => e.name).toList(),
      'walkDurations': walkDurations.map((e) => e.name).toList(),
      'availability': availability.map((e) => e.name).toList(),
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'recentWalks': recentWalks.map((e) => e.toMap()).toList(),
      'bio': bio,
      'isAvailable': isAvailable,
      'lastActiveDate': lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
      'serviceArea': serviceArea,
      'pricePerWalk': pricePerWalk,
    };
  }

  factory WalkerProfile.fromMap(Map<String, dynamic> map) {
    return WalkerProfile(
      city: map['city'] ?? '',
      dogSizePreferences: (map['dogSizePreferences'] as List<dynamic>?)
          ?.map((e) => DogSize.values.firstWhere((size) => size.name == e))
          .toList() ?? [],
      walkDurations: (map['walkDurations'] as List<dynamic>?)
          ?.map((e) => WalkDuration.values.firstWhere((duration) => duration.name == e))
          .toList() ?? [],
      availability: (map['availability'] as List<dynamic>?)
          ?.map((e) => Availability.values.firstWhere((avail) => avail.name == e))
          .toList() ?? [],
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      recentWalks: (map['recentWalks'] as List<dynamic>?)
          ?.map((e) => WalkSummary.fromMap(e))
          .toList() ?? [],
      bio: map['bio'],
      isAvailable: map['isAvailable'] ?? true,
      lastActiveDate: (map['lastActiveDate'] as Timestamp?)?.toDate(),
      serviceArea: Map<String, dynamic>.from(map['serviceArea'] ?? {}),
      pricePerWalk: map['pricePerWalk']?.toDouble(),
    );
  }

  WalkerProfile copyWith({
    String? city,
    List<DogSize>? dogSizePreferences,
    List<WalkDuration>? walkDurations,
    List<Availability>? availability,
    double? averageRating,
    int? totalReviews,
    List<WalkSummary>? recentWalks,
    String? bio,
    bool? isAvailable,
    DateTime? lastActiveDate,
    Map<String, dynamic>? serviceArea,
    double? pricePerWalk,
  }) {
    return WalkerProfile(
      city: city ?? this.city,
      dogSizePreferences: dogSizePreferences ?? this.dogSizePreferences,
      walkDurations: walkDurations ?? this.walkDurations,
      availability: availability ?? this.availability,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      recentWalks: recentWalks ?? this.recentWalks,
      bio: bio ?? this.bio,
      isAvailable: isAvailable ?? this.isAvailable,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      serviceArea: serviceArea ?? this.serviceArea,
      pricePerWalk: pricePerWalk ?? this.pricePerWalk,
    );
  }

  String get formattedRating => averageRating.toStringAsFixed(1);
  
  bool get hasReviews => totalReviews > 0;
  
  String get availabilityText {
    if (availability.isEmpty) return 'No availability set';
    return availability.map((a) => a.name.toUpperCase()).join(', ');
  }
} 