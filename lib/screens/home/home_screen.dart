import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../explore/explore_screen.dart';
import '../friends/friends_screen.dart';
import '../chats/chats_screen.dart';
import '../account/account_screen.dart';
import '../camera/camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  late PageController _pageController;

  // Define the accent blue color from PRD
  static const Color accentBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
    // Handle camera button differently since it's not a page
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(),
        ),
      );
      return;
    }
    
    // Convert bottom nav index to page index (skipping camera)
    int pageIndex = index;
    if (index > 2) pageIndex = index - 1; // Account tab becomes page 3
    
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Redirect to LoginScreen if the user becomes unauthenticated
    final isAuthenticated = context.watch<AuthService>().isAuthenticated;
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
          
          setState(() {
            _currentIndex = bottomNavIndex;
          });
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
                // Explore Tab
                _buildTabItem(
                  icon: Icons.explore,
                  label: 'Explore',
                  index: 0,
                ),
                // Friends Tab
                _buildTabItem(
                  icon: Icons.people,
                  label: 'Friends',
                  index: 1,
                ),
                // Camera Button (integrated into nav bar)
                _buildCameraButton(),
                // Chats Tab
                _buildTabItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chats',
                  index: 3,
                ),
                // Account Tab
                _buildTabItem(
                  icon: Icons.person_outline,
                  label: 'Account',
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
    return GestureDetector(
      onTap: () => _navigateToTab(2), // Use the centralized navigation
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: accentBlue,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: accentBlue.withOpacity(0.3),
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
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _navigateToTab(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? accentBlue : Colors.grey[600],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? accentBlue : Colors.grey[600],
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