import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// One destination in the floating bar.
class AppTabItem {
  const AppTabItem({
    required this.label,
    required this.glyph,
    this.showFlag = false,
  });

  final String label;

  /// Shown instead of the label on a narrow display. The label still carries
  /// the accessibility name in every mode.
  final GlyphType glyph;

  /// A red dot on the tab. One dot, one meaning: a permission is missing and
  /// the app will not ring.
  final bool showFlag;
}

/// The floating pill bar: three destinations and one primary action, sitting
/// clear of the list so content can scroll all the way to the bottom edge.
class AppFloatingTabBar extends StatelessWidget {
  const AppFloatingTabBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onCompose,
    this.composeLabel,
    this.iconsOnly = false,
    super.key,
  });

  /// Bar height on its own, before any bottom inset.
  static const double height = 56;

  /// Gap between the bottom edge of the display and the bottom of the bar,
  /// on top of the view's own bottom inset.
  static const double edgeGap = 22;

  /// What a screen should leave free at the bottom of its scroll view so the
  /// last row clears the bar. Add the view's own bottom inset on top.
  static const double contentGap = height + 28;

  /// How tall the fade behind the bar is, so its top edge lands on the top of
  /// the bar and never above it. Add the view's own bottom inset on top.
  static const double fadeHeight = height + edgeGap;

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompose;
  final String? composeLabel;

  /// Draw glyphs instead of word labels. For a Galaxy Fold cover screen and
  /// anything else too narrow to spell out three tab names.
  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.fullAll,
        border: Border.all(color: colors.panelLine),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      // The bar floats over whichever screen is showing, so it carries its own
      // Material for the ink on each slot.
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              _TabSlot(
                item: items[i],
                isCurrent: i == currentIndex,
                iconsOnly: iconsOnly,
                onTap: () {
                  if (i == currentIndex) return;
                  AppHaptics.selection();
                  onSelect(i);
                },
              ),
            ],
            const SizedBox(width: 4),
            _ComposeSlot(label: composeLabel, onTap: onCompose),
          ],
        ),
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    required this.isCurrent,
    required this.onTap,
    this.iconsOnly = false,
  });

  final AppTabItem item;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = isCurrent ? colors.inkFixed : colors.onPanel;

    return Semantics(
      button: true,
      selected: isCurrent,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullAll,
        child: AnimatedContainer(
          duration: AppDurations.quick,
          curve: AppCurves.easeSpring,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 0 : 14),
          decoration: BoxDecoration(
            color: isCurrent ? colors.yellow : Colors.transparent,
            borderRadius: Radii.fullAll,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Center(
                child: iconsOnly
                    ? SizedBox(
                        width: 44,
                        child: Center(
                          child: AppGlyph(item.glyph, size: 20, color: fg),
                        ),
                      )
                    : Text(
                        item.label.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontFamilyFallback:
                              AppTypography.fontDisplayFallbacks,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.6,
                          height: 1.1,
                          color: fg,
                        ),
                      ),
              ),
              if (item.showFlag)
                Positioned(
                  top: 4,
                  right: iconsOnly ? 2 : -6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colors.high,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent ? colors.yellow : colors.panel,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeSlot extends StatelessWidget {
  const _ComposeSlot({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          AppHaptics.capture();
          onTap();
        },
        borderRadius: Radii.fullAll,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.highlight,
            borderRadius: Radii.fullAll,
          ),
          child: Center(
            child: AppGlyph(
              GlyphType.plus,
              size: 20,
              color: colors.onHighlight,
            ),
          ),
        ),
      ),
    );
  }
}
