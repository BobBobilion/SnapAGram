import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/user_database_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import '../../models/owner_profile.dart';
import '../../models/walker_profile.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/complete_onboarding_screen.dart';
import 'my_stories_screen.dart';
import 'dart:async';

class AccountScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const AccountScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Account',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.grey[600]),
            onPressed: () => _showSignOutDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
          stream: authService.userStream,
          builder: (context, snapshot) {
            final userModel = snapshot.data ?? authService.userModel;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Card
                  _buildProfileCard(user, userModel),
                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(userModel),
                  const SizedBox(height: 24),

                  // Settings Section - Commented out placeholder features
                  /*
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Settings Cards
                  _buildSettingsSection(),
                  const SizedBox(height: 24),
                  */

                  // Privacy Section
                  Text(
                    'Privacy & Security',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPrivacySection(),
                  const SizedBox(height: 24),

                  // Support Section
                  Text(
                    'Support & Legal',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSupportSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileCard(user, UserModel? userModel) {
    final displayName = userModel?.displayName ?? user?.displayName ?? user?.email ?? 'User';
    final profilePicture = userModel?.profilePictureUrl ?? user?.photoURL;
    final handle = userModel?.handle ?? '';
    final bio = userModel?.bio ?? '';
    final createdAt = userModel?.createdAt;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // User Avatar at the top
                GestureDetector(
                  onTap: () => _showProfilePictureViewer(context, profilePicture, userModel),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.getColorShade(userModel, 100),
                    backgroundImage: profilePicture != null
                        ? NetworkImage(profilePicture)
                        : null,
                    child: profilePicture == null
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: AppTheme.getPrimaryColor(userModel),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                
                // User Info below avatar
                Column(
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (handle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        handle,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // User Role and Onboarding Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getColorShade(userModel, 100),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userModel?.roleText ?? 'User',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.getColorShade(userModel, 700),
                            ),
                          ),
                        ),
                        if (userModel?.isOnboardingComplete == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              userModel?.isOwner == true 
                                  ? userModel?.ownerProfile?.city ?? 'No City'
                                  : userModel?.walkerProfile?.city ?? 'No City',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.purple[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    bio,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                // Role-specific detailed information
                if (userModel?.isOnboardingComplete == true) ...[
                  const SizedBox(height: 20),
                  if (userModel?.isOwner == true && userModel?.ownerProfile != null) ...[
                    _buildOwnerDogSection(userModel!.ownerProfile!),
                  ] else if (userModel?.isWalker == true && userModel?.walkerProfile != null) ...[
                    _buildWalkerPreferencesSection(userModel!.walkerProfile!),
                  ],
                ],
                
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Stories', userModel?.storiesCount.toString() ?? '0'),
                    _buildStatItem('Connections', userModel?.connectionsCount.toString() ?? '0'),
                    _buildStatItem('Member Since', _formatDate(createdAt)),
                  ],
                ),
              ],
            ),
          ),
          
          // Edit button positioned at the top right
          Positioned(
            top: 8,
            right: 8,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.edit),
              onSelected: (value) async {
                if (value == 'edit_handle') {
                  final result = await _showEditHandleDialog(context, userModel);
                  if (!context.mounted) return;

                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Handle updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (result is Exception) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating handle: $result'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit_handle',
                  child: Row(
                    children: [
                      Icon(Icons.alternate_email, color: AppTheme.getPrimaryColor(userModel)),
                      const SizedBox(width: 8),
                      Text('Change Handle', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
                // Commented out placeholder feature
                /*
                PopupMenuItem(
                  value: 'edit_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text('Edit Profile', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
                */
              ],
            ),
          ),
          
          // Onboarding status dot positioned at the top left
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: userModel?.isOnboardingComplete == true ? Colors.green : Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerDogSection(OwnerProfile ownerProfile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dog header with photo and name
          Row(
            children: [
              // Dog photo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: ClipOval(
                  child: ownerProfile.dogPhotoUrl != null
                      ? Image.network(
                          ownerProfile.dogPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.pets,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.pets,
                            size: 30,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Dog name and basic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerProfile.dogName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (ownerProfile.dogBreed?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        ownerProfile.dogBreed!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Dog bio if available
          if (ownerProfile.dogBio?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      ownerProfile.dogBio!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 2,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Bio',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Dog stats stacked vertically
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDogStatCapsule(
                      icon: Icons.pets,
                      value: _getSizeLetter(ownerProfile.dogSize),
                      color: Colors.blue[100]!,
                      textColor: Colors.blue[700]!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDogStatCapsule(
                      icon: _getGenderIcon(ownerProfile.dogGender),
                      value: _getGenderText(ownerProfile.dogGender),
                      color: Colors.pink[100]!,
                      textColor: Colors.pink[700]!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDogStatCapsule(
                      icon: Icons.timer,
                      value: ownerProfile.preferredDurationText,
                      color: Colors.green[100]!,
                      textColor: Colors.green[700]!,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Age if available
          if (ownerProfile.dogAge != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.cake, size: 16, color: Colors.orange[600]),
                const SizedBox(width: 6),
                Text(
                  ownerProfile.ageText,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalkerPreferencesSection(WalkerProfile walkerProfile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Walker header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_walk,
                  size: 24,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dog Walker',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (walkerProfile.hasReviews) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${walkerProfile.formattedRating} (${walkerProfile.totalReviews} reviews)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Walker bio if available
          if (walkerProfile.bio?.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                walkerProfile.bio!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Preferences section
          Text(
            'Preferences',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          
          // Dog sizes
          _buildPreferenceRow(
            icon: Icons.pets,
            label: 'Dog Sizes',
            values: walkerProfile.dogSizePreferences.isEmpty 
                ? ['All sizes']
                : walkerProfile.dogSizePreferences.map((s) => s.displayName).toList(),
            color: Colors.green[100]!,
            textColor: Colors.green[700]!,
          ),
          
          const SizedBox(height: 8),
          
          // Walk durations
          _buildPreferenceRow(
            icon: Icons.timer,
            label: 'Walk Durations',
            values: walkerProfile.walkDurations.map((d) => d.displayText).toList(),
            color: Colors.blue[100]!,
            textColor: Colors.blue[700]!,
          ),
          
          const SizedBox(height: 8),
          
          // Availability
          _buildPreferenceRow(
            icon: Icons.schedule,
            label: 'Availability',
            values: walkerProfile.availability.map((a) => a.displayName).toList(),
            color: Colors.orange[100]!,
            textColor: Colors.orange[700]!,
          ),
          
          // Price if available
          if (walkerProfile.pricePerWalk != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
                const SizedBox(width: 6),
                Text(
                  '\$${walkerProfile.pricePerWalk!.toStringAsFixed(0)} per walk',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDogStatCapsule({
    required IconData icon,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow({
    required IconData icon,
    required String label,
    required List<String> values,
    required Color color,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: values.map((value) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else {
      return 'Today';
    }
  }

  Widget _buildStatItem(String label, String value) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.getPrimaryColor(userModel),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(UserModel? userModel) {
    final connectionsCount = userModel?.connectionsCount ?? 0;
    final storiesCount = userModel?.storiesCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.people,
            title: 'Connections',
            value: connectionsCount.toString(),
            color: AppTheme.getPrimaryColor600(userModel),
            userModel: userModel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.photo_library,
            title: 'Stories',
            value: storiesCount.toString(),
            color: Colors.purple,
            userModel: userModel,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    UserModel? userModel,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: title == 'Connections' ? _navigateToFriendsTab : 
               title == 'Stories' ? _navigateToMyStories : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      children: [
        _buildSettingsCard(
          icon: Icons.settings,
          title: 'App Settings',
          subtitle: 'Configure app preferences',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App settings coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle: 'Configure push notifications',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications settings coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.storage,
          title: 'Storage & Data',
          subtitle: 'Manage app storage and data usage',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage settings coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      children: [
        // Redo Onboarding - functional feature
        _buildSettingsCard(
          icon: Icons.refresh,
          title: 'Redo Onboarding',
          subtitle: 'Update your profile and preferences',
          onTap: () => _showRedoOnboardingDialog(context),
        ),
        const SizedBox(height: 8),
        // Commented out placeholder features
        /*
        _buildSettingsCard(
          icon: Icons.privacy_tip,
          title: 'Privacy Settings',
          subtitle: 'Manage your privacy preferences',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Privacy settings coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.security,
          title: 'Security',
          subtitle: 'Two-factor authentication and security',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Security settings coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.block,
          title: 'Blocked Users',
          subtitle: 'Manage blocked users list',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Blocked users coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        */
        _buildDeleteAccountCard(),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      children: [
        // Commented out placeholder features
        /*
        _buildSettingsCard(
          icon: Icons.help,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Help & support coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.feedback,
          title: 'Send Feedback',
          subtitle: 'Share your thoughts with us',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Feedback feature coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.description,
          title: 'Terms of Service',
          subtitle: 'Read our terms and conditions',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Terms of service coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        _buildSettingsCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Privacy policy coming soon!'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),
        */
        _buildSettingsCard(
          icon: Icons.info,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () {
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppTheme.getPrimaryColor(userModel),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDeleteAccountCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.delete_forever,
          color: Colors.red[600],
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red[600],
          ),
        ),
        subtitle: Text(
          'Permanently delete your account and all data',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.red[400],
        ),
        onTap: () => _showDeleteAccountDialog(context),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.red[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delete Account',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action cannot be undone. All your data will be permanently deleted:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Your profile and account information\n'
                    '• All your walk stories and photos\n'
                    '• Your connections and chat history\n'
                    '• All walk session data',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to delete your account?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading 
                      ? null 
                      : () async {
                          setState(() => isLoading = true);

                          try {
                            final authService = ref.read(authServiceProvider);
                            await authService.deleteAccount();
                            
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close dialog
                              
                              // Show success message and navigate to login
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              
                              // Navigate to login screen and clear navigation stack
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting account: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Delete Forever',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    showAboutDialog(
      context: context,
      applicationName: 'DogWalk',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.getPrimaryColor(userModel),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.pets,
          color: Colors.white,
          size: 28,
        ),
      ),
      children: [
        Text(
          'DogWalk connects dog owners with trusted walkers in their area. Track walks in real-time, share photos, and build lasting connections.',
          style: GoogleFonts.poppins(),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Sign Out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(authServiceProvider).signOut();
                // After signing out, navigate to the login screen and clear the navigation stack
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                'Sign Out',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToFriendsTab() {
    // Navigate to friends tab (index 1) using the callback
    widget.onNavigateToTab?.call(1);
  }

  void _navigateToMyStories() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MyStoriesScreen(),
      ),
    );
  }

  Future<dynamic> _showEditHandleDialog(BuildContext context, UserModel? userModel) {
    final handleController = TextEditingController(text: userModel?.handle.replaceFirst('@', '') ?? '');
    bool isLoading = false;
    String? validationError;
    bool isCheckingHandle = false;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to validate handle
            Future<void> validateHandle(String handle) async {
              if (handle.isEmpty) {
                setState(() {
                  validationError = null;
                  isCheckingHandle = false;
                });
                return;
              }

              if (handle.length < 3) {
                setState(() {
                  validationError = 'Handle must be at least 3 characters';
                  isCheckingHandle = false;
                });
                return;
              }

              if (!RegExp(r'^[a-z0-9-]+$').hasMatch(handle)) {
                setState(() {
                  validationError = 'Handle can only contain lowercase letters, numbers, and hyphens';
                  isCheckingHandle = false;
                });
                return;
              }

              // Check if handle is the same as current
              final currentHandle = userModel?.handle.replaceFirst('@', '') ?? '';
              if (handle.toLowerCase() == currentHandle.toLowerCase()) {
                setState(() {
                  validationError = null;
                  isCheckingHandle = false;
                });
                return;
              }

              setState(() {
                isCheckingHandle = true;
                validationError = null;
              });

              try {
                final isAvailable = await UserDatabaseService.isHandleAvailable('@$handle', excludeUserId: userModel?.uid);
                setState(() {
                  isCheckingHandle = false;
                  if (!isAvailable) {
                    validationError = 'Handle is already taken';
                  } else {
                    validationError = null;
                  }
                });
              } catch (e) {
                setState(() {
                  isCheckingHandle = false;
                  validationError = 'Error checking handle availability';
                });
              }
            }

            // Debounced validation
            Timer? debounceTimer;
            void debouncedValidate(String handle) {
              debounceTimer?.cancel();
              debounceTimer = Timer(const Duration(milliseconds: 500), () {
                validateHandle(handle);
              });
            }

            return AlertDialog(
              title: Text(
                'Change Handle',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Your handle must be unique and can contain letters, numbers, and hyphens.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: handleController,
                        decoration: InputDecoration(
                          labelText: 'Handle',
                          hintText: 'Enter your new handle (without @)',
                          prefixText: '@',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.getPrimaryColor(userModel)),
                          ),
                          suffixIcon: isCheckingHandle
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        enabled: !isLoading,
                        onChanged: (value) {
                          // Replace spaces with hyphens
                          final processedValue = value.replaceAll(' ', '-');
                          if (processedValue != value) {
                            handleController.value = TextEditingValue(
                              text: processedValue,
                              selection: TextSelection.collapsed(offset: processedValue.length),
                            );
                          }
                          debouncedValidate(processedValue);
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            validationError != null ? Icons.error_outline : Icons.check_circle_outline,
                            size: 14,
                            color: validationError != null ? Colors.red[400] : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              validationError ?? 'Handle is available',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: validationError != null ? Colors.red[400] : Colors.grey[500],
                              ),
                              softWrap: true,
                              maxLines: null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                TextButton(
                  onPressed: (isLoading || validationError != null || isCheckingHandle)
                      ? null
                      : () async {
                          final newHandle = handleController.text.trim();
                          if (newHandle.isEmpty) return;

                          setState(() => isLoading = true);

                          try {
                            final authService = ref.read(authServiceProvider);
                            await authService.updateHandle(newHandle);

                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            print('Error updating handle: $e'); // Debug log
                            if (context.mounted) {
                              Navigator.of(context).pop(e);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Confirm',
                          style: TextStyle(color: AppTheme.getPrimaryColor(userModel)),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRedoOnboardingDialog(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
                      title: Text(
              'Redo Onboarding',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: AppTheme.getPrimaryColor(userModel),
              ),
            ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You can update your profile information and preferences by redoing the onboarding process.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will allow you to:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Update your role (Owner/Walker)\n'
                '• Change your location\n'
                '• Update dog information (for owners)\n'
                '• Modify preferences and availability',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your existing connections and stories will remain unchanged.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                try {
                  // Reset onboarding status in database
                  final authService = ref.read(authServiceProvider);
                  final currentUser = authService.userModel;
                  
                  if (currentUser != null) {
                    // Reset onboarding completion flag
                    await UserDatabaseService.updateUserProfile(currentUser.uid, {
                      'isOnboardingComplete': false,
                      'role': UserRole.owner.name, // Reset to default
                      'walkerProfile': null,
                      'ownerProfile': null,
                    });
                    
                    // Reload user model to reflect changes
                    await authService.reloadUserModel();
                    
                    // Navigate to onboarding screen
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => CompleteOnboardingScreen(
                            email: currentUser.email,
                            displayName: currentUser.displayName,
                            handle: currentUser.handle.replaceFirst('@', ''),
                          ),
                        ),
                        (route) => false, // Clear navigation stack
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error starting onboarding: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimaryColor(userModel),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Start Onboarding',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProfilePictureViewer(BuildContext context, String? profilePicture, UserModel? userModel) {
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.8),
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: GestureDetector(
                      onTap: () {}, // Prevent tap from bubbling up
                      child: InteractiveViewer(
                        child: profilePicture != null
                            ? Image.network(
                                profilePicture,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: AppTheme.getColorShade(userModel, 100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 100,
                                      color: AppTheme.getPrimaryColor(userModel),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: AppTheme.getColorShade(userModel, 100),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 100,
                                  color: AppTheme.getPrimaryColor(userModel),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Upload button
                Positioned(
                  top: 40,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(userModel),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close viewer first
                        _showUploadProfilePictureDialog(context, userModel);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadProfilePictureDialog(BuildContext context, UserModel? userModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.edit,
              color: AppTheme.getPrimaryColor(userModel),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Update Profile Picture',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you\'d like to update your profile picture.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take Photo',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfilePicture(ImageSource.camera, userModel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadProfilePicture(ImageSource.gallery, userModel);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadProfilePicture(ImageSource source, UserModel? userModel) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Show confirmation dialog
      final shouldUpload = await _showUploadConfirmationDialog(context, pickedFile.path, userModel);
      if (!shouldUpload) {
        // Delete the temporary file
        try {
          await File(pickedFile.path).delete();
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading profile picture...',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Upload image to storage
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.user;
      if (currentUser == null) throw Exception('User not authenticated');

      final String imageUrl = await StorageService.uploadProfilePicture(
        currentUser.uid,
        File(pickedFile.path),
      );

      // Update user profile with new image URL
      await UserDatabaseService.updateUserProfile(currentUser.uid, {
        'profilePictureUrl': imageUrl,
      });

      // Update the auth service user model
      await authService.reloadUserModel();

      // Delete the temporary file
      try {
        await File(pickedFile.path).delete();
      } catch (e) {
        print('Error deleting temporary file: $e');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showUploadConfirmationDialog(BuildContext context, String imagePath, UserModel? userModel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Profile Picture',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.getPrimaryColor(userModel),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to use this as your profile picture?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getPrimaryColor(userModel),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _getSizeLetter(DogSize dogSize) {
    switch (dogSize) {
      case DogSize.small:
        return 'S';
      case DogSize.medium:
        return 'M';
      case DogSize.large:
        return 'L';
      case DogSize.extraLarge:
        return 'XL';
    }
  }

  IconData _getGenderIcon(String? dogGender) {
    if (dogGender == null) return Icons.question_mark;
    switch (dogGender.toLowerCase()) {
      case 'male':
        return Icons.male;
      case 'female':
        return Icons.female;
      default:
        return Icons.question_mark;
    }
  }

  String _getGenderText(String? dogGender) {
    if (dogGender == null) return 'Unknown';
    switch (dogGender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Unknown';
    }
  }
} 