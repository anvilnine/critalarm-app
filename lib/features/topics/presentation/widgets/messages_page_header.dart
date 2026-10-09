import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/topics/domain/topic_messages_page.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// The top of a topic's messages page: a small label, how many messages there
// are as the big value, and the last seven days as bars with their own
// caption. The count is every message the plan keeps, so no period is written
// under it. A soft disc breathes behind it. The bars grow once when the
// numbers arrive, and the disc is the only thing that keeps moving.

/// The bars' width and the room round them.
const double _kBarWidth = 12;
const double _kBarGap = 6;
const double _kBarsHeight = 72;

/// A day with no messages, and the shortest bar a day with some has.
const double _kQuietBar = 8;
const double _kShortestBar = 16;

/// The space either side of the header.
const double kMessagesHeaderMargin = 20;

/// How wide the bars are as a block.
double get _barsWidth =>
    kMessageBarDays * _kBarWidth + (kMessageBarDays - 1) * _kBarGap;

/// The height of the bar for [bar], [_kQuietBar] to [_kBarsHeight].
double messageBarHeight(MessageDayBar bar) => bar.count == 0
    ? _kQuietBar
    : _kShortestBar + (_kBarsHeight - _kShortestBar) * bar.fraction;

/// The label, the count and the captioned bars, with [below] under them.
///
/// The disc behind the header runs on behind [below] as well, so [below]
/// belongs in this widget and not in a sliver of its own: a later sliver
/// would paint over the disc.
///
/// [count] is null while the messages are being read or could not be read.
/// The header keeps its height either way. [isLoading] tells which: a bone
/// stands where the count will be.
class MessagesPageHeader extends StatelessWidget {
  const MessagesPageHeader({
    required this.count,
    required this.bars,
    required this.isLoading,
    required this.below,
    super.key,
  });

  final int? count;
  final List<MessageDayBar> bars;
  final bool isLoading;

  /// What sits under the header, drawn over the disc.
  final Widget below;

  @override
  Widget build(BuildContext context) {
    // The bars wait at zero until the numbers are here, then grow.
    return PaywallClockHold(
      isWaiting: isLoading || count == null,
      child: _MessagesClock(
        builder: (context, clock, {required isStill}) => Stack(
          // The disc runs up behind the top bar and off the right edge. It
          // is first, so it is behind the rest.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -150,
              top: -40,
              child: IgnorePointer(
                child: _Disc(clock: clock, isStill: isStill),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Spacing.s2),
                _Words(
                  count: count,
                  bars: bars,
                  isLoading: isLoading,
                  clock: clock,
                ),
                const SizedBox(height: Spacing.s5),
                below,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({
    required this.count,
    required this.bars,
    required this.isLoading,
    required this.clock,
  });

  final int? count;
  final List<MessageDayBar> bars;
  final bool isLoading;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final value = count;

    final label = Text(
      LocaleKeys.topic_detail_messages_header.tr().toUpperCase(),
      style: AppTypography.monoBold(
        colors.onCanvas,
        fontSize: 10.5,
      ).copyWith(letterSpacing: 10.5 * 0.1, height: 1.2),
    );

    // The numeral stops growing with the text size at the chrome limit, and
    // shrinks to fit rather than break a long count.
    final Widget numeral = SizedBox(
      height: 44,
      child: isLoading
          ? const Align(
              alignment: Alignment.centerLeft,
              child: AppSkeleton(
                child: AppSkeletonBone(
                  width: 64,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            )
          : value == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberFormat.decimalPattern().format(value),
                maxLines: 1,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: kChromeMaxTextScale),
                style: AppTypography.headline(
                  colors.onCanvas,
                  fontSize: 42,
                ).copyWith(height: 1.05),
              ),
            ),
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(height: 2),
        numeral,
      ],
    );

    // The caption says what the bars cover, not what the count covers. With
    // no count there are no bars to describe, so it keeps its height and is
    // not drawn. The bars' own spoken label already names the period.
    final caption = ExcludeSemantics(
      child: Opacity(
        opacity: isLoading || value != null ? 1 : 0,
        child: Text(
          LocaleKeys.topic_messages_window.tr(),
          textAlign: TextAlign.right,
          // Stops growing at the chrome limit so it never outruns the bars it
          // sits over.
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: kChromeMaxTextScale),
          style: AppTypography.mono(
            colors.onCanvasMuted,
            fontSize: 12,
          ).copyWith(height: 1.4, letterSpacing: 0),
        ),
      ),
    );

    final barsView = Semantics(
      container: true,
      label: LocaleKeys.topic_messages_bars_aria.tr(),
      excludeSemantics: true,
      child: _Bars(bars: bars, clock: clock),
    );

    // The caption sits over the bars, right aligned with them.
    final captioned = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        caption,
        const SizedBox(height: 6),
        barsView,
      ],
    );

    // Large text stacks the bars under the words so neither is squeezed.
    final isStacked = scale > kChromeMaxTextScale;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMessagesHeaderMargin),
      child: MergeSemantics(
        child: isStacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words,
                  const SizedBox(height: Spacing.s3),
                  captioned,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: words),
                  const SizedBox(width: 12),
                  captioned,
                ],
              ),
      ),
    );
  }
}

