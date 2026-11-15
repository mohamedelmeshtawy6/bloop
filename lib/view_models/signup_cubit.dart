import 'package:flutter/foundation.dart';

import '../data/authentication_repository.dart';
import '../data/user_repository.dart';
import 'authentication_form_cubit.dart';
import 'validators.dart';

/// View model for the sign-up screen.
class SignupCubit extends AuthenticationFormCubit {
  SignupCubit(this._authentication, this._users);

  final AuthenticationRepository _authentication;
  final UserRepository _users;

  int get minPasswordLength => Validators.minPasswordLength;

  int get maxUsernameLength => Validators.maxUsernameLength;

  String? validateName(String? value) => Validators.name(value);

  String? validateUsername(String? value) => Validators.username(value);

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.newPassword(value);

  String? validateConfirmPassword(String? value, String password) =>
      Validators.confirmPassword(value, password);

  /// Creates the account, then the public profile with the username.
  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => run(() async {
    final handle = Validators.normalizeUsername(username);

    // Check first, so a taken username doesn't leave behind an account.
    if (!await _users.isUsernameAvailable(handle)) {
      throw UsernameTakenException(handle);
    }

    await _authentication.signUp(name: name, email: email, password: password);

    final uid = _authentication.currentUser?.id;
    if (uid == null) return;
    try {
      await _users.createProfile(
        uid: uid,
        username: handle,
        displayName: name.trim(),
      );
    } catch (e) {
      // The account exists and the user is already signed in. If the
      // username was grabbed in the last second or the network dropped,
      // home asks them to choose a username, so let them in anyway.
      debugPrint('Profile not created after sign-up: $e');
    }
  });
}
