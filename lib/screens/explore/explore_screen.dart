import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapagram/models/enums.dart';
import 'package:video_player/video_player.dart';
import 'package:snapagram/screens/profile/public_profile_screen.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/story_model.dart';
import '../../utils/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicStories();
    _loadFriendsStories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _friendsScrollController.dispose();
    super.dispose();
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
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[600]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search coming soon!'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.grey[600]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filters coming soon!'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
          ),
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

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: stories.length + 1,
      itemBuilder: (context, index) {
        if (index == stories.length) {
          return _buildRefreshButton(storyType, userModel);
        }
        return _buildStoryCard(stories[index], storyType, userModel);
      },
    );
  }

  Widget _buildStoryCard(StoryModel story, String storyType, userModel) {
    final timeAgo = _getTimeAgo(story.createdAt);
    final isLiked =
        story.hasUserLiked(ref.read(appServiceManagerProvider).currentUserId ?? '');
    final isViewed =
        story.hasUserViewed(ref.read(appServiceManagerProvider).currentUserId ?? '');
    final cardColor =
        story.creatorRole == UserRole.walker ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
            child: ListTile(
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
              title: Text(
                story.creatorUsername,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                timeAgo,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
            ),
          ),
          GestureDetector(
            onTap: () => _viewStory(story),
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
                          borderRadius: BorderRadius.circular(12),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      _loadPublicStories();
      _loadFriendsStories();
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
      _loadPublicStories();
      _loadFriendsStories();
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

  Widget _buildRefreshButton(String storyType, userModel) {
    final isPublic = storyType == 'public';
    final isLoading = isPublic ? _isLoadingPublic : _isLoadingFriends;
    final themeColor =
        isPublic ? AppTheme.getColorShade(userModel, 600) : Colors.green[600];
    final themeLightColor =
        isPublic ? AppTheme.getColorShade(userModel, 300) : Colors.green[300];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Column(
        children: [
          Container(
            height: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.only(bottom: 20),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      if (isPublic) {
                        _refreshPublicStories();
                      } else {
                        _refreshFriendsStories();
                      }
                    },
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey[400]!,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: themeColor,
                    ),
              label: Text(
                isLoading
                    ? 'Refreshing...'
                    : 'Refresh ${isPublic ? "Public" : "Friends"} Stories',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLoading ? Colors.grey[500] : themeColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: themeColor,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: themeLightColor ?? Colors.grey,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'You\'ve reached the end!',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down or tap refresh to see new stories',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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