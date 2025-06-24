import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../models/story_model.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<StoryModel> _stories = [];
  final AppServiceManager _serviceManager = AppServiceManager();

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('ExploreScreen: Loading public stories...');
      final stories = await _serviceManager.getPublicStories();
      print('ExploreScreen: Loaded ${stories.length} stories');
      
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ExploreScreen: Error loading stories - $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Explore',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[600],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search coming soon!'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter functionality
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
      body: RefreshIndicator(
        onRefresh: _loadStories,
        child: _buildStoriesFeed(),
      ),
    );
  }

  Widget _buildStoriesFeed() {
    if (_isLoading && _stories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No stories yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share a story!',
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _stories.length,
      itemBuilder: (context, index) {
        return _buildStoryCard(_stories[index]);
      },
    );
  }

  Widget _buildStoryCard(StoryModel story) {
    final timeAgo = _getTimeAgo(story.createdAt);
    final isLiked = story.hasUserLiked(_serviceManager.currentUserId ?? '');
    final isViewed = story.hasUserViewed(_serviceManager.currentUserId ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              backgroundImage: story.creatorProfilePicture != null
                  ? NetworkImage(story.creatorProfilePicture!)
                  : null,
              child: story.creatorProfilePicture == null
                  ? Text(
                      story.creatorUsername.isNotEmpty 
                          ? story.creatorUsername[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.blue[600],
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
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showStoryOptions(context, story),
            ),
          ),
          
          // Story Content
          GestureDetector(
            onTap: () => _viewStory(story),
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  // Story media placeholder (will be replaced with actual media)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          story.type == StoryType.image 
                              ? Icons.image 
                              : Icons.videocam,
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
                          const SizedBox(height: 4),
                          Text(
                            story.caption!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // View indicator
                  if (isViewed)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          
          // Story Actions
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
    final currentUserId = _serviceManager.currentUserId ?? '';
    
    // Don't update UI if already viewed
    if (story.hasUserViewed(currentUserId)) {
      return;
    }
    
    // Optimistic UI update - immediately update the local state
    final updatedStory = _updateStoryViewOptimistically(story, currentUserId);
    final storyIndex = _stories.indexWhere((s) => s.id == story.id);
    if (storyIndex != -1) {
      setState(() {
        _stories[storyIndex] = updatedStory;
      });
    }
    
    try {
      // Sync with database in the background
      await _serviceManager.viewStory(story.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story viewed!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1000),
        ),
      );
      
      // Optionally refresh from server to ensure consistency (but don't await it)
      _loadStories();
      
    } catch (e) {
      // Revert the optimistic update on error
      if (storyIndex != -1) {
        setState(() {
          _stories[storyIndex] = story; // Revert to original state
        });
      }
      
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
    final currentUserId = _serviceManager.currentUserId ?? '';
    final isCurrentlyLiked = story.hasUserLiked(currentUserId);
    
    // Optimistic UI update - immediately update the local state
    final updatedStory = _updateStoryLikeOptimistically(story, currentUserId, !isCurrentlyLiked);
    final storyIndex = _stories.indexWhere((s) => s.id == story.id);
    if (storyIndex != -1) {
      setState(() {
        _stories[storyIndex] = updatedStory;
      });
    }
    
    try {
      // Sync with database in the background
      await _serviceManager.likeStory(story.id);
      
      // Optionally refresh from server to ensure consistency (but don't await it)
      _loadStories();
      
    } catch (e) {
      // Revert the optimistic update on error
      if (storyIndex != -1) {
        setState(() {
          _stories[storyIndex] = story; // Revert to original state
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${!isCurrentlyLiked ? "like" : "unlike"} story: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }
  
  StoryModel _updateStoryLikeOptimistically(StoryModel story, String userId, bool isLiked) {
    final currentLikedBy = List<String>.from(story.likedBy);
    int newLikeCount = story.likeCount;
    
    if (isLiked && !currentLikedBy.contains(userId)) {
      // Add like
      currentLikedBy.add(userId);
      newLikeCount++;
    } else if (!isLiked && currentLikedBy.contains(userId)) {
      // Remove like
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
} 