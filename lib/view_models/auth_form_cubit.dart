import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';

enum AuthFormStatus {
  /// Waiting for input.
  idle,

  /// A request is running; the form should be locked.
  loading,

  /// The request failed; [AuthFormState.errorMessage] says why.
  failure,

  /// Signed in (after logging in or creating an account).
  signedIn,

  /// A password reset email was sent.
  resetEmailSent,
}

/// State of a login or sign-up form.
@immutable
class AuthFormState {
  const AuthFormState({this.status = AuthFormStatus.idle, this.errorMessage});

  final AuthFormStatus status;
  final String? errorMessage;

  bool get isLoading => status == AuthFormStatus.loading;
}

/// Shared behaviour for Cubits that submit an auth form.
abstract class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit() : super(const AuthFormState());

  /// Runs [task] and emits loading, then [onSuccess] or failure. A call
  /// while one is already running is ignored, so double taps submit once.
  @protected
  Future<void> run(
    Future<void> Function() task, {
    AuthFormStatus onSuccess = AuthFormStatus.signedIn,
  }) async {
    if (state.isLoading) return;
    emit(const AuthFormState(status: AuthFormStatus.loading));
    AuthFormState result;
    try {
      await task();
      result = AuthFormState(status: onSuccess);
    } on AuthException catch (e) {
      result = AuthFormState(
        status: AuthFormStatus.failure,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Unexpected error in $runtimeType: $e');
      result = const AuthFormState(
        status: AuthFormStatus.failure,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
    // The screen may have closed (closing this Cubit) while the task ran.
    if (!isClosed) emit(result);
  }
}
