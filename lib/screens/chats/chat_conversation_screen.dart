import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId; // For direct chats
  final String? otherUserName; // For direct chats

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    this.otherUserId,
    this.otherUserName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AppServiceManager _serviceManager = AppServiceManager();
  
  ChatModel? _chat;
  List<MessageModel> _messages = [];
  UserModel? _otherUser; // Store the other user's data
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadChatAndMessages();
    _startMessageTimer();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startMessageTimer() {
    _messageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMessageTimers();
    });
  }

  void _updateMessageTimers() {
    final now = DateTime.now();
    final expiredMessages = <MessageModel>[];
    
    for (final message in _messages) {
      final timeElapsed = now.difference(message.createdAt).inSeconds;
      if (timeElapsed >= 30) {
        expiredMessages.add(message);
      }
    }
    
    if (expiredMessages.isNotEmpty) {
      // Delete expired messages from server
      _deleteExpiredMessagesFromServer(expiredMessages);
      
      // Remove from local list immediately
      setState(() {
        _messages.removeWhere((message) => expiredMessages.contains(message));
      });
    } else if (mounted) {
      // Force rebuild to update countdown timers
      setState(() {});
    }
  }

  Future<void> _deleteExpiredMessagesFromServer(List<MessageModel> expiredMessages) async {
    for (final message in expiredMessages) {
      try {
        // Delete message from server (for everyone)
        await _serviceManager.deleteMessage(message.id, forEveryone: true);
        print('ChatConversationScreen: Deleted expired message ${message.id} from server');
      } catch (e) {
        print('ChatConversationScreen: Failed to delete expired message ${message.id}: $e');
        // Continue with other messages even if one fails
      }
    }
  }

  List<MessageModel> _filterExpiredMessages(List<MessageModel> messages) {
    final now = DateTime.now();
    final validMessages = <MessageModel>[];
    final expiredMessages = <MessageModel>[];
    
    for (final message in messages) {
      final timeElapsed = now.difference(message.createdAt).inSeconds;
      if (timeElapsed >= 30) {
        expiredMessages.add(message);
      } else {
        validMessages.add(message);
      }
    }
    
    // Delete any expired messages found during reload
    if (expiredMessages.isNotEmpty) {
      _deleteExpiredMessagesFromServer(expiredMessages);
    }
    
    return validMessages;
  }

  int _getMessageTimeLeft(MessageModel message) {
    final now = DateTime.now();
    final timeElapsed = now.difference(message.createdAt).inSeconds;
    return 30 - timeElapsed;
  }

  Future<void> _loadChatAndMessages() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Load chat details
      final chat = await _serviceManager.getChatById(widget.chatId);
      if (chat != null) {
        setState(() => _chat = chat);
        
        // Load other user's data for direct chats
        if (chat.type == ChatType.direct) {
          final otherUserId = chat.getOtherParticipant(_serviceManager.currentUserId ?? '');
          if (otherUserId != null) {
            final otherUser = await _serviceManager.getUserById(otherUserId);
            setState(() => _otherUser = otherUser);
          }
        }
      }

      // Load messages and filter out expired ones
      final messages = await _serviceManager.getChatMessages(widget.chatId);
      final filteredMessages = _filterExpiredMessages(messages);
      setState(() {
        _messages = filteredMessages;
        _isLoading = false;
      });

      // Mark messages as read
      if (chat != null) {
        await _serviceManager.markMessagesAsRead(widget.chatId);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final messageId = await _serviceManager.sendMessage(
        chatId: widget.chatId,
        type: MessageType.text,
        content: message,
      );
      
      // Create a local message object and add it to the list
      // This avoids reloading all messages which could bring back expired ones
      final currentUser = _serviceManager.currentUser;
      if (currentUser != null) {
        final newMessage = MessageModel(
          id: messageId,
          chatId: widget.chatId,
          senderId: currentUser.uid,
          senderUsername: currentUser.handle,
          senderProfilePicture: currentUser.profilePictureUrl,
          type: MessageType.text,
          content: message,
          createdAt: DateTime.now(),
        );
        
        setState(() {
          _messages.insert(0, newMessage); // Insert at the beginning (reverse order)
        });
      }
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _getChatTitle() {
    if (_chat != null) {
      if (_chat!.type == ChatType.direct && _otherUser != null) {
        return _otherUser!.displayName; // Show full name
      } else {
        return _chat!.getDisplayName(_serviceManager.currentUserId ?? '');
      }
    }
    return widget.otherUserName ?? 'Chat';
  }

  String _getSenderDisplayName(MessageModel message) {
    if (message.senderId == _serviceManager.currentUserId) {
      // Current user - show first name
      final currentUser = _serviceManager.currentUser;
      if (currentUser != null && currentUser.displayName.isNotEmpty) {
        return currentUser.displayName.split(' ').first;
      }
      return 'You';
    } else {
      // Other user - show first name
      if (_otherUser != null && _otherUser!.displayName.isNotEmpty) {
        return _otherUser!.displayName.split(' ').first;
      }
      return message.senderUsername.split(' ').first; // Fallback to handle
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getChatTitle(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[600],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat options coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF), // Pure white at top
                          Color(0xFFBFDBFE), // More saturated light blue at bottom
                        ],
                      ),
                    ),
                  ),
                ),
                _isLoading && _messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
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
                                  'No messages yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a conversation!',
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
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageItem(_messages[index]);
                            },
                          ),
              ],
            ),
          ),
          
          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(MessageModel message) {
    final isCurrentUser = message.senderId == _serviceManager.currentUserId;
    final isDeleted = message.isDeleted;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              backgroundImage: message.senderProfilePicture != null
                  ? NetworkImage(message.senderProfilePicture!)
                  : null,
              child: message.senderProfilePicture == null
                  ? Text(
                      message.senderUsername.isNotEmpty 
                          ? message.senderUsername[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue[600] : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser) ...[
                    Text(
                      _getSenderDisplayName(message),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  
                  Text(
                    isDeleted ? 'This message was deleted' : message.content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isCurrentUser ? Colors.white : Colors.grey[800],
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isCurrentUser 
                              ? Colors.white.withOpacity(0.7) 
                              : Colors.grey[500],
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.hasUserRead(_serviceManager.currentUserId ?? '')
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: message.hasUserRead(_serviceManager.currentUserId ?? '')
                              ? Colors.white.withOpacity(0.7)
                              : Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // Countdown timer
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMessageTimeLeft(message) <= 5 
                            ? Icons.warning_amber 
                            : Icons.timer,
                        size: 10,
                        color: _getMessageTimeLeft(message) <= 5
                            ? Colors.red.withOpacity(0.7)
                            : isCurrentUser 
                                ? Colors.white.withOpacity(0.5) 
                                : Colors.grey[400],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _getMessageTimeLeft(message) <= 0 
                            ? 'Deleting...'
                            : 'Disappears in ${_getMessageTimeLeft(message)}s',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: _getMessageTimeLeft(message) <= 5
                              ? Colors.red.withOpacity(0.7)
                              : isCurrentUser 
                                  ? Colors.white.withOpacity(0.5) 
                                  : Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              backgroundImage: _serviceManager.currentUser?.profilePictureUrl != null
                  ? NetworkImage(_serviceManager.currentUser!.profilePictureUrl!)
                  : null,
              child: _serviceManager.currentUser?.profilePictureUrl == null
                  ? Text(
                      _serviceManager.currentUser?.displayName.isNotEmpty == true
                          ? _serviceManager.currentUser!.displayName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
} 