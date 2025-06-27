import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the current index of the BottomNavigationBar in HomeScreen.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0); 