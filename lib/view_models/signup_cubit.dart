import '../data/auth_repository.dart';
import 'auth_form_cubit.dart';
import 'validators.dart';

/// View model for the sign-up screen.
class SignupCubit extends AuthFormCubit {
  SignupCubit(this._repository);

  final AuthRepository _repository;

  int get minPasswordLength => Validators.minPasswordLength;

  String? validateName(String? value) => Validators.name(value);

  String? validateEmail(String? value) => Validators.email(value);

  String? validatePassword(String? value) => Validators.newPassword(value);

  String? validateConfirmPassword(String? value, String password) =>
      Validators.confirmPassword(value, password);

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => run(
    () => _repository.signUp(name: name, email: email, password: password),
  );
}
