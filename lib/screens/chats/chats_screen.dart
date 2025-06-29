import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapagram/providers/ui_provider.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import 'chat_conversation_screen.dart';
import '../../services/notification_service.dart';
import '../../services/user_database_service.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<ChatModel> _chats = [];
  List<ChatModel> _archivedChats = [];
  bool _isLoading = false;
  bool _showArchivedChats = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    
    // Mark all chats as read when user opens chats screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllChatsAsRead();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final allChats = await serviceManager.getCurrentUserChats();
      if (mounted) {
        setState(() {
          _chats = allChats.where((chat) => chat.isActive).toList();
          _archivedChats = allChats.where((chat) => !chat.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllChatsAsRead() async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final currentUserId = serviceManager.currentUserId;
      if (currentUserId != null) {
        await NotificationService.markAllChatsAsRead(currentUserId);
      }
    } catch (e) {
      print('Error marking chats as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    final unreadCount = ref.watch(unreadMessageCountProvider).value ?? 0;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Chats',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[600]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search chats coming soon!'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.group_add, color: Colors.grey[600]),
            onPressed: () {
              _showCreateGroupDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                // TODO: Implement search functionality
              },
            ),
          ),
          // Chats List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadChats,
              child: _isLoading && _chats.isEmpty && _archivedChats.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _chats.isEmpty && _archivedChats.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No chats yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pull down to refresh or start a chat',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Use the provider to navigate to the Friends tab (index 1)
                                      ref.read(bottomNavIndexProvider.notifier).state = 1;
                                    },
                                    icon: const Icon(Icons.group_add),
                                    label: const Text('Start Chat'),
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
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            // Active Chats
                            if (_chats.isNotEmpty) ...[
                              ..._chats.map((chat) => _buildChatItem(chat, userModel)),
                            ],
                            
                            // Archived Chats Section
                            if (_archivedChats.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showArchivedChats = !_showArchivedChats;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.archive,
                                        color: Colors.grey[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Archived Chats (${_archivedChats.length})',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        _showArchivedChats ? Icons.expand_less : Icons.expand_more,
                                        color: Colors.grey[600],
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showArchivedChats) ...[
                                const SizedBox(height: 8),
                                ..._archivedChats.map((chat) => _buildArchivedChatItem(chat, userModel)),
                              ],
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat, UserModel? userModel) {
    final serviceManager = ref.read(appServiceManagerProvider);
    final currentUserId = serviceManager.currentUserId ?? '';
    final isGroup = chat.type == ChatType.group;
    final unreadCount = chat.getUnreadCount(currentUserId);
    final hasUnreadMessages = unreadCount > 0;
    final displayName = chat.getDisplayName(currentUserId);
    final avatarUrl = chat.getChatAvatarUrl(currentUserId);
    final lastMessageTime = chat.lastMessageTime;
    final String? otherUserId = isGroup ? null : chat.getOtherParticipant(currentUserId);
    
    final isAvatarUrlValid = avatarUrl != null && (Uri.tryParse(avatarUrl)?.host.isNotEmpty ?? false);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.getColorShade(userModel, 50),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isGroup ? Colors.orange[100] : AppTheme.getColorShade(userModel, 100),
              backgroundImage: isAvatarUrlValid
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: !isAvatarUrlValid
                  ? Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: isGroup ? Colors.orange[600] : AppTheme.getPrimaryColor(userModel),
                    )
                  : null,
            ),
            if (hasUnreadMessages)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Online/Offline status dot
            if (!isGroup && otherUserId != null && otherUserId.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                child: Consumer(
                  builder: (context, ref, child) {
                    final userAsync = ref.watch(userProfileProvider(otherUserId));
                    return userAsync.when(
                      data: (user) {
                        final isOnline = user?.isOnline ?? false;
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.red, // Online status
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
          ],
        ),
        title: isGroup
            ? Text(
                displayName,
                style: GoogleFonts.poppins(
                  fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 16,
                  color: hasUnreadMessages ? Colors.black : Colors.grey[800],
                ),
              )
            : Consumer(
                builder: (context, ref, child) {
                  if (otherUserId == null || otherUserId.isEmpty) {
                    return Text(
                      displayName, // Fallback to handle
                      style: GoogleFonts.poppins(
                        fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 16,
                        color: hasUnreadMessages ? Colors.black : Colors.grey[800],
                      ),
                    );
                  }
                  final userAsync = ref.watch(userProfileProvider(otherUserId));
                  return userAsync.when(
                    data: (user) => Text(
                      user?.displayName ?? displayName,
                      style: GoogleFonts.poppins(
                        fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 16,
                        color: hasUnreadMessages ? Colors.black : Colors.grey[800],
                      ),
                    ),
                    loading: () => Text(
                      displayName, // Show handle while loading
                      style: GoogleFonts.poppins(
                        fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 16,
                        color: hasUnreadMessages ? Colors.black : Colors.grey[800],
                      ),
                    ),
                    error: (e, st) => Text(
                      displayName, // Show handle on error
                      style: GoogleFonts.poppins(
                        fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 16,
                        color: hasUnreadMessages ? Colors.black : Colors.grey[800],
                      ),
                    ),
                  );
                },
              ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chat.lastMessageContent ?? 'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: hasUnreadMessages ? Colors.grey[800] : Colors.grey[600],
                fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (chat.isEncrypted) ...[
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'E2EE',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  lastMessageTime != null ? _formatTime(lastMessageTime) : '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () async => await _openChat(chat),
        onLongPress: () => _showChatOptions(context, chat),
      ),
    );
  }

  Widget _buildArchivedChatItem(ChatModel chat, UserModel? userModel) {
    final serviceManager = ref.read(appServiceManagerProvider);
    final currentUserId = serviceManager.currentUserId ?? '';
    final isGroup = chat.type == ChatType.group;
    final displayName = chat.getDisplayName(currentUserId);
    final avatarUrl = chat.getChatAvatarUrl(currentUserId);
    final lastMessageTime = chat.lastMessageTime;
    final String? otherUserId = isGroup ? null : chat.getOtherParticipant(currentUserId);
    
    final isAvatarUrlValid = avatarUrl != null && (Uri.tryParse(avatarUrl)?.host.isNotEmpty ?? false);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey[200], // Different color for archived chats
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: isAvatarUrlValid
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: !isAvatarUrlValid
                  ? Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: Colors.grey[600],
                    )
                  : null,
            ),
            // Archive indicator
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.archive,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chat.lastMessageContent ?? 'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.archive,
                  size: 12,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Archived',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  lastMessageTime != null ? _formatTime(lastMessageTime) : '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () async => await _openChat(chat),
        onLongPress: () => _showArchivedChatOptions(context, chat),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create Group Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter group description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create group feature coming soon!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(ChatModel chat) async {
    try {
      // Clear notifications for this specific chat
      final serviceManager = ref.read(appServiceManagerProvider);
      final currentUserId = serviceManager.currentUserId;
      if (currentUserId != null) {
        await NotificationService.markChatAsRead(chat.id, currentUserId);
      }
    } catch (e) {
      print('Error clearing chat notification: $e');
    }
    
    // Navigate to chat conversation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          chatId: chat.id,
          otherUserId: chat.getOtherParticipant(ref.read(appServiceManagerProvider).currentUserId ?? ''),
          otherUserName: chat.getDisplayName(ref.read(appServiceManagerProvider).currentUserId ?? ''),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, ChatModel chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Archive Chat', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _confirmArchiveChat(context, chat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _confirmDeleteChat(context, chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showArchivedChatOptions(BuildContext context, ChatModel chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive, color: Colors.green),
              title: const Text('Unarchive Chat', style: TextStyle(color: Colors.green)),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _confirmUnarchiveChat(context, chat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _confirmDeleteChat(context, chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchiveChat(BuildContext context, ChatModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Chat?'),
        content: const Text('This will hide the chat from your chat list. You can restore it later from your profile settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await _archiveChat(chat);
            },
            child: const Text('Archive', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, ChatModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will permanently delete the chat and all messages. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await _deleteChat(chat);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmUnarchiveChat(BuildContext context, ChatModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unarchive Chat?'),
        content: const Text('This will restore the chat to your main chat list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await _unarchiveChat(chat);
            },
            child: const Text('Unarchive', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveChat(ChatModel chat) async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.archiveChat(chat.id);
      
      // Remove from local list and update UI
      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat archived successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error archiving chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteChat(ChatModel chat) async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.deleteChat(chat.id);
      
      // Remove from local list and update UI
      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unarchiveChat(ChatModel chat) async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.unarchiveChat(chat.id);
      
      // Update local lists
      setState(() {
        _archivedChats.removeWhere((c) => c.id == chat.id);
        _chats.add(chat.copyWith(isActive: true));
        _chats.sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat unarchived successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unarchiving chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 