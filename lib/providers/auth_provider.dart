import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_prefs_provider.dart';

class AuthState {
  final bool isSignedIn;
  final String? userId;
  final String? userName;
  final String? email;

  const AuthState({
    required this.isSignedIn,
    this.userId,
    this.userName,
    this.email,
  });
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState(isSignedIn: false)) {
    _bind();
  }

  final Ref ref;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<fb_auth.User?>? _sub;
  static const _lastUserKey = 'last_user_id_v1';
  static const _webGoogleClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  void _bind() {
    _sub?.cancel();
    if (!kIsWeb) {
      unawaited(
        _initializeGoogleSignInIfNeeded().catchError((error, stackTrace) {
          debugPrint('[Auth] GoogleSignIn init skipped/failed: $error');
        }),
      );
    }
    _sub = _auth.authStateChanges().listen((user) async {
      debugPrint(
        '[Auth] authStateChanges: ${user?.uid ?? 'signed_out'}',
      );
      if (user == null) {
        await _clearLocalCaches();
        state = const AuthState(isSignedIn: false);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final lastUid = prefs.getString(_lastUserKey);
      if (lastUid != null && lastUid != user.uid) {
        await _clearLocalCaches(preserveUserId: user.uid);
      } else {
        await prefs.setString(_lastUserKey, user.uid);
      }
      final providers = user.providerData.map((p) => p.providerId).toList();
      final isPasswordUser = providers.contains('password');
      if (isPasswordUser && !user.emailVerified) {
        debugPrint('[Auth] authStateChanges: unverified email, signing out');
        await user.sendEmailVerification();
        await _auth.signOut();
        state = const AuthState(isSignedIn: false);
        return;
      }

      final name = user.displayName ?? user.email?.split('@').first;
      state = AuthState(
        isSignedIn: true,
        userId: user.uid,
        userName: name,
        email: user.email,
      );
      await _ensureUserDoc(user);
      await _markHasAccount();
    });
  }

  Future<void> _initializeGoogleSignInIfNeeded() async {
    if (kIsWeb) return;
    await _googleSignIn.initialize(
      clientId: kIsWeb ? _webGoogleClientId : null,
    );
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    debugPrint('[Auth] signUpWithEmail: start');
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[Auth] signUpWithEmail: created uid=${cred.user?.uid}');
      await cred.user?.updateDisplayName(name);
      if (cred.user != null && !(cred.user!.emailVerified)) {
        await cred.user!.sendEmailVerification();
        debugPrint('[Auth] signUpWithEmail: verification email sent');
      }
      await cred.user?.reload();
      debugPrint('[Auth] signUpWithEmail: updated displayName');
      await _auth.signOut();
    } catch (e, st) {
      debugPrint('[Auth] signUpWithEmail: error $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('[Auth] signInWithEmail: start');
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.reload();
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();
        throw StateError('Email not verified. Check your inbox.');
      }
      debugPrint('[Auth] signInWithEmail: success');
    } catch (e, st) {
      debugPrint('[Auth] signInWithEmail: error $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    debugPrint('[Auth] sendPasswordReset: start');
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('[Auth] sendPasswordReset: success');
    } catch (e, st) {
      debugPrint('[Auth] sendPasswordReset: error $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('[Auth] resendVerificationEmail: start');
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
      await _auth.signOut();
      debugPrint('[Auth] resendVerificationEmail: success');
    } catch (e, st) {
      debugPrint('[Auth] resendVerificationEmail: error $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    debugPrint('[Auth] signInWithGoogle: start');
    try {
      if (kIsWeb) {
        final provider = fb_auth.GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
        debugPrint('[Auth] signInWithGoogle(web): success');
        return;
      }
      await _initializeGoogleSignInIfNeeded();

      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw StateError('Google authentication did not return tokens.');
      }
      final credential = fb_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      debugPrint('[Auth] signInWithGoogle: success');
    } catch (e, st) {
      debugPrint('[Auth] signInWithGoogle: error $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
    await _clearLocalCaches();
  }

  Future<void> _clearLocalCaches({String? preserveUserId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (preserveUserId != null) {
      await prefs.setString(_lastUserKey, preserveUserId);
    }
  }

  Future<void> deactivateAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (_) {
        // ignore if not allowed by rules
      }
      try {
        await user.delete();
      } catch (_) {
        // requires recent login; leave account as-is if it fails
      }
    }
    await signOut();
    await ref.read(userPrefsProvider.notifier).setHasAccount(false);
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (user.email != email) {
      await user.verifyBeforeUpdateEmail(email);
    }
    if (user.displayName != name) {
      await user.updateDisplayName(name);
    }
    await user.reload();
  }

  Future<void> _ensureUserDoc(fb_auth.User user) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await doc.set(
      {
        'email': user.email,
        'name': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _markHasAccount() async {
    await ref.read(userPrefsProvider.notifier).setHasAccount(true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

String mapAuthError(Object error) {
  if (error is fb_auth.FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is invalid.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'Account exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        final message = error.message;
        return message?.isNotEmpty == true
            ? message!
            : 'Authentication failed. Please try again.';
    }
  }
  if (error is StateError) return error.message;
  final text = error.toString();
  if (text.contains('authenticate is not supported on the web')) {
    return 'Google Sign-In web flow mismatch. Use popup/redirect flow.';
  }
  if (text.contains('No user currently signed in')) {
    return 'Please enter your email and password to resend verification.';
  }
  return 'Authentication failed. Please try again.';
}
