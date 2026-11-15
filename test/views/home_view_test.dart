import 'package:bloop/data/authentication_repository.dart';
import 'package:bloop/data/user_repository.dart';
import 'package:bloop/models/app_user.dart';
import 'package:bloop/models/user_profile.dart';
import 'package:bloop/theme.dart';
import 'package:bloop/view_models/session_cubit.dart';
import 'package:bloop/views/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const user = AppUser(id: 'me', email: 'mona@x.io', displayName: 'Mona');

Future<FakeUserRepository> pumpHome(
  WidgetTester tester, {
  bool hasUsername = true,
}) async {
  final users = FakeUserRepository([
    if (hasUsername)
      const UserProfile(id: 'me', username: 'mona', displayName: 'Mona'),
    const UserProfile(id: 'u1', username: 'sara', displayName: 'Sara Ali'),
    const UserProfile(id: 'u2', username: 'sami', displayName: 'Sami'),
  ]);
  final authentication = FakeAuthenticationRepository(signedIn: user);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthenticationRepository>.value(
          value: authentication,
        ),
        RepositoryProvider<UserRepository>.value(value: users),
      ],
      child: BlocProvider(
        create: (_) => SessionCubit(authentication),
        child: MaterialApp(theme: AppTheme.light(), home: HomeView.page(user)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return users;
}

void main() {
  testWidgets('shows the empty chats state with a greeting', (tester) async {
    await pumpHome(tester);
    expect(find.text('Hi, Mona 👋'), findsOneWidget);
    expect(find.text('Search by username'), findsOneWidget);
    expect(
      find.text('Choose a username so friends can find you.'),
      findsNothing,
    );
  });

  testWidgets('typing a username shows matching people', (tester) async {
    await pumpHome(tester);
    await tester.enterText(find.byType(TextField), 'sa');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Sami'), findsOneWidget);
    expect(find.text('Mona'), findsNothing);

    // Tapping a person opens their profile.
    await tester.tap(find.text('Sara Ali'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Sara Ali')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('@sara')),
      findsOneWidget,
    );
  });

  testWidgets('no matches explains it, clearing returns to chats', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.enterText(find.byType(TextField), 'zed');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No one found'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Mona 👋'), findsOneWidget);
  });

  testWidgets('users without a username can choose one', (tester) async {
    final users = await pumpHome(tester, hasUsername: false);
    expect(
      find.text('Choose a username so friends can find you.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'sara',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already taken'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Mona.K',
    );
    // Editing clears the "already taken" error (it fades out).
    await tester.pumpAndSettle();
    expect(find.textContaining('already taken'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Choose a username so friends can find you.'),
      findsNothing,
    );
    expect(users.profileOf('me')?.username, 'mona.k');
  });
}
