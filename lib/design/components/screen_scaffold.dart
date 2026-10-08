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
import 'package:critalarm/design_system/bar_backing.dart';
import 'package:critalarm/design_system/widgets/progressive_blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

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
    this.withEdgeBlur = true,
    this.ghostOpacity = 1,
    this.resizeForKeyboard = false,
    this.barBacking,
    this.topBackingPlateau,
    this.bodyClearsBottomBar = false,
    this.contentSortKey,
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
  /// bar. It sits under the bars, so they stay sharp. On by default so every
  /// screen gets it; turn it off for a screen where it gets in the way.
  final bool withEdgeBlur;

  /// Dials the background shapes down, for a screen whose text sits straight
  /// on top of them.
  final double ghostOpacity;

  /// True on a screen with text fields, so the body shrinks for the soft
  /// keyboard and the field being typed into stays in view. The Scaffold takes
  /// the keyboard height off the body on its own, so the scroll view needs no
  /// inset of its own on top of that.
  final bool resizeForKeyboard;

  /// A solid colour behind the top bar and the pinned bottom bar, from the
  /// edge of the display to the inner edge of the bar, with a short soft
  /// edge where the list meets it. Nothing shows through.
  ///
  /// For a screen with a transparent background (it sits on an ambient
  /// canvas) whose body scrolls under a tall pinned block: the usual wash
  /// has no canvas colour to draw there, and half-seen rows between two
  /// pinned controls read as a fault. Pass the canvas colour.
  final Color? barBacking;

  /// How much of the zone behind the top bar holds full strength while a row
  /// is under it, 0 to 1, in place of the shared default.
  ///
  /// For a screen whose rows are text on a white sheet that scrolls under a
  /// title: the title then stays readable with no row showing through it.
  /// Only read where the backing comes from an [AppBarBackingScope].
  final double? topBackingPlateau;

  /// True when the body leaves the room for the pinned bottom bar itself, so
  /// the list adds none under its last row.
  ///
  /// For a body that fills the screen with a `SliverFillRemaining`. That
  /// sliver measures itself against the whole viewport, so it has to carry
  /// the bar's room on its own child, and the room the list would add after
  /// it comes on top: the page then scrolls by that much with nothing more
  /// to show. With this on, the page scrolls only once the body is taller
  /// than the screen.
  ///
  /// The body keeps the bar's height, the [bottomBarGap] under it, the home
  /// indicator and [bodyBarClearance] clear at its end.
  final bool bodyClearsBottomBar;

  /// Where the scrolling body sits in the screen reader order, against the
  /// sort keys the caller put on the controls in [bottomBar]. Null leaves
  /// the usual order: the body, then the pinned bar.
  ///
  /// For a screen whose pinned action has to be reached before its content,
  /// such as the ringing alarm. The body becomes one group with this key, so
  /// a bar control with a lower key is read first. Nothing moves on screen.
  final SemanticsSortKey? contentSortKey;

  /// How far the soft edge of [barBacking] runs past the bar.
  static const double _backingEdge = 16;

  /// The room the list leaves between its last row and the pinned bottom
  /// bar, once it is scrolled to its end.
  static const double listBarClearance = 16;

  /// The same room on a screen whose body leaves it itself. See
  /// [bodyClearsBottomBar].
  static const double bodyBarClearance = 12;

  /// How far a row runs under the pinned bar before a backing from an
  /// [AppBarBackingScope] is fully in. Shorter than the room above a
  /// button's label, so a label never has a sharp row showing through it.
  static const double _underBarRun = 8;

  /// How much of the top backing shows, 0 to 1, with the list scrolled by
  /// [pixels]. Nothing at rest: nothing is under the bar until the list has
  /// moved, and a block there would cut the background shapes for no reason.
  static double topBackingAmount(double pixels) =>
      (pixels / _backingEdge).clamp(0.0, 1.0);

  /// How much of the bottom backing shows, 0 to 1, on a screen that takes
  /// its backing from an [AppBarBackingScope].
  ///
  /// [extentAfter] is how far the list can still scroll and [clearance] is
  /// the room it leaves above the bar at its end, so the difference is how
  /// far a row runs under the bar right now. Nothing shows while every row
  /// is clear of the bar: a screen that fits looks the way it did without a
  /// backing.
  static double bottomBackingAmount({
    required double extentAfter,
    required double clearance,
  }) => ((extentAfter - clearance) / _underBarRun).clamp(0.0, 1.0);

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
  /// How far the list has gone under the top bar, 0 at rest to 1. Only
  /// read when the bars have a backing.
  final ValueNotifier<double> _scrolledUnderTop = ValueNotifier<double>(0);

  /// How far the list runs under the pinned bottom bar, 0 for clear of it
  /// to 1. Only read when the backing comes from an [AppBarBackingScope].
  final ValueNotifier<double> _underBottomBar = ValueNotifier<double>(0);

  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _isDisposed = true;
    _bottomBarHeight.dispose();
    _scrolledUnderTop.dispose();
    _underBottomBar.dispose();
    super.dispose();
  }

  bool _isDisposed = false;

  /// Moves [_scrolledUnderTop] and [_underBottomBar], which rebuild the
  /// backings.
  ///
  /// A scroll notification can be dispatched while the frame is being built
  /// or laid out: the list's extent changing (a bottom bar that just
  /// measured itself, a keyboard) corrects the scroll position mid-layout.
  /// Writing a notifier then asks for a rebuild during build, which Flutter
  /// refuses. So inside a frame the write waits for the frame to end.
  void _setBacking(ValueNotifier<double> backing, double value) {
    if (_isDisposed || backing.value == value) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final isInFrame =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!isInFrame) {
      backing.value = value;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) backing.value = value;
    });
  }

  /// Reads where the list is. Called when it scrolls and when its length or
  /// the room it has changes, which is how a list that never moves still
  /// says a row sits under the pinned bar.
  void _readScroll(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    _setBacking(
      _scrolledUnderTop,
      AppScreenScaffold.topBackingAmount(metrics.pixels),
    );
    _setBacking(
      _underBottomBar,
      AppScreenScaffold.bottomBackingAmount(
        extentAfter: metrics.extentAfter,
        clearance: widget.bodyClearsBottomBar
            ? AppScreenScaffold.bodyBarClearance
            : AppScreenScaffold.listBarClearance,
      ),
    );
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

    // A backing the screen asked for is always there under the pinned bar.
    // One from the scope around it shows only while a row is under a bar.
    // A screen that paints its own background is backed with that, since
    // the scope's canvas is not what shows behind it.
    final scope = AppBarBackingScope.maybeOf(context);
    final backing =
        widget.barBacking ??
        (scope == null ? null : (canvas.a == 0 ? scope.color : canvas));
    final backsBottomAlways = widget.barBacking != null;
    final topBarMaxTextScale = scope?.topBarMaxTextScale;
    // A backing from the scope is the blur with a fade of the canvas colour
    // over it. A backing the screen asked for itself stays solid.
    final backingConfig = widget.topBackingPlateau == null
        ? BarBackingConfig.defaults
        : BarBackingConfig.defaults.copyWith(
            top: BarBackingConfig.defaults.top.copyWith(
              plateau: widget.topBackingPlateau,
            ),
          );
    final isScoped = widget.barBacking == null && backing != null;

    // On its side, or wide enough for two panes, the tab bar stands up as a
    // rail down one edge, so the screen keeps clear of it sideways instead of
    // above the bottom edge. The display's own safe area on that side, the
    // notch on a phone turned sideways, comes on top.
    final hasRail = size.hasRail && widget.hasTabBar;
    final railOnRight = size.navPlacement == AppNavPlacement.right;
    final railGap = hasRail
        ? AppNavRail.contentGap + (railOnRight ? padding.right : padding.left)
        : 0.0;
    final available = boxWidth - railGap;

    // A long row is hard to read, the eye has to travel, so cap the column.
    // Two panes have already narrowed it, so they need no gutter of their own.
    // One column keeps the rail's clearance on both sides, so it sits in the
    // middle of the display rather than in the middle of what the rail leaves.
    final paneWidth = twoPane
        ? AppScreenScaffold.listPaneWidth(available)
        : boxWidth;
    final gutter = twoPane
        ? 0.0
        : math.max(railGap, (paneWidth - AppSize.contentMaxWidth) / 2);

    // What a pinned bottom bar keeps clear of on each side in one column.
    final sideClearance = twoPane ? 0.0 : railGap;

    final topInset =
        padding.top +
        (widget.topBar == null ? 0 : AppScreenScaffold.topBarHeight);

    // The tab bar leaves room for itself, and so does a pinned bar.
    final tabBarRoom = widget.hasTabBar && !size.hasRail
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

      // Never taller than the room the list leaves at its end, so the last
      // row is sharp once the list is scrolled all the way down.
      final edgeBlurBottom = math.min(padding.bottom + 60, bottomInset);

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
          if (!widget.bodyClearsBottomBar)
            SliverPadding(padding: EdgeInsets.only(top: bottomInset)),
        ],
      );

      if (widget.contentSortKey != null) {
        list = Semantics(
          container: true,
          sortKey: widget.contentSortKey,
          child: list,
        );
      }

      if (widget.onRefresh != null) {
        list = RefreshIndicator(
          onRefresh: widget.onRefresh!,
          edgeOffset: topInset,
          color: colors.cobalt,
          backgroundColor: colors.surface,
          child: list,
        );
      }

      // The backing from the scope behind whatever is pinned at the bottom,
      // [bar] tall from the edge of the display.
      Widget scopedBottomBacking(double bar) => ValueListenableBuilder<double>(
        valueListenable: _underBottomBar,
        builder: (context, amount, _) => Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (widget.withEdgeBlur)
              _BarBlur(
                style: backingConfig.bottom,
                amount: amount,
                bar: bar,
                isTop: false,
              ),
            _BarTint(
              style: backingConfig.bottom,
              color: backing!,
              amount: amount,
              bar: bar,
              isTop: false,
            ),
          ],
        ),
      );

      return Stack(
        children: [
          Positioned.fill(
            child: backing == null
                ? list
                : NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) {
                      if (notification.depth == 0) {
                        _readScroll(notification.metrics);
                      }
                      return false;
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0) {
                          _readScroll(notification.metrics);
                        }
                        return false;
                      },
                      child: list,
                    ),
                  ),
          ),
          if (widget.withEdgeBlur) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: isScoped && widget.topBar != null
                  // At rest this is the quiet edge blur every screen has.
                  // Once a row is under the bar the same blur reaches a
                  // little further and gets stronger at the screen edge.
                  ? ValueListenableBuilder<double>(
                      valueListenable: _scrolledUnderTop,
                      builder: (context, amount, _) => _BarBlur(
                        style: backingConfig.top,
                        amount: amount,
                        bar: topInset,
                        isTop: true,
                      ),
                    )
                  : SizedBox(
                      height: topInset + 16,
                      child: ProgressiveBlurEdge(
                        height: topInset + 16,
                        isTop: true,
                      ),
                    ),
            ),
            // Only where something is pinned at the bottom. With nothing
            // there the list runs sharp to the edge of the screen. A pinned
            // bar brings its own blur (AppScrollScrim), and so does a backing
            // from the scope, so skip this one there or the two stack.
            if (!isScoped &&
                (widget.bottomBar == null ? tabBarRoom > 0 : !widget.withFades))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: edgeBlurBottom,
                child: ProgressiveBlurEdge(
                  height: edgeBlurBottom,
                  isTop: false,
                ),
              ),
          ],
          // The tab bar on its own, with a row under it.
          if (isScoped && widget.bottomBar == null && tabBarRoom > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: scopedBottomBacking(padding.bottom + tabBarRoom),
            ),
          // The tab bar floats over every branch screen, so the fade behind it
          // lives here rather than in the shell: this side of the tree is
          // inside the screen's SeverityScope, so the wash follows the retint.
          if (effectiveWithFades && widget.hasTabBar && !size.hasRail)
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
          if (backing != null && widget.topBar != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Nothing is under the bar until the list has moved, and a
              // block there would cut the background shapes for no reason.
              child: ValueListenableBuilder<double>(
                valueListenable: _scrolledUnderTop,
                builder: (context, amount, _) => _BarTint(
                  // A screen's own backing is the solid band it asked for.
                  style: isScoped ? backingConfig.top : null,
                  color: backing,
                  amount: amount,
                  bar: topInset,
                  isTop: true,
                ),
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
                    // The bar has one fixed height, so past a point larger
                    // text is cut by it.
                    child: topBarMaxTextScale == null
                        ? widget.topBar
                        : MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: MediaQuery.textScalerOf(
                                context,
                              ).clamp(maxScaleFactor: topBarMaxTextScale),
                            ),
                            child: widget.topBar!,
                          ),
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
                  if (backsBottomAlways)
                    _BarBacking(
                      color: backing!,
                      solid:
                          padding.bottom +
                          tabBarRoom +
                          barHeight +
                          AppScreenScaffold.bottomBarGap,
                      isTop: false,
                    )
                  // Only while a row is under the bar: a screen that fits
                  // looks the way it did without a backing.
                  else if (isScoped)
                    scopedBottomBacking(
                      padding.bottom +
                          tabBarRoom +
                          barHeight +
                          AppScreenScaffold.bottomBarGap,
                    )
                  else if (widget.withFades)
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
                        math.max(12, sideClearance),
                        0,
                        math.max(12, sideClearance),
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

    if (twoPane && railGap > 0) {
      body = Padding(
        padding: railOnRight
            ? EdgeInsets.only(right: railGap)
            : EdgeInsets.only(left: railGap),
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

/// Tells the screens under it what colour they sit on, so each can back its
/// bars with it while a row is scrolled under them.
///
/// For screens that leave their own background clear and sit on a canvas
/// drawn behind them. Such a screen cannot tell what colour that canvas is,
/// and without one its rows show through the top bar's title and through
/// the pinned buttons. Put this where the canvas is drawn. A screen at rest
/// with every row clear of its bars looks the same with or without it.
///
/// A screen that passes [AppScreenScaffold.barBacking] keeps its own.
class AppBarBackingScope extends InheritedWidget {
  const AppBarBackingScope({
    required this.color,
    required super.child,
    this.topBarMaxTextScale,
    super.key,
  });

  /// The colour of the canvas behind the screens.
  final Color color;

  /// The most the system text size may grow what is in the top bar. Null
  /// leaves the top bar the full scale.
  final double? topBarMaxTextScale;

  static AppBarBackingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBarBackingScope>();

  @override
  bool updateShouldNotify(AppBarBackingScope oldWidget) =>
      color != oldWidget.color ||
      topBarMaxTextScale != oldWidget.topBarMaxTextScale;
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

/// The solid block behind a bar, with its soft inner edge. See
/// [AppScreenScaffold.barBacking].
class _BarBacking extends StatelessWidget {
  const _BarBacking({
    required this.color,
    required this.solid,
    required this.isTop,
  });

  final Color color;

  /// Height of the fully solid part, measured from the edge of the display.
  final double solid;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final edge = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
      child: const SizedBox(
        height: AppScreenScaffold._backingEdge,
        width: double.infinity,
      ),
    );
    final block = ColoredBox(
      color: color,
      child: SizedBox(height: solid, width: double.infinity),
    );
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: isTop ? [block, edge] : [edge, block],
      ),
    );
  }
}