/// The seven bars. Each grows from the bottom, one after the other, once.
class _Bars extends StatelessWidget {
  const _Bars({required this.bars, required this.clock});

  final List<MessageDayBar> bars;
  final ValueListenable<double> clock;

  /// How long one bar takes to grow, and how long the next waits.
  static final double _grow = AppDurations.pass.inMicroseconds / 1e6;
  static final double _each = AppDurations.quick.inMicroseconds / 3e6;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: _barsWidth,
      height: _kBarsHeight,
      child: ValueListenableBuilder<double>(
        valueListenable: clock,
        builder: (context, t, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(width: _kBarGap),
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(
                  1,
                  messageBarGrowth(
                    stagger(i, t, each: _each),
                    _grow,
                  ),
                  1,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bars[i].hasRang ? colors.crit : colors.onCanvas,
                    borderRadius: BorderRadius.circular(_kBarWidth / 2),
                  ),
                  child: SizedBox(
                    width: _kBarWidth,
                    height: messageBarHeight(bars[i]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How far a bar has grown, 0 to a little past 1, [seconds] after it
/// started, when it takes [length] seconds to grow.
double messageBarGrowth(double seconds, double length) =>
    AppCurves.easeBack.transform(phase(seconds, 0, length));

/// The soft disc behind the header.
class _Disc extends StatelessWidget {
  const _Disc({required this.clock, required this.isStill});

  static const double size = 420;
  static const double _breath = 0.035;

  final ValueListenable<double> clock;
  final bool isStill;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final disc = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.canvasAlt.withValues(alpha: 0.6),
      ),
      child: const SizedBox.square(dimension: size),
    );
    if (isStill) return disc;
    final period = AppDurations.ambient.inMicroseconds / 1e6;
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      child: disc,
      builder: (context, t, child) => Transform.scale(
        scale: 1 + _breath * (0.5 - 0.5 * math.cos(2 * math.pi * t / period)),
        child: child,
      ),
    );
  }
}

/// The clock the bars and the disc read: seconds since the header appeared.
/// It stops while the route is covered and while the app is not resumed, and
/// under reduced motion it never runs.
class _MessagesClock extends StatefulWidget {
  const _MessagesClock({required this.builder});

  final Widget Function(
    BuildContext context,
    ValueListenable<double> clock, {
    required bool isStill,
  })
  builder;

  @override
  State<_MessagesClock> createState() => _MessagesClockState();
}

class _MessagesClockState extends PaywallClockState<_MessagesClock> {
  final _clock = ValueNotifier<double>(0);

  /// Past the last bar's growth, so a still header shows them whole.
  @override
  double get restAt => 3;

  @override
  void onTick() => _clock.value = t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A header that holds still has no tick to say where it rests.
    _clock.value = t;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _clock, isStill: isStill);
}
