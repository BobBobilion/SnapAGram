import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'photo_editor_screen.dart';
import 'video_editor_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  String _captureMode = 'photo'; // 'photo' or 'video'
  int _recordingDuration = 0;
  bool _showGrid = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop video recording if active
    if (_isRecording && _cameraController?.value.isRecordingVideo == true) {
      _cameraController?.stopVideoRecording().catchError((e) {
        debugPrint('Error stopping video recording on dispose: $e');
        throw e;
      });
    }
    
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      await Permission.microphone.request();
      
      if (cameraPermission != PermissionStatus.granted) {
        setState(() => _permissionGranted = false);
        return;
      }

      setState(() => _permissionGranted = true);

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Initialize camera controller
      _cameraController = CameraController(
        _cameras[_isFrontCamera ? 1 : 0],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });

    await _cameraController?.dispose();
    
    _cameraController = CameraController(
      _cameras[_isFrontCamera ? 1 : 0],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera switch error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    
    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
    });
    
    await _cameraController!.setFlashMode(_flashMode);
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Set flash mode for capture
      await _cameraController!.setFlashMode(_flashMode);

      final XFile photo = await _cameraController!.takePicture();

      // Turn flash off after capture
      if (_flashMode == FlashMode.always) {
        await _cameraController!.setFlashMode(FlashMode.off);
      }
      
      // Navigate to photo editor
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(
              imagePath: photo.path,
              isFromCamera: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _isRecording ||
        _cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        _startRecordingTimer();
      }
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting video recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || 
        !_isRecording || 
        !_cameraController!.value.isRecordingVideo) {
      if (mounted) {
        setState(() => _isRecording = false);
      }
      return;
    }

    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      if (mounted) {
        setState(() => _isRecording = false);
        
        // Navigate to video editor
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoEditorScreen(
              videoPath: video.path,
              isFromCamera: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping video recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startRecordingTimer() {
    if (!_isRecording || !mounted) return;
    
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _recordingDuration++);
        if (_recordingDuration >= 60) {
          _stopVideoRecording(); // Max 60 seconds
        } else {
          _startRecordingTimer();
        }
      }
    });
  }

  void _switchMode(String mode) {
    if (_isRecording) return;
    
    setState(() {
      _captureMode = mode;
      _recordingDuration = 0;
    });
  }

  void _handleVideoCapture() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: !_permissionGranted
            ? _buildPermissionDenied()
            : !_isInitialized
                ? _buildLoadingScreen()
                : _buildCameraInterface(),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Permission Required',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please allow camera access to take photos',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildCameraInterface() {
    return Column(
      children: [
        // Top Controls
        _buildTopControls(),
        
        // Camera Preview
        Expanded(
          child: _buildCameraPreview(),
        ),
        
        // Bottom Controls
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          
          // Mode Selector
          Row(
            children: [
              _buildModeButton('photo', 'Photo'),
              const SizedBox(width: 16),
              _buildModeButton('video', 'Video'),
            ],
          ),
          
          // Flash Button
          GestureDetector(
            onTap: _toggleFlash,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getFlashIcon(),
                color: _flashMode == FlashMode.off ? Colors.black : Colors.amber,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  Widget _buildModeButton(String mode, String label) {
    final authService = ref.watch(authServiceProvider);
    final userModel = authService.userModel;
    final isSelected = _captureMode == mode;
    final primaryColor = AppTheme.getPrimaryColor(userModel);
    
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Camera Preview - Fill available space while maintaining aspect ratio
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            
            // Grid Overlay
            if (_showGrid)
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(),
                ),
              ),
            
            // Camera Switch Button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flip_camera_ios_outlined,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ),
            
            // Recording Indicator
            if (_isRecording)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_recordingDuration}s',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Gallery Button
          GestureDetector(
            onTap: _openGallery,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
          
          // Capture Button
          GestureDetector(
            onTap: () {
              if (_captureMode == 'photo') {
                _capturePhoto();
              } else {
                _handleVideoCapture();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: Icon(
                  _captureMode == 'photo' 
                      ? Icons.camera_alt_outlined 
                      : _isRecording 
                          ? Icons.stop_outlined 
                          : Icons.videocam_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          
          // Settings Button
          GestureDetector(
            onTap: _showCameraSettings,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGallery() async {
    // TODO: Implement gallery picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gallery picker coming soon!')),
    );
  }

  void _showCameraSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.grid_on_outlined,
                    title: 'Grid',
                    subtitle: 'Show grid overlay',
                    value: _showGrid,
                    onChanged: (value) {
                      setState(() => _showGrid = value);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 1;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}