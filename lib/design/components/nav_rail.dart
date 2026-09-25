import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The floating tab bar stood on its end, for a display on its side or wide
/// enough to run two panes. Same slots, same yellow selection, same red dot,
/// glyphs only. It sits down the left edge, or the right on an unfolded
/// iPhone Fold, so the content keeps the full height of the display.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onCompose,
    this.onSearch,
    this.composeLabel,
    this.searchLabel,
    this.wrapTab,
    this.wrapButton,
    super.key,
  });

  /// One round slot. Every tab and both buttons are this size.
  static const double slotSize = 48;

  /// The rail itself, before any inset: one slot plus the rail's padding.
  static const double width = slotSize + 12;

  /// How far in from the edge the rail floats, on top of the display's own
  /// safe area on that side.
  static const double edgeInset = 14;

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

  final AppNavSlotWrapper<int>? wrapTab;
  final AppNavSlotWrapper<AppNavButton>? wrapButton;

  Widget _wrapTab(int index, Widget child) =>
      wrapTab == null ? child : wrapTab!(index, child);

  Widget _wrapButton(AppNavButton button, Widget child) =>
      wrapButton == null ? child : wrapButton!(button, child);

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
              if (i > 0) const SizedBox(height: 4),
              _wrapTab(
                i,
                _RailSlot(
                  item: items[i],
                  isCurrent: i == currentIndex,
                  // Tapping the current tab still calls onSelect, so it pops
                  // back to that tab's first screen.
                  onTap: () {
                    AppHaptics.selection();
                    onSelect(i);
                  },
                ),
              ),
            ],
            const SizedBox(height: 6),
            if (onSearch != null) ...[
              _wrapButton(
                AppNavButton.search,
                _RailSearch(label: searchLabel, onTap: onSearch!),
              ),
              const SizedBox(height: 6),
            ],
            _wrapButton(
              AppNavButton.compose,
              _RailCompose(label: composeLabel, onTap: onCompose),
            ),
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

    // Glyph only. A label squeezed under the glyph in a 56 wide slot read as
    // clipped on iPad, and the rail is too narrow to spell a name out beside
    // it. The name still reaches VoiceOver and shows as a tooltip on a long
    // press or a pointer hover.
    return Tooltip(
      message: item.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: isCurrent,
        label: item.label,
        // The flag dot is colour only, so say it out loud.
        value: item.showFlag ? LocaleKeys.common_needs_attention.tr() : null,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: context.motion(AppDurations.quick),
            curve: AppCurves.easeSpring,
            width: AppNavRail.slotSize,
            height: AppNavRail.slotSize,
            decoration: BoxDecoration(
              color: isCurrent ? colors.yellow : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AppGlyph(item.glyph, size: 22, color: fg),
                if (item.showFlag)
                  Positioned(
                    top: 8,
                    right: 8,
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
        customBorder: const CircleBorder(),
        child: Container(
          width: AppNavRail.slotSize,
          height: AppNavRail.slotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
        customBorder: const CircleBorder(),
        child: Container(
          width: AppNavRail.slotSize,
          height: AppNavRail.slotSize,
          decoration: BoxDecoration(
            color: colors.highlight,
            shape: BoxShape.circle,
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
