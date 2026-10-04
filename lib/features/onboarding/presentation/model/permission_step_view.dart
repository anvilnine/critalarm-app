import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:flutter/widgets.dart';

/// Everything the permissions screen draws for one step: the words, the
/// face, the canvas behind it and the drawn prompt.
///
/// The screen draws whatever view it is handed and knows nothing about the
/// platform. Each platform builds its own views, from its own strings, in
/// its own file.
@immutable
class PermissionStepView {
  const PermissionStepView({
    required this.face,
    required this.ambient,
    required this.title,
    required this.subtitle,
    required this.button,
    this.grantedFace = FaceState.happy,
    this.badge,
    this.preview,
    this.canSkip = true,
  });

  /// The face at the top of the step, and in its badge.
  final FaceState face;

  /// The face for the beat after the user allows this step.
  final FaceState grantedFace;

  /// What the canvas behind the screen shows on this step.
  final OnboardingAmbientStep ambient;

  /// A chip under the face. No step passes one today: the title and the
  /// line under it already say it.
  final String? badge;
  final String title;
  final String subtitle;

  /// The main button.
  final String button;

  /// The drawn prompt. Null on a step with no prompt coming.
  final PermissionStepPreview? preview;

  /// False where the main button already only moves on, so "Not now" would
  /// be a second button doing the same thing.
  final bool canSkip;
}

/// The drawn copy of the prompt a step opens, and the line under it.
@immutable
class PermissionStepPreview {
  const PermissionStepPreview({
    required this.title,
    required this.child,
    this.hint,
  });

  /// The prompt's own heading, read out for the card as a whole.
  final String title;

  /// What to do when Settings opens. Null for a dialog, whose drawn Allow
  /// button already says it.
  final String? hint;

  /// One platform's drawn prompt.
  final Widget child;
}
