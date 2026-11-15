import 'dart:async';

import 'package:bloop/data/authentication_repository.dart';
import 'package:bloop/data/user_repository.dart';
import 'package:bloop/models/app_user.dart';
import 'package:bloop/models/user_profile.dart';

/// In-memory stand-in for Firebase Authentication.
class FakeAuthenticationRepository implements AuthenticationRepository {
  FakeAuthenticationRepository({AppUser? signedIn}) : _user = signedIn;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  /// When set, calls throw this instead of succeeding.
  AuthenticationException? failWith;

  /// When set, calls wait for this before finishing (to observe loading).
  Completer<void>? gate;

  final calls = <String>[];

  Future<void> _maybeFail() async {
    if (gate != null) await gate!.future;
    final error = failWith;
    if (error != null) throw error;
  }

  void _setUser(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _maybeFail();
    _setUser(AppUser(id: '1', email: email));
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$name:$email');
    await _maybeFail();
    _setUser(AppUser(id: '1', email: email, displayName: name));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    await _maybeFail();
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _setUser(null);
  }
}

/// In-memory stand-in for the Firestore profiles.
class FakeUserRepository implements UserRepository {
  FakeUserRepository([Iterable<UserProfile> profiles = const []]) {
    for (final profile in profiles) {
      _profiles[profile.id] = profile;
    }
  }

  final _profiles = <String, UserProfile>{};
  final _changes = StreamController<void>.broadcast();

  /// When set, searches throw this instead of returning results.
  UserRepositoryException? searchFailure;

  /// When set, createProfile throws this.
  Object? createFailure;

  /// Per-query gates, to finish searches in a chosen order.
  final searchGates = <String, Completer<void>>{};

  final searches = <String>[];

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield _profiles[uid];
    await for (final _ in _changes.stream) {
      yield _profiles[uid];
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !_profiles.values.any((p) => p.username == username);

  @override
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
  }) async {
    final failure = createFailure;
    if (failure != null) throw failure;
    if (!await isUsernameAvailable(username)) {
      throw UsernameTakenException(username);
    }
    _profiles[uid] = UserProfile(
      id: uid,
      username: username,
      displayName: displayName,
    );
    _changes.add(null);
  }

  @override
  Future<List<UserProfile>> searchByUsername(
    String prefix, {
    int limit = 20,
  }) async {
    searches.add(prefix);
    await searchGates[prefix]?.future;
    final failure = searchFailure;
    if (failure != null) throw failure;
    final matches =
        _profiles.values.where((p) => p.username.startsWith(prefix)).toList()
          ..sort((a, b) => a.username.compareTo(b.username));
    return matches.take(limit).toList();
  }

  UserProfile? profileOf(String uid) => _profiles[uid];
}
