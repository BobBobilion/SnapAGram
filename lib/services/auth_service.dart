import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'user_database_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;
  UserModel? _userModel;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _user != null;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      print('AuthService: Auth state changed - user: ${user?.email}');
      _user = user;
      
      if (user != null) {
        try {
          // Update online status (safely)
          await UserDatabaseService.updateOnlineStatus(user.uid, true);
          
          // Load user model
          _userModel = await UserDatabaseService.getUserById(user.uid);
          
          if (_userModel == null) {
            print('AuthService: User document not found for ${user.uid}, user needs onboarding');
          } else {
            // Migrate user to handle if needed (for backward compatibility)
            if (_userModel!.handle.isEmpty) {
              try {
                await UserDatabaseService.migrateUserToHandle(user.uid);
                _userModel = await UserDatabaseService.getUserById(user.uid);
              } catch (e) {
                print('Failed to migrate user to handle: $e');
              }
            }
          }
        } catch (e) {
          print('AuthService: Error loading user data: $e');
          _userModel = null;
        }
      } else {
        // Update offline status for previous user
        if (_userModel != null) {
          await UserDatabaseService.updateOnlineStatus(_userModel!.uid, false);
        }
        _userModel = null;
      }
      
      print('AuthService: Calling notifyListeners - isAuthenticated: ${_user != null}');
      notifyListeners();
    });
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user profile in Firestore
      if (result.user != null) {
        await UserDatabaseService.createUserProfile(
          uid: result.user!.uid,
          email: email,
          displayName: displayName,
          profilePictureUrl: result.user!.photoURL,
        );
        
        // Update Firebase Auth profile
        await result.user!.updateDisplayName(displayName);
        
        // Load user model
        _userModel = await UserDatabaseService.getUserById(result.user!.uid);
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Sign out from Google first to clear cached account and force account selection
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);
      
      // Check if user profile exists in Firestore
      if (result.user != null) {
        _userModel = await UserDatabaseService.getUserById(result.user!.uid);
        
        // If user doesn't exist in Firestore, create profile
        if (_userModel == null) {
          final displayName = result.user!.displayName ?? 'User';
          
          await UserDatabaseService.createUserProfile(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            displayName: displayName,
            profilePictureUrl: result.user!.photoURL,
          );
          
          _userModel = await UserDatabaseService.getUserById(result.user!.uid);
        }
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in Google Sign-In: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Exception in Google Sign-In: $e');
      if (e.toString().contains('cancelled')) {
        throw Exception('Sign-in was cancelled');
      }
      if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      if (e.toString().contains('sign_in_failed')) {
        throw Exception('Google Sign-In failed. Please check your Google account settings and try again.');
      }
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Update offline status before signing out
      if (_userModel != null) {
        await UserDatabaseService.updateOnlineStatus(_userModel!.uid, false);
      }
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      _userModel = null;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Sign out with complete Google disconnect (removes all cached Google credentials)
  Future<void> signOutWithGoogleDisconnect() async {
    try {
      // Update offline status before signing out
      if (_userModel != null) {
        await UserDatabaseService.updateOnlineStatus(_userModel!.uid, false);
      }
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.disconnect(), // This completely removes the account from cache
      ]);
      
      _userModel = null;
    } catch (e) {
      throw Exception('Failed to sign out with Google disconnect: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      
      // Update Firebase Auth profile
      if (displayName != null) await _user!.updateDisplayName(displayName);
      if (photoURL != null) await _user!.updatePhotoURL(photoURL);
      
      // Update Firestore profile
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoURL != null) updates['profilePictureUrl'] = photoURL;
      if (bio != null) updates['bio'] = bio;
      
      if (updates.isNotEmpty) {
        await UserDatabaseService.updateUserProfile(_user!.uid, updates);
        _userModel = await UserDatabaseService.getUserById(_user!.uid);
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update display name (with handle regeneration)
  Future<void> updateDisplayName(String newDisplayName) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      
      // Update Firebase Auth profile
      await _user!.updateDisplayName(newDisplayName);
      
      // Update Firestore profile with new handle
      await UserDatabaseService.updateHandle(_user!.uid, newDisplayName);
      
      // Reload user model
      _userModel = await UserDatabaseService.getUserById(_user!.uid);
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update display name: $e');
    }
  }

  // Update handle
  Future<void> updateHandle(String newHandle) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      
      print('Updating handle to: $newHandle for user: ${_user!.uid}'); // Debug log
      
      // Update Firestore profile with new handle
      await UserDatabaseService.updateHandle(_user!.uid, newHandle);
      
      print('Handle updated successfully in database'); // Debug log
      
      // Reload user model
      _userModel = await UserDatabaseService.getUserById(_user!.uid);
      
      print('New user model handle: ${_userModel?.handle}'); // Debug log
      
      notifyListeners();
    } catch (e) {
      print('Error in updateHandle: $e'); // Debug log
      throw Exception('Failed to update handle: $e');
    }
  }

  // Get current user stream
  Stream<UserModel?> get userStream {
    if (_user == null) return Stream.value(null);
    return UserDatabaseService.listenToUser(_user!.uid);
  }

  // Check if handle is available
  Future<bool> isHandleAvailable(String handle) async {
    return await UserDatabaseService.isHandleAvailable(handle);
  }

  // Reload user model from database
  Future<void> reloadUserModel() async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      _userModel = await UserDatabaseService.getUserById(_user!.uid);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to reload user model: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      
      // Delete user data from Firestore
      await UserDatabaseService.deleteUserData(_user!.uid);
      
      // Delete Firebase Auth account
      await _user!.delete();
      
      // Clear local state
      _user = null;
      _userModel = null;
      
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to delete account: ${_handleAuthException(e)}');
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-action-code':
        return 'The password reset link is invalid or has expired.';
      case 'expired-action-code':
        return 'The password reset link has expired. Please request a new one.';
      case 'user-mismatch':
        return 'The email address does not match the one used for password reset.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
} 