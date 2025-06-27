import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapagram/providers/ui_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../explore/explore_screen.dart';
import '../friends/friends_screen.dart';
import '../chats/chats_screen.dart';
import '../account/account_screen.dart';
import '../camera/camera_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late List<Widget> _screens;
  late PageController _pageController;

  // Colors are now dynamically determined by user role via AppTheme

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: ref.read(bottomNavIndexProvider));
    _screens = [
      const ExploreScreen(),
      const FriendsScreen(),
      const ChatsScreen(),
      AccountScreen(onNavigateToTab: _navigateToTab),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    ref.read(bottomNavIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the provider to command the page controller
    ref.listen<int>(bottomNavIndexProvider, (prev, next) {
      // Handle camera button differently since it's not a page
      if (next == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraScreen(),
          ),
        ).then((_) {
          // When returning from camera, restore previous index
          // to prevent camera tab from looking "selected"
          ref.read(bottomNavIndexProvider.notifier).state = prev ?? 0;
        });
        return;
      }

      // Convert bottom nav index to page index (skipping camera)
      int pageIndex = next;
      if (next > 2) pageIndex = next - 1; // Account tab becomes page 3

      if (_pageController.hasClients && _pageController.page?.round() != pageIndex) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    // Redirect to LoginScreen if the user becomes unauthenticated
    final isAuthenticated = ref.watch(authServiceProvider).isAuthenticated;
    if (!isAuthenticated) {
      // Ensure navigation happens after the current frame to avoid build conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(), // Better swipe feel
        onPageChanged: (index) {
          // Convert page index back to bottom nav index (accounting for camera)
          int bottomNavIndex = index;
          if (index >= 2) bottomNavIndex = index + 1; // Skip camera index

          // Update provider instead of local state
          ref.read(bottomNavIndexProvider.notifier).state = bottomNavIndex;
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Stories Tab (Walk Stories)
                _buildTabItem(
                  icon: Icons.auto_stories,
                  label: 'Stories',
                  index: 0,
                ),
                // Find Tab (Walker-Owner Matching)
                _buildTabItem(
                  icon: Icons.search,
                  label: 'Find',
                  index: 1,
                ),
                // Camera Button (Walk Photos)
                _buildCameraButton(),
                // Chats Tab (Walker-Owner Communication)
                _buildTabItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chats',
                  index: 3,
                ),
                // Profile Tab (Role-based Profiles)
                _buildTabItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  index: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.userModel;
    final accentColor = AppTheme.getPrimaryColor(user);
    
    return GestureDetector(
      onTap: () => _navigateToTab(2), // Use the centralized navigation
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.userModel;
    final isSelected = ref.watch(bottomNavIndexProvider) == index;
    
    // Check if this is the chats tab and get unread count
    final isChatsTab = index == 3;
    final unreadCount = isChatsTab 
        ? ref.watch(unreadMessageCountProvider).value ?? 0
        : 0;
    
    return GestureDetector(
      onTap: () {
        _navigateToTab(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: AppTheme.getIconColor(user, isSelected),
                size: 24,
              ),
              if (isChatsTab && unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: AppTheme.getTextColor(user, isSelected),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('This is a placeholder screen'),
      ),
    );
  }
} 