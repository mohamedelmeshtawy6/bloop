/// Form rules shared by the auth view models. Each returns an error message,
/// or null when the value is valid (the shape Flutter form fields expect).
abstract final class Validators {
  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Enter your name' : null;

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  /// For logging in: any non-empty password.
  static String? existingPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  /// For creating an account: enforces the minimum length.
  static String? newPassword(String? value) =>
      (value == null || value.length < minPasswordLength)
      ? 'Use at least $minPasswordLength characters'
      : null;

  static String? confirmPassword(String? value, String password) =>
      value != password ? 'Passwords don\'t match' : null;
}
