import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_service_manager.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/enums.dart';
import '../../models/review.dart';
import '../../utils/app_theme.dart';
import '../profile/public_profile_screen.dart';

class AddFriendsScreen extends ConsumerStatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  ConsumerState<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends ConsumerState<AddFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _searchResults = [];
  List<String> _sentInvites = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    // Load all users when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllUsers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when coming back to this screen
    if (mounted && _searchResults.isNotEmpty) {
      print('[DEBUG] Screen dependencies changed, refreshing data...');
      _refreshUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  UserRole get _currentUserRole {
    final authService = ref.read(authServiceProvider);
    return authService.userModel?.role ?? UserRole.owner;
  }

    Future<void> _loadAllUsers() async {
    setState(() {
      _isSearching = true;
      _currentQuery = '';
    });
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.userModel;
      
      print('[DEBUG] _loadAllUsers called');
      print('[DEBUG] Current user: ${currentUser?.displayName} (${currentUser?.uid})');
      
      // Search for handles starting with '@' to get all users
      // Add timestamp to force fresh data (cache busting)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      print('[DEBUG] Loading users with cache bust timestamp: $timestamp');
      
      final results = await serviceManager.searchUsers('@');
      print('[DEBUG] Search with "@" returned ${results.length} users at $timestamp');
      
      // Filter out current user and debug review data
      final filteredResults = results.where((user) {
        final isCurrentUser = user.uid == currentUser?.uid || 
                             user.email == currentUser?.email ||
                             user.handle == currentUser?.handle;
        print('[DEBUG] User ${user.displayName} (${user.uid}): isCurrentUser=$isCurrentUser, role=${user.role}');
        print('[DEBUG] User ${user.displayName} - rating: ${user.rating}, totalReviews: ${user.totalReviews}, reviewSummary: ${user.reviewSummary?.toString()}');
        return !isCurrentUser; // Keep users who are NOT the current user
      }).toList();
      
      print('[DEBUG] After filtering current user: ${filteredResults.length} results');
      
      // Sort by compatibility score (rating + other factors)
      filteredResults.sort((a, b) => _calculateCompatibilityScore(b).compareTo(_calculateCompatibilityScore(a)));
      
      if (mounted) {
        setState(() {
          _searchResults = filteredResults;
          _isSearching = false;
        });
        print('[DEBUG] setState called with ${_searchResults.length} results');
      }
    } catch (e) {
      print('[DEBUG] _loadAllUsers error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query == _currentQuery) return;
    
    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });
    
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      print('[DEBUG] _searchUsers called with query: "$query"');
      final results = await serviceManager.searchUsers(query);
      print('[DEBUG] _searchUsers received ${results.length} results');
      
      // Filter to exclude current user only (show both walkers and owners)
      final currentUserId = serviceManager.currentUserId;
      final authService = ref.read(authServiceProvider);
      final authUserId = authService.userModel?.uid;
      
      final filteredResults = results.where((user) {
        // Check against both possible current user IDs for safety
        final isNotCurrentUser = user.uid != currentUserId && user.uid != authUserId;
        print('[DEBUG] User ${user.displayName} (${user.uid}): isNotCurrentUser=$isNotCurrentUser, role=${user.role}');
        print('[DEBUG] User ${user.displayName} - rating: ${user.rating}, totalReviews: ${user.totalReviews}, reviewSummary: ${user.reviewSummary?.toString()}');
        return isNotCurrentUser;
      }).toList();
      
      print('[DEBUG] After filtering current user: ${filteredResults.length} results');
      
      // Sort by compatibility score (rating + other factors)
      filteredResults.sort((a, b) => _calculateCompatibilityScore(b).compareTo(_calculateCompatibilityScore(a)));
      
      if (mounted) {
        setState(() {
          _searchResults = filteredResults;
          _isSearching = false;
        });
        print('[DEBUG] setState called with ${_searchResults.length} results');
      }
    } catch (e) {
      print('[DEBUG] _searchUsers error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _refreshUsers() async {
    print('[DEBUG] Refreshing users with cache invalidation...');
    
    // Force clear any cached data first
    setState(() {
      _searchResults = [];
      _isSearching = true;
    });
    
    // Add a small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (_currentQuery.isEmpty) {
      // If no search query, reload all users
      await _loadAllUsers();
    } else {
      // If there's a search query, re-run the search
      await _searchUsers(_currentQuery);
    }
  }

  double _calculateCompatibilityScore(UserModel user) {
    double score = 0.0;
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.userModel;
    
    if (currentUser == null) return score;
    
    // Base score for all users
    score += 50.0;
    
    // Role compatibility bonus (opposite roles get higher score for better matching)
    if (currentUser.role != user.role) {
      score += 30.0; // Bonus for opposite roles (walker-owner matching)
    } else {
      score += 10.0; // Smaller bonus for same roles
    }
    
    // **CRITICAL DOG COMPATIBILITY CHECKS** - This was missing!
    bool isDogCompatible = true;
    double dogCompatibilityPoints = 0.0;
    
    // Dog size compatibility (CRUCIAL for walker-owner matching)
    if (currentUser.role == UserRole.owner && user.role == UserRole.walker) {
      // Owner looking at walker - check if walker can handle their dog size
      final ownerDogSize = currentUser.ownerProfile?.dogSize;
      final walkerSizePrefs = user.walkerProfile?.dogSizePreferences ?? [];
      
      if (ownerDogSize != null && walkerSizePrefs.isNotEmpty) {
        if (walkerSizePrefs.contains(ownerDogSize)) {
          dogCompatibilityPoints += 40.0; // MAJOR bonus for size compatibility
          print('[DEBUG] ✅ Dog size compatible: Owner has ${ownerDogSize.displayName}, walker accepts it');
        } else {
          isDogCompatible = false;
          dogCompatibilityPoints -= 50.0; // MAJOR penalty for incompatibility
          print('[DEBUG] ❌ Dog size INCOMPATIBLE: Owner has ${ownerDogSize.displayName}, walker only accepts ${walkerSizePrefs.map((s) => s.displayName).join(", ")}');
        }
      }
    } else if (currentUser.role == UserRole.walker && user.role == UserRole.owner) {
      // Walker looking at owner - check if walker can handle their dog size
      final walkerSizePrefs = currentUser.walkerProfile?.dogSizePreferences ?? [];
      final ownerDogSize = user.ownerProfile?.dogSize;
      
      if (ownerDogSize != null && walkerSizePrefs.isNotEmpty) {
        if (walkerSizePrefs.contains(ownerDogSize)) {
          dogCompatibilityPoints += 40.0; // MAJOR bonus for size compatibility
          print('[DEBUG] ✅ Dog size compatible: Walker accepts ${ownerDogSize.displayName}, owner has it');
        } else {
          isDogCompatible = false;
          dogCompatibilityPoints -= 50.0; // MAJOR penalty for incompatibility
          print('[DEBUG] ❌ Dog size INCOMPATIBLE: Walker only accepts ${walkerSizePrefs.map((s) => s.displayName).join(", ")}, owner has ${ownerDogSize.displayName}');
        }
      }
    }
    
    // Walk duration compatibility
    if (currentUser.role == UserRole.owner && user.role == UserRole.walker) {
      final ownerPreferredDurations = currentUser.ownerProfile?.preferredDurations ?? [];
      final walkerDurations = user.walkerProfile?.walkDurations ?? [];
      
      if (ownerPreferredDurations.isNotEmpty && walkerDurations.isNotEmpty) {
        // Check if any of owner's preferred durations match walker's offerings
        final hasCompatibleDuration = ownerPreferredDurations.any((ownerDuration) => 
          walkerDurations.contains(ownerDuration));
        
        if (hasCompatibleDuration) {
          dogCompatibilityPoints += 20.0; // Duration compatibility bonus
          final matches = ownerPreferredDurations.where((d) => walkerDurations.contains(d)).toList();
          print('[DEBUG] ✅ Duration compatible: ${matches.map((d) => d.displayText).join(", ")}');
        } else {
          dogCompatibilityPoints -= 15.0; // Duration mismatch penalty
          print('[DEBUG] ⚠️ Duration mismatch: Owner wants ${ownerPreferredDurations.map((d) => d.displayText).join(", ")}, walker offers ${walkerDurations.map((d) => d.displayText).join(", ")}');
        }
      }
    } else if (currentUser.role == UserRole.walker && user.role == UserRole.owner) {
      final walkerDurations = currentUser.walkerProfile?.walkDurations ?? [];
      final ownerPreferredDurations = user.ownerProfile?.preferredDurations ?? [];
      
      if (ownerPreferredDurations.isNotEmpty && walkerDurations.isNotEmpty) {
        // Check if any of owner's preferred durations match walker's offerings
        final hasCompatibleDuration = ownerPreferredDurations.any((ownerDuration) => 
          walkerDurations.contains(ownerDuration));
        
        if (hasCompatibleDuration) {
          dogCompatibilityPoints += 20.0; // Duration compatibility bonus
          final matches = ownerPreferredDurations.where((d) => walkerDurations.contains(d)).toList();
          print('[DEBUG] ✅ Duration compatible: ${matches.map((d) => d.displayText).join(", ")}');
        } else {
          dogCompatibilityPoints -= 15.0; // Duration mismatch penalty
          print('[DEBUG] ⚠️ Duration mismatch: Walker offers ${walkerDurations.map((d) => d.displayText).join(", ")}, owner wants ${ownerPreferredDurations.map((d) => d.displayText).join(", ")}');
        }
      }
    }
    
    score += dogCompatibilityPoints;
    
    // Rating bonus (0-30 points for 0-5 star rating)
    final rating = user.rating ?? 0.0;
    score += rating * 6.0;
    
    // Location matching bonus
    if (currentUser.city != null && user.city != null && 
        currentUser.city!.toLowerCase() == user.city!.toLowerCase()) {
      score += 25.0; // Same city bonus
    }
    
    // Profile completeness bonus
    if (user.hasCompleteProfile) {
      score += 15.0;
    }
    
    // Recent activity bonus
    final daysSinceLastSeen = DateTime.now().difference(user.lastSeen).inDays;
    if (daysSinceLastSeen <= 7) {
      score += 20.0 - (daysSinceLastSeen * 2); // More points for recent activity
    }
    
    return score;
  }

  // Check if user is highly compatible (golden border worthy)
  bool _isHighlyCompatible(UserModel user) {
    final score = _calculateCompatibilityScore(user);
    // Updated threshold: 125+ points now required for high compatibility
    // This is more realistic with the new dog-specific compatibility checks
    // Max possible score is roughly ~165 (50 base + 30 role + 40 dog size + 20 duration + 30 rating + 25 location + 15 profile + 20 activity)
    final isHighlyCompatible = score >= 125.0;
    
    // Enhanced debug information
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.userModel;
    
    String debugDetails = '';
    if (currentUser != null) {
      if (currentUser.role == UserRole.owner && user.role == UserRole.walker) {
        final ownerDogSize = currentUser.ownerProfile?.dogSize;
        final walkerSizePrefs = user.walkerProfile?.dogSizePreferences ?? [];
        debugDetails = ' | Dog size: ${ownerDogSize?.displayName} vs walker prefs: ${walkerSizePrefs.map((s) => s.displayName).join(", ")}';
      } else if (currentUser.role == UserRole.walker && user.role == UserRole.owner) {
        final walkerSizePrefs = currentUser.walkerProfile?.dogSizePreferences ?? [];
        final ownerDogSize = user.ownerProfile?.dogSize;
        debugDetails = ' | Walker prefs: ${walkerSizePrefs.map((s) => s.displayName).join(", ")} vs owner dog: ${ownerDogSize?.displayName}';
      }
    }
    
    print('[DEBUG] ${user.displayName} compatibility score: ${score.toStringAsFixed(1)}${debugDetails} (${isHighlyCompatible ? "⭐ HIGHLY COMPATIBLE" : "normal"})');
    return isHighlyCompatible;
  }

  // Check if user has critical dog incompatibility (size mismatch)
  bool _isDogIncompatible(UserModel user) {
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.userModel;
    
    if (currentUser == null) return false;
    
    // Check dog size incompatibility
    if (currentUser.role == UserRole.owner && user.role == UserRole.walker) {
      final ownerDogSize = currentUser.ownerProfile?.dogSize;
      final walkerSizePrefs = user.walkerProfile?.dogSizePreferences ?? [];
      
      if (ownerDogSize != null && walkerSizePrefs.isNotEmpty) {
        return !walkerSizePrefs.contains(ownerDogSize);
      }
    } else if (currentUser.role == UserRole.walker && user.role == UserRole.owner) {
      final walkerSizePrefs = currentUser.walkerProfile?.dogSizePreferences ?? [];
      final ownerDogSize = user.ownerProfile?.dogSize;
      
      if (ownerDogSize != null && walkerSizePrefs.isNotEmpty) {
        return !walkerSizePrefs.contains(ownerDogSize);
      }
    }
    
    return false;
  }

  Future<void> _sendFriendRequest(UserModel user) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      await serviceManager.sendFriendRequest(user.uid);
      setState(() {
        _sentInvites.add(user.uid);
        _isLoading = false;
      });
      
      // Show hover popup
      _showInviteSentPopup(user);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteSentPopup(UserModel user) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.3,
        left: MediaQuery.of(context).size.width * 0.1,
        right: MediaQuery.of(context).size.width * 0.1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Invite sent to ${user.handle.startsWith('@') ? user.handle : '@${user.handle}'}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove overlay after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _showAllUsernames() async {
    try {
      final serviceManager = ref.read(appServiceManagerProvider);
      final authService = ref.read(authServiceProvider);
      final userModel = authService.userModel;
      final userIdentifiers = await serviceManager.getAllUserIdentifiers();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'All Users (${userIdentifiers.length})',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: userIdentifiers.isEmpty
                  ? Center(
                      child: Text(
                        'No users found in database',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: userIdentifiers.length,
                      itemBuilder: (context, index) {
                        final user = userIdentifiers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.getColorShade(userModel, 100),
                            child: Text(
                              (user['displayName'] ?? '').isNotEmpty 
                                  ? (user['displayName'] ?? '')[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: AppTheme.getColorShade(userModel, 600),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            user['displayName'] ?? 'Unknown User',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            user['handle'] ?? 'No handle',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            final handle = user['handle'] ?? '';
                            _searchController.text = handle;
                            Navigator.pop(context);
                            _searchUsers(handle);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
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
          'Find Friends',
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
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: AppTheme.getColorShade(userModel, 600) ?? Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search for Walkers & Owners',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Start typing to filter • Pull down or tap ↻ to refresh',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or handle...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[500],
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[500],
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadAllUsers();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.getColorShade(userModel, 600) ?? Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) async {
                          if (value.length >= 1) {
                            await _searchUsers(value);
                          } else if (value.isEmpty) {
                            await _loadAllUsers();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        print('[DEBUG] Manual refresh triggered');
                        _refreshUsers();
                      },
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.grey[600],
                      ),
                      tooltip: 'Refresh user data',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showAllUsernames,
                      icon: Icon(
                        Icons.bug_report,
                        color: Colors.grey[600],
                      ),
                      tooltip: 'Debug: Show all handles',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results Section with Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshUsers,
              child: _buildResultsSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isSearching) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      if (_currentQuery.isEmpty) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(),
          ),
        );
      } else {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildNoResultsState(),
          ),
        );
      }
    }

    // Group results by role (though we're only showing opposite role, this is for future extensibility)
    final groupedResults = <UserRole, List<UserModel>>{};
    for (final user in _searchResults) {
      groupedResults.putIfAbsent(user.role, () => []).add(user);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _calculateListItemCount(groupedResults),
      itemBuilder: (context, index) {
        return _buildListItem(groupedResults, index);
      },
    );
  }

  int _calculateListItemCount(Map<UserRole, List<UserModel>> groupedResults) {
    int count = 0;
    for (final entry in groupedResults.entries) {
      if (entry.value.isNotEmpty) {
        count += 1 + entry.value.length; // 1 for header + users
      }
    }
    return count;
  }

  Widget _buildListItem(Map<UserRole, List<UserModel>> groupedResults, int index) {
    int currentIndex = 0;
    
    for (final entry in groupedResults.entries) {
      final role = entry.key;
      final users = entry.value;
      
      if (users.isEmpty) continue;
      
      // Header item
      if (index == currentIndex) {
        return _buildRoleHeader(role, users.length);
      }
      currentIndex++;
      
      // User items
      for (int i = 0; i < users.length; i++) {
        if (index == currentIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildUserCard(users[i]),
          );
        }
        currentIndex++;
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildRoleHeader(UserRole role, int count) {
    final color = role == UserRole.walker 
        ? const Color(0xFF66BB6A) // Green for walkers  
        : const Color(0xFF6495ED); // Blue for owners
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
                       color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(
              role == UserRole.walker ? Icons.directions_walk : Icons.pets,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '${role.displayName}s ($count found)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                 color: color.withOpacity(0.2),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Text(
                 'Compatible',
                 style: GoogleFonts.poppins(
                   fontSize: 10,
                   fontWeight: FontWeight.w500,
                   color: color,
                 ),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Users...',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finding walkers and owners in your area',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
                      Text(
              'No users found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Try searching with a different handle',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final serviceManager = ref.read(appServiceManagerProvider);
    final authService = ref.read(authServiceProvider);
    final userModel = authService.userModel;
    final bool isFriend = serviceManager.currentUser?.connections.contains(user.uid) ?? false;
    final bool hasSentRequest = _sentInvites.contains(user.uid);
    final bool hasReceivedRequest = serviceManager.currentUser?.connectionRequests.contains(user.uid) ?? false;
    final bool isHighlyCompatible = _isHighlyCompatible(user);
    
    // Role-based colors for each individual user
    final roleColor = user.role == UserRole.walker 
        ? const Color(0xFF66BB6A) // Green for walkers
        : const Color(0xFF6495ED); // Blue for owners

    // Golden color for highly compatible users
    final borderColor = isHighlyCompatible 
        ? const Color(0xFFFFD700) // Gold
        : roleColor.withOpacity(0.2);
    final borderWidth = isHighlyCompatible ? 3.0 : 1.0;

    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: isHighlyCompatible ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: borderWidth,
            ),
          ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              roleColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Profile Picture with role indicator
                  Stack(
                    children: [
                                             CircleAvatar(
                         radius: 28,
                         backgroundColor: roleColor.withOpacity(0.1),
                         backgroundImage: user.profilePictureUrl != null
                             ? NetworkImage(user.profilePictureUrl!)
                             : null,
                         child: user.profilePictureUrl == null
                             ? Text(
                                 user.displayName.isNotEmpty 
                                     ? user.displayName[0].toUpperCase()
                                     : 'U',
                                 style: TextStyle(
                                   color: roleColor,
                                   fontWeight: FontWeight.bold,
                                   fontSize: 18,
                                 ),
                               )
                             : null,
                       ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: roleColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            user.role == UserRole.walker ? Icons.directions_walk : Icons.pets,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PublicProfileScreen(userId: user.uid),
                                    ),
                                  );
                                },
                                child: Text(
                                  user.displayName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: roleColor.withOpacity(0.8),
                                    decoration: TextDecoration.underline,
                                    decorationColor: roleColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                            // Perfect Match badge for highly compatible users
                            if (isHighlyCompatible) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700), // Gold
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'PERFECT MATCH',
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Role badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: roleColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                user.role.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.handle.startsWith('@') ? user.handle : '@${user.handle}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        // Rating display - always show rating section
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Check multiple sources for rating data
                            ...() {
                              final rating = user.rating ?? user.reviewSummary?.averageRating ?? 0.0;
                              final totalReviews = user.totalReviews ?? user.reviewSummary?.totalReviews ?? 0;
                              print('[DEBUG] Final rating for ${user.displayName}: $rating, reviews: $totalReviews');
                              
                              if (rating > 0) {
                                return [
                                  // Rating stars
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < rating.floor() 
                                          ? Icons.star 
                                          : index < rating 
                                              ? Icons.star_half 
                                              : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                  const SizedBox(width: 8),
                                  // Rating text with enhanced styling
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '${rating.toStringAsFixed(1)} ($totalReviews)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.amber[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ];
                              } else {
                                return [
                                  // No rating yet - show placeholder
                                  Icon(
                                    Icons.star_outline,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'New ${user.role.displayName}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ];
                              }
                            }(),
                          ],
                        ),
                        // Location
                        if (user.city != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.city!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Bio
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            user.bio!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(user, isFriend, hasSentRequest, hasReceivedRequest, roleColor),
              ),
            ],
          ),
        ),
      ),
        ),
        // Golden star for highly compatible users
        if (isHighlyCompatible)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700), // Gold
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.star,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(UserModel user, bool isFriend, bool hasSentRequest, bool hasReceivedRequest, Color roleColor) {
    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 18,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Connected',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    } else if (hasSentRequest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 18,
              color: Colors.green[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Request Sent',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    } else if (hasReceivedRequest) {
      return ElevatedButton.icon(
        onPressed: () {
          // TODO: Implement accept/reject from this screen
        },
        icon: const Icon(Icons.reply, size: 18),
        label: const Text('Respond'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _sendFriendRequest(user),
        icon: Icon(
          user.role == UserRole.walker ? Icons.directions_walk : Icons.pets,
          size: 18,
        ),
        label: Text('Connect with ${user.role.displayName}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: roleColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
} 