/// The blur behind a bar that takes its backing from an
/// [AppBarBackingScope]: the progressive blur over the height of the [bar]
/// plus the fade length. It is nothing at the inner edge of that zone and
/// rises smoothly to the strength [style] says only at the edge of the
/// screen, with no flat part unless the style has a plateau.
///
/// [amount] is how far a row is under the bar, 0 to 1. With no row there
/// the top edge is the quiet blur every screen has, and it grows from that
/// into the configured one as the row goes under. The bottom draws nothing
/// at rest. A screen at rest is what it was.
class _BarBlur extends StatelessWidget {
  const _BarBlur({
    required this.style,
    required this.amount,
    required this.bar,
    required this.isTop,
  });

  final BarBackingStyle style;
  final double amount;

  /// Height of the bar, measured from the edge of the display.
  final double bar;
  final bool isTop;

  /// How far the quiet top blur runs past the bar.
  static const double _quietRun = 16;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0 || !style.mode.blurs) {
      if (!isTop) return const SizedBox.shrink();
      return SizedBox(
        height: bar + _quietRun,
        child: ProgressiveBlurEdge(height: bar + _quietRun, isTop: true),
      );
    }
    // The top starts from the quiet blur that is already there, so nothing
    // jumps on the first pixel of scroll. The bottom starts from nothing.
    final fromSigma = isTop ? ProgressiveBlurEdge.quietSigma : 0.0;
    final fromRun = isTop ? _quietRun : style.fadeLength;
    final height = bar + fromRun + (style.fadeLength - fromRun) * amount;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ProgressiveBlurEdge(
        height: height,
        isTop: isTop,
        maxSigma: fromSigma + (style.blurSigma - fromSigma) * amount,
        plateau: height * style.plateau * amount,
      ),
    );
  }
}

