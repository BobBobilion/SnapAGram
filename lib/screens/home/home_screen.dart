import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../explore/explore_screen.dart';
import '../friends/friends_screen.dart';
import '../chats/chats_screen.dart';
import '../account/account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Define the accent blue color from PRD
  static const Color accentBlue = Color(0xFF2196F3);

  final List<Widget> _screens = [
    const ExploreScreen(),
    const FriendsScreen(),
    const PlaceholderScreen(), // Post screen will be handled by FAB
    const ChatsScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: IndexedStack(
        index: _currentIndex,
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
      onTap: () {
        // Navigate to camera/post screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera/Post feature coming soon!'),
            duration: Duration(milliseconds: 500),
          ),
        );
      },
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
        setState(() {
          _currentIndex = index;
        });
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