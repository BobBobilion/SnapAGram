import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class OwnerProfile {
  final String dogName;
  final String? dogPhotoUrl;
  final DogSize dogSize;
  final String? dogBio;
  final String city;
  final List<WalkDuration> preferredDurations;
  final String? specialInstructions;
  final String? dogBreed;
  final int? dogAge; // in years
  final String? dogGender;
  final List<String> walkHistory; // walk session IDs
  final bool isActivelyLooking;
  final DateTime? lastWalkDate;
  final Map<String, dynamic> dogPersonality; // energetic, calm, social, etc.
  final List<String> connectedWalkers; // walker UIDs

  OwnerProfile({
    required this.dogName,
    this.dogPhotoUrl,
    required this.dogSize,
    this.dogBio,
    required this.city,
    this.preferredDurations = const [],
    this.specialInstructions,
    this.dogBreed,
    this.dogAge,
    this.dogGender,
    this.walkHistory = const [],
    this.isActivelyLooking = true,
    this.lastWalkDate,
    this.dogPersonality = const {},
    this.connectedWalkers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'dogName': dogName,
      'dogPhotoUrl': dogPhotoUrl,
      'dogSize': dogSize.name,
      'dogBio': dogBio,
      'city': city,
      'preferredDurations': preferredDurations.map((e) => e.name).toList(),
      'specialInstructions': specialInstructions,
      'dogBreed': dogBreed,
      'dogAge': dogAge,
      'dogGender': dogGender,
      'walkHistory': walkHistory,
      'isActivelyLooking': isActivelyLooking,
      'lastWalkDate': lastWalkDate != null ? Timestamp.fromDate(lastWalkDate!) : null,
      'dogPersonality': dogPersonality,
      'connectedWalkers': connectedWalkers,
    };
  }

  factory OwnerProfile.fromMap(Map<String, dynamic> map) {
    return OwnerProfile(
      dogName: map['dogName'] ?? '',
      dogPhotoUrl: map['dogPhotoUrl'],
      dogSize: DogSize.values.firstWhere(
        (size) => size.name == map['dogSize'], 
        orElse: () => DogSize.medium,
      ),
      dogBio: map['dogBio'],
      city: map['city'] ?? '',
      preferredDurations: (map['preferredDurations'] as List<dynamic>?)
          ?.map((e) => WalkDuration.values.firstWhere((duration) => duration.name == e))
          .toList() ?? [],
      specialInstructions: map['specialInstructions'],
      dogBreed: map['dogBreed'],
      dogAge: map['dogAge'],
      dogGender: map['dogGender'],
      walkHistory: List<String>.from(map['walkHistory'] ?? []),
      isActivelyLooking: map['isActivelyLooking'] ?? true,
      lastWalkDate: (map['lastWalkDate'] as Timestamp?)?.toDate(),
      dogPersonality: Map<String, dynamic>.from(map['dogPersonality'] ?? {}),
      connectedWalkers: List<String>.from(map['connectedWalkers'] ?? []),
    );
  }

  OwnerProfile copyWith({
    String? dogName,
    String? dogPhotoUrl,
    DogSize? dogSize,
    String? dogBio,
    String? city,
    List<WalkDuration>? preferredDurations,
    String? specialInstructions,
    String? dogBreed,
    int? dogAge,
    String? dogGender,
    List<String>? walkHistory,
    bool? isActivelyLooking,
    DateTime? lastWalkDate,
    Map<String, dynamic>? dogPersonality,
    List<String>? connectedWalkers,
  }) {
    return OwnerProfile(
      dogName: dogName ?? this.dogName,
      dogPhotoUrl: dogPhotoUrl ?? this.dogPhotoUrl,
      dogSize: dogSize ?? this.dogSize,
      dogBio: dogBio ?? this.dogBio,
      city: city ?? this.city,
      preferredDurations: preferredDurations ?? this.preferredDurations,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      dogBreed: dogBreed ?? this.dogBreed,
      dogAge: dogAge ?? this.dogAge,
      dogGender: dogGender ?? this.dogGender,
      walkHistory: walkHistory ?? this.walkHistory,
      isActivelyLooking: isActivelyLooking ?? this.isActivelyLooking,
      lastWalkDate: lastWalkDate ?? this.lastWalkDate,
      dogPersonality: dogPersonality ?? this.dogPersonality,
      connectedWalkers: connectedWalkers ?? this.connectedWalkers,
    );
  }

  String get dogSizeText {
    switch (dogSize) {
      case DogSize.small:
        return 'Small';
      case DogSize.medium:
        return 'Medium';
      case DogSize.large:
        return 'Large';
      case DogSize.extraLarge:
        return 'Extra Large';
    }
  }

  String get ageText {
    if (dogAge == null) return 'Age unknown';
    if (dogAge == 1) return '1 year old';
    return '$dogAge years old';
  }

  String get preferredDurationText {
    if (preferredDurations.isEmpty) return 'Any duration';
    return preferredDurations.map((d) => d.displayText).join(', ');
  }

  int get totalWalks => walkHistory.length;

  bool get hasWalkHistory => walkHistory.isNotEmpty;
} 