import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapagram/models/owner_profile.dart';
import 'package:snapagram/models/walker_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_database_service.dart';
import '../../services/review_service.dart';
import '../../models/user_model.dart';
import '../../models/review.dart';
import '../../utils/app_theme.dart';
import '../../widgets/rating_display_widget.dart';
import '../../widgets/reviews_list_widget.dart';

import '../account/my_stories_screen.dart';
import 'review_submission_screen.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  Future<void> _refreshProfile(WidgetRef ref, String userId) async {
    print('🔄 [PROFILE] Refreshing profile data with aggressive cache clearing...');
    
    try {
      final reviewService = ref.read(reviewServiceProvider);
      
      // Step 1: Force complete recalculation of review summary
      print('🔄 [PROFILE] Forcing review summary recalculation...');
      await reviewService.forceRecalculateReviewSummary(userId);
      
      // Step 2: Run diagnostic to verify data is current
      await reviewService.diagnoseReviewSubmission(userId);
      
      // Step 3: Clear all providers aggressively
      print('🔄 [PROFILE] Invalidating all providers...');
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
      ref.invalidate(reviewServiceProvider);
      
      // Step 4: Wait for database propagation
      await Future.delayed(const Duration(milliseconds: 1200));
      
      // Step 5: Force another provider refresh
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
      ref.invalidate(reviewServiceProvider);
      
      // Step 6: Final delay for UI updates
      await Future.delayed(const Duration(milliseconds: 300));
      
      print('🔄 [PROFILE] Aggressive refresh completed');
    } catch (e) {
      print('🔄 [PROFILE] Refresh error: $e');
      // Even if there's an error, still try to refresh providers
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
      ref.invalidate(reviewServiceProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileStream = ref.watch(enhancedUserProfileProvider(userId));
    final authService = ref.watch(authServiceProvider);
    final currentUser = authService.userModel;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () => _refreshProfile(ref, userId),
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
            tooltip: 'Refresh profile',
          ),
          if (currentUser != null && currentUser.uid != userId)
            _buildFriendshipButton(context, ref, currentUser, userId),
        ],
      ),
      body: SafeArea(
        child: userProfileStream.when(
          data: (userModel) {
            if (userModel == null) {
              return const Center(child: Text('User not found.'));
            }
            return RefreshIndicator(
              onRefresh: () => _refreshProfile(ref, userModel.uid),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(context, userModel),
                    const SizedBox(height: 24),
                    _buildQuickStats(context, userModel),
                    const SizedBox(height: 24),
                    _buildReviewsSection(context, ref, userModel, currentUser),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Widget _buildFriendshipButton(BuildContext context, WidgetRef ref, UserModel currentUser, String targetUserId) {
    final isFriend = currentUser.connections.contains(targetUserId);
    final hasSentRequest = currentUser.sentRequests.contains(targetUserId);

    if (isFriend) {
      return TextButton.icon(
        onPressed: () {},
        icon: Icon(Icons.check, color: Colors.green),
        label: Text(
          'Friends',
          style: GoogleFonts.poppins(
            color: Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (hasSentRequest) {
      return TextButton.icon(
        onPressed: () {},
        icon: Icon(Icons.hourglass_top, color: Colors.grey[600]),
        label: Text(
          'Request Sent',
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () => _showAddFriendDialog(context, ref, currentUser.uid, targetUserId),
      icon: Icon(Icons.person_add, color: Colors.grey[600]),
      label: Text(
        'Add',
        style: GoogleFonts.poppins(
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref, String currentUserId, String targetUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Friend Request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              UserDatabaseService.sendConnectionRequest(currentUserId, targetUserId);
              Navigator.of(context).pop();
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserModel userModel) {
    final displayName = userModel.displayName;
    final profilePicture = userModel.profilePictureUrl;
    final handle = userModel.handle;
    final bio = userModel.bio;
    final createdAt = userModel.createdAt;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
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
            const SizedBox(height: 16),
            Text(
              displayName ?? 'User',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (handle != null && handle.isNotEmpty) ...[
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
            if (bio != null && bio.isNotEmpty) ...[
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
            if (userModel.isOnboardingComplete == true) ...[
              const SizedBox(height: 20),
              if (userModel.isOwner == true && userModel.ownerProfile != null) ...[
                _buildOwnerDogSection(userModel.ownerProfile!),
              ] else if (userModel.isWalker == true && userModel.walkerProfile != null) ...[
                _buildWalkerPreferencesSection(userModel.walkerProfile!),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Stories', userModel.storiesCount.toString(), userModel),
                _buildStatItem('Connections', userModel.connectionsCount.toString(), userModel),
                _buildStatItem('Member Since', _formatDate(createdAt), userModel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, UserModel userModel) {
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

  Widget _buildQuickStats(BuildContext context, UserModel userModel) {
    final connectionsCount = userModel.connectionsCount;
    final storiesCount = userModel.storiesCount;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            context,
            icon: Icons.people,
            title: 'Connections',
            value: connectionsCount.toString(),
            color: AppTheme.getPrimaryColor600(userModel),
            userModel: userModel,
            onTap: () {}, // No action on public profile
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            context,
            icon: Icons.photo_library,
            title: 'Stories',
            value: storiesCount.toString(),
            color: Colors.purple,
            userModel: userModel,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MyStoriesScreen(userId: userModel.uid),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required UserModel userModel,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
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

  Widget _buildOwnerDogSection(OwnerProfile ownerProfile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(6),
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
                      value: ownerProfile.dogSizeText,
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
                      icon: Icons.male,
                      value: ownerProfile.dogGender ?? 'Not specified',
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
        borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(6),
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
                  '\${walkerProfile.pricePerWalk!.toStringAsFixed(0)} per walk',
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

  Widget _buildReviewsSection(BuildContext context, WidgetRef ref, UserModel userModel, UserModel? currentUser) {
    return Consumer(
      builder: (context, ref, child) {
        // Show reviews section for all users, but only allow submission for friends
        final reviewService = ref.watch(reviewServiceProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviews Header with Rating Summary
            StreamBuilder<ReviewSummary?>(
              stream: reviewService.getReviewSummaryStream(userModel.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                final reviewSummary = snapshot.data;
                if (reviewSummary == null || !reviewSummary.hasReviews) {
                  return _buildNoReviewsCard(context, ref, userModel, currentUser);
                }

                return _buildReviewsSummaryCard(context, reviewSummary, userModel, currentUser);
              },
            ),
            const SizedBox(height: 16),
            // Reviews List with Refresh Capability
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                                  child: RefreshIndicator(
                    onRefresh: () => _refreshProfile(ref, userModel.uid),
                    child: ReviewsListWidget(
                      key: ValueKey('reviews_${userModel.uid}'),
                      userId: userModel.uid,
                      showUserInfo: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      currentUserId: currentUser?.uid,
                    ),
                  ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsSummaryCard(BuildContext context, ReviewSummary reviewSummary, UserModel userModel, UserModel? currentUser) {
    return Consumer(
      builder: (context, ref, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with title and write review button
                Row(
                  children: [
                    Icon(
                      Icons.rate_review,
                      size: 24,
                      color: AppTheme.getPrimaryColor(userModel),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    if (currentUser != null && currentUser.uid != userModel.uid)
                      FutureBuilder<bool>(
                        future: ref.read(reviewServiceProvider).canUserReview(currentUser.uid, userModel.uid),
                        builder: (context, snapshot) {
                          final canReview = snapshot.data ?? false;
                          if (!canReview) return const SizedBox.shrink();
                          
                          return TextButton.icon(
                            onPressed: () => _showReviewDialog(context, ref, currentUser, userModel),
                            icon: Icon(
                              Icons.add_comment,
                              size: 16,
                              color: AppTheme.getPrimaryColor(userModel),
                            ),
                            label: Text(
                              'Write Review',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getPrimaryColor(userModel),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Rating display on separate row
                RatingDisplayWidget(
                  reviewSummary: reviewSummary,
                  compact: true,
                ),
                const SizedBox(height: 12),
                RatingDisplayWidget(
                  reviewSummary: reviewSummary,
                  showBreakdown: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoReviewsCard(BuildContext context, WidgetRef ref, UserModel userModel, UserModel? currentUser) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.rate_review,
                  size: 24,
                  color: AppTheme.getPrimaryColor(userModel),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (currentUser != null && currentUser.uid != userModel.uid)
                  FutureBuilder<bool>(
                    future: ref.read(reviewServiceProvider).canUserReview(currentUser.uid, userModel.uid),
                    builder: (context, snapshot) {
                      final canReview = snapshot.data ?? false;
                      if (!canReview) return const SizedBox.shrink();
                      
                      return TextButton.icon(
                        onPressed: () => _showReviewDialog(context, ref, currentUser, userModel),
                        icon: Icon(
                          Icons.add_comment,
                          size: 16,
                          color: AppTheme.getPrimaryColor(userModel),
                        ),
                        label: Text(
                          'Write Review',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getPrimaryColor(userModel),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser != null && currentUser.uid != userModel.uid
                        ? 'Be the first to leave a review!'
                        : 'Reviews from connections will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref, UserModel currentUser, UserModel targetUser) async {
    print('🎯 [PROFILE] Opening review submission screen...');
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ReviewSubmissionScreen(
          currentUser: currentUser,
          targetUser: targetUser,
        ),
      ),
    );
    
    if (result == true) {
      print('🎯 [PROFILE] Review submitted successfully, auto-refreshing...');
      
      // Show loading indicator during refresh
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Refreshing reviews...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[600],
          ),
        );
      }
      
      // Enhanced refresh with multiple attempts
      await _performReviewRefresh(ref, targetUser.uid);
      
      // Show completion message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Review submitted and profile updated!'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    }
  }

  Future<void> _performReviewRefresh(WidgetRef ref, String userId) async {
    print('🔄 [PROFILE] Performing enhanced review refresh...');
    
    try {
      final reviewService = ref.read(reviewServiceProvider);
      
      // Force immediate recalculation of review summary
      print('🔄 [PROFILE] Force recalculating review summary...');
      await reviewService.forceRecalculateReviewSummary(userId);
      
      // Wait for database write propagation
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Invalidate all providers to force fresh streams
      ref.invalidate(reviewServiceProvider);
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
      
      // Additional delay for UI refresh
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Second invalidation to ensure everything is fresh
      ref.invalidate(reviewServiceProvider);
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
      
      // Run diagnostic to verify the data is now correct
      await reviewService.diagnoseReviewSubmission(userId);
      
      print('🔄 [PROFILE] Enhanced review refresh completed successfully');
    } catch (e) {
      print('🔄 [PROFILE] Enhanced refresh error: $e');
      // Fallback to basic invalidation
      ref.invalidate(reviewServiceProvider);
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(enhancedUserProfileProvider(userId));
    }
  }
}