/// The colour over the blur behind a bar, for a mode that has one: a fade
/// of the canvas colour on the same ramp as the blur, or the solid band.
///
/// A null [style] is a screen's own backing, which is the solid band.
class _BarTint extends StatelessWidget {
  const _BarTint({
    required this.style,
    required this.color,
    required this.amount,
    required this.bar,
    required this.isTop,
  });

  final BarBackingStyle? style;
  final Color color;
  final double amount;
  final double bar;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    if (style == null || style.mode == BarBackingMode.solid) {
      return Opacity(
        opacity: amount,
        child: _BarBacking(color: color, solid: bar, isTop: isTop),
      );
    }
    final peak = style.gradientPeak * amount;
    if (!style.mode.fadesCanvas || peak <= 0) return const SizedBox.shrink();
    return _BarFade(
      color: color,
      peak: peak,
      height: bar + style.fadeLength,
      plateau: style.plateau,
      isTop: isTop,
    );
  }
}

/// The canvas colour over a zone [height] tall: clear at the inner edge and
/// rising smoothly across the whole zone to [peak] opacity at the edge of
/// the screen. See [barBackingRamp].
class _BarFade extends StatelessWidget {
  const _BarFade({
    required this.color,
    required this.peak,
    required this.height,
    required this.plateau,
    required this.isTop,
  });

  final Color color;
  final double peak;
  final double height;
  final double plateau;
  final bool isTop;

  /// Enough stops that the ramp reads as one curve, not as bands.
  static const int _steps = 24;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    // Stops run from the edge of the screen to the inner edge.
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= _steps; i++) {
      final fromScreenEdge = i / _steps;
      colors.add(
        color.withValues(
          alpha: peak * barBackingRamp(1 - fromScreenEdge, plateau: plateau),
        ),
      );
      stops.add(fromScreenEdge);
    }
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: colors,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}
