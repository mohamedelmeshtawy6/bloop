import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../models/app_user.dart';

/// App-wide sign-in state.
@immutable
class SessionState {
  const SessionState(this.user);

  /// The signed-in user, or null when signed out.
  final AppUser? user;

  bool get isSignedIn => user != null;
}

/// Follows the repository's user stream. The app root uses it to choose
/// between the welcome flow and the signed-in home screen.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository)
    : super(SessionState(_repository.currentUser)) {
    _subscription = _repository.userChanges.listen(
      (user) => emit(SessionState(user)),
    );
   }

  final AuthRepository _repository;
  late final StreamSubscription<AppUser?> _subscription;

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
