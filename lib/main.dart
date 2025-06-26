import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/app_service_manager.dart';
import 'models/enums.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/complete_onboarding_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'DogWalk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6495ED), // Cornflower blue
            primary: const Color(0xFF6495ED),   // Cornflower blue
            secondary: const Color(0xFF87CEEB), // Sky blue
            surface: const Color(0xFFF0F8FF),   // Alice blue
            background: const Color(0xFFFAFAFF), // Very light blue-white
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6495ED),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Debug print to see authentication state
        print('AuthWrapper: isAuthenticated = ${authService.isAuthenticated}');
        print('AuthWrapper: user = ${authService.user?.email}');
        
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }
        
        // User is authenticated, now check if they have completed onboarding
        return FutureBuilder(
          future: _checkUserOnboardingStatus(authService.user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFFAFAFF),
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6495ED),
                  ),
                ),
              );
            }
            
            if (snapshot.hasError) {
              print('Error checking onboarding status: ${snapshot.error}');
              return const LoginScreen();
            }
            
            final hasCompletedOnboarding = snapshot.data ?? false;
            
            print('AuthWrapper: hasCompletedOnboarding = $hasCompletedOnboarding');
            print('AuthWrapper: User email = ${authService.user!.email}');
            print('AuthWrapper: User UID = ${authService.user!.uid}');
            
            if (!hasCompletedOnboarding) {
              print('AuthWrapper: Showing onboarding screen');
              // User needs to complete comprehensive onboarding
              return CompleteOnboardingScreen(
                email: authService.user!.email ?? '',
                displayName: authService.user!.displayName ?? 'User',
                handle: authService.user!.displayName?.toLowerCase().replaceAll(' ', '_') ?? 'user',
              );
            }
            
            print('AuthWrapper: Showing home screen');
            // User has completed onboarding, show main app
            return const HomeScreen();
          },
        );
      },
    );
  }
  
  Future<bool> _checkUserOnboardingStatus(String uid) async {
    try {
      final serviceManager = AppServiceManager();
      final user = await serviceManager.getUserById(uid);
      
      // If user document doesn't exist, they need onboarding
      if (user == null) {
        print('_checkUserOnboardingStatus: User document not found for UID: $uid - needs onboarding');
        return false;
      }
      
      print('_checkUserOnboardingStatus: User found - isOnboardingComplete: ${user.isOnboardingComplete}, role: ${user.role}');
      print('_checkUserOnboardingStatus: User walkerProfile: ${user.walkerProfile != null ? "exists" : "null"}');
      print('_checkUserOnboardingStatus: User ownerProfile: ${user.ownerProfile != null ? "exists" : "null"}');
      
      // Check if user has completed onboarding
      // Must have isOnboardingComplete=true AND have a role-specific profile
      final hasRole = user.role != null;
      final hasRoleProfile = (user.role == UserRole.walker && user.walkerProfile != null) || 
                            (user.role == UserRole.owner && user.ownerProfile != null);
      final hasCompleted = user.isOnboardingComplete && hasRole && hasRoleProfile;
      
      print('_checkUserOnboardingStatus: hasRole: $hasRole, hasRoleProfile: $hasRoleProfile, isOnboardingComplete: ${user.isOnboardingComplete}');
      print('_checkUserOnboardingStatus: Final result: $hasCompleted');
      
      // TEMPORARY: Force onboarding for testing - uncomment next line to test
      // return false;
      
      return hasCompleted;
    } catch (e) {
      print('Error checking user onboarding status: $e');
      return false;
    }
  }
} 