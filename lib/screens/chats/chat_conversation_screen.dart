import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  ChatModel? _chat;
  List<MessageModel> _messages = [];
  UserModel? _otherUser; // Store the other user's data
  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploadingImage = false;
  Timer? _messageTimer;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  Set<String> _deletingMessages = {}; // Track messages being deleted

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
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _startMessageTimer() {
    _messageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateMessageTimers();
    });
  }

  void _startListeningToMessages() {
    final serviceManager = ref.read(appServiceManagerProvider);
    _messagesSubscription = serviceManager.getChatMessagesStream(widget.chatId)
        .listen((messages) {
      if (mounted) {
        final filteredMessages = _filterExpiredMessages(messages);
        setState(() {
          _messages = filteredMessages;
        });
      }
    }, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _updateMessageTimers() {
    final now = DateTime.now();
    final expiredMessages = <MessageModel>[];
    
    for (final message in _messages) {
      final timeElapsed = now.difference(message.createdAt).inSeconds;
      // Only consider message expired if it's not already being deleted
      if (timeElapsed >= 86400 && !_deletingMessages.contains(message.id)) { // 24 hours
        expiredMessages.add(message);
      }
    }
    
    if (expiredMessages.isNotEmpty) {
      // Mark messages as being deleted to prevent duplicate deletion attempts
      for (final message in expiredMessages) {
        _deletingMessages.add(message.id);
      }
      
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
        final serviceManager = ref.read(appServiceManagerProvider);
        // Delete message from server (for everyone)
        await serviceManager.deleteMessage(message.id, forEveryone: true);
        print('ChatConversationScreen: Deleted expired message ${message.id} from server');
      } catch (e) {
        print('ChatConversationScreen: Failed to delete expired message ${message.id}: $e');
        // Remove from deleting set so it can be retried later if needed
        _deletingMessages.remove(message.id);
      }
    }
  }

  List<MessageModel> _filterExpiredMessages(List<MessageModel> messages) {
    final now = DateTime.now();
    final validMessages = <MessageModel>[];
    final expiredMessages = <MessageModel>[];
    
    for (final message in messages) {
      final timeElapsed = now.difference(message.createdAt).inSeconds;
      if (timeElapsed >= 86400) { // 24 hours
        // Only add to expired list if not already being deleted
        if (!_deletingMessages.contains(message.id)) {
          expiredMessages.add(message);
        }
      } else {
        validMessages.add(message);
        // Remove from deleting set if it's still valid (might have been re-created)
        _deletingMessages.remove(message.id);
      }
    }
    
    // Delete any expired messages found during reload
    if (expiredMessages.isNotEmpty) {
      // Mark messages as being deleted
      for (final message in expiredMessages) {
        _deletingMessages.add(message.id);
      }
      _deleteExpiredMessagesFromServer(expiredMessages);
    }
    
    return validMessages;
  }

  int _getMessageTimeLeft(MessageModel message) {
    final now = DateTime.now();
    final timeElapsed = now.difference(message.createdAt).inSeconds;
    return 86400 - timeElapsed; // 24 hours
  }

  String _formatTimeLeft(int seconds) {
    if (seconds <= 0) return 'Expired';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Widget _buildCountdownTimer(int timeLeft, bool isCurrentUser) {
    if (timeLeft <= 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.red.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Deleting...',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.red.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Calculate progress (0.0 to 1.0)
    final progress = (86400 - timeLeft) / 86400; // Total 24 hours = 86400 seconds
    final isWarning = timeLeft <= 3600; // Warning when 1 hour left

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 1.5,
            backgroundColor: isCurrentUser 
                ? Colors.white.withOpacity(0.3) 
                : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning
                  ? Colors.red.withOpacity(0.8)
                  : isCurrentUser 
                      ? Colors.white.withOpacity(0.7) 
                      : Colors.grey[500]!,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _formatTimeLeft(timeLeft),
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: isWarning
                ? Colors.red.withOpacity(0.7)
                : isCurrentUser 
                    ? Colors.white.withOpacity(0.5) 
                    : Colors.grey[400],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Future<void> _loadChatAndMessages() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      // Load chat details
      final chat = await serviceManager.getChatById(widget.chatId);
      if (chat != null) {
        setState(() => _chat = chat);
        
        // Load other user's data for direct chats
        if (chat.type == ChatType.direct) {
          final otherUserId = chat.getOtherParticipant(serviceManager.currentUserId ?? '');
          if (otherUserId != null) {
            final otherUser = await serviceManager.getUserById(otherUserId);
            setState(() => _otherUser = otherUser);
          }
        }
      }

      // Start listening to messages stream
      _startListeningToMessages();
      
      setState(() => _isLoading = false);

      // Mark messages as read
      if (chat != null) {
        await serviceManager.markMessagesAsRead(widget.chatId);
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
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.sendMessage(
        chatId: widget.chatId,
        type: MessageType.text,
        content: message,
      );
      
      // The real-time stream will automatically update the UI with the new message
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

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage) return;

    try {
      // Show options to take photo or pick from gallery
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      // Upload image to storage
      final currentUser = ref.read(appServiceManagerProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final String imageUrl = await StorageService.uploadChatImageFromBytes(
        await File(pickedFile.path).readAsBytes(),
        currentUser.uid,
        'jpg',
      );

      // Send image message that expires in 30 seconds
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.sendMessage(
        chatId: widget.chatId,
        type: MessageType.image,
        content: imageUrl,
      );

      // The real-time stream will automatically update the UI with the new message
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Delete the temporary file
      try {
        await File(pickedFile.path).delete();
      } catch (e) {
        print('Error deleting temporary file: $e');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Image',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take Photo',
                style: GoogleFonts.poppins(),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.poppins(),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
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

  String _getChatTitle() {
    if (_chat != null) {
      if (_chat!.type == ChatType.direct && _otherUser != null) {
        return _otherUser!.displayName; // Show full name
      } else {
        return _chat!.getDisplayName(ref.read(appServiceManagerProvider).currentUserId ?? '');
      }
    }
    return widget.otherUserName ?? 'Chat';
  }

  String _getSenderDisplayName(MessageModel message) {
    if (message.senderId == ref.read(appServiceManagerProvider).currentUserId) {
      // Current user - show first name
      final currentUser = ref.read(appServiceManagerProvider).currentUser;
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
    final serviceManager = ref.read(appServiceManagerProvider);
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    final currentUserId = serviceManager.currentUserId ?? '';
    final chatName = _chat?.getDisplayName(currentUserId) ?? widget.otherUserName ?? 'Chat';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          chatName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
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
                            itemCount: _messages.where((msg) => !msg.isDeleted).length,
                            itemBuilder: (context, index) {
                              final visibleMessages = _messages.where((msg) => !msg.isDeleted).toList();
                              final message = visibleMessages[index];
                              final bool isBottomMessage = index == 0; // Most recent message (bottom of chat)
                              return _buildMessageItem(message, isBottomMessage, userModel);
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
                // Camera Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isUploadingImage
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.getPrimaryColor(userModel)),
                            ),
                          )
                        : Icon(Icons.camera_alt, color: Colors.grey[600]),
                    onPressed: _isUploadingImage ? null : _pickAndSendImage,
                  ),
                ),
                const SizedBox(width: 8),
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
                    color: AppTheme.getColorShade(userModel, 600),
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

  Widget _buildMessageItem(MessageModel message, bool isBottomMessage, userModel) {
    final isCurrentUser = message.senderId == ref.read(appServiceManagerProvider).currentUserId;
    final isDeleted = message.isDeleted;
    final timeLeft = _getMessageTimeLeft(message);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser ? AppTheme.getColorShade(userModel, 600) : Colors.white,
                borderRadius: isBottomMessage 
                    ? BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isCurrentUser ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(18),
                      )
                    : BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && isBottomMessage) ...[
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
                  
                  // Message content
                  if (message.type == MessageType.image)
                    GestureDetector(
                      onTap: () {
                        // Show full-screen image viewer
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
                                            child: Image.network(
                                              message.content,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 200,
                          maxHeight: 300,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.content,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 150,
                                width: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.grey[600],
                                      size: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Failed to load image',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      message.content,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isCurrentUser ? Colors.white : Colors.grey[800],
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
                          message.hasUserRead(ref.read(appServiceManagerProvider).currentUserId ?? '')
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: message.hasUserRead(ref.read(appServiceManagerProvider).currentUserId ?? '')
                              ? Colors.white.withOpacity(0.7)
                              : Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // Countdown timer
                  _buildCountdownTimer(timeLeft, isCurrentUser),
                ],
              ),
            ),
          ),
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

class MessageTailPainter extends CustomPainter {
  final bool isCurrentUser;
  final Color color;

  MessageTailPainter({
    required this.isCurrentUser,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    if (isCurrentUser) {
      // Right tail for current user
      path.moveTo(size.width - 8, size.height);
      path.lineTo(size.width + 8, size.height + 8);
      path.lineTo(size.width - 8, size.height + 8);
      path.close();
    } else {
      // Left tail for other user
      path.moveTo(8, size.height);
      path.lineTo(-8, size.height + 8);
      path.lineTo(8, size.height + 8);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
