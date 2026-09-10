import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route names, so nothing navigates by a raw string.
///
/// A3 adds the real destinations from PRD §6.8: onboarding (two screens),
/// the topics list, create topic, topic detail, the incidents history and the
/// "Ring me now" test alarm. The single route below only exists so the app
/// boots and the theme can be seen.
abstract final class AppRoute {
  static const home = 'home';
}

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home,
      builder: (context, state) => const _ShellPlaceholder(),
    ),
  ],
);

class _ShellPlaceholder extends StatelessWidget {
  const _ShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Crit Alarm')),
    );
  }
}
