import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../models/story_model.dart';
import '../../models/user_model.dart';
import 'add_friends_screen.dart';
import '../chats/chat_conversation_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final AppServiceManager _serviceManager = AppServiceManager();
  
  List<StoryModel> _friendsStories = [];
  List<UserModel> _friends = [];
  List<UserModel> _friendRequests = [];
  bool _isLoadingStories = false;
  bool _isLoadingFriends = false;
  bool _isLoadingRequests = false;
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh friend requests when screen becomes visible
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFriendsStories(),
      _loadFriendsList(),
      _loadFriendRequests(),
    ]);
  }

  Future<void> _loadFriendsStories() async {
    if (_isLoadingStories) return;
    
    setState(() => _isLoadingStories = true);
    
    try {
      final stories = await _serviceManager.getFriendsStories();
      setState(() {
        _friendsStories = stories;
        _isLoadingStories = false;
      });
    } catch (e) {
      setState(() => _isLoadingStories = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends stories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFriendsList() async {
    if (_isLoadingFriends) return;
    
    setState(() => _isLoadingFriends = true);
    
    try {
      final friends = await _serviceManager.getCurrentUserFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    if (_isLoadingRequests) return;
    
    setState(() => _isLoadingRequests = true);
    
    try {
      final requests = await _serviceManager.getFriendRequests();
      if (mounted) {
        setState(() {
          _friendRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friend requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(UserModel user) async {
    try {
      await _serviceManager.acceptFriendRequest(user.uid);
      setState(() {
        _friendRequests.removeWhere((request) => request.uid == user.uid);
      });
      // Reload friends list to show the new friend
      await _loadFriendsList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now friends with ${user.displayName}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(UserModel user) async {
    try {
      await _serviceManager.rejectFriendRequest(user.uid);
      setState(() {
        _friendRequests.removeWhere((request) => request.uid == user.uid);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request from ${user.displayName} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFriendRequests() {
    setState(() {
      _showRequests = !_showRequests;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Friends',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[600],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Stories'),
            Tab(text: 'Friends'),
          ],
        ),
        actions: [
          // Friend Requests Notification Icon
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: _friendRequests.isNotEmpty ? Colors.blue[600] : Colors.grey[600],
                ),
                onPressed: _showFriendRequests,
              ),
              if (_friendRequests.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _friendRequests.length.toString(),
                      style: GoogleFonts.poppins(
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddFriendsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Friend Requests Section
          if (_showRequests && _friendRequests.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Friend Requests (${_friendRequests.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showRequests = false),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                  ..._friendRequests.map((request) => _buildFriendRequestCard(request)),
                ],
              ),
            ),
          
          // Main Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsStoriesTab(),
                _buildFriendsListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue[100],
            backgroundImage: user.profilePictureUrl != null
                ? NetworkImage(user.profilePictureUrl!)
                : null,
            child: user.profilePictureUrl == null
                ? Text(
                    user.displayName.isNotEmpty 
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.handle.startsWith('@') ? user.handle : '@${user.handle}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.bio!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Action Buttons
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _acceptFriendRequest(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Accept',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _rejectFriendRequest(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Ignore',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsStoriesTab() {
    return RefreshIndicator(
      onRefresh: _loadFriendsStories,
      child: _isLoadingStories && _friendsStories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _friendsStories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No friends\' stories yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your friends haven\'t posted any stories',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _friendsStories.length,
                  itemBuilder: (context, index) {
                    return _buildFriendStoryCard(_friendsStories[index]);
                  },
                ),
    );
  }

  Widget _buildFriendStoryCard(StoryModel story) {
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
          // Friend Story Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              backgroundImage: story.creatorProfilePicture != null
                  ? NetworkImage(story.creatorProfilePicture!)
                  : null,
              child: story.creatorProfilePicture == null
                  ? Text(
                      story.creatorUsername.isNotEmpty 
                          ? story.creatorUsername[0].toUpperCase()
                          : 'F',
                      style: TextStyle(
                        color: Colors.green[600],
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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: story.visibility == StoryVisibility.friends 
                    ? Colors.blue[100] 
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                story.visibility == StoryVisibility.friends 
                    ? 'Friends Only' 
                    : 'Public',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: story.visibility == StoryVisibility.friends 
                      ? Colors.blue[700] 
                      : Colors.green[700],
                ),
              ),
            ),
          ),
          
          // Friend Story Content
          GestureDetector(
            onTap: () => _viewStory(story),
            child: Container(
              height: 250,
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
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          story.isEncrypted ? Icons.lock : 
                          story.type == StoryType.image ? Icons.image : Icons.videocam,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          story.isEncrypted 
                              ? 'Encrypted Story'
                              : story.type == StoryType.image 
                                  ? 'Image Story' 
                                  : 'Video Story',
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
          
          // Friend Story Actions
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

  Widget _buildFriendsListTab() {
    return RefreshIndicator(
      onRefresh: _loadFriendsList,
      child: _isLoadingFriends && _friends.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No friends yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add friends to see their stories here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddFriendsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Friends'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    return _buildFriendCard(_friends[index]);
                  },
                ),
    );
  }

  Widget _buildFriendCard(UserModel friend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          backgroundImage: friend.profilePictureUrl != null
              ? NetworkImage(friend.profilePictureUrl!)
              : null,
          child: friend.profilePictureUrl == null
              ? Text(
                  friend.displayName.isNotEmpty 
                      ? friend.displayName[0].toUpperCase()
                      : 'F',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friend.handle.startsWith('@') ? friend.handle : '@${friend.handle}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (friend.bio != null && friend.bio!.isNotEmpty)
              Text(
                friend.bio!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message Button
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.message, color: Colors.white, size: 20),
                onPressed: () => _startChatWithFriend(friend),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Online Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: friend.isOnline ? Colors.green[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!friend.isOnline)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red[500],
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (!friend.isOnline)
                    const SizedBox(width: 4),
                  Text(
                    friend.isOnline ? 'Online' : 'Offline',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: friend.isOnline ? Colors.green[700] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showFriendProfile(friend),
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

  void _showFriendProfile(UserModel friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${friend.displayName}\'s profile coming soon!')),
    );
  }

  Future<void> _viewStory(StoryModel story) async {
    try {
      await _serviceManager.viewStory(story.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story viewed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing story: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleLike(StoryModel story) async {
    try {
      if (story.hasUserLiked(_serviceManager.currentUserId ?? '')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unlike feature coming soon!')),
        );
      } else {
        await _serviceManager.likeStory(story.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story liked!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error liking story: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareStory(StoryModel story) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!')),
    );
  }

  Future<void> _startChatWithFriend(UserModel friend) async {
    try {
      // Create or get existing direct chat
      final chatId = await _serviceManager.createDirectChat(friend.uid);
      
      // Navigate to chat conversation screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              chatId: chatId,
              otherUserId: friend.uid,
              otherUserName: friend.displayName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 