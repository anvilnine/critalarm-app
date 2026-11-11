import 'dart:async';

import 'package:critalarm/core/l10n/upper_for_locale.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/tap_target.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
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

/// The two buttons after the tabs, on both the bar and the rail.
enum AppNavButton { search, compose }

/// Lets the shell wrap one slot of the bar or the rail, such as to mark it for
/// the guide, without the bar knowing why.
typedef AppNavSlotWrapper<T> = Widget Function(T slot, Widget child);

/// The floating pill bar: three destinations and one primary action, sitting
/// clear of the list so content can scroll all the way to the bottom edge.
class AppFloatingTabBar extends StatelessWidget {
  const AppFloatingTabBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onCompose,
    this.onSearch,
    this.composeLabel,
    this.searchLabel,
    this.iconsOnly = false,
    this.isSearching = false,
    this.searchController,
    this.searchFocusNode,
    this.searchPlaceholder,
    this.onSearchChanged,
    this.onSearchClose,
    this.wrapTab,
    this.wrapButton,
    super.key,
  });

  /// Bar height on its own, before any bottom inset.
  static const double height = 56;

  /// Gap between the bottom edge of the display and the bottom of the bar,
  /// on top of the view's own bottom inset, where nothing system-drawn sits
  /// at the bottom: a Home button iPhone, an old Android, the desktop.
  static const double edgeGap = 22;

  /// How far the bar's bottom sits from the display edge on a phone with a
  /// home indicator or gesture handle. The bar overlaps the inset strip and
  /// stops just above the handle, the way the iOS 26 tab bar does. Holding it
  /// a full [edgeGap] above the inset left it floating mid-air.
  static const double handleClearance = 18;

  /// A bottom inset at or under this is a home indicator or a gesture handle,
  /// which the bar may overlap. A taller one is a row of system buttons
  /// (three-button Android navigation), which the bar must stay clear of.
  static const double handleInsetMax = 40;

  /// Room left between the top of the bar and the last row of a list.
  static const double rowClearance = 6;

  /// What a screen should leave free at the bottom of its scroll view so the
  /// last row clears the bar, with [edgeGap] under it. Add the view's own
  /// bottom inset on top. [contentGapFor] is the one that follows the inset.
  static const double contentGap = height + edgeGap + rowClearance;

  /// How tall the fade behind the bar is, with [edgeGap] under it, so its top
  /// edge lands on the top of the bar. Add the view's own bottom inset on top.
  static const double fadeHeight = height + edgeGap;

  /// [edgeGap] on a cover screen, where every row of height counts.
  static const double coverEdgeGap = 8;

  /// Distance from the bottom edge of the display to the bottom of the bar,
  /// with the view's bottom inset [safeBottom] already counted in.
  static double bottomFor(AppSize size, double safeBottom) {
    if (size.isCover) return safeBottom + coverEdgeGap;
    if (safeBottom <= 0) return edgeGap;
    if (safeBottom <= handleInsetMax) {
      return safeBottom - 16 > handleClearance
          ? safeBottom - 16
          : handleClearance;
    }
    return safeBottom + coverEdgeGap;
  }

  /// The gap under the bar on a display of [size] measured from the top of
  /// the inset [safeBottom]. Negative when the bar overlaps the inset strip.
  static double edgeGapFor(AppSize size, [double safeBottom = 0]) =>
      bottomFor(size, safeBottom) - safeBottom;

  /// [contentGap] on a display of [size] with bottom inset [safeBottom].
  /// Add [safeBottom] on top, as with [contentGap].
  static double contentGapFor(AppSize size, [double safeBottom = 0]) =>
      edgeGapFor(size, safeBottom) + height + rowClearance;

  /// [fadeHeight] on a display of [size] with bottom inset [safeBottom].
  /// Add [safeBottom] on top, as with [fadeHeight].
  static double fadeHeightFor(AppSize size, [double safeBottom = 0]) =>
      edgeGapFor(size, safeBottom) + height;

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompose;

  /// Opens search. Sits immediately left of the compose button, so the two
  /// things a user reaches for from anywhere are next to each other. Null
  /// leaves the slot out entirely.
  final VoidCallback? onSearch;

  final String? composeLabel;
  final String? searchLabel;

  /// Draw glyphs instead of word labels. For a Galaxy Fold cover screen, a
  /// Razr cover, the start pane of a book-posture fold, and anything else too
  /// narrow to spell out three tab names.
  final bool iconsOnly;

  /// Turns the bar into the search field. The pill itself does not move or
  /// change shape: only what is inside it swaps, so searching reads as the bar
  /// opening up rather than a new screen arriving.
  final bool isSearching;

  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final String? searchPlaceholder;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClose;

  final AppNavSlotWrapper<int>? wrapTab;
  final AppNavSlotWrapper<AppNavButton>? wrapButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Each slot is a 48 box around a 44 pill, so the bar gives up 2 of its
    // padding on the sides the boxes reach, and 2 above and below. The
    // pills, and the bar, stay where they were.
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.tabBar,
        borderRadius: Radii.fullAll,
        border: Border.all(color: colors.tabBarLine),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      // The bar floats over whichever screen is showing, so it carries its own
      // Material for the ink on each slot.
      child: Material(
        type: MaterialType.transparency,
        child: isSearching
            ? _SearchRow(
                controller: searchController,
                focusNode: searchFocusNode,
                placeholder: searchPlaceholder,
                onChanged: onSearchChanged,
                onClose: onSearchClose,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabRow(
                    items: items,
                    currentIndex: currentIndex,
                    iconsOnly: iconsOnly,
                    wrapTab: wrapTab,
                    // Tapping the tab already showing still calls onSelect:
                    // that is how the user gets back to its first screen.
                    onTap: (i) {
                      AppHaptics.selection();
                      onSelect(i);
                    },
                  ),
                  const SizedBox(width: 2),
                  if (onSearch != null) ...[
                    _wrap(
                      wrapButton,
                      AppNavButton.search,
                      _SearchSlot(label: searchLabel, onTap: onSearch!),
                    ),
                    // The 48 boxes of the two buttons touch.
                  ],
                  _wrap(
                    wrapButton,
                    AppNavButton.compose,
                    _ComposeSlot(label: composeLabel, onTap: onCompose),
                  ),
                ],
              ),
      ),
    );
  }
}

