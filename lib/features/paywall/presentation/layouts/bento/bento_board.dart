import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The short name of [benefit] on a small tile.
String bentoNameFor(PaywallBenefit benefit) => switch (benefit.id) {
  PaywallBenefitId.topics => LocaleKeys.paywall_bento_names_topics,
  PaywallBenefitId.pushes => LocaleKeys.paywall_bento_names_pushes,
  PaywallBenefitId.history => LocaleKeys.paywall_bento_names_history,
  PaywallBenefitId.widgets => LocaleKeys.paywall_bento_names_widgets,
  PaywallBenefitId.appIcons => LocaleKeys.paywall_bento_names_app_icons,
  PaywallBenefitId.wakeUpChallenges =>
    LocaleKeys.paywall_bento_names_wake_up_challenges,
  PaywallBenefitId.reliabilityChecks =>
    LocaleKeys.paywall_bento_names_reliability_checks,
  PaywallBenefitId.customSounds => LocaleKeys.paywall_bento_names_custom_sounds,
  PaywallBenefitId.customAlarmScreens =>
    LocaleKeys.paywall_bento_names_custom_alarm_screens,
}.tr();

/// What the tiles measure on one phone.
@immutable
class BentoSizes {
  const BentoSizes({
    required this.mark,
    required this.pad,
    required this.label,
    required this.caption,
  });

  factory BentoSizes.of({required bool isCompact}) => isCompact
      ? const BentoSizes(mark: 36, pad: 5, label: 12, caption: 15)
      : const BentoSizes(mark: 44, pad: 8, label: 12.5, caption: 16.5);

  /// The edge of the mark on a small tile.
  final double mark;

  /// Above the mark and under the label.
  final double pad;

  /// Font sizes of a small tile's label and of the stage tile's line.
  final double label;
  final double caption;

  /// Between the mark and its label.
  static const double markGap = 3;

  /// At the sides of the stage tile's line, and under it.
  static const double captionSide = Spacing.s4;
  static const double captionFoot = 14;
}

/// The board: one stage tile and the small tiles under it, all on one
/// tile shape and one fill.
///
/// The stage tile is the kit's stage with the mascot and the playing
/// benefit's preview, and the only thing that moves. A small tile is one
/// mark and a short name. When the benefit changes, its tile and the stage
/// tile trade places.
///
/// A tap on a small tile puts its benefit on the stage. A swipe across
/// the stage goes to the next or the previous one, and a tap on it plays
/// the current one again.
class BentoBoardView extends StatefulWidget {
  const BentoBoardView({
    required this.player,
    required this.benefits,
    required this.plan,
    required this.sizes,
    required this.labelStyle,
    required this.captionStyle,
    this.lead = 0,
    super.key,
  });

  /// The head start of the entrance after an intro. See `bentoLeadFor`.
  final double lead;

  final HeroPlayer player;
  final List<PaywallBenefit> benefits;
  final BentoPlan plan;
  final BentoSizes sizes;
  final TextStyle labelStyle;
  final TextStyle captionStyle;

  @override
  State<BentoBoardView> createState() => _BentoBoardViewState();
}

class _BentoBoardViewState extends State<BentoBoardView> {
  BentoBoard _board = BentoBoard.of(0);

  HeroPlayer get _player => widget.player;

