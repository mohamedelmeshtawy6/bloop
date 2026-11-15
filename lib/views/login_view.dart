import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/authentication_repository.dart';
import '../view_models/authentication_form_cubit.dart';
import '../view_models/login_cubit.dart';
import 'signup_view.dart';
import 'widgets/authentication_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  /// Opens the login screen with its own [LoginCubit].
  static Route<void> route() => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => LoginCubit(context.read<AuthenticationRepository>()),
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
      showAuthenticationMessage(
        context,
        'Enter your email above, then tap "Forgot password?" again.',
      );
      return;
    }
    cubit.sendPasswordReset(_email.text);
  }

  /// One-off reactions to state changes (navigation and messages).
  void _onStateChanged(BuildContext context, AuthenticationFormState state) {
    switch (state.status) {
      case AuthenticationFormStatus.signedIn:
        // The app root switches to the home screen once signed in; close
        // the auth screens stacked on top of it.
        Navigator.of(context).popUntil((route) => route.isFirst);
      case AuthenticationFormStatus.resetEmailSent:
        showAuthenticationMessage(
          context,
          'We sent a password reset link to ${_email.text.trim()}.',
        );
      case AuthenticationFormStatus.failure:
        showAuthenticationMessage(context, state.errorMessage!);
      case AuthenticationFormStatus.idle || AuthenticationFormStatus.loading:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();

    return BlocConsumer<LoginCubit, AuthenticationFormState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final busy = state.isLoading;
        return AuthenticationScaffold(
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
          footer: AuthenticationFooter(
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
