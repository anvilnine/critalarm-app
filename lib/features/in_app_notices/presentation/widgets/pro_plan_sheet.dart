import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/notice_detail_sheet.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// A blank line, then the own-server line, as the last lines of a notice body.
/// Empty for a surface that has none.
List<String> _ownServerLines(HostedSurface surface) => [
  if (surface.ownServerLine case final line?) ...['', line],
];

/// Counts the person's numbers, then opens the leaving paywall. The sheet
/// has closed by now, so the context is Home's.
Future<void> _openLeavingPaywall(BuildContext context, DateTime endsAt) async {
  final location = await leavingPaywallLocation(endsAt);
  if (!context.mounted) return;
  openAppPath(context, location);
}

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
      await showNoticeDetailSheet(
        context: context,
        face: FaceState.watching,
        title: LocaleKeys.notices_pro_ending_title.tr(
          namedArgs: {
            'weekday': DateFormat('EEEE').format(endsAt),
            'date': DateFormat('d MMM').format(endsAt),
          },
        ),
        body: [
          LocaleKeys.notices_pro_ending_intro.tr(),
          hostedBenefitBullets(HostedSurface.endingNotice),
          '',
          LocaleKeys.notices_pro_ending_outro.tr(),
          ..._ownServerLines(HostedSurface.endingNotice),
        ].join('\n'),
        actionLabel: LocaleKeys.notices_pro_ending_action.tr(),
        onAction: () => unawaited(_openLeavingPaywall(context, endsAt)),
        onDismiss: onDismiss ?? () {},
      );
    case ProPlanSheet.ended:
      await proEnding.markEndedSheetShown();
      if (!context.mounted) return;
      await showNoticeDetailSheet(
        context: context,
        face: FaceState.watching,
        title: LocaleKeys.notices_pro_ended_title.tr(),
        body: [
          LocaleKeys.notices_pro_ended_intro.tr(),
          hostedBenefitBullets(HostedSurface.endedNotice),
          ..._ownServerLines(HostedSurface.endedNotice),
        ].join('\n'),
        actionLabel: LocaleKeys.notices_pro_ended_action.tr(),
        dismissLabel: LocaleKeys.notices_pro_ended_dismiss.tr(),
        onAction: () => unawaited(_openEnded(context)),
        onDismiss: onDismiss ?? () {},
      );
  }
}

/// Reads the rows the phone still holds, then opens the ended paywall.
Future<void> _openEnded(BuildContext context) async {
  final location = await hostedPaywallLocationWithOwn(
    PaywallSource.planSheetEnded,
  );
  if (!context.mounted) return;
  openAppPath(context, location);
}
