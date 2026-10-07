import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/priorities/priority_effects.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What priorities 1 to 5 do on this phone, with a way to hear the alarm
/// sound in the app. The words come from [priorityEntriesFor], so they follow
/// what this phone can promise and nothing more.
class PrioritiesScreen extends StatefulWidget {
  const PrioritiesScreen({super.key});

  @override
  State<PrioritiesScreen> createState() => _PrioritiesScreenState();
}

class _PrioritiesScreenState extends State<PrioritiesScreen>
    with WidgetsBindingObserver {
  late final PrioritiesCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<PrioritiesCubit>();
    unawaited(_cubit.load());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_cubit.onLifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Closing the cubit stops the preview.
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: const _PrioritiesView(),
    );
  }
}

class _PrioritiesView extends StatelessWidget {
  const _PrioritiesView();

  static String lineText(PriorityLine line) => switch (line) {
    PriorityLine.alarmAndroid => LocaleKeys.priorities_alarm_android.tr(),
    PriorityLine.alarmIos => LocaleKeys.priorities_alarm_ios.tr(),
    PriorityLine.timeSensitiveIos =>
      LocaleKeys.priorities_time_sensitive_ios.tr(),
    PriorityLine.notificationAndroid =>
      LocaleKeys.priorities_notification_android.tr(),
    PriorityLine.notificationIos => LocaleKeys.priorities_notification_ios.tr(),
    PriorityLine.historyOnly => LocaleKeys.priorities_history_only.tr(),
  };

  /// One face per priority, and a different one for each. Priority 5 only
  /// looks alarmed where the phone really rings an alarm.
  static FaceState faceFor(PriorityEntry entry) => switch (entry.priority) {
    5 =>
      entry.line == PriorityLine.timeSensitiveIos
          ? FaceState.determined
          : FaceState.alarmed,
    4 => FaceState.worried,
    3 => FaceState.curious,
    2 => FaceState.sleepy,
    _ => FaceState.dozing,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<PrioritiesCubit, PrioritiesState>(
      builder: (context, state) {
        final cubit = context.read<PrioritiesCubit>();
        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.priorities_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in state.entries) ...[
                        AppListRow(
                          name: LocaleKeys.priorities_row_title.tr(
                            namedArgs: {'level': '${entry.priority}'},
                          ),
                          meta: lineText(entry.line),
                          metaMaxLines: 6,
                          faceState: faceFor(entry),
                          isCrit: entry.priority == 5,
                          trailing: entry.canHearIt && state.sound != null
                              ? AppPreviewButton(
                                  isPlaying: state.isPlaying,
                                  playLabel: LocaleKeys
                                      .priorities_hear_aria_label
                                      .tr(),
                                  stopLabel: LocaleKeys
                                      .priorities_stop_aria_label
                                      .tr(),
                                  onPressed: () {
                                    AppHaptics.selection();
                                    unawaited(cubit.togglePreview());
                                  },
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!state.isLoading) ...[
                        const SizedBox(height: 6),
                        AppListRow(
                          name: LocaleKeys.priorities_critical_topic_title.tr(),
                          meta: LocaleKeys.priorities_critical_topic_line.tr(),
                          metaMaxLines: 6,
                          faceState: null,
                          trailing: AppGlyph(
                            GlyphType.arrow,
                            color: colors.ink3,
                            size: 16,
                          ),
                          // Replaces the stack, so this page closes and the
                          // preview stops with it.
                          onTap: () => context.go('/'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
