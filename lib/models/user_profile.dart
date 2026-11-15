import 'package:flutter/foundation.dart';

/// A user's public profile: what other people see and search for.
/// Stored separately from sign-in details, so it never contains an email.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
  });

  /// Same id as the user's sign-in account.
  final String id;

  /// Unique, lowercase, without the leading "@".
  final String username;

  final String? displayName;

  /// Name to show in the UI; falls back to the username.
  String get name {
    final display = displayName?.trim() ?? '';
    return display.isNotEmpty ? display : username;
  }

  /// The username as people write it, e.g. "@mona".
  String get handle => '@$username';

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, username, displayName);
}
