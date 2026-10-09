import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The row on a topic's page that picks the look of its alarm screen.
///
/// A topic follows the phone's look until its owner picks one for it. The
/// choice is kept on this phone and the server never hears of it. Locked,
/// the row says Standard, because that is what draws without the plan, and
/// carries the plan badge. A tap opens the same picker sheet as when it is
/// open, with a plan word on each look the plan unlocks. Picking one is the
/// use, and only then does the paywall open. The saved choice is kept for
/// when the plan is back.
class TopicAlarmStyleRow extends StatefulWidget {
  const TopicAlarmStyleRow({required this.topicName, super.key});

  final String topicName;

  @override
  State<TopicAlarmStyleRow> createState() => _TopicAlarmStyleRowState();
}

class _TopicAlarmStyleRowState extends State<TopicAlarmStyleRow> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final AlarmStyleChoices _choices = getIt<AlarmStyleChoices>();
  StreamSubscription<Object?>? _accessChanges;
  StreamSubscription<void>? _choiceChanges;
  StreamSubscription<void>? _ownLookChanges;

  @override
  void initState() {
    super.initState();
    _accessChanges = _access.changes
        .where((feature) => feature == AppFeature.alarmScreenStyles)
        .listen((_) => _redraw());
    _access.planRead.addListener(_redraw);
    _choiceChanges = _choices.changes.listen((_) => _redraw());
    // The own look comes and goes with its photo.
    _ownLookChanges = getIt<OwnAlarmLookKeeper>().changes.listen(
      (_) => _redraw(),
    );
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _access.planRead.removeListener(_redraw);
    unawaited(_accessChanges?.cancel());
    unawaited(_choiceChanges?.cancel());
    unawaited(_ownLookChanges?.cancel());
    super.dispose();
  }

  /// The look this topic picked for itself, or null while it follows the
  /// phone. An id this build does not know reads as the standard look.
  AlarmStyleId? get _own {
    final saved = _choices.assignments.perTopic[widget.topicName];
    if (saved == null) return null;
    return AlarmStyleId.fromId(saved) ?? AlarmStyleId.standard;
  }

  Future<void> _pick() async {
    AppHaptics.selection();
    final own = _own;
    // The fixed looks, and the person's own while its photo can be drawn.
    // Read once, so the index that comes back names the look that was
    // listed.
    final styles = pickableAlarmStyles;
    // Null until the plan is read, and when it is held.
    final plan = lockedPlanWord(AppFeature.alarmScreenStyles);
    // The index comes back, so the phone's look is told apart from a sheet
    // swiped away.
    final picked = await showAppSheet<int>(
      context: context,
      title: LocaleKeys.alarm_styles_row_title.tr(),
      subtitle: LocaleKeys.alarm_styles_sheet_note.tr(),
      options: [
        AppSheetOption<int>(
          label: LocaleKeys.alarm_styles_row_default.tr(),
          value: 0,
          isSelected: own == null,
        ),
        for (final (index, style) in styles.indexed)
          AppSheetOption<int>(
            label: style.nameKey.tr(),
            value: index + 1,
            badge: style.id.isFree ? null : plan,
            isSelected: own == style.id,
          ),
      ],
    );
    if (picked == null) return;
    final style = picked == 0 ? null : styles[picked - 1];
    if (style == null || style.id.isFree) {
      // Following the phone, or the standard look, needs no plan.
      await _choices.setTopicStyle(widget.topicName, style?.id.id);
      return;
    }
    // Choosing it is the use. Asked once the plan is read: right after a
    // cold start the row can be drawn open for someone who holds nothing,
    // or locked for someone who does.
    if (!mounted) return;
    final isGoAhead = await keepOrOpenPaywall(
      context,
      AppFeature.alarmScreenStyles,
      LockSource.topicLook,
    );
    if (!isGoAhead) return;
    await _choices.setTopicStyle(widget.topicName, style.id.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Drawn open until the plan is read, so a held plan never flashes a lock.
    final isLocked =
        _access.isPlanRead &&
        _access.decide(AppFeature.alarmScreenStyles) is FeatureLocked;
    final own = _own;
    final title = LocaleKeys.alarm_styles_row_title.tr();
    final meta = isLocked
        ? alarmStyleOf(AlarmStyleId.standard).nameKey.tr()
        : own == null
        ? LocaleKeys.alarm_styles_row_default.tr()
        : alarmStyleOf(own).nameKey.tr();
    final plan = lockedPlanWord(AppFeature.alarmScreenStyles);
    final row = AppListRow(
      name: title,
      meta: meta,
      trailing: isLocked
          ? null
          : AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
      onTap: () => unawaited(_pick()),
    );
    // The row leads to the sheet, so the tap stays with the row. The badge
    // is the lock's, and the plan is spoken with the row.
    return AccessLock(
      feature: AppFeature.alarmScreenStyles,
      source: LockSource.topicLook,
      tap: LockTap.open,
      badgeAlignment: AlignmentDirectional.centerEnd,
      // Set in from the row's edge, where the arrow sits when it is open.
      badgeOverhang: -14,
      child: plan == null
          ? row
          : Semantics(
              button: true,
              label: LocaleKeys.feature_lock_sheet_option.tr(
                namedArgs: {'name': '$title, $meta', 'plan': plan},
              ),
              onTap: () => unawaited(_pick()),
              excludeSemantics: true,
              child: row,
            ),
    );
  }
}
