import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../view_models/profile_cubit.dart';
import '../view_models/session_cubit.dart';
import '../view_models/user_search_cubit.dart';
import 'widgets/user_widgets.dart';

/// Signed-in landing screen: a username search on top of the chat list.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  /// Home for [user], with the view models it needs.
  static Widget page(AppUser user) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => ProfileCubit(context.read<UserRepository>(), user),
      ),
      BlocProvider(
        create: (context) => UserSearchCubit(
          context.read<UserRepository>(),
          currentUserId: user.id,
        ),
      ),
    ],
    child: const HomeView(),
  );

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    context.read<UserSearchCubit>().queryChanged('');
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: const [_AccountButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SearchField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: context.read<UserSearchCubit>().queryChanged,
              onClear: _clearSearch,
            ),
          ),
          BlocBuilder<ProfileCubit, ProfileState>(
            buildWhen: (previous, current) =>
                previous.needsUsername != current.needsUsername,
            builder: (context, profile) => profile.needsUsername
                ? const _ChooseUsernameBanner()
                : const SizedBox.shrink(),
          ),
          const Expanded(child: _HomeBody()),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      onTapOutside: (_) => focusNode.unfocus(),
      decoration: InputDecoration(
        hintText: 'Search by username',
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        // Show the clear button only while there is text.
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

/// The chat list when not searching; search results while searching.
class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchCubit, UserSearchState>(
      builder: (context, search) {
        switch (search.status) {
          case UserSearchStatus.idle:
            return const _EmptyChats();
          case UserSearchStatus.loading when search.results.isEmpty:
            return const Center(child: CircularProgressIndicator());
          case UserSearchStatus.failure:
            return _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t search right now',
              body: search.errorMessage ?? '',
              action: FilledButton.tonal(
                onPressed: context.read<UserSearchCubit>().retry,
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                child: const Text('Try again'),
              ),
            );
          case UserSearchStatus.success when search.results.isEmpty:
            return _Message(
              icon: Icons.person_search_rounded,
              title: 'No one found',
              body: 'No username starts with "@${search.query}".',
            );
          case UserSearchStatus.loading || UserSearchStatus.success:
            return _SearchResults(
              query: search.query,
              results: search.results,
              refreshing: search.status == UserSearchStatus.loading,
            );
        }
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.results,
    required this.refreshing,
  });

  final String query;
  final List<UserProfile> results;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thin bar while newer results load, so the list doesn't jump.
        SizedBox(
          height: 2,
          child: refreshing ? const LinearProgressIndicator() : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Text(
            'People',
            style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: results.length,
            itemBuilder: (context, index) =>
                _UserResultTile(user: results[index], query: query),
          ),
        ),
      ],
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.user, required this.query});

  final UserProfile user;
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matched = user.username.startsWith(query) ? query.length : 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: UserAvatar(name: user.name, seed: user.id),
      title: Text(
        user.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // The part of the username that matches the query is emphasized.
      subtitle: Text.rich(
        TextSpan(
          style: TextStyle(color: scheme.onSurfaceVariant),
          children: [
            const TextSpan(text: '@'),
            TextSpan(
              text: user.username.substring(0, matched),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: user.username.substring(matched)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        FocusScope.of(context).unfocus();
        showUserProfileSheet(context, user);
      },
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (SessionCubit cubit) => cubit.state.user?.name ?? 'there',
    );
    return _Message(
      icon: Icons.forum_outlined,
      title: 'Hi, $name 👋',
      body:
          'No conversations yet.\nSearch for a username above to find '
          'someone to chat with.',
    );
  }
}

/// Centered icon, title and text, for empty and error states.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Shown to users without a username (e.g. accounts from before usernames).
class _ChooseUsernameBanner extends StatelessWidget {
  const _ChooseUsernameBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = context.read<ProfileCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Choose a username so friends can find you.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ChooseUsernameDialog(profile: profile),
                ),
                child: const Text('Choose'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooseUsernameDialog extends StatefulWidget {
  const _ChooseUsernameDialog({required this.profile});

  /// Passed in because dialogs are built outside home's providers.
  final ProfileCubit profile;

  @override
  State<_ChooseUsernameDialog> createState() => _ChooseUsernameDialogState();
}

class _ChooseUsernameDialogState extends State<_ChooseUsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await widget.profile.claimUsername(_username.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _serverError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose a username'),
      content: Form(
        key: _formKey,
        child: UsernameField(
          controller: _username,
          maxLength: widget.profile.maxUsernameLength,
          enabled: !_saving,
          autofocus: true,
          validator: widget.profile.validateUsername,
          errorText: _serverError,
          onChanged: (_) {
            if (_serverError != null) setState(() => _serverError = null);
          },
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

/// The signed-in user's avatar; opens their account sheet.
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final user = context.select((SessionCubit cubit) => cubit.state.user);
    final profile = context.select((ProfileCubit cubit) => cubit.state.profile);
    if (user == null) return const SizedBox.shrink();
    final name = profile?.name ?? user.name;

    return IconButton(
      tooltip: 'Account',
      icon: UserAvatar(name: name, seed: user.id, radius: 18),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _AccountSheet(
          user: user,
          profile: profile,
          onSignOut: () => _confirmSignOut(context),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await session.signOut();
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({
    required this.user,
    required this.profile,
    required this.onSignOut,
  });

  final AppUser user;
  final UserProfile? profile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = profile?.name ?? user.name;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(name: name, seed: user.id, radius: 36),
            const SizedBox(height: 12),
            Text(
              name,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              profile?.handle ?? 'No username yet',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              user.email,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text('Log out', style: TextStyle(color: scheme.error)),
              onTap: () {
                Navigator.pop(context);
                onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
