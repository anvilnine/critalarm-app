import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the paywall is told opened it from the widgets card or its sheet.
const homeWidgetsPaywallSource = 'home_widgets';

/// The steps to add a widget on [platform], in order, or null where there
/// are no widgets to add. iOS and Android each have their own keys: the
/// gestures and the labels differ.
List<String>? homeWidgetsStepsFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
      return [
        LocaleKeys.home_widgets_ios_step_1.tr(),
        LocaleKeys.home_widgets_ios_step_2.tr(),
        LocaleKeys.home_widgets_ios_step_3.tr(),
        LocaleKeys.home_widgets_ios_step_4.tr(),
      ];
    case TargetPlatform.android:
      return [
        LocaleKeys.home_widgets_android_step_1.tr(),
        LocaleKeys.home_widgets_android_step_2.tr(),
        LocaleKeys.home_widgets_android_step_3.tr(),
        LocaleKeys.home_widgets_android_step_4.tr(),
      ];
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return null;
  }
}

/// Opens the sheet that says how to add a home screen widget on
/// [platform]. [onSeeHosted] runs after the sheet has closed, and is only
/// offered to a user whose widgets are locked.
Future<void> showHomeWidgetsSheet({
  required BuildContext context,
  required TargetPlatform platform,
  required HomeWidgetsPlan plan,
  required VoidCallback onSeeHosted,
}) async {
  final steps = homeWidgetsStepsFor(platform);
  if (steps == null) return;
  await showExpandingSheet<void>(
    context: context,
    title: LocaleKeys.home_widgets_sheet_title.tr(),
    initialChildSize: 0.5,
    minChildSize: 0.3,
    content: (sheetContext) => _HomeWidgetsSheet(
      steps: steps,
      needsHosted: plan == HomeWidgetsPlan.needsHosted,
      onSeeHosted: () {
        Navigator.of(sheetContext).pop();
        onSeeHosted();
      },
    ),
  );
}

class _HomeWidgetsSheet extends StatelessWidget {
  const _HomeWidgetsSheet({
    required this.steps,
    required this.needsHosted,
    required this.onSeeHosted,
  });

  final List<String> steps;
  final bool needsHosted;
  final VoidCallback onSeeHosted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.s2),
        for (final (index, step) in steps.indexed) ...[
          if (index > 0) const SizedBox(height: Spacing.s3),
          AppStepBullet(number: index + 1, text: step),
        ],
        if (needsHosted) ...[
          const SizedBox(height: Spacing.s4),
          AppNote(text: LocaleKeys.home_widgets_needs_hosted.tr()),
          const SizedBox(height: Spacing.s3),
          AppButton(
            label: LocaleKeys.home_widgets_plans_button.tr(),
            variant: AppButtonVariant.ghost,
            isFullWidth: true,
            onPressed: onSeeHosted,
          ),
        ],
      ],
    );
  }
}
