import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The row on a topic's page that picks its wake-up challenge.
///
/// Off for every topic until its owner picks one. The choice is kept on
/// this phone and the server never hears of it. Locked, the row says Off,
/// because no challenge runs without the plan, and carries the plan badge.
/// A tap opens the same picker sheet as when it is open, with a plan word
/// on each option the plan unlocks. Picking one is the use, and only then
/// does the paywall open. The saved choice is kept for when the plan is
/// back.
class TopicChallengeRow extends StatefulWidget {
  const TopicChallengeRow({required this.topicName, super.key});

  final String topicName;

  @override
  State<TopicChallengeRow> createState() => _TopicChallengeRowState();
}

class _TopicChallengeRowState extends State<TopicChallengeRow> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final ChallengeChoices _choices = getIt<ChallengeChoices>();
  StreamSubscription<Object?>? _accessChanges;
  StreamSubscription<void>? _choiceChanges;

  @override
  void initState() {
    super.initState();
    _accessChanges = _access.changes
        .where((feature) => feature == AppFeature.wakeUpChallenges)
        .listen((_) => _redraw());
    _access.planRead.addListener(_redraw);
    _choiceChanges = _choices.changes.listen((_) => _redraw());
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _access.planRead.removeListener(_redraw);
    unawaited(_accessChanges?.cancel());
    unawaited(_choiceChanges?.cancel());
    super.dispose();
  }

  Future<void> _pick() async {
    AppHaptics.selection();
    final current = challengeOf(_choices.choiceFor(widget.topicName));
    // Null until the plan is read, and when it is held.
    final plan = lockedPlanWord(AppFeature.wakeUpChallenges);
    // The index comes back, so Off is told apart from a sheet swiped away.
    final picked = await showAppSheet<int>(
      context: context,
      title: LocaleKeys.challenges_row_title.tr(),
      subtitle: LocaleKeys.challenges_sheet_note.tr(),
      options: [
        AppSheetOption<int>(
          label: LocaleKeys.challenges_off.tr(),
          value: 0,
          isSelected: current == null,
        ),
        for (final (index, challenge) in challenges.indexed)
          AppSheetOption<int>(
            label: challenge.nameKey.tr(),
            value: index + 1,
            badge: plan,
            isSelected: current?.kind == challenge.kind,
          ),
      ],
    );
    if (picked == null) return;
    final kind = picked == 0 ? null : challenges[picked - 1].kind;
    if (kind == null) {
      // Turning one off needs no plan.
      await _choices.setChoice(widget.topicName, null);
      return;
    }
    // Choosing it is the use. Asked once the plan is read: right after a
    // cold start the row can be drawn open for someone who holds nothing,
    // or locked for someone who does.
    if (!mounted) return;
    final isGoAhead = await keepOrOpenPaywall(
      context,
      AppFeature.wakeUpChallenges,
      LockSource.topicChallenge,
    );
    if (!isGoAhead) return;
    await _choices.setChoice(widget.topicName, kind);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Drawn open until the plan is read, so a held plan never flashes a lock.
    final isLocked =
        _access.isPlanRead &&
        _access.decide(AppFeature.wakeUpChallenges) is FeatureLocked;
    final chosen = isLocked
        ? null
        : challengeOf(_choices.choiceFor(widget.topicName));
    final title = LocaleKeys.challenges_row_title.tr();
    final meta = chosen == null
        ? LocaleKeys.challenges_off.tr()
        : chosen.nameKey.tr();
    final plan = lockedPlanWord(AppFeature.wakeUpChallenges);
    final row = AppListRow(
      name: title,
      meta: meta,
      // Asleep while off, up once a challenge is set.
      faceState: chosen == null ? FaceState.sleepy : FaceState.wakesUp,
      trailing: isLocked
          ? null
          : AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
      onTap: () => unawaited(_pick()),
    );
    // The row leads to the sheet, so the tap stays with the row. The badge
    // is the lock's, and the plan is spoken with the row.
    return AccessLock(
      feature: AppFeature.wakeUpChallenges,
      source: LockSource.topicChallenge,
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
