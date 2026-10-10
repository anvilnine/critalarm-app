import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_try.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/challenge_shelf_rules.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_scope.dart';
import 'package:critalarm/features/settings/presentation/personalize/challenge/challenge_tile.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/pass_live.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The Wake-up challenge page: the header on the panel colour, and a shelf of
/// tiles under it. "No challenge" comes first, then the five challenges.
///
/// Two taps, and only one of them can sell:
///
/// - A tile opens the try page for its challenge, for everyone, locked or
///   not. Nothing is saved and no paywall opens.
/// - The control at the right of a tile's name keeps that challenge for topics
///   made from now on. The lock rule says what it does: open, it saves;
///   locked, it opens the Pro paywall. "No challenge" needs no plan.
///
/// The wide button under the shelf says "See Pro" in words and is drawn only
/// while locked. A tag in the header never opens anything.
///
/// The choice here is for topics made from now on. A topic that exists keeps
/// what its own page says.
///
/// [scope] is the whole phone, or one topic. For a topic the saved choice is
/// that topic's own, the pick control saves it for that topic and nothing
/// else, and the line under the shelf says so. The rules are the same.
class ChallengePassScreen extends StatefulWidget {
  const ChallengePassScreen({this.scope = const EverywhereScope(), super.key});

  final PassScope scope;

  @override
  State<ChallengePassScreen> createState() => _ChallengePassScreenState();
}

class _ChallengePassScreenState extends State<ChallengePassScreen> {
  late final FeatureAccess _access = getIt<FeatureAccess>();
  late final ChallengeChoices _choices = getIt<ChallengeChoices>();

  FeatureDecision get _decision => _access.decide(AppFeature.wakeUpChallenges);

  /// Asks the lock rule what [tap] does now. A tap that could sell or save
  /// waits for the plan to be read first, so a paywall is never shown to
  /// someone who already pays and nothing is saved on a guess.
  Future<LockTapAnswer> _answer(ShelfTap tap) async {
    var answer = shelfTapFor(
      tap: tap,
      decision: _decision,
      isPlanRead: _access.isPlanRead,
    );
    if (answer is WaitForPlan) {
      await _access.ready;
      if (!mounted) return const Nothing();
      answer = shelfTapFor(
        tap: tap,
        decision: _decision,
        isPlanRead: _access.isPlanRead,
      );
    }
    return answer;
  }

  /// The tile: the try page for [challenge].
  void _open(Challenge challenge) {
    unawaited(Navigator.of(context).push(ChallengeTryPage.route(challenge)));
  }

  /// The pick control: keep [tile] for [PassScope] (new topics, or one
  /// topic), or sell.
  Future<void> _pick(ShelfTile tile) async {
    final kind = tile.kind;
    if (kind == null) {
      // Taking a challenge away needs no plan.
      assert(shelfOffTapAnswer() is DoIt, 'turning challenges off is free');
      await saveChallenge(widget.scope, _choices, null);
      return;
    }
    switch (await _answer(ShelfTap.pick)) {
      case DoIt():
        await saveChallenge(widget.scope, _choices, kind);
      case OpenPaywall(:final offer):
        if (!mounted) return;
        await openPaywallFor(
          context,
          FeatureDecision.locked(offer),
          LockSource.personalizeChallenge,
        );
      case OpenPage() || TryIt() || WaitForPlan() || Nothing():
        break;
    }
  }

  /// The wide button: the paywall, in words.
  Future<void> _seePlan() async {
    final answer = await _answer(ShelfTap.plan);
    if (answer is! OpenPaywall || !mounted) return;
    await openPaywallFor(
      context,
      FeatureDecision.locked(answer.offer),
      LockSource.personalizeChallenge,
    );
  }

