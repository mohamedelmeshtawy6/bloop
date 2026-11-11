/// The signed-in user, independent of Firebase so the rest of the app never
/// touches Firebase types directly.
class AppUser {
  const AppUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  /// Name to show in the UI; falls back to the part of the email before "@".
  String get name {
    final display = displayName?.trim() ?? '';
    return display.isNotEmpty ? display : email.split('@').first;
  }
}
