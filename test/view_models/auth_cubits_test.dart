import 'dart:async';

import 'package:bloop/data/auth_repository.dart';
import 'package:bloop/models/app_user.dart';
import 'package:bloop/view_models/auth_form_cubit.dart';
import 'package:bloop/view_models/login_cubit.dart';
import 'package:bloop/view_models/session_cubit.dart';
import 'package:bloop/view_models/signup_cubit.dart';
import 'package:bloop/view_models/validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for Firebase.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  /// When set, calls throw this instead of succeeding.
  AuthException? failWith;

  /// When set, calls wait for this before finishing (to observe loading).
  Completer<void>? gate;

  final calls = <String>[];

  Future<void> _maybeFail() async {
    if (gate != null) await gate!.future;
    final error = failWith;
    if (error != null) throw error;
  }

  void _setUser(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _maybeFail();
    _setUser(AppUser(id: '1', email: email));
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$name:$email');
    await _maybeFail();
    _setUser(AppUser(id: '1', email: email, displayName: name));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    await _maybeFail();
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _setUser(null);
  }
}

/// Collects the statuses a Cubit emits while [action] runs.
Future<List<AuthFormStatus>> statusesDuring(
  AuthFormCubit cubit,
  Future<void> Function() action,
) async {
  final statuses = <AuthFormStatus>[];
  final sub = cubit.stream.listen((s) => statuses.add(s.status));
  await action();
  await pumpEventQueue();
  await sub.cancel();
  return statuses;
}

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  group('LoginCubit', () {
    test('starts idle', () {
      expect(LoginCubit(repo).state.status, AuthFormStatus.idle);
    });

    test('emits loading then signedIn', () async {
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(
          cubit,
          () => cubit.login(email: 'a@b.co', password: 'secret'),
        ),
        [AuthFormStatus.loading, AuthFormStatus.signedIn],
      );
      expect(repo.calls, ['signIn:a@b.co']);
    });

    test('emits failure with the repository message', () async {
      repo.failWith = const AuthException('Wrong email or password.');
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(
          cubit,
          () => cubit.login(email: 'a@b.co', password: 'x'),
        ),
        [AuthFormStatus.loading, AuthFormStatus.failure],
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
      expect(cubit.state.status, AuthFormStatus.signedIn);
    });

    test('password reset emits resetEmailSent', () async {
      final cubit = LoginCubit(repo);
      expect(
        await statusesDuring(cubit, () => cubit.sendPasswordReset('a@b.co')),
        [AuthFormStatus.loading, AuthFormStatus.resetEmailSent],
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
    test('passes the name through and signs in', () async {
      final cubit = SignupCubit(repo);
      await cubit.signUp(name: 'Mona', email: 'm@b.co', password: '12345678');
      expect(repo.calls, ['signUp:Mona:m@b.co']);
      expect(cubit.state.status, AuthFormStatus.signedIn);
    });

    test('validates matching passwords', () {
      final cubit = SignupCubit(repo);
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
  });

  test('AppUser.name falls back to the email', () {
    expect(const AppUser(id: '1', email: 'sara@x.io').name, 'sara');
    expect(
      const AppUser(id: '1', email: 'sara@x.io', displayName: 'Sara').name,
      'Sara',
    );
  });
}
