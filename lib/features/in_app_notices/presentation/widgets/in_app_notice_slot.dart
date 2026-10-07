import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/missed_alarm_notice_card.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/no_server_notice_card.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/system_update_notice_card.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/weekly_check_notice_card.dart';
import 'package:critalarm/features/permissions/presentation/widgets/setup_health_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pinned slot above the Home stage hosting the single active alert or prompt.
///
/// Smoothly animates cards in with a spring overshoot and collapses on
/// dismissal, enforcing the single-slot invariant.
class InAppNoticeSlot extends StatelessWidget {
  const InAppNoticeSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InAppNoticeCubit, InAppNoticeState>(
      builder: (context, state) {
        final Widget child;

        if (state.isDismissing || state.noticeType == InAppNoticeType.none) {
          child = const SizedBox.shrink(key: ValueKey('empty_notice'));
        } else {
          switch (state.noticeType) {
            case InAppNoticeType.noServer:
              child = const NoServerNoticeCard(key: ValueKey('no_server'));
            case InAppNoticeType.criticalHealth:
              child = const SetupHealthNotice(key: ValueKey('health_notice'));
            case InAppNoticeType.systemUpdate:
              child = const SystemUpdateNoticeCard(
                key: ValueKey('system_update'),
              );
            case InAppNoticeType.weeklyCheck:
              child = const WeeklyCheckNoticeCard(
                key: ValueKey('weekly_check'),
              );
            case InAppNoticeType.missedAlarm:
              final notice = state.missedAlarm;
              child = notice == null
                  ? const SizedBox.shrink(key: ValueKey('empty_notice'))
                  : MissedAlarmNoticeCard(
                      key: const ValueKey('missed_alarm'),
                      notice: notice,
                    );
            // The backup notice is not a card up here any more. It is a line
            // pinned above the tab bar, so it never pushes a topic off the
            // screen. Pro is not in this slot at all: it asks as a sheet.
            case InAppNoticeType.batteryOptimization:
            case InAppNoticeType.proEnding:
            case InAppNoticeType.accountBackup:
            case InAppNoticeType.none:
              child = const SizedBox.shrink(key: ValueKey('empty_notice'));
          }
        }

        return AnimatedSize(
          duration: context.motion(const Duration(milliseconds: 350)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 350)),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: child,
          ),
        );
      },
    );
  }
}
