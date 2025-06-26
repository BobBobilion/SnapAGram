enum UserRole { 
  walker, 
  owner;
  
  String get displayName {
    switch (this) {
      case UserRole.walker:
        return 'Walker';
      case UserRole.owner:
        return 'Owner';
    }
  }
}

enum DogSize { 
  small, 
  medium, 
  large,
  extraLarge;
  
  String get displayName {
    switch (this) {
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
}

enum WalkDuration { 
  fifteen(15), 
  thirty(30), 
  fortyFive(45), 
  sixty(60), 
  sixtyPlus(90);
  
  const WalkDuration(this.minutes);
  final int minutes;
  
  String get displayText {
    switch (this) {
      case WalkDuration.fifteen:
        return '15 min';
      case WalkDuration.thirty:
        return '30 min';
      case WalkDuration.fortyFive:
        return '45 min';
      case WalkDuration.sixty:
        return '1 hour';
      case WalkDuration.sixtyPlus:
        return '1+ hours';
    }
  }
  
  String get displayName => displayText;
}

enum Availability { 
  morning, 
  afternoon, 
  evening;
  
  String get displayName {
    switch (this) {
      case Availability.morning:
        return 'Morning';
      case Availability.afternoon:
        return 'Afternoon';
      case Availability.evening:
        return 'Evening';
    }
  }
}

enum WalkStatus { 
  scheduled, 
  active, 
  paused, 
  completed, 
  cancelled 
}

enum ConnectionStatus {
  pending,
  accepted,
  declined,
  blocked
} 