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
        // Update online status
        await UserDatabaseService.updateOnlineStatus(user.uid, true);
        
        // Load user model
        _userModel = await UserDatabaseService.getUserById(user.uid);
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
          username: username,
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
  Future<UserCredential?> signInWithGoogle({String? username}) async {
    try {
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
        if (_userModel == null && username != null) {
          await UserDatabaseService.createUserProfile(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            displayName: result.user!.displayName ?? '',
            username: username,
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
    String? username,
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
      
      // Username requires special handling
      if (username != null && _userModel != null && username != _userModel!.username) {
        await UserDatabaseService.updateUsername(_user!.uid, username);
        _userModel = await UserDatabaseService.getUserById(_user!.uid);
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get current user stream
  Stream<UserModel?> get userStream {
    if (_user == null) return Stream.value(null);
    return UserDatabaseService.listenToUser(_user!.uid);
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final user = await UserDatabaseService.getUserByUsername(username);
    return user == null;
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