import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../view_models/auth_form_cubit.dart';
import '../view_models/login_cubit.dart';
import 'signup_view.dart';
import 'widgets/auth_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  /// Opens the login screen with its own [LoginCubit].
  static Route<void> route() => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => LoginCubit(context.read<AuthRepository>()),
      child: const LoginView(),
    ),
  );

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginCubit>().login(
      email: _email.text,
      password: _password.text,
    );
  }

  void _forgotPassword() {
    final cubit = context.read<LoginCubit>();
    if (cubit.validateEmail(_email.text) != null) {
      showAuthMessage(
        context,
        'Enter your email above, then tap "Forgot password?" again.',
      );
      return;
    }
    cubit.sendPasswordReset(_email.text);
  }

  /// One-off reactions to state changes (navigation and messages).
  void _onStateChanged(BuildContext context, AuthFormState state) {
    switch (state.status) {
      case AuthFormStatus.signedIn:
        // The app root switches to the home screen once signed in; close
        // the auth screens stacked on top of it.
        Navigator.of(context).popUntil((route) => route.isFirst);
      case AuthFormStatus.resetEmailSent:
        showAuthMessage(
          context,
          'We sent a password reset link to ${_email.text.trim()}.',
        );
      case AuthFormStatus.failure:
        showAuthMessage(context, state.errorMessage!);
      case AuthFormStatus.idle || AuthFormStatus.loading:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();

    return BlocConsumer<LoginCubit, AuthFormState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final busy = state.isLoading;
        return AuthScaffold(
          title: 'Welcome back',
          subtitle: 'Log in to pick up your conversations.',
          form: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    onFieldSubmitted: (_) => _submit(),
                    validator: cubit.validatePassword,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: 'Log in',
                    loading: busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          footer: AuthFooter(
            question: 'Don\'t have an account?',
            action: 'Sign up',
            onPressed: () =>
                Navigator.of(context).pushReplacement(SignupView.route()),
          ),
        );
      },
    );
  }
}
