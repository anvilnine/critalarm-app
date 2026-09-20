import 'package:critalarm/design/components/bottom_sheets.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Opens the explainer behind a pinned nudge: the same face, title and
/// sentence the nudge is short for, plus the thing it is asking for.
///
/// [onAction] runs after the sheet has closed. [onDismiss] runs when the user
/// takes the way out instead, so the caller can put the nudge to sleep.
Future<void> showPromptDetailSheet({
  required BuildContext context,
  required FaceState face,
  required String title,
  required String body,
  required String actionLabel,
  required VoidCallback onAction,
  required VoidCallback onDismiss,
}) {
  return showAppSheet<void>(
    context: context,
    content: (sheetContext) => PromptDetailSheet(
      face: face,
      title: title,
      body: body,
      actionLabel: actionLabel,
      onAction: () {
        Navigator.of(sheetContext).pop();
        onAction();
      },
      onDismiss: () {
        Navigator.of(sheetContext).pop();
        onDismiss();
      },
    ),
  );
}

/// What [showPromptDetailSheet] puts inside the sheet. The callbacks already
/// close it, so this widget only lays the pieces out.
class PromptDetailSheet extends StatelessWidget {
  const PromptDetailSheet({
    required this.face,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
    super.key,
  });

  final FaceState face;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FaceWidget(state: face, size: 36),
            const SizedBox(width: Spacing.s3),
            Expanded(
              child: Text(
                title,
                style: AppTypography.title(colors.ink, fontSize: 19),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s3),
        Text(body, style: AppTypography.small(colors.ink2)),
        const SizedBox(height: Spacing.s4),
        AppButton(
          label: actionLabel,
          isFullWidth: true,
          onPressed: onAction,
        ),
        const SizedBox(height: Spacing.s2),
        AppButton(
          label: LocaleKeys.common_not_now.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
