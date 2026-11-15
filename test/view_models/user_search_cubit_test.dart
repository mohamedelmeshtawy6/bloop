import 'dart:async';

import 'package:bloop/data/user_repository.dart';
import 'package:bloop/models/app_user.dart';
import 'package:bloop/models/user_profile.dart';
import 'package:bloop/view_models/profile_cubit.dart';
import 'package:bloop/view_models/user_search_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const me = UserProfile(id: 'me', username: 'mona', displayName: 'Mona');
const monaK = UserProfile(id: 'u1', username: 'mona_k', displayName: 'Mona K');
const moe = UserProfile(id: 'u2', username: 'moe', displayName: 'Moe');
const sara = UserProfile(id: 'u3', username: 'sara', displayName: 'Sara');

void main() {
  late FakeUserRepository users;

  setUp(() => users = FakeUserRepository([me, monaK, moe, sara]));

  UserSearchCubit searchCubit() =>
      UserSearchCubit(users, currentUserId: me.id, debounce: Duration.zero);

  group('UserSearchCubit', () {
    test('starts idle', () {
      expect(searchCubit().state.status, UserSearchStatus.idle);
    });

    test('finds usernames by prefix and leaves out yourself', () async {
      final cubit = searchCubit();
      cubit.queryChanged('mo');
      expect(cubit.state.status, UserSearchStatus.loading);
      await pumpEventQueue();
      expect(cubit.state.status, UserSearchStatus.success);
      expect(cubit.state.results, [moe, monaK]);
    });

    test('ignores case, spaces and a leading @', () async {
      final cubit = searchCubit();
      cubit.queryChanged('  @SA ');
      await pumpEventQueue();
      expect(users.searches, ['sa']);
      expect(cubit.state.query, 'sa');
      expect(cubit.state.results, [sara]);
    });

    test('no matches is a success with empty results', () async {
      final cubit = searchCubit();
      cubit.queryChanged('zed');
      await pumpEventQueue();
      expect(cubit.state.status, UserSearchStatus.success);
      expect(cubit.state.results, isEmpty);
    });

    test('clearing the query goes back to idle without searching', () async {
      final cubit = searchCubit();
      cubit.queryChanged('mo');
      cubit.queryChanged('');
      await pumpEventQueue();
      expect(cubit.state.status, UserSearchStatus.idle);
      expect(users.searches, isEmpty);
    });

    test('fast typing only searches for the last query', () async {
      final cubit = UserSearchCubit(
        users,
        currentUserId: me.id,
        debounce: const Duration(milliseconds: 20),
      );
      cubit
        ..queryChanged('m')
        ..queryChanged('mo')
        ..queryChanged('moe');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(users.searches, ['moe']);
      expect(cubit.state.results, [moe]);
      await cubit.close();
    });

    test('a slow older response does not replace newer results', () async {
      final slow = users.searchGates['s'] = Completer<void>();
      final cubit = searchCubit();
      cubit.queryChanged('s');
      await pumpEventQueue(); // "s" is now waiting on the server
      cubit.queryChanged('mo');
      await pumpEventQueue();
      expect(cubit.state.results, [moe, monaK]);

      slow.complete();
      await pumpEventQueue();
      expect(cubit.state.query, 'mo');
      expect(cubit.state.results, [moe, monaK]);
    });

    test('a failure shows the message and retry searches again', () async {
      users.searchFailure = const UserRepositoryException('No internet.');
      final cubit = searchCubit();
      cubit.queryChanged('mo');
      await pumpEventQueue();
      expect(cubit.state.status, UserSearchStatus.failure);
      expect(cubit.state.errorMessage, 'No internet.');

      users.searchFailure = null;
      cubit.retry();
      await pumpEventQueue();
      expect(cubit.state.status, UserSearchStatus.success);
      expect(cubit.state.results, [moe, monaK]);
    });

    test('does not emit after being closed mid-search', () async {
      final gate = users.searchGates['mo'] = Completer<void>();
      final cubit = searchCubit();
      cubit.queryChanged('mo');
      await pumpEventQueue();
      await cubit.close();
      gate.complete();
      await pumpEventQueue(); // would throw if it emitted after close
    });
  });

  group('ProfileCubit', () {
    const newUser = AppUser(
      id: 'new',
      email: 'nadia@x.io',
      displayName: 'Nadia',
    );

    test('asks for a username when the user has none', () async {
      final cubit = ProfileCubit(users, newUser);
      expect(cubit.state.status, ProfileStatus.loading);
      expect(cubit.state.needsUsername, isFalse);
      await pumpEventQueue();
      expect(cubit.state.needsUsername, isTrue);
      await cubit.close();
    });

    test('claiming a username updates the profile', () async {
      final cubit = ProfileCubit(users, newUser);
      await pumpEventQueue();
      expect(await cubit.claimUsername('@Nadia'), isNull);
      await pumpEventQueue();
      expect(cubit.state.needsUsername, isFalse);
      expect(cubit.state.profile?.handle, '@nadia');
      expect(cubit.state.profile?.name, 'Nadia');
      await cubit.close();
    });

    test('a taken username returns a message to show', () async {
      final cubit = ProfileCubit(users, newUser);
      expect(await cubit.claimUsername('sara'), contains('already taken'));
      await cubit.close();
    });
  });
}
