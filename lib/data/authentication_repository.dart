import '../models/app_user.dart';

/// Thrown by an [AuthenticationRepository] with a message that is safe to show the user.
class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Everything the app needs from an authentication backend. View models
/// depend on this interface, so they can be tested with a fake.
abstract interface class AuthenticationRepository {
  /// Emits the current user on sign-in, sign-out and profile changes.
  Stream<AppUser?> get userChanges;

  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