  @override
  Widget build(BuildContext context) => PassLiveBuilder(
    scope: widget.scope,
    builder: (context, live) {
      final colors = context.appColors;
      final tone = live.toneOf(PassId.challenge);
      final decision = _decision;
      final isPlanRead = _access.isPlanRead;
      final chosen = shelfChosenFor(
        saved: challengeSavedFor(widget.scope, _choices),
        decision: decision,
      );
      final footer = shelfFooterFor(decision: decision, isPlanRead: isPlanRead);
      final plan = decision is FeatureLocked
          ? planWordFor(decision.offer)
          : null;
      final tiles = shelfTilesFor([for (final c in challenges) c.kind]);

      return AppPassPage(
        tone: tone,
        label: live.labelOf(PassId.challenge),
        value: live.valueOf(PassId.challenge),
        tag: live.tagOf(PassId.challenge),
        isOn: live.isOn(PassId.challenge),
        foot: LocaleKeys.personalize_passes_challenge_page_note.tr(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              kShelfSidePadding,
              20,
              kShelfSidePadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _Shelf(
                tiles: tiles,
                chosen: chosen,
                decision: decision,
                isPlanRead: isPlanRead,
                onOpen: _open,
                onPick: (tile) => unawaited(_pick(tile)),
                isForTopic: widget.scope.isTopic,
              ),
            ),
          ),
          // Said once, on every plan, under the last row of tiles.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              kPassSidePadding,
              kShelfGap,
              kPassSidePadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                widget.scope is TopicScope
                    ? LocaleKeys.personalize_passes_challenge_topic_scope_note
                          .tr(namedArgs: {'topic': widget.scope.topic!})
                    : LocaleKeys.personalize_passes_challenge_scope_note.tr(),
                style: AppTypography.mono(tone.valueMuted, fontSize: 12),
              ),
            ),
          ),
          if (footer == ShelfFooter.planButton && plan != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                kShelfSidePadding,
                kShelfGap,
                kShelfSidePadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: AppButton(
                  label: LocaleKeys.personalize_passes_widgets_see_plan.tr(
                    namedArgs: {'plan': plan},
                  ),
                  size: AppButtonSize.lg,
                  isFullWidth: true,
                  icon: AppGlyph(
                    GlyphType.lock,
                    size: 18,
                    color: colors.onHighlight,
                  ),
                  onPressed: () => unawaited(_seePlan()),
                ),
              ),
            ),
          if (footer == ShelfFooter.confirming)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                kPassSidePadding,
                kShelfGap + 4,
                kPassSidePadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    LocaleKeys.personalize_try_confirming.tr(),
                    style: AppTypography.mono(tone.valueMuted, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// The grid. Rows of [shelfColumnsFor] tiles, each row as tall as its tallest
/// tile, so a name that wraps never leaves a ragged edge.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.tiles,
    required this.chosen,
    required this.decision,
    required this.isPlanRead,
    required this.onOpen,
    required this.onPick,
    required this.isForTopic,
  });

  final List<ShelfTile> tiles;
  final ChallengeKind? chosen;
  final FeatureDecision decision;
  final bool isPlanRead;
  final void Function(Challenge challenge) onOpen;
  final void Function(ShelfTile tile) onPick;

  /// Whether the pick control saves for one topic, which its spoken label says.
  final bool isForTopic;

  /// What the tile asks, for a screen reader only. It is not drawn, so the
  /// tiles stay apart by ear.
  String _descriptorOf(ChallengeKind? kind) => switch (kind) {
    null => LocaleKeys.personalize_passes_challenge_tile_off.tr(),
    ChallengeKind.typeTopicName =>
      LocaleKeys.personalize_passes_challenge_tile_type_topic.tr(),
    ChallengeKind.typeAlertTitle =>
      LocaleKeys.personalize_passes_challenge_tile_type_title.tr(),
    ChallengeKind.opsMath =>
      LocaleKeys.personalize_passes_challenge_tile_math.tr(),
    ChallengeKind.scratchCard =>
      LocaleKeys.personalize_passes_challenge_tile_scratch.tr(),
    ChallengeKind.shake =>
      LocaleKeys.personalize_passes_challenge_tile_shake.tr(),
  };

  Widget _tileFor(ShelfTile tile) {
    final challenge = challengeOf(tile.kind);
    final name = challenge == null
        ? LocaleKeys.personalize_passes_challenge_tile_off_name.tr()
        : challenge.nameKey.tr();
    final descriptor = _descriptorOf(tile.kind);
    final pick = shelfPickFor(
      tile: tile,
      chosen: chosen,
      decision: decision,
      isPlanRead: isPlanRead,
    );
    final plan = decision is FeatureLocked
        ? planWordFor((decision as FeatureLocked).offer)
        : null;
    final pickLabel = pick == ShelfPick.locked && plan != null
        ? (isForTopic
                  ? LocaleKeys
                        .personalize_passes_challenge_pick_label_topic_locked
                  : LocaleKeys.personalize_passes_challenge_pick_label_locked)
              .tr(namedArgs: {'name': name, 'plan': plan})
        : (isForTopic
                  ? LocaleKeys.personalize_passes_challenge_pick_label_topic
                  : LocaleKeys.personalize_passes_challenge_pick_label)
              .tr(namedArgs: {'name': name});
    return ChallengeTile(
      key: ValueKey('challenge-tile-${tile.kind?.id ?? 'off'}'),
      tile: tile,
      pick: pick,
      name: name,
      tileLabel: '$name, $descriptor',
      // "No challenge" has nothing to try: its tile keeps it for new topics.
      tileHint: challenge == null ? '' : LocaleKeys.challenges_try_hint.tr(),
      pickLabel: pickLabel,
      onOpen: () => challenge == null ? onPick(tile) : onOpen(challenge),
      onPick: () => onPick(tile),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
      // The shelf is inset by the page; the rules count the whole column.
      final columns = shelfColumnsFor(
        columnWidth: constraints.maxWidth + 2 * kShelfSidePadding,
        textScale: textScale,
      );
      final rows = <Widget>[];
      for (var start = 0; start < tiles.length; start += columns) {
        final row = tiles.skip(start).take(columns).toList();
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: kShelfGap),
                  Expanded(
                    child: i < row.length
                        ? _tileFor(row[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: kShelfGap),
            rows[i],
          ],
        ],
      );
    },
  );
}
