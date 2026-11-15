import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_profile.dart';

/// Round avatar with the person's initials. The color comes from [seed]
/// (their user id), so each person keeps the same color everywhere.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.radius = 22,
  });

  final String name;
  final String seed;
  final double radius;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w.characters.first).join();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    // Sum of code units rather than hashCode, which isn't stable across runs.
    final index = seed.codeUnits.fold(0, (sum, unit) => sum + unit);
    final (background, foreground) = palette[index % palette.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Keeps username input in its stored form while typing: lowercase, and
/// only letters, numbers, "_" and ".".
class UsernameInputFormatter extends TextInputFormatter {
  static final _notAllowed = RegExp(r'[^a-z0-9_.]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toLowerCase().replaceAll(_notAllowed, '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Text field for choosing a username, shown with an "@" in front.
class UsernameField extends StatelessWidget {
  const UsernameField({
    super.key,
    required this.controller,
    required this.maxLength,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final int maxLength;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;

  /// An error from the server (e.g. "already taken"), shown until edited.
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newUsername],
      textInputAction: textInputAction,
      inputFormatters: [
        UsernameInputFormatter(),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      validator: validator,
      forceErrorText: errorText,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: const InputDecoration(
        labelText: 'Username',
        prefixIcon: Icon(Icons.alternate_email_rounded),
        helperText: 'Friends find you by this. Letters, numbers, _ and .',
      ),
    );
  }
}

/// Bottom sheet with someone's public profile.
Future<void> showUserProfileSheet(BuildContext context, UserProfile user) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(name: user.name, seed: user.id, radius: 40),
              const SizedBox(height: 16),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.handle,
                style: text.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
