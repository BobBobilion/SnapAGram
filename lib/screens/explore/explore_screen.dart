import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapagram/models/enums.dart';
import 'package:snapagram/models/user_model.dart';
import 'package:snapagram/models/review.dart';
import 'package:video_player/video_player.dart';
import 'package:snapagram/screens/profile/public_profile_screen.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/story_model.dart';
import '../../utils/app_theme.dart';
import '../../providers/ui_provider.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import '../../services/review_service.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _friendsScrollController = ScrollController();
  bool _isLoadingPublic = false;
  bool _isLoadingFriends = false;
  List<StoryModel> _publicStories = [];
  List<StoryModel> _friendsStories = [];
  Set<String> _autoViewedStories = {}; // Track stories that have been auto-viewed
  Map<String, GlobalKey> _storyKeys = {}; // Track story keys for viewport detection
  Timer? _viewportCheckTimer; // Debounce timer for viewport checks
  Set<String> _doubleTapStories = {}; // Track stories that have been double-tapped
  Map<String, bool> _heartAnimations = {}; // Track heart animation states
  Map<String, dynamic> _userCache = {}; // Cache for user data and review summaries
  Map<String, Future<Map<String, dynamic>>> _userDataFutures = {}; // Cache futures to prevent rebuild flickering
  int _sortMode = 0; // 0 = most recent, 1 = highest rating, 2 = best fit

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicStories();
    _loadFriendsStories();
    
    // Add scroll listeners for viewport detection
    _scrollController.addListener(_checkViewportVisibility);
    _friendsScrollController.addListener(_checkViewportVisibility);
    
    // Add tab change listener
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Check viewport visibility when switching tabs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkViewportVisibility();
        });
      }
    });
    
    // Check visibility after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkViewportVisibility();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _friendsScrollController.dispose();
    _viewportCheckTimer?.cancel();
    _userDataFutures.clear(); // Clean up cached futures
    super.dispose();
  }

  void _checkViewportVisibility() {
    // Debounce viewport checks to prevent excessive calls
    _viewportCheckTimer?.cancel();
    _viewportCheckTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      final currentStories = _tabController.index == 0 ? _publicStories : _friendsStories;
      
      for (final story in currentStories) {
        final key = _storyKeys[story.id];
        if (key?.currentContext != null && !_autoViewedStories.contains(story.id)) {
          final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            final screenHeight = MediaQuery.of(context).size.height;
            
            // Check if story is visible in viewport (more than 50% visible)
            final isVisible = position.dy < screenHeight && 
                             position.dy + size.height > 0 &&
                             (position.dy + size.height * 0.5) < screenHeight;
            
            if (isVisible) {
              _autoViewStory(story);
            }
          }
        }
      }
    });
  }

  Future<void> _autoViewStory(StoryModel story) async {
    if (_autoViewedStories.contains(story.id)) return;
    
    final currentUserId = ref.read(appServiceManagerProvider).currentUserId ?? '';
    if (story.hasUserViewed(currentUserId)) return;
    
    // Add to auto-viewed set to prevent duplicate tracking
    _autoViewedStories.add(story.id);
    
    // Update story optimistically
    final updatedStory = _updateStoryViewOptimistically(story, currentUserId);
    final publicStoryIndex = _publicStories.indexWhere((s) => s.id == story.id);
    final friendsStoryIndex = _friendsStories.indexWhere((s) => s.id == story.id);

    setState(() {
      if (publicStoryIndex != -1) {
        _publicStories[publicStoryIndex] = updatedStory;
      }
      if (friendsStoryIndex != -1) {
        _friendsStories[friendsStoryIndex] = updatedStory;
      }
    });

    try {
      await ref.read(appServiceManagerProvider).viewStory(story.id);
      // Silently update the view count without showing a snackbar for auto-views
      print('Auto-viewed story: ${story.id} by user: $currentUserId');
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        if (publicStoryIndex != -1) {
          _publicStories[publicStoryIndex] = story;
        }
        if (friendsStoryIndex != -1) {
          _friendsStories[friendsStoryIndex] = story;
        }
      });
      // Remove from auto-viewed set so it can be retried
      _autoViewedStories.remove(story.id);
      print('Failed to auto-view story: ${story.id}, error: $e');
    }
  }

  Future<void> _loadPublicStories() async {
    if (_isLoadingPublic) return;
    setState(() => _isLoadingPublic = true);
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final stories = await serviceManager.getPublicStories();
      if (mounted) {
        setState(() {
          _publicStories = stories;
          _isLoadingPublic = false;
        });
        _cleanupStoryKeys();
        _clearUserCache(); // Clear cache to get fresh user data
        // Check viewport visibility after loading new stories
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkViewportVisibility();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPublic = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading public stories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFriendsStories() async {
    if (_isLoadingFriends) return;
    setState(() => _isLoadingFriends = true);
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final stories = await serviceManager.getFriendsStories();
      if (mounted) {
        setState(() {
          _friendsStories = stories;
          _isLoadingFriends = false;
        });
        _cleanupStoryKeys();
        _clearUserCache(); // Clear cache to get fresh user data
        // Check viewport visibility after loading new stories
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkViewportVisibility();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends stories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshPublicStories() async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final stories = await serviceManager.getPublicStories();
      if (mounted) {
        setState(() {
          _publicStories = stories;
        });
        _clearUserCache(); // Clear cache to get fresh user data
        _forceRefreshUserData(); // Force refresh user data for all stories
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refreshed ${stories.length} public stories'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing stories: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    }
  }

  Future<void> _refreshFriendsStories() async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final stories = await serviceManager.getFriendsStories();
      if (mounted) {
        setState(() {
          _friendsStories = stories;
        });
        _clearUserCache(); // Clear cache to get fresh user data
        _forceRefreshUserData(); // Force refresh user data for all stories
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refreshed ${stories.length} friends stories'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing friends stories: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    final primaryColor = AppTheme.getPrimaryColor(userModel);

    // Listen to explore refresh trigger
    ref.listen<int>(exploreRefreshTriggerProvider, (previous, next) {
      if (previous != null && next > previous) {
        // Trigger refresh of both story lists
        _loadPublicStories();
        _loadFriendsStories();
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Walk Stories',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All Walks'),
            Tab(text: 'My Connections'),
          ],
        ),
        actions: [
          Icon(
            Icons.sort,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _toggleSort,
            child: Text(
              _sortMode == 0 ? 'Recent' : _sortMode == 1 ? 'Rating' : 'Best Fit',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicStoriesTab(userModel),
          _buildFriendsStoriesTab(userModel),
        ],
      ),
    );
  }

  Widget _buildPublicStoriesTab(userModel) {
    return RefreshIndicator(
      onRefresh: _refreshPublicStories,
      color: AppTheme.getColorShade(userModel, 600),
      backgroundColor: Colors.white,
      child: _buildStoriesFeed(
        stories: _publicStories,
        isLoading: _isLoadingPublic,
        scrollController: _scrollController,
        emptyMessage: 'No walk stories yet',
        emptySubMessage: 'Walkers haven\'t shared any walks yet!',
        storyType: 'public',
        userModel: userModel,
      ),
    );
  }

  Widget _buildFriendsStoriesTab(userModel) {
    return RefreshIndicator(
      onRefresh: _refreshFriendsStories,
      color: Colors.green[600],
      backgroundColor: Colors.white,
      child: _buildStoriesFeed(
        stories: _friendsStories,
        isLoading: _isLoadingFriends,
        scrollController: _friendsScrollController,
        emptyMessage: 'No connection walks yet',
        emptySubMessage: 'Your connections haven\'t shared any walk stories',
        storyType: 'friends',
        userModel: userModel,
      ),
    );
  }

  Widget _buildStoriesFeed({
    required List<StoryModel> stories,
    required bool isLoading,
    required ScrollController scrollController,
    required String emptyMessage,
    required String emptySubMessage,
    required String storyType,
    required userModel,
  }) {
    if (isLoading && stories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              storyType == 'friends' ? Icons.people_outline : Icons.pets,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Apply sorting to the stories
    final sortedStories = _getSortedStories(stories);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedStories.length,
      itemBuilder: (context, index) {
        return _buildStoryCard(sortedStories[index], storyType, userModel);
      },
    );
  }

  Widget _buildStoryCard(StoryModel story, String storyType, userModel) {
    // Ensure we have a key for this story
    if (!_storyKeys.containsKey(story.id)) {
      _storyKeys[story.id] = GlobalKey();
    }
    
    final timeAgo = _getTimeAgo(story.createdAt);
    final isLiked =
        story.hasUserLiked(ref.read(appServiceManagerProvider).currentUserId ?? '');
    final isViewed =
        story.hasUserViewed(ref.read(appServiceManagerProvider).currentUserId ?? '');
    final cardColor =
        story.creatorRole == UserRole.walker ? Colors.green : Colors.blue;

    return Card(
      key: _storyKeys[story.id],
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cardColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PublicProfileScreen(userId: story.uid),
                ),
              );
            },
            child: _buildStoryHeader(story, timeAgo, cardColor, storyType, userModel),
          ),
          GestureDetector(
            onTap: () => _viewStory(story),
            onDoubleTap: () => _handleDoubleTapLike(story),
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    child: _buildStoryMedia(story, userModel),
                  ),
                  if (isViewed)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Viewed',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Debug indicator for auto-viewed stories
                  if (_autoViewedStories.contains(story.id) && !isViewed)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Auto-viewed',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Double tap heart animation
                  if (_heartAnimations[story.id] == true)
                    Positioned.fill(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 60,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (story.caption != null && story.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                story.caption!,
                style: GoogleFonts.poppins(
                  color: Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey[600],
                  ),
                  onPressed: () => _toggleLike(story),
                ),
                Text(
                  story.likeCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => _viewStory(story),
                ),
                Text(
                  story.viewCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.share,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => _shareStory(story),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryHeader(StoryModel story, String timeAgo, Color cardColor, String storyType, userModel) {
    // Get or create cached future to prevent flickering on rebuild
    if (!_userDataFutures.containsKey(story.uid)) {
      _userDataFutures[story.uid] = _getUserDataWithReviewSummary(story.uid);
    }
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _userDataFutures[story.uid],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state while fetching user data
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cardColor.withOpacity(0.1),
              backgroundImage: story.creatorProfilePicture != null
                  ? NetworkImage(story.creatorProfilePicture!)
                  : null,
              child: story.creatorProfilePicture == null
                  ? Text(
                      story.creatorUsername.isNotEmpty
                          ? story.creatorUsername[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    story.creatorUsername,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardColor.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(
                    story.creatorRole == UserRole.walker ? 'Walker' : 'Owner',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Loading...',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    timeAgo,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: storyType == 'friends'
                ? (story.visibility == StoryVisibility.friends
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.getColorShade(userModel, 100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Friends Only',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getColorShade(userModel, 700),
                          ),
                        ),
                      )
                    : null)
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showStoryOptions(context, story),
                  ),
          );
        }

        if (snapshot.hasError) {
          print('Error loading user data for ${story.uid}: ${snapshot.error}');
          // Show fallback with error state
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cardColor.withOpacity(0.1),
              backgroundImage: story.creatorProfilePicture != null
                  ? NetworkImage(story.creatorProfilePicture!)
                  : null,
              child: story.creatorProfilePicture == null
                  ? Text(
                      story.creatorUsername.isNotEmpty
                          ? story.creatorUsername[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: cardColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    story.creatorUsername,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardColor.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(
                    story.creatorRole == UserRole.walker ? 'Walker' : 'Owner',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red[400],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Error loading rating',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red[400],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: storyType == 'friends'
                ? (story.visibility == StoryVisibility.friends
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.getColorShade(userModel, 100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Friends Only',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getColorShade(userModel, 700),
                          ),
                        ),
                      )
                    : null)
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showStoryOptions(context, story),
                  ),
          );
        }

        final data = snapshot.data!;
        final user = data['user'] as UserModel?;
        final reviewSummary = data['reviewSummary'] as ReviewSummary?;
        
        final displayName = user?.displayName ?? story.creatorUsername;
        final rating = reviewSummary?.averageRating;
        final totalReviews = reviewSummary?.totalReviews;
        
        // Debug logging
        print('User data for ${story.uid}: displayName=$displayName, rating=$rating, totalReviews=$totalReviews, hasReviewSummary=${reviewSummary != null}');
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cardColor.withOpacity(0.1),
            backgroundImage: story.creatorProfilePicture != null
                ? NetworkImage(story.creatorProfilePicture!)
                : null,
            child: story.creatorProfilePicture == null
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardColor.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  story.creatorRole == UserRole.walker ? 'Walker' : 'Owner',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cardColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating row
              if (rating != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (totalReviews != null && totalReviews > 0) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '(${totalReviews})',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '(No reviews)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
              ] else ...[
                // Show when rating is null
                Row(
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'No rating',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
              // Time ago
              Text(
                timeAgo,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          trailing: storyType == 'friends'
              ? (story.visibility == StoryVisibility.friends
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.getColorShade(userModel, 100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Friends Only',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getColorShade(userModel, 700),
                        ),
                      ),
                    )
                  : null)
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showStoryOptions(context, story),
                ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserDataWithReviewSummary(String userId) async {
    // Check cache first
    final cacheKey = '${userId}_with_review';
    if (_userCache.containsKey(cacheKey)) {
      print('Using cached user data with review summary for $userId');
      return _userCache[cacheKey] as Map<String, dynamic>;
    }
    
    try {
      print('Fetching user data and review summary for $userId');
      
      // Fetch user data and review summary in parallel
      final futures = await Future.wait([
        ref.read(appServiceManagerProvider).getUserById(userId),
        ref.read(reviewServiceProvider).getReviewSummary(userId),
      ]);
      
      final user = futures[0] as UserModel?;
      final reviewSummary = futures[1] as ReviewSummary?;
      
      final result = {
        'user': user,
        'reviewSummary': reviewSummary,
      };
      
      _userCache[cacheKey] = result;
      print('Fetched user data for $userId: ${user?.displayName}, rating: ${reviewSummary?.averageRating}');
      return result;
    } catch (e) {
      print('Error fetching user data for $userId: $e');
      rethrow;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showStoryOptions(BuildContext context, StoryModel story) {
    final currentUserId = ref.read(appServiceManagerProvider).currentUserId ?? '';
    final isOwnStory = story.uid == currentUserId;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnStory) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Story'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteStory(story);
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report Story'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Block feature coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteStory(StoryModel story) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Story',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete this story? This action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop();
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 16),
                          Text('Deleting story...'),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(milliseconds: 500),
                    ),
                  );

                  final serviceManager = ref.read(appServiceManagerProvider);
                  await serviceManager.deleteStory(story.id);
                  
                  // Immediately remove the story from local state
                  setState(() {
                    _publicStories.removeWhere((s) => s.id == story.id);
                    _friendsStories.removeWhere((s) => s.id == story.id);
                    // Also clean up any tracking sets
                    _autoViewedStories.remove(story.id);
                    _doubleTapStories.remove(story.id);
                    _heartAnimations.remove(story.id);
                    _storyKeys.remove(story.id);
                  });
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Story deleted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Refresh both story lists to ensure everything is in sync
                    await _loadPublicStories();
                    await _loadFriendsStories();
                  }
                } catch (e) {
                  print('Error deleting story: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting story: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewStory(StoryModel story) async {
    final currentUserId =
        ref.read(appServiceManagerProvider).currentUserId ?? '';
    if (story.hasUserViewed(currentUserId)) {
      return;
    }
    final updatedStory = _updateStoryViewOptimistically(story, currentUserId);
    final publicStoryIndex =
        _publicStories.indexWhere((s) => s.id == story.id);
    final friendsStoryIndex =
        _friendsStories.indexWhere((s) => s.id == story.id);

    setState(() {
      if (publicStoryIndex != -1) {
        _publicStories[publicStoryIndex] = updatedStory;
      }
      if (friendsStoryIndex != -1) {
        _friendsStories[friendsStoryIndex] = updatedStory;
      }
    });

    try {
      await ref.read(appServiceManagerProvider).viewStory(story.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story viewed!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1000),
        ),
      );
      // Don't reload stories or clear cache for view operations - just update the local state
      // This prevents flickering of user data
    } catch (e) {
      setState(() {
        if (publicStoryIndex != -1) {
          _publicStories[publicStoryIndex] = story;
        }
        if (friendsStoryIndex != -1) {
          _friendsStories[friendsStoryIndex] = story;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to view story: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  StoryModel _updateStoryViewOptimistically(StoryModel story, String userId) {
    final currentViewedBy = List<String>.from(story.viewedBy);
    int newViewCount = story.viewCount;

    if (!currentViewedBy.contains(userId)) {
      currentViewedBy.add(userId);
      newViewCount++;
    }

    return story.copyWith(
      viewedBy: currentViewedBy,
      viewCount: newViewCount,
    );
  }

  Future<void> _toggleLike(StoryModel story) async {
    final currentUserId =
        ref.read(appServiceManagerProvider).currentUserId ?? '';
    final isCurrentlyLiked = story.hasUserLiked(currentUserId);
    final updatedStory =
        _updateStoryLikeOptimistically(story, currentUserId, !isCurrentlyLiked);
    final publicStoryIndex =
        _publicStories.indexWhere((s) => s.id == story.id);
    final friendsStoryIndex =
        _friendsStories.indexWhere((s) => s.id == story.id);

    setState(() {
      if (publicStoryIndex != -1) {
        _publicStories[publicStoryIndex] = updatedStory;
      }
      if (friendsStoryIndex != -1) {
        _friendsStories[friendsStoryIndex] = updatedStory;
      }
    });

    try {
      await ref.read(appServiceManagerProvider).likeStory(story.id);
      // Don't reload stories or clear cache for like operations - just update the local state
      // This prevents flickering of user data during heart animations
    } catch (e) {
      setState(() {
        if (publicStoryIndex != -1) {
          _publicStories[publicStoryIndex] = story;
        }
        if (friendsStoryIndex != -1) {
          _friendsStories[friendsStoryIndex] = story;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to ${!isCurrentlyLiked ? "like" : "unlike"} story: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  StoryModel _updateStoryLikeOptimistically(
      StoryModel story, String userId, bool isLiked) {
    final currentLikedBy = List<String>.from(story.likedBy);
    int newLikeCount = story.likeCount;

    if (isLiked && !currentLikedBy.contains(userId)) {
      currentLikedBy.add(userId);
      newLikeCount++;
    } else if (!isLiked && currentLikedBy.contains(userId)) {
      currentLikedBy.remove(userId);
      newLikeCount--;
    }

    return story.copyWith(
      likedBy: currentLikedBy,
      likeCount: newLikeCount,
    );
  }

  void _shareStory(StoryModel story) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!')),
    );
  }

  void _handleDoubleTapLike(StoryModel story) {
    if (_doubleTapStories.contains(story.id)) {
      return;
    }
    
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();
    
    // Add to double tap set to prevent multiple rapid taps
    _doubleTapStories.add(story.id);
    
    // Start heart animation
    setState(() {
      _heartAnimations[story.id] = true;
    });
    
    // Toggle like status
    _toggleLike(story);
    
    // Remove animation after completion
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _heartAnimations.remove(story.id);
        });
      }
    });
    
    // Allow future double taps after a delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _doubleTapStories.remove(story.id);
        });
      }
    });
  }

  void _clearUserCache() {
    print('Clearing user cache');
    _userCache.clear();
    _userDataFutures.clear(); // Also clear cached futures
  }

  void _forceRefreshUserData() {
    print('Force refreshing user data for all stories');
    // Force rebuild by clearing cache and triggering setState
    _clearUserCache();
    if (mounted) {
      setState(() {
        // This will trigger rebuild of all story cards
      });
    }
  }

  void _toggleSort() {
    setState(() {
      _sortMode = (_sortMode + 1) % 3; // Cycle through 0, 1, 2
    });
  }

  List<StoryModel> _getSortedStories(List<StoryModel> stories) {
    if (_sortMode == 1) {
      // Sort by highest rating
      return _sortStoriesByRating(stories);
    } else if (_sortMode == 2) {
      // Sort by best fit
      return _sortStoriesByBestFit(stories);
    } else {
      // Sort by most recent (default)
      final sortedStories = List<StoryModel>.from(stories);
      sortedStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sortedStories;
    }
  }

  List<StoryModel> _sortStoriesByRating(List<StoryModel> stories) {
    final sortedStories = List<StoryModel>.from(stories);
    
    // Sort stories by user rating, with stories without ratings at the end
    sortedStories.sort((a, b) {
      final aRating = _getUserRating(a.uid);
      final bRating = _getUserRating(b.uid);
      
      // Stories with ratings come first, sorted by rating descending
      if (aRating != null && bRating != null) {
        return bRating.compareTo(aRating);
      } else if (aRating != null) {
        return -1; // a has rating, b doesn't - a comes first
      } else if (bRating != null) {
        return 1; // b has rating, a doesn't - b comes first
      } else {
        // Both have no rating, sort by most recent
        return b.createdAt.compareTo(a.createdAt);
      }
    });
    
    return sortedStories;
  }

  double? _getUserRating(String userId) {
    final cacheKey = '${userId}_with_review';
    if (_userCache.containsKey(cacheKey)) {
      final data = _userCache[cacheKey] as Map<String, dynamic>;
      final reviewSummary = data['reviewSummary'] as ReviewSummary?;
      return reviewSummary?.averageRating;
    }
    return null;
  }

  List<StoryModel> _sortStoriesByBestFit(List<StoryModel> stories) {
    final currentUser = ref.read(authServiceProvider).userModel;
    if (currentUser == null) {
      // Fallback to recent sort if no current user
      final sortedStories = List<StoryModel>.from(stories);
      sortedStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sortedStories;
    }

    final sortedStories = List<StoryModel>.from(stories);
    
    // Sort stories by best fit score
    sortedStories.sort((a, b) {
      final aFitScore = _calculateFitScore(currentUser, a);
      final bFitScore = _calculateFitScore(currentUser, b);
      
      // Higher fit score comes first
      final scoreComparison = bFitScore.compareTo(aFitScore);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      
      // If fit scores are equal, sort by most recent
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return sortedStories;
  }

  double _calculateFitScore(UserModel currentUser, StoryModel story) {
    final cacheKey = '${story.uid}_with_review';
    UserModel? storyUser;
    
    if (_userCache.containsKey(cacheKey)) {
      final data = _userCache[cacheKey] as Map<String, dynamic>;
      storyUser = data['user'] as UserModel?;
    }
    
    if (storyUser == null) {
      return 0.0; // No user data available
    }

    double fitScore = 0.0;
    
    // Base score: Prioritize opposite roles
    if (currentUser.role != storyUser.role) {
      fitScore += 100.0; // High base score for opposite roles
      
      // Match walker capabilities with owner needs
      if (currentUser.role == UserRole.owner && storyUser.role == UserRole.walker) {
        fitScore += _matchOwnerWithWalker(currentUser, storyUser);
      } else if (currentUser.role == UserRole.walker && storyUser.role == UserRole.owner) {
        fitScore += _matchWalkerWithOwner(currentUser, storyUser);
      }
    } else {
      fitScore += 20.0; // Lower base score for same roles
      
      // For same roles, match similar characteristics
      if (currentUser.role == UserRole.walker && storyUser.role == UserRole.walker) {
        fitScore += _matchWalkerWithWalker(currentUser, storyUser);
      } else if (currentUser.role == UserRole.owner && storyUser.role == UserRole.owner) {
        fitScore += _matchOwnerWithOwner(currentUser, storyUser);
      }
    }
    
    // Add rating bonus if available
    final rating = _getUserRating(story.uid);
    if (rating != null) {
      fitScore += rating * 5.0; // Add up to 25 points for 5-star rating
    }
    
    return fitScore;
  }

  double _matchOwnerWithWalker(UserModel owner, UserModel walker) {
    double matchScore = 0.0;
    
    if (owner.ownerProfile != null && walker.walkerProfile != null) {
      final ownerProfile = owner.ownerProfile!;
      final walkerProfile = walker.walkerProfile!;
      
              // Match dog size with walker preferences
        if (walkerProfile.dogSizePreferences.contains(ownerProfile.dogSize)) {
          matchScore += 30.0; // Perfect match
        } else {
          // Partial match for similar sizes
          matchScore += _getDogSizeCompatibilityScore(ownerProfile.dogSize, walkerProfile.dogSizePreferences);
        }
      
      // Match location/area (simplified - could be enhanced with actual distance calculation)
      if (ownerProfile.city.isNotEmpty && walkerProfile.city.isNotEmpty) {
        // Basic city matching - you could enhance this with actual location matching
        if (ownerProfile.city.toLowerCase() == walkerProfile.city.toLowerCase()) {
          matchScore += 20.0; // Same city
        } else {
          matchScore += 5.0; // Different cities but at least both have locations
        }
      }
    }
    
    return matchScore;
  }

  double _matchWalkerWithOwner(UserModel walker, UserModel owner) {
    // Same logic as above but from walker's perspective
    return _matchOwnerWithWalker(owner, walker);
  }

  double _matchWalkerWithWalker(UserModel walker1, UserModel walker2) {
    double matchScore = 0.0;
    
    if (walker1.walkerProfile != null && walker2.walkerProfile != null) {
      final profile1 = walker1.walkerProfile!;
      final profile2 = walker2.walkerProfile!;
      
      // Match similar dog size preferences
      final commonSizes = profile1.dogSizePreferences.where(
        (size) => profile2.dogSizePreferences.contains(size)
      ).length;
      matchScore += commonSizes * 15.0;
      
      // Match similar cities
      if (profile1.city.isNotEmpty && profile2.city.isNotEmpty) {
        if (profile1.city.toLowerCase() == profile2.city.toLowerCase()) {
          matchScore += 15.0; // Same city
        } else {
          matchScore += 3.0; // Different cities but both have locations
        }
      }
    }
    
    return matchScore;
  }

  double _matchOwnerWithOwner(UserModel owner1, UserModel owner2) {
    double matchScore = 0.0;
    
    if (owner1.ownerProfile != null && owner2.ownerProfile != null) {
      final profile1 = owner1.ownerProfile!;
      final profile2 = owner2.ownerProfile!;
      
      // Match similar dog sizes
      if (profile1.dogSize == profile2.dogSize) {
        matchScore += 20.0; // Same dog size
      } else {
        // Partial match for similar sizes
        matchScore += _getDogSizeCompatibilityScore(
          profile1.dogSize.name, 
          {profile2.dogSize.name}
        );
      }
      
      // Match similar cities
      if (profile1.city.isNotEmpty && profile2.city.isNotEmpty) {
        if (profile1.city.toLowerCase() == profile2.city.toLowerCase()) {
          matchScore += 15.0; // Same city
        } else {
          matchScore += 3.0; // Different cities but both have locations
        }
      }
    }
    
    return matchScore;
  }

  double _getDogSizeCompatibilityScore(dynamic ownerDogSize, dynamic walkerPreferences) {
    // Define size compatibility matrix using DogSize enum values
    const sizeOrder = [DogSize.small, DogSize.medium, DogSize.large, DogSize.extraLarge];
    
    // Get owner dog size index
    int ownerIndex = -1;
    if (ownerDogSize is DogSize) {
      ownerIndex = sizeOrder.indexOf(ownerDogSize);
    } else if (ownerDogSize is String) {
      // Handle string names
      for (int i = 0; i < sizeOrder.length; i++) {
        if (sizeOrder[i].name == ownerDogSize) {
          ownerIndex = i;
          break;
        }
      }
    }
    
    if (ownerIndex == -1) return 0.0;
    
    double bestScore = 0.0;
    
    // Handle List<DogSize> or Set<String>
    Iterable<DogSize> preferences = [];
    if (walkerPreferences is List<DogSize>) {
      preferences = walkerPreferences;
    } else if (walkerPreferences is Set<String>) {
      preferences = walkerPreferences.map((name) => 
        sizeOrder.firstWhere((size) => size.name == name, orElse: () => DogSize.medium)
      );
    }
    
    for (final walkerSize in preferences) {
      final walkerIndex = sizeOrder.indexOf(walkerSize);
      if (walkerIndex == -1) continue;
      
      // Calculate compatibility: closer sizes get higher scores
      final sizeDifference = (ownerIndex - walkerIndex).abs();
      double score = 0.0;
      
      switch (sizeDifference) {
        case 0:
          score = 30.0; // Perfect match
          break;
        case 1:
          score = 20.0; // Adjacent sizes (medium-large closer than small-large)
          break;
        case 2:
          score = 10.0; // Two sizes apart
          break;
        case 3:
          score = 5.0; // Maximum difference
          break;
      }
      
      if (score > bestScore) {
        bestScore = score;
      }
    }
    
    return bestScore;
  }

  Widget _buildStoryMedia(StoryModel story, userModel) {
    if (story.type == StoryType.image) {
      if (story.mediaUrl.startsWith('http')) {
        return Image.network(
          story.mediaUrl,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildMediaPlaceholder(story);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
        );
      } else {
        return Image.file(
          File(story.mediaUrl),
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildMediaPlaceholder(story);
          },
        );
      }
    } else if (story.type == StoryType.video) {
      return _VideoStoryPlayer(story: story, userModel: userModel);
    } else {
      return _buildMediaPlaceholder(story);
    }
  }

  Widget _buildMediaPlaceholder(StoryModel story) {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            story.type == StoryType.image ? Icons.image : Icons.videocam,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            story.type == StoryType.image ? 'Image Story' : 'Video Story',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (story.caption != null && story.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                story.caption!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _cleanupStoryKeys() {
    // Remove keys for stories that are no longer in the lists
    final currentStoryIds = <String>{};
    currentStoryIds.addAll(_publicStories.map((s) => s.id));
    currentStoryIds.addAll(_friendsStories.map((s) => s.id));
    
    _storyKeys.removeWhere((key, value) => !currentStoryIds.contains(key));
    
    // Clean up animation states for stories that are no longer in the lists
    _heartAnimations.removeWhere((key, value) => !currentStoryIds.contains(key));
    _doubleTapStories.removeWhere((storyId) => !currentStoryIds.contains(storyId));
    
    // Clean up user cache for users that are no longer in the stories
    final currentUserIds = <String>{};
    currentUserIds.addAll(_publicStories.map((s) => s.uid));
    currentUserIds.addAll(_friendsStories.map((s) => s.uid));
    
    _userCache.removeWhere((key, value) {
      // Extract user ID from cache key (format: "userId_with_review")
      final userId = key.split('_with_review')[0];
      return !currentUserIds.contains(userId);
    });
    
    // Clean up cached futures for users that are no longer in the stories
    _userDataFutures.removeWhere((userId, future) => !currentUserIds.contains(userId));
  }

  Future<void> _refreshUserDataOnly() async {
    print('Refreshing user data only');
    _clearUserCache();
    if (mounted) {
      setState(() {
        // This will trigger rebuild of all story cards with fresh user data
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshed user ratings'),
          backgroundColor: Colors.blue,
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }
}

class _VideoStoryPlayer extends StatefulWidget {
  final StoryModel story;
  final dynamic userModel;

  const _VideoStoryPlayer({
    required this.story,
    required this.userModel,
  });

  @override
  State<_VideoStoryPlayer> createState() => _VideoStoryPlayerState();
}

class _VideoStoryPlayerState extends State<_VideoStoryPlayer> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.story.mediaUrl))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          }).catchError((error) {
            print('Error initializing video: $error');
          });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.isInitialized
                ? _controller.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(_controller),
          ),
          if (_controller.value.isInitialized)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 64,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                    ),
                    _buildControlBar(),
                  ],
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isPlaying ? _controller.pause() : _controller.play();
              });
            },
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: _controller.value.position.inMilliseconds.toDouble(),
                min: 0.0,
                max: _controller.value.duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _controller.seekTo(Duration(milliseconds: value.toInt()));
                },
                activeColor: AppTheme.getPrimaryColor(widget.userModel),
                inactiveColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          Text(
            '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 