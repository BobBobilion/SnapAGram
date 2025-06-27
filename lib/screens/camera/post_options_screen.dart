import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/story_model.dart';
import '../../utils/app_theme.dart';

class PostOptionsScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const PostOptionsScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<PostOptionsScreen> createState() => _PostOptionsScreenState();
}

class _PostOptionsScreenState extends ConsumerState<PostOptionsScreen> {
  final TextEditingController _captionController = TextEditingController();
  
  String _selectedVisibility = 'public'; // 'public' or 'friends'
  bool _isPosting = false;
  String _uploadStatus = '';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _postStory() async {
    setState(() {
      _isPosting = true;
      _uploadStatus = 'Preparing...';
    });

    try {
      final isPublic = _selectedVisibility == 'public';
      final caption = _captionController.text.trim();
      
      setState(() => _uploadStatus = 'Uploading image...');
      
      // Create the story using the service manager - it will handle Firebase Storage upload
      final serviceManager = ref.read(appServiceManagerProvider);
      final storyId = await serviceManager.createStory(
        type: StoryType.image,
        visibility: isPublic ? StoryVisibility.public : StoryVisibility.friends,
        mediaUrl: widget.imagePath, // Local file path - will be uploaded automatically
        caption: caption.isNotEmpty ? caption : null,
      );
      
      setState(() => _uploadStatus = 'Creating story...');
      
      print('Story created with ID: $storyId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPublic ? 'Posted to public stories!' : 'Posted to friends only!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to main app
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isPosting = false;
        _uploadStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Share Story',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _postStory,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: GoogleFonts.poppins(
                      color: AppTheme.getColorShade(userModel, 600),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Preview
            AspectRatio(
              aspectRatio: 1, // You can adjust this ratio as needed
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Caption Input
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Add a caption',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    maxLength: 280,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.getColorShade(userModel, 600) ?? Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Visibility Options
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Who can see this?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Public Option
                  _buildVisibilityOption(
                    value: 'public',
                    title: 'Everyone',
                    subtitle: 'Your story will be visible to all Snapagram users',
                    icon: Icons.public,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 12),

                  // Friends Only Option
                  _buildVisibilityOption(
                    value: 'friends',
                    title: 'Friends Only',
                    subtitle: 'Only your friends can see this story',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),

            // Post Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isPosting ? null : _postStory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getColorShade(userModel, 600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isPosting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _uploadStatus.isEmpty ? 'Posting...' : _uploadStatus,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _selectedVisibility == 'public'
                            ? 'Post to Everyone'
                            : 'Post to Friends',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedVisibility == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedVisibility = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}