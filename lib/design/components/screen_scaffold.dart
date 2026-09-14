import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/scroll_fade.dart';
import 'package:critalarm/design/faces/ghost_field.dart';
import 'package:critalarm/design/tokens/colors.dart';
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
    this.hasTabBar = true,
    this.scrollController,
    this.backgroundColor,
    this.withGhosts = true,
    super.key,
  });

  /// The body. Plain slivers, no padding of their own at the edges.
  final List<Widget> slivers;

  /// Floats over the top of the list, on top of a fade.
  final Widget? topBar;

  /// Floats over the bottom of the list, on top of a fade. Use it for pinned
  /// actions on screens that have no tab bar.
  final Widget? bottomBar;

  final Future<void> Function()? onRefresh;

  /// True when the floating tab bar is on screen, so the list leaves room for
  /// it below the last row.
  final bool hasTabBar;

  final ScrollController? scrollController;
  final Color? backgroundColor;
  final bool withGhosts;

  /// Height of the top bar itself, before the status bar inset.
  static const double topBarHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.paddingOf(context);
    final canvas = backgroundColor ?? colors.canvas;

    final topInset = padding.top + (topBar == null ? 0 : topBarHeight);
    var bottomInset = padding.bottom + 16;
    if (hasTabBar) bottomInset += AppFloatingTabBar.contentGap;

    Widget list = CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: topInset)),
        ...slivers,
        SliverPadding(padding: EdgeInsets.only(top: bottomInset)),
      ],
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: topInset,
        color: colors.onCanvas,
        backgroundColor: colors.panel,
        child: list,
      );
    }

    Widget body = Stack(
      children: [
        Positioned.fill(child: list),
        if (topBar != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                AppScrollFade(
                  edge: ScrollFadeEdge.top,
                  height: topInset + 28,
                  color: canvas,
                ),
                SafeArea(
                  bottom: false,
                  child: SizedBox(height: topBarHeight, child: topBar),
                ),
              ],
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
                AppScrollFade(
                  edge: ScrollFadeEdge.bottom,
                  height: padding.bottom + 116,
                  color: canvas,
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: bottomBar,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (withGhosts) body = GhostField(child: body);

    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: body,
    );
  }
}
