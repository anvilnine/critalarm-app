import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/prompts/domain/pro_ending.dart';
import 'package:critalarm/features/prompts/presentation/widgets/prompt_detail_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// The free plan's limits, read from the same numbers the app falls back
/// to, so the copy never drifts from `AccountCaps.free`.
Map<String, String> get _freeCaps => {
  'history_days': '${AccountCaps.free.historyDays}',
  'p4_daily': '${AccountCaps.free.p4Daily}',
  'critical_topics': '${AccountCaps.free.criticalTopics}',
};

/// Opens the "Pro ends" or "Pro ended" sheet for [view]. Marks it shown as it
/// opens, so walking away counts as seen. [onDismiss] runs on "Not now".
Future<void> showProPlanSheet(
  BuildContext context,
  ProEndingView view, {
  VoidCallback? onDismiss,
}) async {
  final proEnding = getIt<ProEnding>();
  switch (view.sheet) {
    case ProPlanSheet.none:
      return;
    case ProPlanSheet.ending:
      final endsAt = view.endsAt!;
      await proEnding.markEndingSheetShown(endsAt);
      if (!context.mounted) return;
      await showPromptDetailSheet(
        context: context,
        face: FaceState.watching,
        title: LocaleKeys.home_pro_ending_title.tr(
          namedArgs: {
            'weekday': DateFormat('EEEE').format(endsAt),
            'date': DateFormat('d MMM').format(endsAt),
          },
        ),
        body: LocaleKeys.home_pro_ending_body.tr(namedArgs: _freeCaps),
        actionLabel: LocaleKeys.home_pro_ending_action.tr(),
        onAction: () => openAppPath(context, '/paywall'),
        onDismiss: onDismiss ?? () {},
      );
    case ProPlanSheet.ended:
      await proEnding.markEndedSheetShown();
      if (!context.mounted) return;
      await showPromptDetailSheet(
        context: context,
        face: FaceState.watching,
        title: LocaleKeys.home_pro_ended_title.tr(),
        body: LocaleKeys.home_pro_ended_body.tr(namedArgs: _freeCaps),
        actionLabel: LocaleKeys.home_pro_ended_action.tr(),
        dismissLabel: LocaleKeys.home_pro_ended_dismiss.tr(),
        onAction: () => openAppPath(context, '/paywall'),
        onDismiss: onDismiss ?? () {},
      );
  }
}