Widget _wrap<T>(AppNavSlotWrapper<T>? wrapper, T slot, Widget child) =>
    wrapper == null ? child : wrapper(slot, child);

/// What the pill holds while searching: the same 44px slots, with the field
/// stretched across the middle where the tabs were.
class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: AppGlyph(
              GlyphType.search,
              size: 20,
              color: colors.onPanelMuted,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            // Focus is asked for by the shell once the bar has swapped, not
            // with autofocus: the field is built in the middle of the same
            // frame the bar changes shape in, and autofocus does not land.
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            cursorColor: colors.highlight,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontFamilyFallback: AppTypography.fontBodyFallbacks,
              fontSize: 15,
              color: colors.onPanel,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: placeholder,
              hintStyle: TextStyle(
                fontFamily: AppTypography.fontBody,
                fontFamilyFallback: AppTypography.fontBodyFallbacks,
                fontSize: 15,
                color: colors.onPanelMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        _CloseSlot(onTap: onClose),
      ],
    );
  }
}

/// Leaves search and puts the tabs back.
class _CloseSlot extends StatelessWidget {
  const _CloseSlot({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: LocaleKeys.common_close.tr(),
      excludeSemantics: true,
      child: AppTapTarget(
        onTap: () {
          AppHaptics.selection();
          onTap?.call();
        },
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            onTap?.call();
          },
          borderRadius: Radii.fullAll,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AppGlyph(
                GlyphType.close,
                size: 18,
                color: colors.onPanelMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tabs, with one yellow pill that slides from the old tab to the new
/// one. It is one shape that moves, so a change of tab reads as the pill
/// travelling rather than one pill going out and another coming in.
///
/// Two copies of the tabs are drawn. The one underneath is the real one:
/// light labels, the tap targets, the semantics. The one on top is yellow
/// with dark, heavier labels, and it is clipped to the pill. So wherever the
/// pill is, the label under it turns dark and bold, pixel for pixel, in step
/// with the move.
///
/// Taps, deep links and the back button all arrive here as a new
/// [currentIndex], so they all slide the same way. Under reduce motion the
/// pill jumps.
class _TabRow extends StatefulWidget {
  const _TabRow({
    required this.items,
    required this.currentIndex,
    required this.iconsOnly,
    required this.onTap,
    required this.wrapTab,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final bool iconsOnly;
  final ValueChanged<int> onTap;
  final AppNavSlotWrapper<int>? wrapTab;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> with SingleTickerProviderStateMixin {
  // Starts finished, so the first frame is the resting picture.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _move = CurvedAnimation(
    parent: _controller,
    curve: AppCurves.easeOut,
  );

  final GlobalKey _clipKey = GlobalKey();
  late List<GlobalKey> _pillKeys = _keysFor(widget.items.length);

  // Where the pill was when the current move began. A change in the middle
  // of a move starts from wherever the pill had got to, so it never snaps.
  Rect? _fromRect;
  Rect? _lastRect;

  static List<GlobalKey> _keysFor(int n) => [
    for (var i = 0; i < n; i++) GlobalKey(),
  ];

  @override
  void didUpdateWidget(_TabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _pillKeys = _keysFor(widget.items.length);
      _fromRect = null;
      _controller.value = 1;
      return;
    }
    if (widget.currentIndex == oldWidget.currentIndex) return;

    _fromRect = _lastRect;
    final duration = context.motion(AppDurations.base);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.duration = duration;
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where the pill is this frame, in the clip layer's coordinates. Called
  /// while painting, after the tabs have been laid out. Null before the
  /// first layout.
  Rect? _pillRect() {
    final index = widget.currentIndex;
    if (index < 0 || index >= _pillKeys.length) return null;
    final clipBox = _clipKey.currentContext?.findRenderObject();
    final pillBox = _pillKeys[index].currentContext?.findRenderObject();
    if (clipBox is! RenderBox || pillBox is! RenderBox) return null;
    if (!clipBox.hasSize || !pillBox.hasSize || !pillBox.attached) {
      return null;
    }
    final to = MatrixUtils.transformRect(
      pillBox.getTransformTo(clipBox),
      Offset.zero & pillBox.size,
    );
    final rect = Rect.lerp(_fromRect ?? to, to, _move.value);
    _lastRect = rect;
    return rect;
  }

  Widget _row({required bool ink}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < widget.items.length; i++) ...[
        if (i > 0) const SizedBox(width: 2),
        if (ink)
          _TabSlot(
            item: widget.items[i],
            iconsOnly: widget.iconsOnly,
            ink: true,
          )
        else
          _wrap(
            widget.wrapTab,
            i,
            _TabSlot(
              pillKey: _pillKeys[i],
              item: widget.items[i],
              isCurrent: i == widget.currentIndex,
              iconsOnly: widget.iconsOnly,
              onTap: () => widget.onTap(i),
            ),
          ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      children: [
        _row(ink: false),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ClipPath(
                key: _clipKey,
                clipper: _PillClipper(reclip: _move, rect: _pillRect),
                child: ColoredBox(
                  color: colors.yellow,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _row(ink: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillClipper extends CustomClipper<Path> {
  _PillClipper({required Listenable reclip, required this.rect})
    : super(reclip: reclip);

  final Rect? Function() rect;

  @override
  Path getClip(Size size) {
    final r = rect();
    if (r == null) return Path();
    return Path()..addRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2)),
    );
  }

  // The tabs can change width without this box changing size (a new
  // language, a new label), so always clip again after a rebuild.
  @override
  bool shouldReclip(_PillClipper oldClipper) => true;
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    this.pillKey,
    this.isCurrent = false,
    this.onTap,
    this.iconsOnly = false,
    this.ink = false,
  });

  /// Marks the box the yellow pill fills when this tab is current.
  final GlobalKey? pillKey;
  final AppTabItem item;
  final bool isCurrent;
  final VoidCallback? onTap;
  final bool iconsOnly;

  /// The copy drawn on the pill: dark, heavier labels, no taps, no semantics.
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = ink ? colors.inkFixed : colors.onPanel;

    TextStyle labelStyle(FontWeight weight, Color color) => TextStyle(
      fontFamily: AppTypography.fontDisplay,
      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
      fontWeight: weight,
      fontSize: 12,
      letterSpacing: 0.6,
      height: 1.1,
      color: color,
    );

    final label = upperInContext(item.label, context);

    final pill = Container(
      key: pillKey,
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 0 : 14),
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
                // The label on the pill is the heavier cut. In Bricolage
                // the heavier cut is also narrower, so the slot holds an
                // invisible copy of the other cut and is always as wide as
                // the wider of the two. The copies line up and the tabs
                // never shift when the pill arrives.
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: labelStyle(
                          ink ? FontWeight.w700 : FontWeight.w800,
                          const Color(0x00000000),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        style: labelStyle(
                          ink ? FontWeight.w800 : FontWeight.w700,
                          fg,
                        ),
                      ),
                    ],
                  ),
          ),
          // Drawn in both copies. Its ring takes the colour of what is
          // under it, the bar or the pill, so the dot looks cut into both.
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
                    color: ink ? colors.yellow : colors.panel,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // The same 48 box as the real slot, so the copies line up.
    if (ink) return AppTapTarget(minWidth: 0, child: pill);

    return Semantics(
      button: true,
      selected: isCurrent,
      label: item.label,
      // The flag dot is colour only, so say it out loud.
      value: item.showFlag ? LocaleKeys.common_needs_attention.tr() : null,
      excludeSemantics: true,
      child: AppTapTarget(
        onTap: onTap,
        minWidth: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.fullAll,
          child: pill,
        ),
      ),
    );
  }
}

/// Opens search. Outlined rather than filled, so the filled compose button
/// stays the one obviously primary action on the bar.
class _SearchSlot extends StatelessWidget {
  const _SearchSlot({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    void tap() {
      AppHaptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      label: label,
      child: AppTapTarget(
        onTap: tap,
        child: InkWell(
          onTap: tap,
          borderRadius: Radii.fullAll,
          child: Container(
            width: 44,
            height: 44,
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

    void tap() {
      AppHaptics.capture();
      onTap();
    }

    return Semantics(
      button: true,
      label: label,
      child: AppTapTarget(
        onTap: tap,
        child: InkWell(
          onTap: tap,
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
      ),
    );
  }
}
