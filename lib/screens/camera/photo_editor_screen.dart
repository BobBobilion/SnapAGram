import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import 'share_story_screen.dart';
import 'text_overlay_notifier.dart';
import 'package:path_provider/path_provider.dart';

class PhotoEditorScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final bool isFromCamera;

  const PhotoEditorScreen({
    super.key,
    required this.imagePath,
    this.isFromCamera = false,
  });

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  img.Image? _originalImage;
  img.Image? _editedImage;
  bool _isLoading = true;
  
  // Editor modes
  String _currentMode = 'filters'; // 'filters', 'adjust', 'text'
  
  // Filter settings
  String _selectedFilter = 'none';
  
  // Adjustment settings
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _warmth = 0.0;
  double _vignette = 0.0;
  double _blur = 0.0;
  
  @override
  void initState() {
    super.initState();
    // Clear any existing text overlays when starting a new photo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(textOverlayProvider.notifier).clear();
      }
    });
    _loadImage();
  }

  @override
  void dispose() {
    // Clear text overlays when leaving the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(textOverlayProvider.notifier).clear();
    });
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final imageFile = File(widget.imagePath);
      final bytes = await imageFile.readAsBytes();
      _originalImage = img.decodeImage(bytes);
      _editedImage = img.copyResize(_originalImage!, width: 1080);
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading image: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String filterName) async {
    if (_originalImage == null) return;
    
    setState(() {
      _selectedFilter = filterName;
      _isLoading = true;
    });

    try {
      final params = ImageProcessingParams(
        originalImageBytes: Uint8List.fromList(img.encodePng(_originalImage!)),
        filterName: filterName,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        blur: _blur,
      );

      final processedBytes = await compute(_processImageInBackground, params);
      final processedImage = img.decodeImage(processedBytes);
      
      setState(() {
        _editedImage = processedImage;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error applying filter: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying filter: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  img.Image _applyVintageFilter(img.Image image) {
    // Apply sepia and reduce saturation for vintage look
    image = img.sepia(image);
    image = img.adjustColor(image, saturation: 0.7, contrast: 1.2);
    return image;
  }

  img.Image _applyCoolFilter(img.Image image) {
    // Increase blue tones
    return img.adjustColor(image, 
      contrast: 1.1
    );
  }

  img.Image _applyWarmFilter(img.Image image) {
    // Increase red/yellow tones
    return img.adjustColor(image, 
      saturation: 1.1
    );
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
          content: SingleChildScrollView(
            child: Column(
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

  void _resetAdjustments() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _warmth = 0.0;
      _vignette = 0.0;
      _blur = 0.0;
    });
    _applyFilter(_selectedFilter);
  }

  Future<void> _saveAndProceed() async {
    if (_editedImage == null) return;

    try {
      setState(() => _isLoading = true);
      
      // Capture the composed image with text overlays
      final RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        // Save the final image to app documents directory for better persistence
        final appDir = await getApplicationDocumentsDirectory();
        final finalImagePath = '${appDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png';
        final finalFile = File(finalImagePath);
        await finalFile.writeAsBytes(byteData.buffer.asUint8List());
        
        setState(() => _isLoading = false);
        
        // Navigate to post options
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ShareStoryScreen(
                imagePath: finalImagePath,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textOverlays = ref.watch(textOverlayProvider);

    return WillPopScope(
      onWillPop: () async {
        // Clear text overlays when user presses back button
        // Use a microtask to avoid build-time modification
        Future.microtask(() {
          ref.read(textOverlayProvider.notifier).clear();
        });
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          title: Text(
            'Edit Photo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveAndProceed,
              child: Text(
                'Next',
                style: GoogleFonts.poppins(
                  color: AppTheme.getPrimaryColor(ref.watch(authServiceProvider).userModel),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : Column(
                children: [
                  // Image Preview
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: Stack(
                          children: [
                            // Image
                            if (_editedImage != null)
                              Center(
                                child: Image.memory(
                                  Uint8List.fromList(img.encodePng(_editedImage!)),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            // Text overlays
                            ...textOverlays.map((overlay) => DraggableTextOverlay(overlay: overlay, onEdit: _editTextOverlay)).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Mode Selector
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModeButton('filters', 'Filters', Icons.photo_filter),
                        _buildModeButton('adjust', 'Adjust', Icons.tune),
                        _buildModeButton('text', 'Text', Icons.text_fields),
                      ],
                    ),
                  ),
                  
                  // Editor Panel
                  Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: _buildEditorPanel(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isSelected = _currentMode == mode;
    final userModel = ref.watch(authServiceProvider).userModel;
    
    return GestureDetector(
      onTap: () => setState(() => _currentMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.getPrimaryColor(userModel) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    switch (_currentMode) {
      case 'filters':
        return _buildFiltersPanel();
      case 'adjust':
        return _buildAdjustPanel();
      case 'text':
        return _buildTextPanel();
      default:
        return const SizedBox();
    }
  }

  Widget _buildFiltersPanel() {
    const filters = [
      {'name': 'none', 'label': 'Original'},
      {'name': 'sepia', 'label': 'Sepia'},
      {'name': 'grayscale', 'label': 'B&W'},
      {'name': 'vintage', 'label': 'Vintage'},
      {'name': 'cool', 'label': 'Cool'},
      {'name': 'warm', 'label': 'Warm'},
      {'name': 'high_contrast', 'label': 'Contrast'},
      {'name': 'soft', 'label': 'Soft'},
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        final isSelected = _selectedFilter == filter['name'];
        
        return GestureDetector(
          onTap: () => _applyFilter(filter['name']!),
          child: Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected 
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  child: Icon(
                    Icons.photo_filter,
                    color: isSelected ? Colors.white : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filter['label']!,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.blue : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdjustPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Adjustments',
                style: GoogleFonts.poppins(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: _resetAdjustments,
                child: Text(
                  'Reset',
                  style: GoogleFonts.poppins(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              _buildAdjustmentSlider(
                'Brightness',
                _brightness,
                -100,
                100,
                (value) {
                  setState(() => _brightness = value);
                  _applyFilter(_selectedFilter);
                },
              ),
              _buildAdjustmentSlider(
                'Contrast',
                _contrast,
                0.5,
                2.0,
                (value) {
                  setState(() => _contrast = value);
                  _applyFilter(_selectedFilter);
                },
              ),
              _buildAdjustmentSlider(
                'Saturation',
                _saturation,
                0.0,
                2.0,
                (value) {
                  setState(() => _saturation = value);
                  _applyFilter(_selectedFilter);
                },
              ),
              _buildAdjustmentSlider(
                'Blur',
                _blur,
                0.0,
                10.0,
                (value) {
                  setState(() => _blur = value);
                  _applyFilter(_selectedFilter);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustmentSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey[800],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  Widget _buildTextPanel() {
    final textOverlays = ref.watch(textOverlayProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                icon: const Icon(Icons.add),
                label: const Text('Add Text'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: textOverlays.isEmpty
              ? Center(
                  child: Text(
                    'Tap "Add Text" to add text overlays',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: textOverlays.length,
                  itemBuilder: (context, index) {
                    final overlay = textOverlays[index];
                    return ListTile(
                      title: Text(
                        overlay.text,
                        style: GoogleFonts.poppins(color: Colors.grey[800]),
                      ),
                      subtitle: Text(
                        'Tap to edit, drag to move, pinch to resize',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          ref.read(textOverlayProvider.notifier).remove(overlay.id);
                        },
                      ),
                      onTap: () => _editTextOverlay(overlay),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DraggableTextOverlay extends ConsumerStatefulWidget {
  final TextOverlay overlay;
  final Function(TextOverlay) onEdit;

  const DraggableTextOverlay({super.key, required this.overlay, required this.onEdit});

  @override
  ConsumerState<DraggableTextOverlay> createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends ConsumerState<DraggableTextOverlay> {
  late Offset _position;
  double _fontSize = 24.0; // Initialize with default value

  @override
  void initState() {
    super.initState();
    _position = widget.overlay.position;
    _fontSize = widget.overlay.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx * MediaQuery.of(context).size.width - 100,
      top: _position.dy * 300,
      child: GestureDetector(
        onTap: () {
          widget.onEdit(widget.overlay);
        },
        onScaleStart: (details) {
          // Store initial position for pan calculations
        },
        onScaleUpdate: (details) {
          setState(() {
            // Handle pan movement (single finger or multi-finger drag)
            if (details.pointerCount == 1) {
              // Single finger - handle pan
              _position = Offset(
                (details.focalPoint.dx) / MediaQuery.of(context).size.width,
                (details.focalPoint.dy - 200) / 300,
              );
            } else if (details.pointerCount > 1) {
              // Multi-finger - handle scale
              final newFontSize = (widget.overlay.fontSize * details.scale).clamp(12.0, 72.0);
              _fontSize = newFontSize;
            }
          });
        },
        onScaleEnd: (details) {
          ref.read(textOverlayProvider.notifier).update(widget.overlay.copyWith(
            position: _position,
            fontSize: _fontSize,
          ));
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
              fontSize: _fontSize,
              fontWeight: widget.overlay.fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}

// Data class to pass parameters to the isolate
class ImageProcessingParams {
  final Uint8List originalImageBytes;
  final String filterName;
  final double brightness;
  final double contrast;
  final double saturation;
  final double blur;

  ImageProcessingParams({
    required this.originalImageBytes,
    required this.filterName,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.blur,
  });
}

// Top-level function for image processing in an isolate
Future<Uint8List> _processImageInBackground(ImageProcessingParams params) async {
  img.Image? image = img.decodeImage(params.originalImageBytes);
  if (image == null) {
    throw Exception('Failed to decode image in isolate');
  }

  // Resize for consistent processing
  image = img.copyResize(image, width: 1080);

  // Apply filter
  switch (params.filterName) {
    case 'sepia':
      image = img.sepia(image);
      break;
    case 'grayscale':
      image = img.grayscale(image);
      break;
    case 'vintage':
      image = _applyVintageFilter(image);
      break;
    case 'cool':
      image = _applyCoolFilter(image);
      break;
    case 'warm':
      image = _applyWarmFilter(image);
      break;
    case 'high_contrast':
      image = img.contrast(image, contrast: 1.5);
      break;
    case 'soft':
      image = img.gaussianBlur(image, radius: 1);
      break;
    case 'none':
    default:
      // No filter applied
      break;
  }

  // Apply adjustments
  if (params.brightness != 0.0) {
    final normalizedBrightness = params.brightness / 100.0;
    image = img.adjustColor(image, brightness: normalizedBrightness);
  }
  if (params.contrast != 1.0) {
    image = img.contrast(image, contrast: params.contrast);
  }
  if (params.saturation != 1.0) {
    image = img.adjustColor(image, saturation: params.saturation);
  }
  if (params.blur > 0.0) {
    image = img.gaussianBlur(image, radius: params.blur.round());
  }

  return Uint8List.fromList(img.encodePng(image));
}

// Helper functions for filters (must be top-level for isolates)
img.Image _applyVintageFilter(img.Image image) {
  image = img.sepia(image);
  image = img.adjustColor(image, saturation: 0.7, contrast: 1.2);
  return image;
}

img.Image _applyCoolFilter(img.Image image) {
  return img.adjustColor(image, contrast: 1.1);
}

img.Image _applyWarmFilter(img.Image image) {
  return img.adjustColor(image, saturation: 1.1);
} 