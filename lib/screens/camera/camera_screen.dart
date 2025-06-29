import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../services/story_database_service.dart';
import '../../services/user_database_service.dart';
import '../../utils/app_theme.dart';
import 'photo_editor_screen.dart';
import 'video_editor_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isFlashOn = false;
  FlashMode _flashMode = FlashMode.off;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  String _captureMode = 'photo'; // 'photo' or 'video'
  int _recordingDuration = 0;
  bool _showGrid = false;
  bool _permissionGranted = false;
  final DeepArControllerPlus _deepArController = DeepArControllerPlus();
  String _currentEffect = 'none';
  List<String> _effects = [
    'none',
    'assets/effects/viking_helmet.deepar',
    'assets/effects/MakeupLook.deepar',
    'assets/effects/Neon_Devil_Horns.deepar',
    'assets/effects/flower_face.deepar',
    'assets/effects/Stallone.deepar',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepArController.destroy();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _deepArController.destroy();
    }
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
    super.didChangeAppLifecycleState(state);
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

      // Initialize DeepAR
      final dynamic result = await _deepArController.initialize(
        androidLicenseKey: dotenv.env['DEEPAR_ANDROID_KEY']!,
        iosLicenseKey: '',
      );
      
      bool isSuccess = false;
      if (result is bool) {
        isSuccess = result;
      } else {
        isSuccess = result.success;
      }

      if (mounted && isSuccess) {
        setState(() => _isInitialized = true);
      } else {
        debugPrint('Failed to initialize DeepAR');
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final File? photoFile = await _deepArController.takeScreenshot();
      if (photoFile == null) return;
      final XFile photo = XFile(photoFile.path);

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
    if (_isRecording) {
      return;
    }

    try {
      await _deepArController.startVideoRecording();
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
    if (!_isRecording) {
      return;
    }

    try {
      final File? videoFile = await _deepArController.stopVideoRecording();
      if (videoFile == null) return;
      final XFile video = XFile(videoFile.path);
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

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _deepArController.toggleFlash();
  }

  Icon _getFlashIcon() {
    return Icon(
      _isFlashOn ? Icons.flash_on : Icons.flash_off,
      color: Colors.black,
      size: 28,
    );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 28,
            ),
          ),
          Row(
            children: [
              // IconButton(
              //   onPressed: _toggleFlash,
              //   icon: _getFlashIcon(),
              // ),
              IconButton(
                onPressed: () {
                  // Open settings or something
                },
                icon: const Icon(
                  Icons.settings,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              child: Transform.scale(
                scale: _deepArController.aspectRatio,
                child: DeepArPreviewPlus(_deepArController),
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
                onTap: () => _deepArController.flipCamera(),
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
    return Column(
      children: [
        // Filter Selector
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _effects.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _currentEffect = _effects[index];
                  _deepArController.switchEffect(_currentEffect);
                  setState(() {});
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentEffect == _effects[index]
                          ? Colors.blue
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _effects[index]
                          .split('/')
                          .last
                          .replaceAll('.deepar', ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: _currentEffect == _effects[index]
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModeButton('photo', 'Photo'),
            const SizedBox(width: 20),
            _buildModeButton('video', 'Video'),
          ],
        ),
        Container(
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
                    color: AppTheme.getPrimaryColor(
                        ref.watch(authServiceProvider).userModel),
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
        ),
      ],
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