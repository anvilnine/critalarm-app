import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('OnboardingAmbientController', () {
    test('initializes with default step and push direction', () {
      final controller = OnboardingAmbientController();
      expect(controller.step, OnboardingAmbientStep.notifications);
      expect(controller.direction, AmbientDirection.push);
    });

    test('updates step and infers push direction when advancing', () {
      var notifications = 0;
      final controller = OnboardingAmbientController()
        ..addListener(() => notifications++)
        ..setStep(OnboardingAmbientStep.connect);

      expect(controller.step, OnboardingAmbientStep.connect);
      expect(controller.direction, AmbientDirection.push);
      expect(notifications, 1);
    });

    test('updates step and infers pop direction when reversing', () {
      var notifications = 0;
      final controller = OnboardingAmbientController(
        initialStep: OnboardingAmbientStep.connected,
      )
        ..addListener(() => notifications++)
        ..setStep(OnboardingAmbientStep.notifications);

      expect(controller.step, OnboardingAmbientStep.notifications);
      expect(controller.direction, AmbientDirection.pop);
      expect(notifications, 1);
    });

    test('does not notify when setting the exact same step', () {
      var notifications = 0;
      final controller = OnboardingAmbientController()
        ..addListener(() => notifications++)
        ..setStep(OnboardingAmbientStep.notifications);

      expect(controller.step, OnboardingAmbientStep.notifications);
      expect(notifications, 0);
    });
  });

  group('OnboardingShell widget', () {
    testWidgets('mounts AmbientCanvas and provides OnboardingAmbientScope', (
      tester,
    ) async {
      OnboardingAmbientController? resolvedScope;

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                OnboardingShell(state: state, child: child),
            routes: [
              GoRoute(
                path: '/onboarding',
                builder: (context, state) => Builder(
                  builder: (context) {
                    resolvedScope = OnboardingAmbientScope.maybeOf(context);
                    return const Text('Step 1');
                  },
                ),
              ),
              GoRoute(
                path: '/onboarding/connect',
                builder: (context, state) => const Text('Step 2'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byType(AmbientCanvas), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(resolvedScope, isNotNull);
      expect(resolvedScope!.step, OnboardingAmbientStep.notifications);

      // Navigate to connect route
      router.go('/onboarding/connect');
      await tester.pumpAndSettle();

      expect(find.text('Step 2'), findsOneWidget);
      expect(resolvedScope!.step, OnboardingAmbientStep.connect);
    });
  });
}
