import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/readiness_pips.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:critalarm/features/reliability/presentation/readiness_view.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_card_effect.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What the dark card at the top of Settings says, as plain values.
///
/// The count, the pips, the worst check and the fix come from
/// [ReadinessSummary], the same rule the Topics card reads, so the two screens
/// cannot disagree. Pure, so it is unit tested; the widget only translates it.
@immutable
class SettingsReadinessView {
  const SettingsReadinessView._({
    required this.summary,
    required this.face,
    required this.lineKey,
  });

  factory SettingsReadinessView.from(ReliabilitySnapshot snapshot) {
    final summary = ReadinessSummary.of(
      loaded: snapshot.loaded,
      incomplete: snapshot.incomplete,
      checks: snapshot.checks,
    );
    return SettingsReadinessView._(
      summary: summary,
      face: readinessFace(summary.kind),
      lineKey: reliabilityHeadlineView(readinessHeadline(summary.kind)).lineKey,
    );
  }

  final ReadinessSummary summary;

  /// The small face: happy, skeptical, sad, or watching while it loads.
  final FaceState face;

  /// A `LocaleKeys` key for the title when it does not name a check: the
  /// "checking" line while loading, the "no issues" line when all is fine.
  final String lineKey;

  ReadinessKind get kind => summary.kind;

  /// The check the title names, or null when the title is not about one.
  ReliabilityCheckId? get titleCheck => summary.worst?.id;

  /// True when the title says a check could not run.
  bool get titleIsMissingCheck => summary.namesMissingCheck;

  /// Whether the title names a check (or the check that could not run)
  /// instead of reading [lineKey].
  bool get titleNamesCheck =>
      kind == ReadinessKind.look || kind == ReadinessKind.broken;

  /// The fix the button runs, or null for no button.
  ReliabilityFix? get fix => summary.fix;
}

/// The first letter of [text] in capitals. The card's title is a sentence, and
/// the check lines are written to sit after a label.
String sentenceCase(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// The Settings card that answers "will it wake me?". It reads the overall
/// state from `ReliabilityCubit` and asks it to read again when Settings
/// opens, when the app comes back to the front and when the Reliability
/// screen is closed. The whole card opens that screen.
class SettingsReadinessCard extends StatefulWidget {
  const SettingsReadinessCard({super.key});

  @override
  State<SettingsReadinessCard> createState() => _SettingsReadinessCardState();
}

class _SettingsReadinessCardState extends State<SettingsReadinessCard>
    with WidgetsBindingObserver {
  final ReliabilityCubit _cubit = getIt<ReliabilityCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cubit.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.refresh());
  }

  Future<void> _open() async {
    await context.push<void>('/settings/reliability');
    if (!_cubit.isClosed) await _cubit.refresh();
  }

  /// Does what the Topics card does for the same fix.
  Future<void> _fix(ReliabilityFix fix) async {
    final effect = homeCardEffectFor(
      Fix(fix),
      missed: null,
      testRouteName: AppRoute.testRing,
      askPermissionsRouteName: AppRoute.askPermissions,
    );
    switch (effect) {
      case OpenRoute(:final name):
        await context.pushNamed<void>(name);
      case RunReliabilityFix(:final fix):
        await getIt<ReliabilityFixRunner>().run(fix);
      case OpenPath() || RefreshHome() || NoEffect():
        break;
    }
    if (!_cubit.isClosed) await _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReliabilityCubit, ReliabilitySnapshot>(
      bloc: _cubit,
      builder: (context, snapshot) {
        final view = SettingsReadinessView.from(snapshot);
        final summary = view.summary;
        final fix = view.fix;
        final title = !view.titleNamesCheck
            ? view.lineKey.tr()
            : view.titleIsMissingCheck
            ? sentenceCase(LocaleKeys.home_card_foot_check_could_not_run.tr())
            : sentenceCase(readinessCheckLine(view.titleCheck));
        return AppStatusCard.strip(
          face: view.face,
          label: LocaleKeys.home_card_label_will_it_wake_me.tr().toUpperCase(),
          title: title,
          numeral: summary.numeralText,
          numeralLabel: view.kind == ReadinessKind.loading
              ? null
              : LocaleKeys.settings_card_numeral_label.tr(
                  namedArgs: {
                    'fine': '${summary.count.fine}',
                    'total': '${summary.count.total}',
                  },
                ),
          numeralTone: readinessNumeralTone(view.kind),
          pips: summary.pips.isEmpty
              ? null
              : [for (final tone in summary.pips) readinessPipTone(tone)],
          actionLabel: fix == null
              ? null
              : LocaleKeys.home_card_action_fix.tr(),
          onAction: fix == null ? null : () => unawaited(_fix(fix)),
          onTap: () => unawaited(_open()),
          liveRegion: true,
        );
      },
    );
  }
}
