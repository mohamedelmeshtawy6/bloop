import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/app_exception.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import 'validators.dart';

enum ProfileStatus { loading, ready, failure }

/// The signed-in user's own public profile.
@immutable
class ProfileState {
  const ProfileState({this.status = ProfileStatus.loading, this.profile});

  final ProfileStatus status;

  /// Null while loading, or when the user has no profile yet.
  final UserProfile? profile;

  /// True once we know the user has no username (e.g. accounts created
  /// before usernames existed), so home can ask them to pick one.
  bool get needsUsername => status == ProfileStatus.ready && profile == null;
}

/// Follows the signed-in user's profile and lets them claim a username.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._users, this._user) : super(const ProfileState()) {
    _subscription = _users
        .watchProfile(_user.id)
        .listen(
          (profile) =>
              emit(ProfileState(status: ProfileStatus.ready, profile: profile)),
          onError: (Object e) {
            debugPrint('Could not load profile: $e');
            emit(const ProfileState(status: ProfileStatus.failure));
          },
        );
  }

  final UserRepository _users;
  final AppUser _user;
  late final StreamSubscription<UserProfile?> _subscription;

  int get maxUsernameLength => Validators.maxUsernameLength;

  String? validateUsername(String? value) => Validators.username(value);

  /// Claims [username] for the signed-in user. Returns an error message to
  /// show, or null on success (the profile stream then updates the state).
  Future<String?> claimUsername(String username) async {
    try {
      await _users.createProfile(
        uid: _user.id,
        username: Validators.normalizeUsername(username),
        displayName: _user.name,
      );
      return null;
    } on AppException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('Unexpected error claiming username: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
