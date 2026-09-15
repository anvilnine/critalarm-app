import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The floating tab bar stood on its end, for a display wide enough to run
/// two panes. Same slots, same yellow selection, same red dot. It sits down
/// the left edge so the panes keep the full height of the display.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onCompose,
    this.onSearch,
    this.composeLabel,
    this.searchLabel,
    super.key,
  });

  /// The rail itself, before any inset.
  static const double width = 68;

  /// How far in from the left edge the rail floats.
  static const double edgeInset = 18;

  /// What a screen should leave free on its left so content clears the rail.
  static const double contentGap = width + edgeInset + 14;

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompose;

  /// Opens search, in the slot just above compose. Matches the tab bar, where
  /// search sits just left of it. Null leaves the slot out.
  final VoidCallback? onSearch;

  final String? composeLabel;
  final String? searchLabel;

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
      // The rail floats over whichever screen is showing, so it carries its
      // own Material for the ink on each slot.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              _RailSlot(
                item: items[i],
                isCurrent: i == currentIndex,
                onTap: () {
                  if (i == currentIndex) return;
                  AppHaptics.selection();
                  onSelect(i);
                },
              ),
            ],
            const SizedBox(height: 6),
            if (onSearch != null) ...[
              _RailSearch(label: searchLabel, onTap: onSearch!),
              const SizedBox(height: 6),
            ],
            _RailCompose(label: composeLabel, onTap: onCompose),
          ],
        ),
      ),
    );
  }
}

class _RailSlot extends StatelessWidget {
  const _RailSlot({
    required this.item,
    required this.isCurrent,
    required this.onTap,
  });

  final AppTabItem item;
  final bool isCurrent;
  final VoidCallback onTap;

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
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isCurrent ? colors.yellow : Colors.transparent,
            borderRadius: Radii.fullAll,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppGlyph(item.glyph, size: 20, color: fg),
                  const SizedBox(height: 3),
                  Text(
                    item.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: AppTypography.fontDisplay,
                      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 0.63,
                      height: 1,
                      color: fg,
                    ),
                  ),
                ],
              ),
              if (item.showFlag)
                Positioned(
                  top: 0,
                  right: 3,
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

/// Opens search. Outlined, so the filled compose slot stays the one obviously
/// primary action on the rail.
class _RailSearch extends StatelessWidget {
  const _RailSearch({required this.label, required this.onTap});

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
          AppHaptics.selection();
          onTap();
        },
        borderRadius: Radii.fullAll,
        child: Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: Radii.fullAll,
            border: Border.all(color: colors.panelLine, width: 1.5),
          ),
          child: Center(
            child: AppGlyph(
              GlyphType.search,
              size: 20,
              color: colors.onPanelMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailCompose extends StatelessWidget {
  const _RailCompose({required this.label, required this.onTap});

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
          width: 56,
          height: 48,
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
