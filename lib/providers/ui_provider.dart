import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the current index of the BottomNavigationBar in HomeScreen.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to trigger refresh of the explore screen
final exploreRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Helper function to trigger explore screen refresh
void triggerExploreRefresh(WidgetRef ref) {
  ref.read(exploreRefreshTriggerProvider.notifier).state++;
} 