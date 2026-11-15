import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/app_exception.dart';

enum AuthenticationFormStatus {
  /// Waiting for input.
  idle,

  /// A request is running; the form should be locked.
  loading,

  /// The request failed; [AuthenticationFormState.errorMessage] says why.
  failure,

  /// Signed in (after logging in or creating an account).
  signedIn,

  /// A password reset email was sent.
  resetEmailSent,
}

/// State of a login or sign-up form.
@immutable
class AuthenticationFormState {
  const AuthenticationFormState({
    this.status = AuthenticationFormStatus.idle,
    this.errorMessage,
  });

  final AuthenticationFormStatus status;
  final String? errorMessage;

  bool get isLoading => status == AuthenticationFormStatus.loading;
}

/// Shared behaviour for Cubits that submit an auth form.
abstract class AuthenticationFormCubit extends Cubit<AuthenticationFormState> {
  AuthenticationFormCubit() : super(const AuthenticationFormState());

  /// Runs [task] and emits loading, then [onSuccess] or failure. A call
  /// while one is already running is ignored, so double taps submit once.
  @protected
  Future<void> run(
    Future<void> Function() task, {
    AuthenticationFormStatus onSuccess = AuthenticationFormStatus.signedIn,
  }) async {
    // If a request is already running, ignore this one.
    if (state.isLoading) return;
    emit(
      const AuthenticationFormState(status: AuthenticationFormStatus.loading),
    );
    AuthenticationFormState result;
    try {
      await task();
      result = AuthenticationFormState(status: onSuccess);
    } on AppException catch (e) {
      result = AuthenticationFormState(
        status: AuthenticationFormStatus.failure,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Unexpected error in $runtimeType: $e');
      result = const AuthenticationFormState(
        status: AuthenticationFormStatus.failure,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
    // The screen may have closed (closing this Cubit) while the task ran.
    if (!isClosed) emit(result);
  }
}
