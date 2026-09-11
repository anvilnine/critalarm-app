import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route names, so nothing navigates by a raw string.
abstract final class AppRoute {
  static const home = 'home';
  static const gallery = 'gallery';
  static const onboarding = 'onboarding';
  static const onboardingPermissions = 'onboardingPermissions';
}

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home,
      builder: (context, state) => const _ShellPlaceholder(),
    ),
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/gallery',
      name: AppRoute.gallery,
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: AppRoute.onboarding,
      builder: (context, state) => const OnboardingWelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/permissions',
      name: AppRoute.onboardingPermissions,
      builder: (context, state) => const OnboardingPermissionsScreen(),
    ),
  ],
);

class _ShellPlaceholder extends StatelessWidget {
  const _ShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaceWidget(state: FaceState.calm, size: 80),
            const SizedBox(height: Spacing.s4),
            Text(
              'Crit Alarm',
              style: AppTypography.headline(colors.onCanvas),
            ),
            const SizedBox(height: Spacing.s2),
            Text(
              'Design System & Gallery',
              style: AppTypography.lead(colors.onCanvasMuted),
            ),
            const SizedBox(height: Spacing.s5),
            AppButton(
              label: 'Open Design System Gallery',
              onPressed: () => context.go('/gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
