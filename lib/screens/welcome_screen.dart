import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

/// The first screen people see: a short pitch for bloop and the two ways in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea( 
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _Logo(size: 36),
                          const SizedBox(width: 10),
                          Text(
                            'bloop',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: _ChatPreview()),
                        ),
                      ),
                      Text(
                        'Say hello,\nthe easy way.',
                        style: text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -1,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fast, simple messaging with the people who matter to you.',
                        style: text.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).push(SignupScreen.route()),
                        child: const Text('Get started'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).push(LoginScreen.route()),
                        child: const Text('I already have an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        color: scheme.onPrimary,
        size: size * 0.55,
      ),
    );
  }
}

/// A small mock conversation that shows what the app is for.
class _ChatPreview extends StatelessWidget {
  const _ChatPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.45),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bubble(
                incoming: true,
                avatar: 'S',
                child: Text(
                  'Are we still on for tonight?',
                  style: TextStyle(color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 10),
              _Bubble(
                incoming: false,
                child: Text(
                  'Yes! See you at 8 🎉',
                  style: TextStyle(color: scheme.onPrimary),
                ),
              ),
              const SizedBox(height: 10),
              const _Bubble(incoming: true, avatar: 'S', child: _TypingDots()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.incoming, required this.child, this.avatar});

  final bool incoming;
  final Widget child;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: incoming ? scheme.surfaceContainerHighest : scheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: incoming ? tail : r,
          bottomRight: incoming ? r : tail,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    return Row(
      mainAxisAlignment: incoming
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (incoming && avatar != null) ...[
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.tertiaryContainer,
            child: Text(
              avatar!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
      ],
    );
  }
}

/// Three dots that pulse in turn, like someone is typing.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset in time so they light up one after another.
            final t = (_controller.value - i * 0.2) % 1.0;
            final opacity = t < 0.5 ? 0.35 + 1.3 * t : 1.0 - 1.3 * (t - 0.5);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity.clamp(0.35, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
