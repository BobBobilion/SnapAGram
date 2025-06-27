import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'user_service.dart';
import 'handle_service.dart';

final authServiceProvider =
    ChangeNotifierProvider((ref) => AuthService(ref, auth: FirebaseAuth.instance));

class AuthService extends ChangeNotifier {
  final Ref _ref;
  final FirebaseAuth auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;
  UserModel? _userModel;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _user != null;

  AuthService(this._ref, {required this.auth}) {
    auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    print('AuthService: Auth state changed - user: ${user?.email}');
    _user = user;

    if (user != null) {
      final userService = _ref.read(userServiceProvider);
      try {
        await userService.updateOnlineStatus(user.uid, true);
        _userModel = await userService.getUserById(user.uid);

        if (_userModel == null) {
          print(
              'AuthService: User document not found for ${user.uid}, user needs onboarding');
        } else {
          if (_userModel!.handle.isEmpty) {
            try {
              await userService.migrateUserToHandle(user.uid);
              _userModel = await userService.getUserById(user.uid);
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
      if (_userModel != null) {
        final userService = _ref.read(userServiceProvider);
        await userService.updateOnlineStatus(_userModel!.uid, false);
      }
      _userModel = null;
    }

    print(
        'AuthService: Calling notifyListeners - isAuthenticated: ${_user != null}');
    notifyListeners();
  }

  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      UserCredential result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final userService = _ref.read(userServiceProvider);
        await userService.createUserProfile(
          uid: result.user!.uid,
          email: email,
          displayName: displayName,
          profilePictureUrl: result.user!.photoURL,
        );

        await result.user!.updateDisplayName(displayName);
        _userModel = await userService.getUserById(result.user!.uid);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await auth.signInWithCredential(credential);

      if (result.user != null) {
        final userService = _ref.read(userServiceProvider);
        _userModel = await userService.getUserById(result.user!.uid);

        if (_userModel == null) {
          final displayName = result.user!.displayName ?? 'User';
          await userService.createUserProfile(
            uid: result.user!.uid,
            email: result.user!.email ?? '',
            displayName: displayName,
            profilePictureUrl: result.user!.photoURL,
          );
          _userModel = await userService.getUserById(result.user!.uid);
        }
      }

      return result;
    } on FirebaseAuthException catch (e) {
      print(
          'FirebaseAuthException in Google Sign-In: ${e.code} - ${e.message}');
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
        throw Exception(
            'Google Sign-In failed. Please check your Google account settings and try again.');
      }
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      if (_userModel != null) {
        final userService = _ref.read(userServiceProvider);
        await userService.updateOnlineStatus(_userModel!.uid, false);
      }

      await Future.wait([
        auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      _userModel = null;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> signOutWithGoogleDisconnect() async {
    try {
      if (_userModel != null) {
        final userService = _ref.read(userServiceProvider);
        await userService.updateOnlineStatus(_userModel!.uid, false);
      }

      await Future.wait([
        auth.signOut(),
        _googleSignIn.disconnect(),
      ]);

      _userModel = null;
    } catch (e) {
      throw Exception('Failed to sign out with Google disconnect: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      final userService = _ref.read(userServiceProvider);

      if (displayName != null) await _user!.updateDisplayName(displayName);
      if (photoURL != null) await _user!.updatePhotoURL(photoURL);

      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoURL != null) updates['profilePictureUrl'] = photoURL;
      if (bio != null) updates['bio'] = bio;

      if (updates.isNotEmpty) {
        await userService.updateUserProfile(_user!.uid, updates);
        _userModel = await userService.getUserById(_user!.uid);
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> updateDisplayName(String newDisplayName) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      final userService = _ref.read(userServiceProvider);

      await _user!.updateDisplayName(newDisplayName);
      await userService.updateHandle(_user!.uid, newDisplayName);
      _userModel = await userService.getUserById(_user!.uid);

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update display name: $e');
    }
  }

  Future<void> updateHandle(String newHandle) async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      final userService = _ref.read(userServiceProvider);

      print('Updating handle to: $newHandle for user: ${_user!.uid}');
      await userService.updateHandle(_user!.uid, newHandle);
      print('Handle updated successfully in database');
      _userModel = await userService.getUserById(_user!.uid);
      print('New user model handle: ${_userModel?.handle}');

      notifyListeners();
    } catch (e) {
      print('Error in updateHandle: $e');
      throw Exception('Failed to update handle: $e');
    }
  }

  Stream<UserModel?> get userStream {
    return auth.authStateChanges().asyncExpand((user) {
      if (user != null) {
        final userService = _ref.read(userServiceProvider);
        return userService.listenToUser(user.uid);
      } else {
        return Stream.value(null);
      }
    });
  }

  Future<bool> isHandleAvailable(String handle) async {
    final handleService = _ref.read(handleServiceProvider);
    return await handleService.isHandleAvailable(handle,
        excludeUserId: _user?.uid);
  }

  Future<void> reloadUserModel() async {
    try {
      if (_user == null) throw Exception('User not authenticated');
      final userService = _ref.read(userServiceProvider);
      _userModel = await userService.getUserById(_user!.uid);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to reload user model: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      if (_user == null) throw Exception('User not authenticated');

      // This needs a more complete implementation once other services are refactored
      // await userService.deleteUserData(_user!.uid);

      await _user!.delete();
      _user = null;
      _userModel = null;

      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception('Failed to delete account: ${_handleAuthException(e)}');
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

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