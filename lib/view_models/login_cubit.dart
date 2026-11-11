import '../data/auth_repository.dart';
import 'auth_form_cubit.dart';
import 'validators.dart';

/// View model for the login screen.
class LoginCubit extends AuthFormCubit {
  LoginCubit(this._repository);

  final AuthRepository _repository;

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.existingPassword(value);

  Future<void> login({required String email, required String password}) =>
      run(() => _repository.signIn(email: email, password: password));

  Future<void> sendPasswordReset(String email) => run(
    () => _repository.sendPasswordReset(email),
    onSuccess: AuthFormStatus.resetEmailSent,
  );
}
