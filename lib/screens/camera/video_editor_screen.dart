import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'text_overlay_notifier.dart';
import 'video_post_screen.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final bool isFromCamera;

  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.isFromCamera = false,
  });

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  TabController? _tabController;
  
  bool _isInitialized = false;
  
  // Video playback controls
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _videoController!.value.duration;
        });
        
        // Add position listener
        _videoController!.addListener(() {
          if (mounted) {
            setState(() {
              _currentPosition = _videoController!.value.position;
            });
          }
        });
        
        _videoController!.setLooping(false);
        _videoController!.play();
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addTextOverlay() {
    ref.read(textOverlayProvider.notifier).add(TextOverlay(
      id: DateTime.now().toIso8601String(),
      text: 'Tap to edit',
      position: const Offset(0.5, 0.5),
      color: Colors.white,
      fontSize: 24.0,
      fontWeight: FontWeight.bold,
    ));
  }

  void _editTextOverlay(TextOverlay overlay) {
    _showTextEditDialog(overlay);
  }

  void _showTextEditDialog(TextOverlay overlay) {
    final textController = TextEditingController(text: overlay.text);
    Color selectedColor = overlay.color;
    double fontSize = overlay.fontSize;
    FontWeight fontWeight = overlay.fontWeight;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Text',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Size: '),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12.0,
                      max: 48.0,
                      divisions: 36,
                      activeColor: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
                      onChanged: (value) {
                        setDialogState(() => fontSize = value);
                      },
                    ),
                  ),
                  Text('${fontSize.round()}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Bold: '),
                  Switch(
                    value: fontWeight == FontWeight.bold,
                    activeColor: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
                    onChanged: (value) {
                      setDialogState(() {
                        fontWeight = value ? FontWeight.bold : FontWeight.normal;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick a color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: selectedColor,
                          onColorChanged: (color) {
                            selectedColor = color;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Center(
                    child: Text('Tap to change color'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(textOverlayProvider.notifier).remove(overlay.id);
                Navigator.pop(context);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(textOverlayProvider.notifier).update(overlay.copyWith(
                  text: textController.text,
                  color: selectedColor,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
    return '${duration.inSeconds}';
  }

  Future<void> _saveAndProceed() async {
    // Navigate to separate post screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPostScreen(
            videoPath: widget.videoPath,
            textOverlays: ref.read(textOverlayProvider),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textOverlays = ref.watch(textOverlayProvider);
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Prevent video resizing when keyboard opens
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: Text(
          'Edit Video',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saveAndProceed,
            child: Text(
              'Next',
              style: GoogleFonts.poppins(
                color: AppTheme.getPrimaryColor(userModel),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'Text'),
            Tab(icon: Icon(Icons.photo_filter), text: 'Filters'),
          ],
          labelColor: AppTheme.getPrimaryColor(userModel),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppTheme.getPrimaryColor(userModel),
        ),
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 140, // Account for app bar + tabs
                child: Column(
                  children: [
                    // Video Preview Section (Fixed Height)
                    Container(
                      height: 300, // Fixed height to prevent resizing
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
                            ...textOverlays.map((overlay) => DraggableVideoTextOverlay(
                              overlay: overlay, 
                              onEdit: _editTextOverlay,
                              videoSize: _videoController!.value.size,
                            )).toList(),
                            
                            // Play/Pause Overlay (only when paused)
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
                    
                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTextPanel(),
                          _buildFiltersPanel(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                overlayColor: AppTheme.getPrimaryColor(userModel)?.withOpacity(0.1),
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
            '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPanel() {
    final textOverlays = ref.watch(textOverlayProvider);
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Text Overlays',
                style: GoogleFonts.poppins(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addTextOverlay,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Text'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimaryColor(userModel),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (textOverlays.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap "Add Text" to add text overlays to your video',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: textOverlays.length,
              itemBuilder: (context, index) {
                final overlay = textOverlays[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      overlay.text,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Tap to edit, drag on video to move',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editTextOverlay(overlay),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            ref.read(textOverlayProvider.notifier).remove(overlay.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () => _editTextOverlay(overlay),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return const Center(
      child: Text(
        'Filters coming soon!',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
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
    // Calculate position based on video container size (300px height)
    final containerWidth = MediaQuery.of(context).size.width - 32; // Account for margins
    final containerHeight = 300.0;
    
    return Positioned(
      left: (_position.dx * containerWidth) - 50,
      top: (_position.dy * containerHeight) - 20,
      child: GestureDetector(
        onTap: () => widget.onEdit(widget.overlay),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (details.globalPosition.dx - 16) / containerWidth,
              (details.globalPosition.dy - 200) / containerHeight, // Account for app bar height
            );
          });
        },
        onPanEnd: (_) {
          ref.read(textOverlayProvider.notifier).update(widget.overlay.copyWith(position: _position));
        },
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
      ),
    );
  }
}

 