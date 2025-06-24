import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  late AnimationController _flashAnimationController;
  late AnimationController _modeAnimationController;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  String _captureMode = 'photo'; // 'photo' or 'video'
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _modeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _flashAnimationController.dispose();
    _modeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls
            _buildTopControls(),
            
            // Camera Preview Area
            Expanded(
              child: _buildCameraPreview(),
            ),
            
            // Bottom Controls
            _buildBottomControls(),
          ],
        ),
      ),
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: _flashAnimationController,
                builder: (context, child) {
                  return Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellow : Colors.white,
                    size: 24,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    final isSelected = _captureMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.black : Colors.white,
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
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Camera Preview Placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera Preview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _captureMode == 'photo' ? 'Tap to capture photo' : 'Hold to record video',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                if (_captureMode == 'video' && _isRecording) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Recording: ${_recordingDuration}s',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 20,
                ),
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
        ],
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
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          
          // Capture Button
          GestureDetector(
            onTapDown: (_) => _startCapture(),
            onTapUp: (_) => _stopCapture(),
            onTapCancel: () => _stopCapture(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 4,
                ),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _captureMode == 'photo' ? Icons.camera_alt : Icons.fiber_manual_record,
                    color: _isRecording ? Colors.white : Colors.grey[600],
                    size: 32,
                  ),
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
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    if (_isFlashOn) {
      _flashAnimationController.forward();
    } else {
      _flashAnimationController.reverse();
    }
  }

  void _switchMode(String mode) {
    setState(() {
      _captureMode = mode;
      _isRecording = false;
      _recordingDuration = 0;
    });
    _modeAnimationController.forward().then((_) {
      _modeAnimationController.reverse();
    });
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  void _startCapture() {
    if (_captureMode == 'video') {
      setState(() {
        _isRecording = true;
      });
      _startRecordingTimer();
    } else {
      _capturePhoto();
    }
  }

  void _stopCapture() {
    if (_captureMode == 'video' && _isRecording) {
      setState(() {
        _isRecording = false;
      });
      _stopRecordingTimer();
      _saveVideo();
    }
  }

  void _capturePhoto() {
    // TODO: Implement photo capture
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo captured!'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _saveVideo() {
    // TODO: Implement video save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video saved! Duration: ${_recordingDuration}s'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _startRecordingTimer() {
    // TODO: Implement actual timer
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        setState(() {
          _recordingDuration++;
        });
        _startRecordingTimer();
      }
    });
  }

  void _stopRecordingTimer() {
    // Timer stops automatically when _isRecording becomes false
  }

  void _openGallery() {
    // TODO: Implement gallery access
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gallery coming soon!'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _showCameraSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: Icons.grid_on,
                      title: 'Grid',
                      subtitle: 'Show grid overlay',
                      value: _showGrid,
                      onChanged: (value) {
                        setState(() {
                          _showGrid = value;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.timer,
                      title: 'Timer',
                      subtitle: 'Set capture timer',
                      value: false,
                      onChanged: (value) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Timer feature coming soon!')),
                        );
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.aspect_ratio,
                      title: 'Aspect Ratio',
                      subtitle: 'Change aspect ratio',
                      value: false,
                      onChanged: (value) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aspect ratio feature coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      leading: Icon(
        icon,
        color: Colors.white,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  bool _showGrid = false;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
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