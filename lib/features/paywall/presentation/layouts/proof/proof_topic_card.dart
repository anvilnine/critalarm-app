import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_replay.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_topics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The topic list the Proof layout replays the free cap on.
///
/// The rows that ring stand still. The rows past the cap are locked, one
/// is tapped and refused, the paid plan arrives, and the same tap works.
/// Every position comes from [ProofFrame], so a still clock draws the end
/// of the replay: every switch on.
class ProofTopicCard extends StatelessWidget {
  const ProofTopicCard({
    required this.topics,
    required this.clock,
    required this.height,
    required this.lockedLabel,
    super.key,
  });

  /// The rows, already shaped by `proofTopicsFor`.
  final List<ProofTopic> topics;
  final PaywallClock clock;

  /// The height the card takes. The header and the rows share it.
  final double height;

  /// The word on a locked row's chip: the plan that unlocks it.
  final String lockedLabel;

  static const double _padV = 6;
  static const double _maxHeader = 58;
  static const double _maxRow = 70;

  /// The header's share of the height, with a row as 1.
  static const double _headerShare = 1.05;

  /// The tallest the card gets with [rows] rows.
  static double maxHeightFor(int rows) =>
      _padV * 2 + _maxHeader + rows * _maxRow;

  /// The height the card takes with [rows] rows when it sets its own, at
  /// the text size [scale].
  static double naturalHeightFor(int rows, double scale) =>
      _padV * 2 + (48 + rows * 50) * scale;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unit = (height - _padV * 2) / (topics.length + _headerShare);
    final headerHeight = math.min(_maxHeader, unit * _headerShare);
    final rowHeight = math.min(_maxRow, unit);
    final cap = topics.where((t) => t.rings).length;
    final locked = topics.length - cap;

    return Semantics(
      container: true,
      image: true,
      label: LocaleKeys.paywall_proof_demo_aria.tr(),
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: _padV),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.lgAll,
          boxShadow: AppShadows.shadowMd(isDark: isDark),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      LocaleKeys.paywall_proof_card_title.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline(colors.ink, fontSize: 19),
                    ),
                  ),
                  PaywallClockBuilder(
                    clock: clock,
                    builder: (context, t, _) => _Count(
                      frame: ProofFrame.atClock(t, lockedRows: locked),
                      cap: cap,
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, topic) in topics.indexed)
              Container(
                height: rowHeight,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.hairline)),
                ),
                child: i < cap
                    ? _Row(name: topic.name, height: rowHeight)
                    : PaywallClockBuilder(
                        clock: clock,
                        builder: (context, t, _) => _Row(
                          name: topic.name,
                          height: rowHeight,
                          lockedLabel: lockedLabel,
                          lockedRow: i - cap,
                          frame: ProofFrame.atClock(t, lockedRows: locked),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The count in the header: full on the free plan, then no limit.
class _Count extends StatelessWidget {
  const _Count({required this.frame, required this.cap});

  final ProofFrame frame;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lifted = frame.lifted;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        if (lifted < 1)
          Opacity(
            opacity: 1 - lifted,
            child: Transform.scale(
              scale: frame.noteScale,
              alignment: Alignment.centerRight,
              child: _CountPill(
                value: LocaleKeys.paywall_proof_counter_used.tr(
                  namedArgs: {'used': '$cap', 'cap': '$cap'},
                ),
                background: colors.ink,
                foreground: colors.canvas,
              ),
            ),
          ),
        if (lifted > 0)
          Opacity(
            opacity: lifted,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - lifted)),
              child: _CountPill(
                value: LocaleKeys.paywall_proof_counter_no_limit.tr(),
                background: colors.highlight,
                foreground: colors.onHighlight,
              ),
            ),
          ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.value,
    required this.background,
    required this.foreground,
  });

  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.paywall_proof_counter_label.tr(),
            style: AppTypography.small(
              foreground,
              fontSize: 11,
            ).copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: AppTypography.monoBold(
              foreground,
              fontSize: 11.5,
            ).copyWith(height: 1),
          ),
        ],
      ),
    );
  }
}

/// One topic: its face, its name, how it arrives and its Critical switch.
/// With no [frame] it is a row that rings and stands still.
class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.height,
    this.frame,
    this.lockedRow = 0,
    this.lockedLabel = '',
  });

  final String name;
  final double height;
  final ProofFrame? frame;

  /// Which of the rows past the cap this is, from 0.
  final int lockedRow;
  final String lockedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final frame = this.frame;
    final faceSize = (height - 8).clamp(20.0, 40.0);
    final rings = frame == null ? 1.0 : frame.rings(lockedRow);
    final on = frame == null ? 1.0 : frame.switchOn(lockedRow);
    final lifted = frame == null ? 1.0 : frame.lifted;
    final tap = frame?.tap(lockedRow);
    final shake = lockedRow == 0 ? (frame?.shakeDx ?? 0.0) : 0.0;

    return Row(
      children: [
        SizedBox.square(
          dimension: faceSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (rings < 1)
                Opacity(
                  opacity: 1 - rings,
                  child: FaceWidget(state: FaceState.content, size: faceSize),
                ),
              if (rings > 0)
                Opacity(
                  opacity: rings,
                  child: FaceWidget(
                    // A row that has always rung is calm. One that was
                    // just let in is glad.
                    state: frame == null ? FaceState.calm : FaceState.happy,
                    size: faceSize,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoBold(
              colors.ink,
              fontSize: 14.5,
            ).copyWith(height: 1.1),
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            if (lifted < 1)
              Opacity(
                opacity: 1 - lifted,
                child: _LockedChip(label: lockedLabel),
              ),
            if (lifted > 0 && rings < 1)
              Opacity(
                opacity: lifted * (1 - rings),
                child: AppDeliveryChip(
                  label: LocaleKeys.home_delivery_normal.tr(),
                  rings: false,
                ),
              ),
            if (rings > 0)
              Opacity(
                opacity: rings,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * rings,
                  child: AppDeliveryChip(
                    label: LocaleKeys.home_delivery_rings.tr(),
                    rings: true,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        // Only the switch shakes. The row holds still.
        Transform.translate(
          offset: Offset(shake, 0),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _Switch(on: on),
              if (tap != null)
                Positioned.fill(
                  child: OverflowBox(
                    maxWidth: 80,
                    maxHeight: 80,
                    child: Opacity(
                      opacity: tap.opacity,
                      child: Transform.scale(
                        scale: tap.scale,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.ink.withValues(alpha: 0.2),
                            border: Border.all(
                              color: colors.ink.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The design system switch, drawn at any point between off and on so the
/// replay can stop it half way. Same size and colours as `AppSwitch`.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  /// 0 is off, 1 is on.
  final double on;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: Alignment(on * 2 - 1, 0),
      decoration: BoxDecoration(
        color: Color.lerp(colors.switchOff, colors.highlight, on),
        borderRadius: Radii.fullAll,
      ),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(colors.switchThumbOff, colors.onHighlight, on),
          boxShadow: AppShadows.lightSm,
        ),
      ),
    );
  }
}

/// The chip on a row the free plan will not let ring: a lock and the name
/// of the plan that does.
class _LockedChip extends StatelessWidget {
  const _LockedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(
            GlyphType.lock,
            size: 12,
            color: colors.canvas,
            strokeWidth: 2.4,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: AppTypography.monoBold(
              colors.canvas,
              fontSize: 12,
            ).copyWith(height: 1, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
