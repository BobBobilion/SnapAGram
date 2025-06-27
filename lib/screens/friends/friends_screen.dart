import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import 'add_friends_screen.dart';
import '../chats/chat_conversation_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<UserModel> _friends = [];
  List<UserModel> _friendRequests = [];
  bool _isLoadingFriends = false;
  bool _isLoadingRequests = false;
  bool _showRequests = false;

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFriendsList(),
      _loadFriendRequests(),
    ]);
  }

  Future<void> _refreshData() async {
    // Refresh both friends list and friend requests
    await Future.wait([
      _loadFriendsList(),
      _loadFriendRequests(),
    ]);
  }

  Future<void> _loadFriendsList() async {
    if (_isLoadingFriends) return;
    
    setState(() => _isLoadingFriends = true);
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final friends = await serviceManager.getCurrentUserFriends();
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
      final serviceManager = ref.read(appServiceManagerProvider);
      final requests = await serviceManager.getFriendRequests();
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
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.acceptFriendRequest(user.uid);
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
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.rejectFriendRequest(user.uid);
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
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Find',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Connection Requests Notification Icon
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: Colors.grey[600],
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
              icon: Icon(Icons.search, color: Colors.grey[600]),
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
                          color: AppTheme.getColorShade(userModel, 600),
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
                  ..._friendRequests.map((request) => _buildFriendRequestCard(request, userModel)),
                ],
              ),
            ),
          
          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: _friends.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pets,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No connections yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Search for walkers or dog owners to connect',
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
                                icon: const Icon(Icons.search),
                                label: const Text('Find People'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.getPrimaryColor(userModel),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        return _buildFriendCard(_friends[index], userModel);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestCard(UserModel user, UserModel? userModel) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getColorShade(userModel, 50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.getColorShade(userModel, 100),
            backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                ? NetworkImage(user.profilePictureUrl!)
                : null,
            child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                ? Text(
                    user.displayName.isNotEmpty 
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: AppTheme.getColorShade(userModel, 600),
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

  Widget _buildFriendCard(UserModel friend, UserModel? userModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.getColorShade(userModel, 50),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.getColorShade(userModel, 100),
              backgroundImage: friend.profilePictureUrl != null && friend.profilePictureUrl!.isNotEmpty
                  ? NetworkImage(friend.profilePictureUrl!)
                  : null,
              child: friend.profilePictureUrl == null || friend.profilePictureUrl!.isEmpty
                  ? Text(
                      friend.displayName.isNotEmpty 
                          ? friend.displayName[0].toUpperCase()
                          : 'F',
                      style: TextStyle(
                        color: AppTheme.getColorShade(userModel, 600),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            // Online/Offline status dot
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: friend.isOnline ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
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
        trailing: Container(
          decoration: BoxDecoration(
            color: AppTheme.getColorShade(userModel, 600),
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
        onTap: () => _showFriendProfile(friend),
      ),
    );
  }

  void _showFriendProfile(UserModel friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${friend.displayName}\'s profile coming soon!')),
    );
  }

  Future<void> _startChatWithFriend(UserModel friend) async {
    try {
      // Create or get existing direct chat
      final serviceManager = ref.read(appServiceManagerProvider);
      final chatId = await serviceManager.createDirectChat(friend.uid);
      
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