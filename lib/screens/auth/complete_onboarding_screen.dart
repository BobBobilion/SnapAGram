import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math';

import '../../models/enums.dart';
import '../../models/walker_profile.dart';
import '../../models/owner_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_database_service.dart';
import '../../services/storage_service.dart';
import '../home/home_screen.dart';

class CompleteOnboardingScreen extends StatefulWidget {
  final String email;
  final String displayName;
  final String handle;

  const CompleteOnboardingScreen({
    super.key,
    required this.email,
    required this.displayName,
    required this.handle,
  });

  @override
  State<CompleteOnboardingScreen> createState() => _CompleteOnboardingScreenState();
}

class _CompleteOnboardingScreenState extends State<CompleteOnboardingScreen>
    with TickerProviderStateMixin {
  // Controllers and form keys
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Basic info
  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  
  // Role selection
  UserRole? _selectedRole;
  
  // Walker-specific
  Set<DogSize> _selectedDogSizes = {};
  Set<WalkDuration> _selectedWalkDurations = {};
  Set<Availability> _selectedAvailability = {};
  
  // Owner-specific
  late TextEditingController _dogNameController;
  late TextEditingController _dogBreedController;
  late TextEditingController _dogAgeController;
  late TextEditingController _dogBioController;
  late TextEditingController _specialInstructionsController;
  File? _dogImage;
  DogSize? _dogSize;
  String? _dogGender;
  WalkDuration? _preferredWalkDuration;
  
  // UI state
  int _currentStep = 0;
  bool _isLoading = false;
  final int _totalSteps = 5;
  
  // DogWalk colors
  static const Color cornflowerBlue = Color(0xFF6495ED);
  static const Color skyBlue = Color(0xFF87CEEB);
  static const Color lightBlueWhite = Color(0xFFFAFAFF);
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
  }
  
  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.displayName);
    _handleController = TextEditingController(text: widget.handle);
    _bioController = TextEditingController();
    _cityController = TextEditingController();
    
    // Owner-specific controllers
    _dogNameController = TextEditingController();
    _dogBreedController = TextEditingController();
    _dogAgeController = TextEditingController();
    _dogBioController = TextEditingController();
    _specialInstructionsController = TextEditingController();
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _dogNameController.dispose();
    _dogBreedController.dispose();
    _dogAgeController.dispose();
    _dogBioController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage({bool isDogImage = false}) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        if (isDogImage) {
          _dogImage = File(image.path);
        } else {
          _profileImage = File(image.path);
        }
      });
    }
  }
  
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  bool _canProceedFromCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic info
        return _nameController.text.isNotEmpty && 
               _handleController.text.isNotEmpty;
      case 1: // Role selection
        return _selectedRole != null;
      case 2: // Role-specific questions
        if (_selectedRole == UserRole.walker) {
          return _selectedDogSizes.isNotEmpty && 
                 _selectedWalkDurations.isNotEmpty && 
                 _selectedAvailability.isNotEmpty;
        } else {
          return _dogNameController.text.isNotEmpty && 
                 _dogSize != null && 
                 _dogGender != null &&
                 _preferredWalkDuration != null;
        }
      case 3: // Location
        return _cityController.text.isNotEmpty;
      case 4: // Final review
        return true;
      default:
        return false;
    }
  }
  
  String _generateRandomHandle(String baseName) {
    final random = Random();
    final suffix = random.nextInt(9999).toString().padLeft(4, '0');
    return '${baseName.toLowerCase().replaceAll(' ', '_')}_$suffix';
  }
  
  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = context.read<AuthService>();
      final user = authService.user;
      if (user == null) throw Exception('User not authenticated');
      
      // Upload profile image if selected
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await StorageService.uploadProfilePicture(
          user.uid,
          _profileImage!,
        );
      }
      
      // Upload dog image if selected (for owners)
      String? dogImageUrl;
      if (_dogImage != null && _selectedRole == UserRole.owner) {
        dogImageUrl = await StorageService.uploadDogPicture(
          user.uid,
          _dogImage!,
        );
      }
      
      // Create role-specific profile
      WalkerProfile? walkerProfile;
      OwnerProfile? ownerProfile;
      
      if (_selectedRole == UserRole.walker) {
        walkerProfile = WalkerProfile(
          city: _cityController.text.trim(),
          dogSizePreferences: _selectedDogSizes.toList(),
          walkDurations: _selectedWalkDurations.toList(),
          availability: _selectedAvailability.toList(),
          averageRating: 0.0,
          totalReviews: 0,
          recentWalks: [],
        );
      } else {
        ownerProfile = OwnerProfile(
          dogName: _dogNameController.text.trim(),
          dogPhotoUrl: dogImageUrl,
          dogSize: _dogSize!,
          dogGender: _dogGender!,
          dogAge: _dogAgeController.text.isNotEmpty ? int.tryParse(_dogAgeController.text.trim()) : null,
          dogBreed: _dogBreedController.text.trim(),
          dogBio: _dogBioController.text.trim(),
          city: _cityController.text.trim(),
          preferredDurations: [_preferredWalkDuration!],
          specialInstructions: _specialInstructionsController.text.trim(),
        );
      }
      
      // Update user profile with onboarding data
      await UserDatabaseService.completeUserOnboarding(
        user.uid,
        displayName: _nameController.text.trim(),
        handle: _handleController.text.trim(),
        bio: _bioController.text.trim(),
        profilePictureUrl: profileImageUrl,
        role: _selectedRole!,
        walkerProfile: walkerProfile,
        ownerProfile: ownerProfile,
      );
      
      // Update auth service user model
      await authService.reloadUserModel();
      
      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        
        // Show welcome message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to DogWalk, ${_nameController.text}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlueWhite,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                
                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicInfoStep(),
                      _buildRoleSelectionStep(),
                      _buildRoleSpecificStep(),
                      _buildLocationStep(),
                      _buildReviewStep(),
                    ],
                  ),
                ),
                
                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                '${((_currentStep + 1) / _totalSteps * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cornflowerBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(cornflowerBlue),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let\'s set up your profile',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile picture
          Center(
            child: GestureDetector(
              onTap: () => _pickImage(),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  image: _profileImage != null
                      ? DecorationImage(
                          image: FileImage(_profileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: Colors.grey[500],
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add Photo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Name field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          
          // Handle field
          TextFormField(
            controller: _handleController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Choose a unique username',
              prefixIcon: const Icon(Icons.alternate_email),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _handleController.text = _generateRandomHandle(_nameController.text);
                  });
                },
                tooltip: 'Generate random username',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Username is required' : null,
          ),
          const SizedBox(height: 16),
          
          // Bio field
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Bio (Optional)',
              hintText: 'Tell us about yourself...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your role',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How would you like to use DogWalk?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Walker card
          _buildRoleCard(
            role: UserRole.walker,
            title: 'I\'m a Walker',
            subtitle: 'I want to walk dogs and earn money',
            icon: Icons.directions_walk,
            color: cornflowerBlue,
            features: [
              'Set your availability',
              'Choose dog sizes you prefer',
              'Track walks with GPS',
              'Build your reputation',
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Owner card
          _buildRoleCard(
            role: UserRole.owner,
            title: 'I\'m a Dog Owner',
            subtitle: 'I need someone to walk my dog',
            icon: Icons.pets,
            color: skyBlue,
            features: [
              'Find trusted walkers',
              'Track your dog\'s walks live',
              'Receive photos during walks',
              'Rate and review walkers',
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutBack,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Filled background with gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected 
                ? [
                    color.withOpacity(0.8),
                    color.withOpacity(0.6),
                  ]
                : [
                    color.withOpacity(0.1),
                    color.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.1),
              blurRadius: isSelected ? 20 : 8,
              offset: Offset(0, isSelected ? 8 : 3),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        transform: Matrix4.identity()
          ..scale(isSelected ? 1.02 : 1.0)
          ..translate(0.0, isSelected ? -4.0 : 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.9) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon, 
                    color: color, 
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check, 
                          color: isSelected ? Colors.white : color, 
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isSelected ? Colors.white.withOpacity(0.95) : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleSpecificStep() {
    if (_selectedRole == UserRole.walker) {
      return _buildWalkerQuestionsStep();
    } else {
      return _buildOwnerQuestionsStep();
    }
  }
  
  Widget _buildWalkerQuestionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Walker Preferences',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us match you with the right dogs',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Dog sizes (multiple selection)
          _buildDogSizeChipSection(
            title: 'What dog sizes are you comfortable walking?',
            selectedOptions: _selectedDogSizes.map((size) {
              switch (size) {
                case DogSize.small:
                  return 'S';
                case DogSize.medium:
                  return 'M';
                case DogSize.large:
                  return 'L';
                case DogSize.extraLarge:
                  return 'XL';
              }
            }).toSet(),
            onSelectionChanged: (option, isSelected) {
              setState(() {
                final dogSize = {
                  'S': DogSize.small,
                  'M': DogSize.medium,
                  'L': DogSize.large,
                  'XL': DogSize.extraLarge,
                }[option]!;
                
                if (isSelected) {
                  _selectedDogSizes.add(dogSize);
                } else {
                  _selectedDogSizes.remove(dogSize);
                }
              });
            },
            isMultiSelect: true,
          ),
          
          const SizedBox(height: 24),
          
          // Walk durations (multiple selection)
          _buildWalkDurationChipSection(
            title: 'How long are you willing to walk?',
            selectedOptions: _selectedWalkDurations.map((duration) {
              switch (duration) {
                case WalkDuration.fifteen:
                  return '<15 min';
                case WalkDuration.thirty:
                  return '15-30 min';
                case WalkDuration.fortyFive:
                case WalkDuration.sixty:
                case WalkDuration.sixtyPlus:
                  return '30+ min';
              }
            }).toSet(),
            onSelectionChanged: (option, isSelected) {
              setState(() {
                final walkDurations = {
                  '<15 min': [WalkDuration.fifteen],
                  '15-30 min': [WalkDuration.thirty],
                  '30+ min': [WalkDuration.fortyFive, WalkDuration.sixty, WalkDuration.sixtyPlus],
                }[option]!;
                
                if (isSelected) {
                  _selectedWalkDurations.addAll(walkDurations);
                } else {
                  for (final duration in walkDurations) {
                    _selectedWalkDurations.remove(duration);
                  }
                }
              });
            },
            isMultiSelect: true,
          ),
          
          const SizedBox(height: 24),
          
          // Availability
          _buildSelectionSection(
            title: 'When are you usually available?',
            items: Availability.values,
            selectedItems: _selectedAvailability,
            onSelectionChanged: (item, isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedAvailability.add(item);
                } else {
                  _selectedAvailability.remove(item);
                }
              });
            },
            itemBuilder: (availability) => availability.displayName,
          ),
        ],
      ),
    );
  }
  
  Widget _buildOwnerQuestionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your dog',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help walkers understand your furry friend',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Dog photo
          Center(
            child: GestureDetector(
              onTap: () => _pickImage(isDogImage: true),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  image: _dogImage != null
                      ? DecorationImage(
                          image: FileImage(_dogImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _dogImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pets,
                            color: Colors.grey[500],
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add Dog Photo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Dog name
          TextFormField(
            controller: _dogNameController,
            decoration: InputDecoration(
              labelText: 'Dog\'s Name',
              hintText: 'What\'s your dog\'s name?',
              prefixIcon: const Icon(Icons.pets),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Dog\'s name is required' : null,
          ),
          const SizedBox(height: 16),
          
          // Dog breed and age
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dogBreedController,
                  decoration: InputDecoration(
                    labelText: 'Breed',
                    hintText: 'e.g., Golden Retriever',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _dogAgeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Age',
                    hintText: 'e.g., 3',
                    suffixText: 'years',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Dog size (single selection)
          _buildDogSizeChipSection(
            title: 'Dog Size',
            selectedOptions: _dogSize != null ? {
              switch (_dogSize!) {
                DogSize.small => 'S',
                DogSize.medium => 'M', 
                DogSize.large => 'L',
                DogSize.extraLarge => 'XL',
              }
            } : <String>{},
            onSelectionChanged: (option, isSelected) {
              setState(() {
                if (isSelected) {
                  _dogSize = {
                    'S': DogSize.small,
                    'M': DogSize.medium,
                    'L': DogSize.large,
                    'XL': DogSize.extraLarge,
                  }[option]!;
                }
              });
            },
            isMultiSelect: false,
          ),
          const SizedBox(height: 16),
          
          // Dog gender (single selection with pink/blue)
          _buildGenderChipSection(),
          const SizedBox(height: 16),
          
          // Preferred walk duration (single selection)
          _buildWalkDurationChipSection(
            title: 'Preferred Walk Duration',
            selectedOptions: _preferredWalkDuration != null ? {
              switch (_preferredWalkDuration!) {
                WalkDuration.fifteen => '<15 min',
                WalkDuration.thirty => '15-30 min',
                WalkDuration.fortyFive => '30+ min',
                WalkDuration.sixty => '30+ min',
                WalkDuration.sixtyPlus => '30+ min',
              }
            } : <String>{},
            onSelectionChanged: (option, isSelected) {
              setState(() {
                if (isSelected) {
                  _preferredWalkDuration = {
                    '<15 min': WalkDuration.fifteen,
                    '15-30 min': WalkDuration.thirty,
                    '30+ min': WalkDuration.fortyFive,
                  }[option]!;
                }
              });
            },
            isMultiSelect: false,
          ),
          const SizedBox(height: 16),
          
          // Dog bio
          TextFormField(
            controller: _dogBioController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Dog\'s Bio (Optional)',
              hintText: 'Personality, likes, dislikes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Special instructions
          TextFormField(
            controller: _specialInstructionsController,
            maxLines: 2,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Special Instructions (Optional)',
              hintText: 'Any special care instructions for walkers...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where are you located?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us connect you with nearby ${_selectedRole == UserRole.walker ? 'dog owners' : 'walkers'}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // City field
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Enter your city',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'City is required' : null,
          ),
          const SizedBox(height: 24),
          
          // Location info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cornflowerBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cornflowerBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cornflowerBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We only show your city to other users, never your exact address. Your privacy is important to us.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: cornflowerBlue.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review your profile',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure everything looks good before we create your account',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Profile picture
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? Icon(Icons.person, color: Colors.grey[500], size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    
                    // Name and role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${_handleController.text}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedRole == UserRole.walker ? cornflowerBlue : skyBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedRole?.displayName ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (_bioController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _bioController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _cityController.text,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Role-specific info
                if (_selectedRole == UserRole.walker) ...[
                  _buildReviewSection('Dog Sizes', _selectedDogSizes.map((e) => e.displayName).join(', ')),
                  _buildReviewSection('Walk Durations', _selectedWalkDurations.map((e) => e.displayName).join(', ')),
                  _buildReviewSection('Availability', _selectedAvailability.map((e) => e.displayName).join(', ')),
                ] else if (_selectedRole == UserRole.owner) ...[
                  if (_dogImage != null)
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_dogImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  _buildReviewSection('Dog\'s Name', _dogNameController.text),
                  if (_dogBreedController.text.isNotEmpty)
                    _buildReviewSection('Breed', _dogBreedController.text),
                  if (_dogAgeController.text.isNotEmpty)
                    _buildReviewSection('Age', _dogAgeController.text),
                  _buildReviewSection('Size', _dogSize?.displayName ?? ''),
                  _buildReviewSection('Gender', _dogGender ?? ''),
                  _buildReviewSection('Preferred Walk Duration', _preferredWalkDuration?.displayName ?? ''),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewSection(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectionSection<T>({
    required String title,
    required List<T> items,
    required Set<T> selectedItems,
    required Function(T, bool) onSelectionChanged,
    required String Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selectedItems.contains(item);
            return FilterChip(
              label: Text(itemBuilder(item)),
              selected: isSelected,
              onSelected: (selected) => onSelectionChanged(item, selected),
              selectedColor: cornflowerBlue.withOpacity(0.2),
              checkmarkColor: cornflowerBlue,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: isSelected ? cornflowerBlue : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) itemBuilder,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemBuilder(item)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? '$label is required' : null,
    );
  }

  Widget _buildChipSelectionSection({
    required String title,
    required List<String> options,
    required Set<String> selectedOptions,
    required Function(String, bool) onSelectionChanged,
    required bool isMultiSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedOptions.contains(option);
            return GestureDetector(
              onTap: () {
                if (isMultiSelect) {
                  onSelectionChanged(option, !isSelected);
                } else {
                  // For single select, deselect all others first
                  for (final otherOption in options) {
                    if (otherOption != option && selectedOptions.contains(otherOption)) {
                      onSelectionChanged(otherOption, false);
                    }
                  }
                  onSelectionChanged(option, !isSelected);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? cornflowerBlue 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? cornflowerBlue 
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Text(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDogSizeChipSection({
    required String title,
    required Set<String> selectedOptions,
    required Function(String, bool) onSelectionChanged,
    required bool isMultiSelect,
  }) {
    final sizeOptions = ['S', 'M', 'L', 'XL'];
    final sizeColors = {
      'S': Colors.green[300]!,
      'M': Colors.blue[300]!,
      'L': Colors.orange[300]!,
      'XL': Colors.red[300]!,
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: sizeOptions.map((option) {
            final isSelected = selectedOptions.contains(option);
            final color = sizeColors[option]!;
            
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: option != sizeOptions.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (isMultiSelect) {
                      onSelectionChanged(option, !isSelected);
                    } else {
                      // For single select, deselect all others first
                      for (final otherOption in sizeOptions) {
                        if (otherOption != option && selectedOptions.contains(otherOption)) {
                          onSelectionChanged(otherOption, false);
                        }
                      }
                      onSelectionChanged(option, !isSelected);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isSelected ? 1.0 : 0.6),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: color,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }



  Widget _buildWalkDurationChipSection({
    required String title,
    required Set<String> selectedOptions,
    required Function(String, bool) onSelectionChanged,
    required bool isMultiSelect,
  }) {
    final durationOptions = ['<15 min', '15-30 min', '30+ min'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: durationOptions.map((option) {
            final isSelected = selectedOptions.contains(option);
            
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: option != durationOptions.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (isMultiSelect) {
                      onSelectionChanged(option, !isSelected);
                    } else {
                      // For single select, deselect all others first
                      for (final otherOption in durationOptions) {
                        if (otherOption != option && selectedOptions.contains(otherOption)) {
                          onSelectionChanged(otherOption, false);
                        }
                      }
                      onSelectionChanged(option, !isSelected);
                    }
                  },
                                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? cornflowerBlue : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: cornflowerBlue,
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: cornflowerBlue.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : cornflowerBlue,
                          ),
                        ),
                      ),
                    ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenderChipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _dogGender = 'Male';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[300]!.withOpacity(_dogGender == 'Male' ? 1.0 : 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue[300]!,
                      width: _dogGender == 'Male' ? 3 : 2,
                    ),
                    boxShadow: _dogGender == 'Male' ? [
                      BoxShadow(
                        color: Colors.blue[300]!.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.male,
                        color: Colors.white.withOpacity(_dogGender == 'Male' ? 1.0 : 0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Male',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(_dogGender == 'Male' ? 1.0 : 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _dogGender = 'Female';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.pink[300]!.withOpacity(_dogGender == 'Female' ? 1.0 : 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.pink[300]!,
                      width: _dogGender == 'Female' ? 3 : 2,
                    ),
                    boxShadow: _dogGender == 'Female' ? [
                      BoxShadow(
                        color: Colors.pink[300]!.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.female,
                        color: Colors.white.withOpacity(_dogGender == 'Female' ? 1.0 : 0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Female',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(_dogGender == 'Female' ? 1.0 : 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          // Next/Complete button
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading || !_canProceedFromCurrentStep()
                  ? null
                  : _currentStep == _totalSteps - 1
                      ? _completeOnboarding
                      : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: cornflowerBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1 ? 'Complete Setup' : 'Next',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}