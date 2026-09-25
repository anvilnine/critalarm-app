import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Priority levels corresponding to ntfy / Crit Alarm server specification.
enum PriorityLevel {
  min,
  low,
  defaultPriority,
  high,
  critical,
}

/// Priority chip with accurate glyph, weight and styling.
/// Critical chip is taller (30px), bordered, bolder so it reads in grayscale.
class AppPriorityChip extends StatelessWidget {
  const AppPriorityChip({
    required this.priority,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  const AppPriorityChip.critical({
    this.isSelected = false,
    this.onTap,
    super.key,
  }) : priority = PriorityLevel.critical;

  const AppPriorityChip.high({
    this.isSelected = false,
    this.onTap,
    super.key,
  }) : priority = PriorityLevel.high;

  const AppPriorityChip.defaultPriority({
    this.isSelected = false,
    this.onTap,
    super.key,
  }) : priority = PriorityLevel.defaultPriority;

  const AppPriorityChip.low({
    this.isSelected = false,
    this.onTap,
    super.key,
  }) : priority = PriorityLevel.low;

  const AppPriorityChip.min({
    this.isSelected = false,
    this.onTap,
    super.key,
  }) : priority = PriorityLevel.min;

  final PriorityLevel priority;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final isCrit = priority == PriorityLevel.critical;
    final height = isCrit ? 30.0 : 26.0;
    final hPadding = isCrit ? 12.0 : 10.0;
    final glyphSize = isCrit ? 14.0 : 12.0;

    final (label, glyph, bg, fg, border) = switch (priority) {
      PriorityLevel.min => (
        'min',
        GlyphType.down,
        Colors.transparent,
        colors.ink2,
        Border.all(color: colors.hairline, width: 1.5),
      ),
      PriorityLevel.low => (
        'low',
        GlyphType.minus,
        colors.ash,
        colors.ink2,
        Border.all(color: Colors.transparent, width: 1.5),
      ),
      PriorityLevel.defaultPriority => (
        'default',
        GlyphType.dot,
        colors.yellow,
        colors.inkFixed,
        Border.all(color: Colors.transparent, width: 1.5),
      ),
      PriorityLevel.high => (
        'high',
        GlyphType.up,
        colors.high,
        colors.inkFixed,
        Border.all(color: Colors.transparent, width: 1.5),
      ),
      PriorityLevel.critical => (
        'critical',
        GlyphType.bell,
        colors.crit,
        colors.inkFixed,
        Border.all(color: colors.inkFixed, width: 1.5),
      ),
    };

    final fontWeight = switch (priority) {
      PriorityLevel.min || PriorityLevel.low => FontWeight.w500,
      _ => FontWeight.w700,
    };

    final shadows = isSelected
        ? [
            BoxShadow(
              color: colors.surface,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: colors.ink,
              spreadRadius: 4,
            ),
          ]
        : null;

    final chip = Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.fullAll,
        border: border,
        boxShadow: shadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(
            glyph,
            size: glyphSize,
            color: fg,
            strokeWidth: isCrit ? 2.8 : 2.4,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: fontWeight,
                fontSize: 12,
                letterSpacing: 0.2,
                color: fg,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: chip,
        ),
      ),
    );
  }
}

/// Says how a topic is set up to arrive, for a row where nothing is ringing.
///
/// The priority chip reads the last page that came in, so it stays red long
/// after the alarm was acknowledged and fights the face above it. This one
/// carries no alarm colour at all: it is the resting state of the topic.
class AppDeliveryChip extends StatelessWidget {
  const AppDeliveryChip({
    required this.label,
    required this.rings,
    super.key,
  });

  final String label;

  /// True when critical delivery is on for this topic, so a page rings
  /// through the silent switch.
  final bool rings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = rings ? colors.ink : colors.ink2;

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: Radii.fullAll,
        border: Border.all(
          color: rings ? colors.ink : colors.hairline,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(
            rings ? GlyphType.bell : GlyphType.dot,
            size: 12,
            color: fg,
            strokeWidth: 2.4,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: rings ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.2,
                color: fg,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip used for topic names (e.g. `POST /alerts`).
class AppTopicChip extends StatelessWidget {
  const AppTopicChip({
    required this.text,
    this.onTap,
    super.key,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final chip = Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cobaltTint,
        borderRadius: Radii.fullAll,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: colors.ink,
          height: 1,
        ),
      ),
    );

    if (onTap == null) return chip;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: chip,
        ),
      ),
    );
  }
}

/// A small label in a pill, with nothing to tap. For a short fact next to a
/// value, like "Max" next to a clip length.
class AppPlainChip extends StatelessWidget {
  const AppPlainChip({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cobaltTint,
        borderRadius: Radii.fullAll,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: colors.ink,
          height: 1,
        ),
      ),
    );
  }
}
