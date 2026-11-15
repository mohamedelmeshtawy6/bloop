import '../models/user_profile.dart';
import 'app_exception.dart';

/// Thrown by a [UserRepository] with a message that is safe to show the user.
class UserRepositoryException extends AppException {
  const UserRepositoryException(super.message);
}

/// Thrown when someone else already owns the username.
class UsernameTakenException extends UserRepositoryException {
  const UsernameTakenException(String username)
    : super('@$username is already taken. Try another one.');
}

/// Public user profiles: reading, creating and searching them. View models
/// depend on this interface, so they can be tested with a fake.
abstract interface class UserRepository {
  /// Emits the profile for [uid], or null while it has no profile yet.
  Stream<UserProfile?> watchProfile(String uid);

  /// Whether nobody owns [username] yet. [username] must be normalized.
  Future<bool> isUsernameAvailable(String username);

  /// Reserves [username] for [uid] and creates their profile in one step.
  /// Throws [UsernameTakenException] if it was claimed in the meantime.
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
  });

  /// Profiles whose username starts with [prefix], in alphabetical order.
  /// [prefix] must be normalized.
  Future<List<UserProfile>> searchByUsername(String prefix, {int limit = 20});
}
