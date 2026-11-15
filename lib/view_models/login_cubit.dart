import '../data/authentication_repository.dart';
import 'authentication_form_cubit.dart';
import 'validators.dart';

/// View model for the login screen.
class LoginCubit extends AuthenticationFormCubit {
  LoginCubit(this._repository);

  final AuthenticationRepository _repository;

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.existingPassword(value);

  Future<void> login({required String email, required String password}) =>
      run(() => _repository.signIn(email: email, password: password));

  Future<void> sendPasswordReset(String email) => run(
    () => _repository.sendPasswordReset(email),
    onSuccess: AuthenticationFormStatus.resetEmailSent,
  );
}
