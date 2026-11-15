import 'dart:async';

import 'package:bloop/data/authentication_repository.dart';
import 'package:bloop/data/user_repository.dart';
import 'package:bloop/models/app_user.dart';
import 'package:bloop/models/user_profile.dart';
import 'package:bloop/view_models/authentication_form_cubit.dart';
import 'package:bloop/view_models/login_cubit.dart';
import 'package:bloop/view_models/session_cubit.dart';
import 'package:bloop/view_models/signup_cubit.dart';
import 'package:bloop/view_models/validators.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

/// Collects the statuses a Cubit emits while [action] runs.
Future<List<AuthenticationFormStatus>> statusesDuring(
  AuthenticationFormCubit cubit,
  Future<void> Function() action,
) async {
  final statuses = <AuthenticationFormStatus>[];
  final sub = cubit.stream.listen((s) => statuses.add(s.status));
  await action();
  await pumpEventQueue();
  await sub.cancel();
  return statuses;
}

void main() {
  late FakeAuthenticationRepository repo;

  setUp(() => repo = FakeAuthenticationRepository());

  group('LoginCubit', () {
    test('starts idle', () {
      expect(LoginCubit(repo).state.status, AuthenticationFormStatus.idle);
    });

    test('emits loading then signedIn', () async {
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(
          cubit,
          () => cubit.login(email: 'a@b.co', password: 'secret'),
        ),
        [AuthenticationFormStatus.loading, AuthenticationFormStatus.signedIn],
      );
      expect(repo.calls, ['signIn:a@b.co']);
    });

    test('emits failure with the repository message', () async {
      repo.failWith = const AuthenticationException('Wrong email or password.');
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(
          cubit,
          () => cubit.login(email: 'a@b.co', password: 'x'),
        ),
        [AuthenticationFormStatus.loading, AuthenticationFormStatus.failure],
      );
      expect(cubit.state.errorMessage, 'Wrong email or password.');
    });

    test('ignores a second submit while loading', () async {
      repo.gate = Completer<void>();
      final cubit = LoginCubit(repo);
      final first = cubit.login(email: 'a@b.co', password: 'secret');
      expect(cubit.state.isLoading, isTrue);
      await cubit.login(email: 'a@b.co', password: 'secret');
      repo.gate!.complete();
      await first;
      expect(repo.calls, hasLength(1));
      expect(cubit.state.status, AuthenticationFormStatus.signedIn);
    });

    test('password reset emits resetEmailSent', () async {
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(cubit, () => cubit.sendPasswordReset('a@b.co')),
        [
          AuthenticationFormStatus.loading,
          AuthenticationFormStatus.resetEmailSent,
        ],
      );
      expect(repo.calls, ['reset:a@b.co']);
    });

    test('does not emit after being closed mid-request', () async {
      repo.gate = Completer<void>();
      final cubit = LoginCubit(repo);
      final pending = cubit.login(email: 'a@b.co', password: 'secret');
      await cubit.close();
      repo.gate!.complete();
      await expectLater(pending, completes);
    });
  });

  group('SignupCubit', () {
    late FakeUserRepository users;

    setUp(() => users = FakeUserRepository());

    Future<void> signUp(SignupCubit cubit, {String username = 'Mona_K'}) =>
        cubit.signUp(
          name: 'Mona',
          username: username,
          email: 'm@b.co',
          password: '12345678',
        );

    test('creates the account and a profile with the username', () async {
      final cubit = SignupCubit(repo, users);
      await signUp(cubit, username: ' @Mona_K ');
      expect(repo.calls, ['signUp:Mona:m@b.co']);
      expect(cubit.state.status, AuthenticationFormStatus.signedIn);
      expect(
        users.profileOf('1'),
        const UserProfile(id: '1', username: 'mona_k', displayName: 'Mona'),
      );
    });

    test('a taken username fails before any account is created', () async {
      users = FakeUserRepository([
        const UserProfile(id: '9', username: 'mona_k'),
      ]);
      final cubit = SignupCubit(repo, users);
      await signUp(cubit);
      expect(repo.calls, isEmpty);
      expect(cubit.state.status, AuthenticationFormStatus.failure);
      expect(cubit.state.errorMessage, contains('@mona_k is already taken'));
    });

    test('still signs in when the profile fails after the account', () async {
      users.createFailure = const UserRepositoryException('offline');
      final cubit = SignupCubit(repo, users);
      await signUp(cubit);
      expect(cubit.state.status, AuthenticationFormStatus.signedIn);
      expect(users.profileOf('1'), isNull);
    });

    test('validates matching passwords', () {
      final cubit = SignupCubit(repo, users);
      expect(cubit.validateConfirmPassword('abc', 'abc'), isNull);
      expect(cubit.validateConfirmPassword('abc', 'abd'), isNotNull);
    });
  });

  group('SessionCubit', () {
    test('follows sign-in and sign-out', () async {
      final session = SessionCubit(repo);
      expect(session.state.isSignedIn, isFalse);

      await repo.signUp(name: 'Mona', email: 'm@b.co', password: '12345678');
      await pumpEventQueue();
      expect(session.state.isSignedIn, isTrue);
      expect(session.state.user!.name, 'Mona');

      await session.signOut();
      await pumpEventQueue();
      expect(session.state.isSignedIn, isFalse);
      await session.close();
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(' a@b.co '), isNull);
    });

    test('new password needs the minimum length', () {
      expect(Validators.newPassword('1234567'), isNotNull);
      expect(Validators.newPassword('12345678'), isNull);
    });

    test('username', () {
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
      expect(Validators.username('1mona'), isNotNull);
      expect(Validators.username('mo na'), isNotNull);
      expect(Validators.username('mona.k_1'), isNull);
      expect(Validators.username(' @Mona '), isNull);
    });

    test('normalizeUsername trims, lowercases and drops the @', () {
      expect(Validators.normalizeUsername('  @Mona_K '), 'mona_k');
      expect(Validators.normalizeUsername(null), '');
    });
  });

  test('AppUser.name falls back to the email', () {
    expect(const AppUser(id: '1', email: 'sara@x.io').name, 'sara');
    expect(
      const AppUser(id: '1', email: 'sara@x.io', displayName: 'Sara').name,
      'Sara',
    );
  });
}
