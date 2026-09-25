import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens the next onboarding [step].
///
/// On a real run it saves the step first, so a relaunch opens it. On a replay
/// from Settings (`?demo=true`) it saves nothing and carries the flag on, so
/// every screen after it is a look too.
void goToOnboardingStep(BuildContext context, OnboardingStep step) {
  final isDemo =
      GoRouterState.of(context).uri.queryParameters['demo'] == 'true';
  if (isDemo) {
    context.go('${step.route}?demo=true');
    return;
  }
  unawaited(getIt<RememberOnboardingStepUsecase>()(step));
  context.go(step.route);
}
