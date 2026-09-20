import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/components/scroll_fade.dart';
import 'package:critalarm/design/faces/ghost_field.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:flutter/material.dart';

/// The standard Crit Alarm screen: one scroll view that runs from the very top
/// of the display to the very bottom of it.
///
/// Nothing is clamped inside the safe area. The top bar and any pinned bottom
/// actions float over the list, and the list passes behind them through a fade
/// so rows dissolve instead of being cut by a hard edge.
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    required this.slivers,
    this.topBar,
    this.bottomBar,
    this.onRefresh,
    this.onFaceRefresh,
    this.hasTabBar = true,
    this.detail,
    this.scrollController,
    this.physics,
    this.backgroundColor,
    this.withGhosts = true,
    this.withFades = true,
    this.ghostOpacity = 1,
    this.resizeForKeyboard = false,
    super.key,
  }) : assert(
         onRefresh == null || onFaceRefresh == null,
         'Pick one: the spinner (onRefresh) or the face (onFaceRefresh).',
       );

  /// The body. Plain slivers, no padding of their own at the edges.
  final List<Widget> slivers;

  /// Floats over the top of the list, on top of a fade.
  final Widget? topBar;

  /// Floats over the bottom of the list, on top of a fade. Use it for pinned
  /// actions on screens that have no tab bar.
  final Widget? bottomBar;

  final Future<void> Function()? onRefresh;

  /// Pull to refresh acted out by the face on the stage instead of a
  /// spinner. Return true when the refresh worked.
  final Future<bool> Function()? onFaceRefresh;

  /// True when the floating tab bar is on screen, so the list leaves room for
  /// it below the last row.
  final bool hasTabBar;

  /// The second pane, shown only on an expanded display. On anything smaller
  /// the screen opens the same content as its own page instead, so this is
  /// ignored rather than stacked below the list.
  final Widget? detail;

  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final Color? backgroundColor;
  final bool withGhosts;
  final bool withFades;

  /// Dials the background shapes down, for a screen whose text sits straight
  /// on top of them.
  final double ghostOpacity;

  /// True on a screen with text fields, so the body shrinks for the soft
  /// keyboard and the field being typed into stays in view. The Scaffold takes
  /// the keyboard height off the body on its own, so the scroll view needs no
  /// inset of its own on top of that.
  final bool resizeForKeyboard;

  /// Height of the top bar itself, before the status bar inset.
  static const double topBarHeight = 56;

  /// How wide the list pane gets when two panes are showing. It keeps a
  /// readable column without starving the detail beside it.
  static double listPaneWidth(double available) =>
      (available * 0.38).clamp(340.0, 460.0);

  /// Gap between the bottom of the [bottomBar] slot and whatever is under it.
  static const double bottomBarGap = 12;

  /// How far the [bottomBar] slot sits above the bottom edge of the display.
  ///
  /// The shell draws the floating tab bar over the same edge, so a screen that
  /// has one lifts the slot clear of it. On an expanded display the tab bar
  /// stands up as a rail on the left, so the slot stays where it is. A screen
  /// with no tab bar keeps the safe area and the gap it always had.
  static double bottomBarInset({
    required bool hasTabBar,
    required bool isExpanded,
    required double safeAreaBottom,
  }) {
    final lift = hasTabBar && !isExpanded ? AppFloatingTabBar.contentGap : 0.0;
    return safeAreaBottom + bottomBarGap + lift;
  }

  @override
  Widget build(BuildContext context) {
    // Width comes from the box this scaffold was given, not from the display,
    // so a screen nested inside a detail pane measures its own pane.
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.maxWidth),
    );
  }

  Widget _build(BuildContext context, double boxWidth) {
    final colors = context.appColors;
    final padding = MediaQuery.paddingOf(context);
    final inAmbient = AmbientScope.isInAmbientScope(context);
    final effectiveWithGhosts = !inAmbient && withGhosts;
    final effectiveWithFades = !inAmbient && withFades;
    final canvas =
        backgroundColor ?? (inAmbient ? Colors.transparent : colors.canvas);
    final size = AppSize.of(context);
    final twoPane = size.isExpanded && detail != null;

    // On an expanded display the tab bar stands up as a rail on the left, so
    // the screen keeps clear of it sideways instead of above the bottom edge.
    final railGap = size.isExpanded && hasTabBar ? AppNavRail.contentGap : 0.0;
    final available = boxWidth - railGap;

    // A long row is hard to read, the eye has to travel, so cap the column.
    // Two panes have already narrowed it, so they need no gutter of their own.
    final paneWidth = twoPane ? listPaneWidth(available) : available;
    final gutter = twoPane || paneWidth <= AppSize.contentMaxWidth
        ? 0.0
        : (paneWidth - AppSize.contentMaxWidth) / 2;

    final topInset = padding.top + (topBar == null ? 0 : topBarHeight);
    var bottomInset = padding.bottom + 16;
    if (hasTabBar && !size.isExpanded) {
      bottomInset += AppFloatingTabBar.contentGap;
    }

    Widget list = CustomScrollView(
      controller: scrollController,
      physics:
          physics ??
          const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: topInset)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
        SliverPadding(padding: EdgeInsets.only(top: bottomInset)),
      ],
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: topInset,
        color: colors.cobalt,
        backgroundColor: colors.surface,
        child: list,
      );
    }

    Widget body = Stack(
      children: [
        Positioned.fill(child: list),
        // The tab bar floats over every branch screen, so the fade behind it
        // lives here rather than in the shell: this side of the tree is inside
        // the screen's SeverityScope, so the wash follows the retint.
        // A screen with a pinned bottom slot draws its own, taller fade
        // below, so drawing this one too would wash the canvas twice.
        if (effectiveWithFades &&
            hasTabBar &&
            !size.isExpanded &&
            bottomBar == null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppScrollFade(
              edge: ScrollFadeEdge.bottom,
              height: padding.bottom + AppFloatingTabBar.fadeHeight,
              color: canvas,
            ),
          ),
        // The list runs under the top bar, so wash the canvas over the last
        // few pixels and let rows dissolve instead of meeting a hard edge.
        if (effectiveWithFades && topBar != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppScrollFade(
              edge: ScrollFadeEdge.top,
              height: padding.top + topBarHeight + 16,
              color: canvas,
            ),
          ),
        if (topBar != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: SizedBox(height: topBarHeight, child: topBar),
              ),
            ),
          ),
        if (bottomBar != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // The fade has to reach the top of the slot, so it grows by
                // whatever the slot was lifted to clear the tab bar.
                if (effectiveWithFades)
                  AppScrollFade(
                    edge: ScrollFadeEdge.bottom,
                    height:
                        padding.bottom +
                        116 +
                        (hasTabBar && !size.isExpanded
                            ? AppFloatingTabBar.contentGap
                            : 0.0),
                    color: canvas,
                  ),
                // The bottom padding carries the safe area itself, so the slot
                // can also be lifted over the floating tab bar in one number.
                // The sides still need the inset a notch takes in landscape,
                // the same one the top bar keeps.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12 + padding.left,
                    0,
                    12 + padding.right,
                    bottomBarInset(
                      hasTabBar: hasTabBar,
                      isExpanded: size.isExpanded,
                      safeAreaBottom: padding.bottom,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSize.contentMaxWidth,
                      ),
                      child: bottomBar,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    // Around the list and the top bar, so a spinner in the bar can follow the
    // refresh. The side pane stays outside: its face is not this refresh.
    if (onFaceRefresh != null) {
      body = RefreshFaceHost(onRefresh: onFaceRefresh!, child: body);
    }

    if (twoPane) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: paneWidth, child: body),
          Expanded(child: AppDetailPane(child: detail!)),
        ],
      );
    }

    if (railGap > 0) {
      body = Padding(
        padding: EdgeInsets.only(left: railGap),
        child: body,
      );
    }

    if (effectiveWithGhosts) {
      body = GhostField(opacity: ghostOpacity, child: body);
    }

    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: resizeForKeyboard,
      body: body,
    );
  }
}

/// The second pane on an expanded display. It is a raised surface that runs
/// to the bottom edge, so the list beside it keeps the canvas.
class AppDetailPane extends StatelessWidget {
  const AppDetailPane({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      margin: EdgeInsets.only(top: top + 14, left: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Radii.xl),
        ),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: child,
    );
  }
}
