import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/app_exception.dart';
import '../data/user_repository.dart';
import '../models/user_profile.dart';
import 'validators.dart';

enum UserSearchStatus {
  /// Nothing typed; home shows the chats instead of results.
  idle,

  /// Waiting for the user to stop typing, or for the server.
  loading,

  /// [UserSearchState.results] holds the matches (possibly none).
  success,

  /// The search failed; [UserSearchState.errorMessage] says why.
  failure,
}

@immutable
class UserSearchState {
  const UserSearchState({
    this.query = '',
    this.status = UserSearchStatus.idle,
    this.results = const [],
    this.errorMessage,
  });

  /// The normalized query: lowercase, without a leading "@".
  final String query;
  final UserSearchStatus status;
  final List<UserProfile> results;
  final String? errorMessage;

  bool get isSearching => status != UserSearchStatus.idle;
}

/// Searches other users by username as the user types.
class UserSearchCubit extends Cubit<UserSearchState> {
  UserSearchCubit(
    this._users, {
    required this.currentUserId,
    this.debounce = const Duration(milliseconds: 300),
  }) : super(const UserSearchState());

  final UserRepository _users;

  /// Left out of the results: you can't start a chat with yourself.
  final String currentUserId;

  /// How long typing must pause before a search runs, so each keystroke
  /// doesn't send a request.
  final Duration debounce;

  Timer? _debounceTimer;

  /// Increases with every new search, so a slow response for an old query
  /// can't overwrite the results for the current one.
  int _latestRequest = 0;

  void queryChanged(String text) {
    final query = Validators.normalizeUsername(text);
    if (query == state.query) return;

    _debounceTimer?.cancel();
    _latestRequest++;

    if (query.isEmpty) {
      emit(const UserSearchState());
      return;
    }
    // Keep the previous results on screen while the new ones load.
    emit(
      UserSearchState(
        query: query,
        status: UserSearchStatus.loading,
        results: state.results,
      ),
    );
    _debounceTimer = Timer(debounce, () => _search(query));
  }

  /// Runs the current query again, e.g. after a failure.
  void retry() {
    if (state.query.isEmpty) return;
    emit(UserSearchState(query: state.query, status: UserSearchStatus.loading));
    _search(state.query);
  }

  Future<void> _search(String query) async {
    final request = ++_latestRequest;
    UserSearchState result;
    try {
      final matches = await _users.searchByUsername(query);
      result = UserSearchState(
        query: query,
        status: UserSearchStatus.success,
        results: [
          for (final user in matches)
            if (user.id != currentUserId) user,
        ],
      );
    } on AppException catch (e) {
      result = UserSearchState(
        query: query,
        status: UserSearchStatus.failure,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Unexpected error searching users: $e');
      result = UserSearchState(
        query: query,
        status: UserSearchStatus.failure,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
    if (!isClosed && request == _latestRequest) emit(result);
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
