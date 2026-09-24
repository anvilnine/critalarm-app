import 'dart:math' as math;

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
import 'package:critalarm/design_system/widgets/progressive_blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The standard Crit Alarm screen: one scroll view that runs from the very top
/// of the display to the very bottom of it.
///
/// Nothing is clamped inside the safe area. The top bar and any pinned bottom
/// actions float over the list, and the list passes behind them through a fade
/// so rows dissolve instead of being cut by a hard edge.
class AppScreenScaffold extends StatefulWidget {
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
    this.withEdgeBlur = false,
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
  /// actions on screens that have no tab bar. The list leaves room for it, so
  /// the screen adds no bottom padding of its own.
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

  /// A soft blur on the list where it runs under the top bar and the tab
  /// bar. It sits under the bars, so they stay sharp.
  final bool withEdgeBlur;

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

  /// The gap under the pinned bottom bar, inside the safe area.
  static const double bottomBarGap = 12;

  /// How far the wash behind the pinned bar runs above the bar itself, so rows
  /// start dissolving before they reach the button. Short on purpose: any
  /// more and the strip reads as a second surface laid over the page rather
  /// than as the button's own backdrop.
  static const double _bottomBarFadeRun = 20;

  /// How wide the list pane gets when two panes are showing. It keeps a
  /// readable column without starving the detail beside it.
  static double listPaneWidth(double available) =>
      (available * 0.38).clamp(340.0, 460.0);

  @override
  State<AppScreenScaffold> createState() => _AppScreenScaffoldState();
}

class _AppScreenScaffoldState extends State<AppScreenScaffold> {
  /// How tall the pinned bottom bar came out, once it has laid out.
  ///
  /// The bar is whatever the screen handed over, so its height is not known
  /// before layout. The list leaves this much room under its last row, which
  /// is why it is measured rather than guessed at.
  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _bottomBarHeight.dispose();
    super.dispose();
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
    final effectiveWithGhosts = !inAmbient && widget.withGhosts;
    final effectiveWithFades = !inAmbient && widget.withFades;
    final canvas =
        widget.backgroundColor ??
        (inAmbient ? Colors.transparent : colors.canvas);
    final size = AppSize.of(context);
    final twoPane = size.isExpanded && widget.detail != null;

    // On an expanded display the tab bar stands up as a rail on the left, so
    // the screen keeps clear of it sideways instead of above the bottom edge.
    final railGap = size.isExpanded && widget.hasTabBar
        ? AppNavRail.contentGap
        : 0.0;
    final available = boxWidth - railGap;

    // A long row is hard to read, the eye has to travel, so cap the column.
    // Two panes have already narrowed it, so they need no gutter of their own.
    final paneWidth = twoPane
        ? AppScreenScaffold.listPaneWidth(available)
        : available;
    final gutter = twoPane || paneWidth <= AppSize.contentMaxWidth
        ? 0.0
        : (paneWidth - AppSize.contentMaxWidth) / 2;

    final topInset =
        padding.top +
        (widget.topBar == null ? 0 : AppScreenScaffold.topBarHeight);

    // The tab bar leaves room for itself, and so does a pinned bar.
    final tabBarRoom = widget.hasTabBar && !size.isExpanded
        ? AppFloatingTabBar.contentGap
        : 0.0;

