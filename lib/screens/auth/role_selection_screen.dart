import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/enums.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String email;
  final String displayName;
  final String handle;

  const RoleSelectionScreen({
    super.key,
    required this.email,
    required this.displayName,
    required this.handle,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  UserRole? selectedRole;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // DogWalk blue color palette
  static const Color cornflowerBlue = Color(0xFF6495ED);
  static const Color skyBlue = Color(0xFF87CEEB);
  static const Color lightBlueWhite = Color(0xFFFAFAFF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectRole(UserRole role) {
    setState(() {
      selectedRole = role;
    });
    
    // Add haptic feedback
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // HapticFeedback.lightImpact();
    }
  }

  void _continueToOnboarding() {
    if (selectedRole == null) return;
    
    // Navigate to respective onboarding screen
    if (selectedRole == UserRole.walker) {
      Navigator.pushNamed(
        context,
        '/walker-onboarding',
        arguments: {
          'email': widget.email,
          'displayName': widget.displayName,
          'handle': widget.handle,
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        '/owner-onboarding',
        arguments: {
          'email': widget.email,
          'displayName': widget.displayName,
          'handle': widget.handle,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlueWhite,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App Logo/Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cornflowerBlue,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: cornflowerBlue.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.pets,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Welcome text
                            Text(
                              'Welcome to DogWalk',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose your role to get started',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Role Selection Cards
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            // Walker Card
                            _buildRoleCard(
                              role: UserRole.walker,
                              title: 'I\'m a Walker',
                              subtitle: 'I want to walk dogs and earn money',
                              icon: Icons.directions_walk,
                              color: cornflowerBlue,
                              features: [
                                'Set your availability',
                                'Choose dog sizes you prefer',
                                'Track walks with GPS',
                                'Build your reputation',
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Owner Card
                            _buildRoleCard(
                              role: UserRole.owner,
                              title: 'I\'m a Dog Owner',
                              subtitle: 'I need someone to walk my dog',
                              icon: Icons.pets,
                              color: skyBlue,
                              features: [
                                'Find trusted walkers',
                                'Track your dog\'s walks live',
                                'Receive photos during walks',
                                'Rate and review walkers',
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Continue Button
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: selectedRole != null ? _continueToOnboarding : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedRole != null ? cornflowerBlue : Colors.grey[300],
                                  foregroundColor: Colors.white,
                                  elevation: selectedRole != null ? 8 : 0,
                                  shadowColor: cornflowerBlue.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Continue',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = selectedRole == role;
    
    return GestureDetector(
      onTap: () => _selectRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              blurRadius: isSelected ? 15 : 5,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Features list
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
} 