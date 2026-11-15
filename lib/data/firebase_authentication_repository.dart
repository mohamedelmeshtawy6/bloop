import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'authentication_repository.dart';

/// [AuthenticationRepository] backed by Firebase Authentication (email and password).
class FirebaseAuthenticationRepository implements AuthenticationRepository {
  FirebaseAuthenticationRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  // userChanges (not authStateChanges) also fires when the display name is
  // set right after sign-up, so the UI always shows the right name.
  @override
  Stream<AppUser?> get userChanges => _auth.userChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          id: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
        );

  /// Runs [action] and turns Firebase errors into readable [AuthenticationException]s.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) => switch (code) {
    'invalid-email' => 'That email address isn\'t valid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => 'Wrong email or password.',
    'email-already-in-use' =>
      'An account with this email already exists. Try logging in instead.',
    'weak-password' => 'That password is too weak. Try a longer one.',
    'too-many-requests' =>
      'Too many attempts. Please wait a moment and try again.',
    'network-request-failed' =>
      'No internet connection. Check your connection and try again.',
    'operation-not-allowed' => 'Email sign-in isn\'t enabled for this app yet.',
    _ => 'Something went wrong. Please try again.',
  };
}