    Widget buildBody(double barHeight) {
      final bottomBarRoom = widget.bottomBar == null
          ? 0.0
          : barHeight + AppScreenScaffold.bottomBarGap;
      // A screen with both sits the pinned bar on top of the tab bar rather
      // than behind it, so the content has to clear both of them.
      final bottomInset =
          padding.bottom +
          16 +
          (tabBarRoom > 0 && bottomBarRoom > 0
              ? tabBarRoom + bottomBarRoom
              : math.max(tabBarRoom, bottomBarRoom));

      Widget list = CustomScrollView(
        controller: widget.scrollController,
        physics:
            widget.physics ??
            const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: topInset)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: SliverMainAxisGroup(slivers: widget.slivers),
          ),
          SliverPadding(padding: EdgeInsets.only(top: bottomInset)),
        ],
      );

      if (widget.onRefresh != null) {
        list = RefreshIndicator(
          onRefresh: widget.onRefresh!,
          edgeOffset: topInset,
          color: colors.cobalt,
          backgroundColor: colors.surface,
          child: list,
        );
      }

      return Stack(
        children: [
          Positioned.fill(child: list),
          if (widget.withEdgeBlur) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: padding.top + AppScreenScaffold.topBarHeight + 16,
              child: ProgressiveBlurEdge(
                height: padding.top + AppScreenScaffold.topBarHeight + 16,
                isTop: true,
              ),
            ),
            // A pinned bottom bar brings its own blur (AppScrollScrim), so
            // skip this one there or the two stack.
            if (widget.bottomBar == null || !widget.withFades)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: padding.bottom + 60,
                child: ProgressiveBlurEdge(
                  height: padding.bottom + 60,
                  isTop: false,
                ),
              ),
          ],
          // The tab bar floats over every branch screen, so the fade behind it
          // lives here rather than in the shell: this side of the tree is
          // inside the screen's SeverityScope, so the wash follows the retint.
          if (effectiveWithFades && widget.hasTabBar && !size.isExpanded)
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
          if (effectiveWithFades && widget.topBar != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppScrollFade(
                edge: ScrollFadeEdge.top,
                height: padding.top + AppScreenScaffold.topBarHeight + 16,
                color: canvas,
              ),
            ),
          if (widget.topBar != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: SizedBox(
                    height: AppScreenScaffold.topBarHeight,
                    child: widget.topBar,
                  ),
                ),
              ),
            ),
          if (widget.bottomBar != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Gated on the screen's own flag, not on effectiveWithFades.
                  // A screen that draws an ambient canvas leaves this scaffold
                  // transparent, and that is exactly the screen where the
                  // button floats over a white card with nothing behind it.
                  if (widget.withFades)
                    AppScrollScrim(
                      height:
                          padding.bottom +
                          tabBarRoom +
                          barHeight +
                          AppScreenScaffold.bottomBarGap +
                          AppScreenScaffold._bottomBarFadeRun,
                      // The wash only reads when the canvas is what sits
                      // behind the bar. With the canvas transparent, tint with
                      // the page colour at part strength and let the blur do
                      // the rest.
                      tint: canvas.a == 0
                          ? colors.canvas.withValues(alpha: 0.55)
                          : canvas,
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      // On a screen with tabs the bar sits above the floating
                      // tab bar, not behind it.
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        AppScreenScaffold.bottomBarGap + tabBarRoom,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSize.contentMaxWidth,
                          ),
                          child: _MeasureHeight(
                            onHeight: (height) {
                              if (!mounted) return;
                              _bottomBarHeight.value = height;
                            },
                            child: widget.bottomBar!,
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

    var body = widget.bottomBar == null
        ? buildBody(0)
        : ValueListenableBuilder<double>(
            valueListenable: _bottomBarHeight,
            builder: (context, barHeight, _) => buildBody(barHeight),
          );

    // Around the list and the top bar, so a spinner in the bar can follow the
    // refresh. The side pane stays outside: its face is not this refresh.
    if (widget.onFaceRefresh != null) {
      body = RefreshFaceHost(onRefresh: widget.onFaceRefresh!, child: body);
    }

    if (twoPane) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: paneWidth, child: body),
          Expanded(child: AppDetailPane(child: widget.detail!)),
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
      body = GhostField(opacity: widget.ghostOpacity, child: body);
    }

    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: widget.resizeForKeyboard,
      body: body,
    );
  }
}

/// Hands over how tall its child came out, once per change.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required Widget super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderMeasureHeight createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.height) return;
    _reported = size.height;
    // Handing the number over mid-layout would rebuild the list while it is
    // laying out, so wait for the frame to finish.
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
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
