import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/auth_repository.dart';
import 'data/firebase_auth_repository.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'view_models/session_cubit.dart';
import 'views/home_view.dart';
import 'views/welcome_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    // Data layer first, then the app-wide Cubit that depends on it.
    RepositoryProvider<AuthRepository>(
      create: (_) => FirebaseAuthRepository(),
      child: BlocProvider(
        create: (context) => SessionCubit(context.read<AuthRepository>()),
        child: const MainApp(),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bloop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Signed-in users go straight to their chats; everyone else sees the
      // welcome screen. Signing in or out swaps this automatically.
      home: BlocBuilder<SessionCubit, SessionState>(
        buildWhen: (previous, current) =>
            previous.isSignedIn != current.isSignedIn,
        builder: (context, session) =>
            session.isSignedIn ? const HomeView() : const WelcomeView(),
      ),
    );
  }
}
