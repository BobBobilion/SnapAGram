import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../models/story_model.dart';
import 'text_overlay_notifier.dart';
import '../../providers/ui_provider.dart';

class VideoPostScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final List<TextOverlay> textOverlays;

  const VideoPostScreen({
    super.key,
    required this.videoPath,
    required this.textOverlays,
  });

  @override
  ConsumerState<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends ConsumerState<VideoPostScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  
  // Post settings
  final TextEditingController _captionController = TextEditingController();
  String _selectedVisibility = 'public';
  bool _isPosting = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
      await _videoController!.initialize();
      
      _videoController!.addListener(() {
        if (mounted) {
          setState(() {
            _currentPosition = _videoController!.value.position;
            _totalDuration = _videoController!.value.duration;
          });
        }
      });
      
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _seekTo(double value) {
    final position = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
    _videoController!.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    return '${duration.inSeconds}s';
  }

  Future<void> _postVideo() async {
    setState(() {
      _isPosting = true;
      _uploadStatus = 'Uploading video...';
    });

    try {
      final isPublic = _selectedVisibility == 'public';
      final caption = _captionController.text.trim();
      
      final serviceManager = ref.read(appServiceManagerProvider);
      final storyId = await serviceManager.createStory(
        type: StoryType.video,
        visibility: isPublic ? StoryVisibility.public : StoryVisibility.friends,
        mediaUrl: widget.videoPath,
        caption: caption.isNotEmpty ? caption : null,
      );
      
      debugPrint('Video story created with ID: $storyId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPublic ? 'Video posted to public stories!' : 'Video posted to friends only!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Trigger refresh of explore screen
        triggerExploreRefresh(ref);
        
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
            content: Text('Error posting video: $e'),
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: Text(
          'Post Video',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _postVideo,
            child: Text(
              'Post',
              style: GoogleFonts.poppins(
                color: _isPosting ? Colors.grey : AppTheme.getPrimaryColor(userModel),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Video Preview Section
                Container(
                  height: 300,
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Video Player
                        Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                        
                        // Text overlays
                        ...widget.textOverlays.map((overlay) => DraggableVideoTextOverlay(
                          overlay: overlay,
                          onEdit: (_) {}, // Read-only for post screen
                          videoSize: _videoController!.value.size,
                        )).toList(),
                        
                        // Play/Pause Overlay
                        if (!_videoController!.value.isPlaying)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Video Controls
                _buildVideoControls(),
                
                // Post Content
                Expanded(
                  child: _buildPostPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildVideoControls() {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play/Pause Button
          IconButton(
            onPressed: _togglePlayPause,
            icon: Icon(
              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: AppTheme.getPrimaryColor(userModel),
              size: 32,
            ),
          ),
          
          // Progress Bar
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.getPrimaryColor(userModel),
                inactiveTrackColor: Colors.grey[300],
                thumbColor: AppTheme.getPrimaryColor(userModel),
                overlayColor: AppTheme.getPrimaryColor(userModel).withOpacity(0.1),
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              ),
              child: Slider(
                value: _totalDuration.inMilliseconds > 0 
                    ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds 
                    : 0.0,
                onChanged: _seekTo,
                min: 0.0,
                max: 1.0,
              ),
            ),
          ),
          
          // Time Display
          Text(
            _formatDuration(_currentPosition),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostPanel() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caption Input
            Text(
              'Caption',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 3,
              enabled: !_isPosting,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Visibility Settings
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
              subtitle: 'Your video will be visible to all users',
              icon: Icons.public,
              color: Colors.green,
            ),
            
            const SizedBox(height: 12),
            
            // Friends Only Option
            _buildVisibilityOption(
              value: 'friends',
              title: 'Friends Only',
              subtitle: 'Only your friends can see this video',
              icon: Icons.people,
              color: Colors.blue,
            ),
            
            if (_isPosting)
              Container(
                margin: const EdgeInsets.only(top: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _uploadStatus.isEmpty ? 'Posting...' : _uploadStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
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
      onTap: _isPosting ? null : () => setState(() => _selectedVisibility = value),
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

class DraggableVideoTextOverlay extends ConsumerStatefulWidget {
  final TextOverlay overlay;
  final Function(TextOverlay) onEdit;
  final Size videoSize;

  const DraggableVideoTextOverlay({
    super.key, 
    required this.overlay, 
    required this.onEdit,
    required this.videoSize,
  });

  @override
  ConsumerState<DraggableVideoTextOverlay> createState() => _DraggableVideoTextOverlayState();
}

class _DraggableVideoTextOverlayState extends ConsumerState<DraggableVideoTextOverlay> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.overlay.position;
  }

  @override
  Widget build(BuildContext context) {
    final containerWidth = MediaQuery.of(context).size.width - 32;
    final containerHeight = 300.0;
    
    return Positioned(
      left: (_position.dx * containerWidth) - 50,
      top: (_position.dy * containerHeight) - 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.overlay.text,
          style: GoogleFonts.poppins(
            color: widget.overlay.color,
            fontSize: widget.overlay.fontSize,
            fontWeight: widget.overlay.fontWeight,
          ),
        ),
      ),
    );
  }
} 