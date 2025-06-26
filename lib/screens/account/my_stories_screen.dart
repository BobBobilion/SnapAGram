import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/story_model.dart';

class MyStoriesScreen extends ConsumerStatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  ConsumerState<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends ConsumerState<MyStoriesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<StoryModel> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadMyStories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyStories() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      print('MyStoriesScreen: Loading user stories...');
      final stories = await serviceManager.getCurrentUserStories();
      print('MyStoriesScreen: Loaded ${stories.length} stories');
      
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('MyStoriesScreen: Error loading stories - $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading your stories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.user;
    final userModel = authService.userModel;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Stories',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[600],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyStories,
        child: _buildStoriesFeed(user, userModel),
      ),
    );
  }

  Widget _buildStoriesFeed(user, userModel) {
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
              'Take a photo to share your first story!',
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
        return _buildStoryCard(_stories[index], user, userModel);
      },
    );
  }

  Widget _buildStoryCard(StoryModel story, user, userModel) {
    final timeAgo = _getTimeAgo(story.createdAt);

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
              backgroundImage: (userModel?.profilePictureUrl ?? user?.photoURL) != null
                  ? NetworkImage(userModel?.profilePictureUrl ?? user?.photoURL)
                  : null,
              child: (userModel?.profilePictureUrl ?? user?.photoURL) == null
                  ? Text(
                      (userModel?.displayName ?? user?.displayName ?? user?.email ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              userModel?.displayName ?? user?.displayName ?? user?.email ?? 'You',
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
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditCaptionDialog(story);
                } else if (value == 'visibility') {
                  _showChangeVisibilityDialog(story);
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog(story);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text('Edit Caption', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'visibility',
                  child: Row(
                    children: [
                      Icon(
                        story.visibility == StoryVisibility.public 
                            ? Icons.public 
                            : Icons.people,
                        color: Colors.orange[600],
                      ),
                      const SizedBox(width: 8),
                      Text('Change Visibility', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Text('Delete Story', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Story Content
          Container(
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
                // Display actual story media
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: _buildStoryMedia(story),
                ),
                
                // Caption overlay (if image loaded successfully)
                if (story.caption != null && story.caption!.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        story.caption!,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Story Stats
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  story.likeCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.visibility,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  story.viewCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: story.visibility == StoryVisibility.public 
                        ? Colors.orange[100] 
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    story.visibility == StoryVisibility.public ? 'Public' : 'Friends',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: story.visibility == StoryVisibility.public 
                          ? Colors.orange[700] 
                          : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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

  void _showEditCaptionDialog(StoryModel story) {
    final captionController = TextEditingController(text: story.caption ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Edit Caption',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: TextField(
                controller: captionController,
                decoration: InputDecoration(
                  labelText: 'Caption',
                  hintText: 'Add a caption to your story...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[600]!),
                  ),
                ),
                maxLines: 3,
                maxLength: 200,
                enabled: !isLoading,
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
                  onPressed: isLoading ? null : () async {
                    final newCaption = captionController.text.trim();

                    setState(() => isLoading = true);

                    try {
                      final serviceManager = ref.read(appServiceManagerProvider);
                      await serviceManager.updateStoryCaption(story.id, newCaption);
                      
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Caption updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadMyStories(); // Refresh the stories
                      }
                    } catch (e) {
                      print('Error updating caption: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating caption: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => isLoading = false);
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
                          'Save',
                          style: TextStyle(color: Colors.blue[600]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeVisibilityDialog(StoryModel story) {
    StoryVisibility selectedVisibility = story.visibility;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            
            return AlertDialog(
              title: Text(
                'Change Visibility',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Who can see this story?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.public,
                      color: selectedVisibility == StoryVisibility.public 
                          ? Colors.green[600] 
                          : Colors.grey[600],
                    ),
                    title: Text(
                      'Public',
                      style: GoogleFonts.poppins(
                        fontWeight: selectedVisibility == StoryVisibility.public 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                        color: Colors.grey[800],
                      ),
                    ),
                    subtitle: Text(
                      'Anyone can see this story',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: selectedVisibility == StoryVisibility.public
                        ? Icon(Icons.radio_button_checked, color: Colors.green[600])
                        : Icon(Icons.radio_button_unchecked, color: Colors.grey[600]),
                    onTap: () {
                      dialogSetState(() {
                        selectedVisibility = StoryVisibility.public;
                      });
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.people,
                      color: selectedVisibility == StoryVisibility.friends 
                          ? Colors.blue[600] 
                          : Colors.grey[600],
                    ),
                    title: Text(
                      'Friends Only',
                      style: GoogleFonts.poppins(
                        fontWeight: selectedVisibility == StoryVisibility.friends 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                        color: Colors.grey[800],
                      ),
                    ),
                    subtitle: Text(
                      'Only your friends can see this story',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: selectedVisibility == StoryVisibility.friends
                        ? Icon(Icons.radio_button_checked, color: Colors.blue[600])
                        : Icon(Icons.radio_button_unchecked, color: Colors.grey[600]),
                    onTap: () {
                      dialogSetState(() {
                        selectedVisibility = StoryVisibility.friends;
                      });
                    },
                  ),
                ],
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
                  onPressed: selectedVisibility == story.visibility
                      ? null
                      : () => _updateStoryVisibility(story, selectedVisibility),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: selectedVisibility == story.visibility
                          ? Colors.grey[400]
                          : Colors.blue[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateStoryVisibility(StoryModel story, StoryVisibility newVisibility) async {
    if (story.visibility == newVisibility) {
      Navigator.of(context).pop();
      return;
    }

    try {
      Navigator.of(context).pop();
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Updating visibility...'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );

      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.updateStoryVisibility(story.id, newVisibility);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Story visibility changed to ${newVisibility == StoryVisibility.public ? "Public" : "Friends Only"}!'
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyStories(); // Refresh the stories
      }
    } catch (e) {
      print('Error updating story visibility: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating story visibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(StoryModel story) {
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
                    ),
                  );

                  final serviceManager = ref.read(appServiceManagerProvider);
                  await serviceManager.deleteStory(story.id);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Story deleted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadMyStories(); // Refresh the stories
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

  Widget _buildStoryMedia(StoryModel story) {
    if (story.type == StoryType.image) {
      // Check if it's a local file path or URL
      if (story.mediaUrl.startsWith('http')) {
        // Network image (for placeholder URLs or Firebase Storage URLs)
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
        // Local file path
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
    } else {
      // Video placeholder for now
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