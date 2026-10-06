import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:flutter/material.dart';

/// A setup step that cannot go on, or is waiting on something: the face,
/// then one card holding what is wrong in a short title, at most one plain
/// line, and the thing to do about it.
///
/// The words sit on a card, never straight on the canvas: the canvas moves,
/// and text over it is hard to read. Every problem and wait in setup uses
/// this one widget, so they all look alike.
///
/// The face is the step's one hero face, so it flies in from the step
/// before and holds still while the card under it changes.
class SetupProblemCard extends StatelessWidget {
  const SetupProblemCard({
    required this.face,
    this.title,
    this.line,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.footer,
    super.key,
  }) : assert(
         title != null || line != null,
         'A problem card says something: a title, a line or both.',
       );

  /// A wait on something outside the app: the watching face over one line.
  const SetupProblemCard.waiting({required String message, Key? key})
    : this(face: FaceState.watching, line: message, key: key);

  /// The face over the card. `watching` for a wait, `sad` for something
  /// missing, `confused` for a test that timed out, `worried` for a
  /// failure.
  final FaceState face;

  /// What is wrong, in a few words. Left out for a wait, which is one line.
  final String? title;

  /// One plain line under the title.
  final String? line;

  /// Something more the card holds between the words and the action: the
  /// server's own reason, or a list of things to check.
  final Widget? detail;

  /// The one thing to do about it. Drawn only with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A quieter second way on, under a rule: a test of this phone only.
  final Widget? footer;

  /// The face every setup step shares.

  /// Widest the card runs, so it stays a card on a tablet.
  static const double _maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = this.title;
    final line = this.line;
    final detail = this.detail;
    final footer = this.footer;
    final onAction = this.onAction;
    final actionLabel = this.actionLabel;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SetupFace(state: face, gap: Spacing.s4),
            ),
            AppSheet(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Read out when it changes: a wait that turns into a
                  // failure says so to a screen reader too.
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null)
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTypography.headline(
                              colors.ink,
                              fontSize: 22,
                            ),
                          ),
                        if (title != null && line != null)
                          const SizedBox(height: Spacing.s2),
                        if (line != null)
                          Text(
                            line,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              title == null ? colors.ink : colors.ink2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: Spacing.s4),
                    detail,
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: Spacing.s4),
                    AppButton(
                      label: actionLabel,
                      isFullWidth: true,
                      onPressed: onAction,
                    ),
                  ],
                  if (footer != null) ...[
                    const AppSectionDivider(
                      padding: EdgeInsets.symmetric(vertical: Spacing.s4),
                    ),
                    footer,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
