import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'user_repository.dart';

/// [UserRepository] backed by Cloud Firestore.
///
/// Layout (see firestore.rules for who may write what):
/// * `users/{uid}`: `{username, displayName, createdAt}`, the public profile.
/// * `usernames/{username}`: `{uid}`, one document per taken username. The
///   document id is the username itself, so Firestore guarantees uniqueness.
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// U+F8FF, the last private-use character, which sorts after every
  /// character a username can contain.
  static final _prefixEnd = String.fromCharCode(0xF8FF);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  @override
  Stream<UserProfile?> watchProfile(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? _toProfile(doc) : null);

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _guard(() async => !(await _usernames.doc(username).get()).exists);

  @override
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
  }) => _guard(
    () => _db.runTransaction((transaction) async {
      final reservation = _usernames.doc(username);
      if ((await transaction.get(reservation)).exists) {
        throw UsernameTakenException(username);
      }
      transaction
        ..set(reservation, {'uid': uid})
        ..set(_users.doc(uid), {
          'username': username,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }),
  );

  @override
  Future<List<UserProfile>> searchByUsername(String prefix, {int limit = 20}) =>
      _guard(() async {
        // Prefix match: every string that starts with `prefix` sorts between
        // `prefix` and `prefix` followed by a very high code point.
        final snapshot = await _users
            .where('username', isGreaterThanOrEqualTo: prefix)
            .where('username', isLessThan: prefix + _prefixEnd)
            .orderBy('username')
            .limit(limit)
            .get();
        return snapshot.docs.map(_toProfile).toList();
      });

  static UserProfile _toProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UserProfile(
      id: doc.id,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String?,
    );
  }

  /// Runs [action] and turns Firestore errors into [UserRepositoryException]s.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.code} ${e.message}');
      throw UserRepositoryException(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) => switch (code) {
    'unavailable' =>
      'No internet connection. Check your connection and try again.',
    'permission-denied' => 'You don\'t have permission to do that.',
    'deadline-exceeded' => 'That took too long. Please try again.',
    _ => 'Something went wrong. Please try again.',
  };
}
