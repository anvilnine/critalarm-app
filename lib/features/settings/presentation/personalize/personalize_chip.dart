import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:flutter/material.dart';

/// One option in a strip on the Personalize page.
///
/// Every chip is the same height at every text size, so a strip never
/// changes height. At large text the label wraps to two lines. The picked
/// chip carries a tick and a solid outline, so it reads without colour.
class PersonalizeChip extends StatelessWidget {
  const PersonalizeChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isMarked = false,
    this.trailing,
    super.key,
  });

  /// The height of every chip.
  static const double height = 48;

  final String label;
  final VoidCallback onTap;

  /// The saved choice: a tick and a solid outline.
  final bool isSelected;

  /// A solid outline with no tick: the option being tried.
  final bool isMarked;

  /// A glyph after the label, for a chip that leaves the page.
  final GlyphType? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final isLarge = media.textScaler.scale(1) >= personalizeLargeText;
    final strong = isSelected || isMarked;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 64, maxWidth: 168),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.fullAll,
            border: Border.all(
              color: strong ? colors.ink : colors.hairline,
              width: strong ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                AppGlyph(GlyphType.check, color: colors.ink),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: MediaQuery(
                  // Two lines of this fit the chip up to here.
                  data: media.copyWith(
                    textScaler: media.textScaler.clamp(maxScaleFactor: 1.4),
                  ),
                  child: Text(
                    label,
                    maxLines: isLarge ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.small(
                      colors.ink,
                      fontSize: 13,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.15),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                AppGlyph(trailing!, size: 13, color: colors.ink3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of chips that scrolls sideways. Its height is fixed, with room
/// above the chips for a lock badge on a corner.
class PersonalizeStrip extends StatelessWidget {
  const PersonalizeStrip({required this.children, super.key});

  final List<Widget> children;

  /// Room above the chips, for a badge that hangs over a chip's corner.
  static const double badgeRoom = 10;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PersonalizeChip.height + badgeRoom + Spacing.s1,
      // A strip holds a handful of chips, so all of them are built: a
      // screen reader can reach the ones off the edge.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Spacing.s4,
          badgeRoom,
          Spacing.s4,
          Spacing.s1,
        ),
        child: Row(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(width: Spacing.s2),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
