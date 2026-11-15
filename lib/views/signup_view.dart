import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/authentication_repository.dart';
import '../data/user_repository.dart';
import '../view_models/authentication_form_cubit.dart';
import '../view_models/signup_cubit.dart';
import 'login_view.dart';
import 'widgets/authentication_widgets.dart';
import 'widgets/user_widgets.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  /// Opens the sign-up screen with its own [SignupCubit].
  static Route<void> route() => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => SignupCubit(
        context.read<AuthenticationRepository>(),
        context.read<UserRepository>(),
      ),
      child: const SignupView(),
    ),
  );

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<SignupCubit>().signUp(
      name: _name.text,
      username: _username.text,
      email: _email.text,
      password: _password.text,
    );
  }

  /// One-off reactions to state changes (navigation and messages).
  void _onStateChanged(BuildContext context, AuthenticationFormState state) {
    switch (state.status) {
      case AuthenticationFormStatus.signedIn:
        // New accounts are signed in right away; the app root shows home.
        Navigator.of(context).popUntil((route) => route.isFirst);
      case AuthenticationFormStatus.failure:
        showAuthenticationMessage(context, state.errorMessage!);
      case AuthenticationFormStatus.idle ||
          AuthenticationFormStatus.loading ||
          AuthenticationFormStatus.resetEmailSent:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();

    return BlocConsumer<SignupCubit, AuthenticationFormState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final busy = state.isLoading;
        return AuthenticationScaffold(
          title: 'Create your account',
          subtitle: 'It only takes a minute to start chatting.',
          form: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    validator: cubit.validateName,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  UsernameField(
                    controller: _username,
                    maxLength: cubit.maxUsernameLength,
                    enabled: !busy,
                    validator: cubit.validateUsername,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: cubit.validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    enabled: !busy,
                    helperText:
                        'At least ${cubit.minPasswordLength} characters',
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: cubit.validatePassword,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    enabled: !busy,
                    label: 'Confirm password',
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        cubit.validateConfirmPassword(value, _password.text),
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    label: 'Create account',
                    loading: busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          footer: AuthenticationFooter(
            question: 'Already have an account?',
            action: 'Log in',
            onPressed: () =>
                Navigator.of(context).pushReplacement(LoginView.route()),
          ),
        );
      },
    );
  }
}
