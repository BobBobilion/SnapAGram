import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'enums.dart';

class WalkSession {
  final String id;
  final String walkerId;
  final String ownerId;
  final String dogName;
  final WalkStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<LatLng> pathPoints;
  final List<String> photoUrls;
  final double? distance; // in kilometers
  final int? duration; // in minutes
  final String? location; // city/area name
  final Map<String, dynamic> startLocation; // {lat, lng, address}
  final Map<String, dynamic> endLocation; // {lat, lng, address}
  final String? notes; // walker notes about the walk
  final bool isLive; // currently active and being tracked
  final DateTime createdAt;
  final DateTime updatedAt;

  WalkSession({
    required this.id,
    required this.walkerId,
    required this.ownerId,
    required this.dogName,
    this.status = WalkStatus.scheduled,
    this.startTime,
    this.endTime,
    this.pathPoints = const [],
    this.photoUrls = const [],
    this.distance,
    this.duration,
    this.location,
    this.startLocation = const {},
    this.endLocation = const {},
    this.notes,
    this.isLive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walkerId': walkerId,
      'ownerId': ownerId,
      'dogName': dogName,
      'status': status.name,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'pathPoints': pathPoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'photoUrls': photoUrls,
      'distance': distance,
      'duration': duration,
      'location': location,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'notes': notes,
      'isLive': isLive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory WalkSession.fromMap(Map<String, dynamic> map) {
    return WalkSession(
      id: map['id'] ?? '',
      walkerId: map['walkerId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      dogName: map['dogName'] ?? '',
      status: WalkStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => WalkStatus.scheduled,
      ),
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      pathPoints: (map['pathPoints'] as List<dynamic>?)
          ?.map((point) => LatLng(
                point['latitude'] ?? 0.0,
                point['longitude'] ?? 0.0,
              ))
          .toList() ?? [],
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      distance: map['distance']?.toDouble(),
      duration: map['duration'],
      location: map['location'],
      startLocation: Map<String, dynamic>.from(map['startLocation'] ?? {}),
      endLocation: Map<String, dynamic>.from(map['endLocation'] ?? {}),
      notes: map['notes'],
      isLive: map['isLive'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory WalkSession.fromSnapshot(DocumentSnapshot snapshot) {
    return WalkSession.fromMap(snapshot.data() as Map<String, dynamic>);
  }

  WalkSession copyWith({
    WalkStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    List<LatLng>? pathPoints,
    List<String>? photoUrls,
    double? distance,
    int? duration,
    String? location,
    Map<String, dynamic>? startLocation,
    Map<String, dynamic>? endLocation,
    String? notes,
    bool? isLive,
    DateTime? updatedAt,
  }) {
    return WalkSession(
      id: id,
      walkerId: walkerId,
      ownerId: ownerId,
      dogName: dogName,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pathPoints: pathPoints ?? this.pathPoints,
      photoUrls: photoUrls ?? this.photoUrls,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      notes: notes ?? this.notes,
      isLive: isLive ?? this.isLive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Getters for formatted display
  String get statusText {
    switch (status) {
      case WalkStatus.scheduled:
        return 'Scheduled';
      case WalkStatus.active:
        return 'In Progress';
      case WalkStatus.paused:
        return 'Paused';
      case WalkStatus.completed:
        return 'Completed';
      case WalkStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get durationText {
    if (duration == null) return 'Duration unknown';
    final hours = duration! ~/ 60;
    final minutes = duration! % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get distanceText {
    if (distance == null) return 'Distance unknown';
    if (distance! < 1) {
      return '${(distance! * 1000).round()}m';
    } else {
      return '${distance!.toStringAsFixed(1)}km';
    }
  }

  String get walkDateText {
    if (startTime == null) return 'No date';
    final now = DateTime.now();
    final difference = now.difference(startTime!);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${startTime!.day}/${startTime!.month}/${startTime!.year}';
    }
  }

  bool get isActive => status == WalkStatus.active;
  bool get isCompleted => status == WalkStatus.completed;
  bool get hasPath => pathPoints.isNotEmpty;
  bool get hasPhotos => photoUrls.isNotEmpty;
  
  // Calculate actual duration from start/end times
  int? get actualDurationMinutes {
    if (startTime == null) return null;
    final endTimeToUse = endTime ?? (status == WalkStatus.active ? DateTime.now() : null);
    if (endTimeToUse == null) return null;
    return endTimeToUse.difference(startTime!).inMinutes;
  }
} 