  /// The board as [frame] leaves it: the benefit on the stage has traded
  /// places with the one that was there.
  BentoBoard _boardAt(HeroFrame frame) {
    if (_board.order.length != widget.benefits.length) {
      _board = BentoBoard.of(widget.benefits.length);
    }
    return _board = _board.stage(frame.activeIndex, at: frame.turn);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return SizedBox(
      width: plan.stage.width,
      height: plan.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: plan.stage,
            child: HeroTouchArea(
              player: _player,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: PaywallClockBuilder(
                clock: _player.clock,
                builder: (context, t, _) => _tiles(context, t),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles(BuildContext context, double t) {
    final plan = widget.plan;
    final benefits = widget.benefits;
    final frame = _player.frameAt(t);
    final board = _boardAt(frame);
    final isStill = _player.isStill;
    final trade = isStill ? 1.0 : bentoTradeAt(board, _player.loopSeconds(t));
    final isTrading = trade < 1;

    // The tiles at home first, then the one leaving the stage, then the
    // one taking it, so the tile on its way up passes over the other.
    final drawn = [
      for (final benefit in board.order.skip(1))
        if (!isTrading || benefit != board.unstaged) benefit,
      if (isTrading) board.unstaged!,
      board.staged,
    ];
    final staged = benefits[board.staged];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final benefit in drawn)
          Positioned.fromRect(
            rect: bentoTileRect(
              board: board,
              plan: plan,
              benefit: benefit,
              trade: trade,
            ),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _tile(context, t, frame, board, benefit, trade),
              ),
            ),
          ),
        Positioned.fromRect(
          rect: plan.stage,
          child: IgnorePointer(
            child: Semantics(
              container: true,
              image: true,
              label: LocaleKeys.paywall_hero_stage_label.tr(
                namedArgs: {'benefit': heroLineFor(staged)},
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        for (final (i, rect) in plan.small.indexed)
          Positioned.fromRect(
            rect: rect,
            child: Semantics(
              button: true,
              label: benefits[board.order[i + 1]].line,
              onTap: () => _player.touch(index: _board.order[i + 1]),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () => _player.touch(index: _board.order[i + 1]),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    double t,
    HeroFrame frame,
    BentoBoard board,
    int benefit,
    double trade,
  ) {
    final plan = widget.plan;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slot = board.slotOf(benefit);
    final isTrading = trade < 1 && (slot == 0 || slot == board.tradedSlot);
    final rect = bentoTileRect(
      board: board,
      plan: plan,
      benefit: benefit,
      trade: trade,
    );
    final share = bentoStageShare(rect, plan);
    final stage = bentoStageOpacity(
      share,
      isLeaving: isTrading && slot != 0,
    );
    final mark = 1 - stage;
    final lift = isTrading ? bentoLiftAt(trade) : 0.0;

    Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        // The fill of the mark's own tile, so a mark sits on the bento
        // tile with no box of its own.
        color: colors.cream,
        borderRadius: Radii.mdAll,
        boxShadow: lift <= 0
            ? null
            : [
                for (final shadow in AppShadows.shadowMd(isDark: isDark))
                  shadow.copyWith(
                    color: shadow.color.withValues(
                      alpha: shadow.color.a * lift,
                    ),
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: Radii.mdAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (stage > 0)
              Opacity(
                opacity: stage,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: _StageFace(
                    size: plan.stage.size,
                    frame: frame,
                    seconds: _player.stageSeconds(t),
                    pull: slot == 0 ? _player.pullAt(t) : 0,
                    line: heroLineFor(widget.benefits[benefit]),
                    sizes: widget.sizes,
                    style: widget.captionStyle,
                  ),
                ),
              ),
            if (mark > 0)
              Opacity(
                opacity: mark,
                child: _MarkFace(
                  benefit: widget.benefits[benefit],
                  sizes: widget.sizes,
                  style: widget.labelStyle,
                ),
              ),
          ],
        ),
      ),
    );

    // The entrance: the tiles drop onto the board one by one, the small
    // ones left to right and the stage tile last, each with a bounce.
    if (!_player.isStill && t < _player.loop.entranceEnd) {
      final at = t + widget.lead;
      final drop = slot == 0
          ? bentoDropAt(bentoStageLandAt(at), from: bentoStageDropFrom)
          : bentoDropAt(
              bentoSmallLandAt(at, slot - 1),
              from: bentoSmallDropFrom,
            );
      tile = Opacity(
        opacity: drop.opacity,
        child: Transform.translate(offset: Offset(0, drop.dy), child: tile),
      );
    }
    return tile;
  }
}

/// A small tile's face: one mark over a short name, still.
class _MarkFace extends StatelessWidget {
  const _MarkFace({
    required this.benefit,
    required this.sizes,
    required this.style,
  });

  final PaywallBenefit benefit;
  final BentoSizes sizes;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.s1,
        vertical: sizes.pad,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PaywallPreview(
            benefit.previewId,
            sizeClass: PaywallPreviewClass.small,
            size: Size.square(sizes.mark),
          ),
          const SizedBox(height: BentoSizes.markGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(bentoNameFor(benefit), maxLines: 1, style: style),
          ),
        ],
      ),
    );
  }
}

/// The stage tile's face, [size] large: the kit's stage over the line of
/// the benefit it plays.
class _StageFace extends StatelessWidget {
  const _StageFace({
    required this.size,
    required this.frame,
    required this.seconds,
    required this.pull,
    required this.line,
    required this.sizes,
    required this.style,
  });

  final Size size;
  final HeroFrame frame;
  final double seconds;
  final double pull;
  final String line;
  final BentoSizes sizes;
  final TextStyle style;

  /// How tall the line's strip is under the stage, for a line [text]
  /// points tall.
  static double captionHeightFor(double text) => text + BentoSizes.captionFoot;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = scaler.scale(style.fontSize!) * style.height!;
    final caption = captionHeightFor(text).clamp(0.0, size.height);
    return SizedBox.fromSize(
      size: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroStage(
            size: Size(size.width, size.height - caption),
            frame: frame,
            seconds: seconds,
            pull: pull,
            arrange: bentoArrangementFor,
            tone: PaywallTone.surface,
            motion: bentoMotion,
          ),
          SizedBox(
            height: caption,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BentoSizes.captionSide,
              ),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(line, maxLines: 1, style: style),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
