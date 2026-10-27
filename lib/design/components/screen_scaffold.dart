import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_scope.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/nav_rail.dart';
import 'package:critalarm/design/components/scroll_fade.dart';
import 'package:critalarm/design/faces/ghost_field.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/fold.dart';
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
    this.foldStage,
    this.scrollController,
    this.physics,
    this.backgroundColor,
    this.withGhosts = true,
    this.withFades = true,
    this.withEdgeBlur = true,
    this.ghostOpacity = 1,
    this.resizeForKeyboard = false,
    this.barBacking,
    this.bodyClearsBottomBar = false,
    this.contentSortKey,
    this.contentMaxWidth = AppSize.contentMaxWidth,
    super.key,
  }) : assert(
         onRefresh == null || onFaceRefresh == null,
         'Pick one: the spinner (onRefresh) or the face (onFaceRefresh).',
       );

  /// How wide the body and the top bar get on a wide display. One column
  /// of rows keeps the default. A page that lays two columns side by side
  /// asks for more, so neither column is narrower than a phone.
  final double contentMaxWidth;

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

  /// The second pane, shown where [showsDetail] says so: on an expanded
  /// display (inside the frame, its content capped at
  /// [AppSize.detailMaxWidth] and centred), and in book posture at any width
  /// (list in the start pane, detail in the end pane). On anything else the
  /// screen opens the same content as its own page instead, so this is
  /// ignored rather than stacked below the list. Tabletop shows no detail: a
  /// half that short is too short for list beside detail.
  final Widget? detail;

  /// The part of the screen that holds still beside or above a fold, such as
  /// the hero face and its panel. Drawn only on a folding display:
  ///
  /// - Tabletop: this fills the top half and the slivers scroll in the bottom
  ///   half, with the rail or tab bar.
  /// - Book, when there is no [detail]: this fills the start pane, with the
  ///   tab bar floating over its foot, and the slivers scroll in the end pane.
  ///
  /// The [topBar] goes with the stage: it draws along the top of the stage's
  /// pane (the top half, or the start pane), above the stage, so the title
  /// sits over the hero it names and never under the fold. The list in the
  /// other pane then has no top bar of its own.
  ///
  /// With no fold it is not drawn, so the screen keeps the same content in its
  /// slivers and leaves it out of them when `AppFold.of(context)` is not none.
  ///
  /// With [onFaceRefresh], the stage, its top bar and the list share one pull
  /// to refresh: a face the stage draws with `stageFace` acts out the pull of
  /// the list in the other pane, and a `RefreshActivityIndicator` in the top
  /// bar shows the refresh running. The stage has to call `stageFace` with a
  /// context from inside the stage (its own build method or a `Builder`).
  final Widget? foldStage;

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

  /// How tall the backing at the top is, from the edge of the display, or
  /// null when nothing there is backed. A screen with a top bar backs that
  /// bar. One without backs the bar its host draws over it, [barOverTop]
  /// tall below the status bar, and none when the host draws none.
  static double? backedTopHeight({
    required bool hasTopBar,
    required double safeTop,
    double? barOverTop,
  }) {
    if (hasTopBar) return safeTop + topBarHeight;
    if (barOverTop == null || barOverTop <= 0) return null;
    return safeTop + barOverTop;
  }

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

  /// True when a screen with a [detail] shows it beside the list on a display
  /// of [size] with [fold]: book posture at any width, or an expanded display
  /// that is not in tabletop posture. Where this is false a tap on a row
  /// opens the full screen instead.
  static bool showsDetailFor(AppSize size, AppFold fold) =>
      fold.isBook || (size.isExpanded && !fold.isTabletop);

  /// [showsDetailFor] the display [context] is drawn on.
  static bool showsDetail(BuildContext context) =>
      showsDetailFor(AppSize.of(context), AppFold.of(context));

  @override
  State<AppScreenScaffold> createState() => _AppScreenScaffoldState();
}

class _AppScreenScaffoldState extends State<AppScreenScaffold> {
  /// The list and the detail keep their state (scroll position, a selected
  /// row, a half-typed field) when the hinge opens or closes and the tree
  /// around them changes shape.
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _detailKey = GlobalKey();

  /// The scroll view and what floats over it. On an expanded window the list
  /// sits inside a frame with the detail beside it, and in a fold pane it
  /// does not, so this key moves it from one shape to the other without
  /// losing the scroll position.
  final GlobalKey _bodyKey = GlobalKey();

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
    final fold = AppFold.of(context);
    final stage = widget.foldStage;
    final detail = widget.detail;

    // The list as the scaffold lays it out in the box it is given. Width
    // comes from that box, not from the display, so a screen nested inside a
    // detail pane measures its own pane.
    Widget list({
      required Widget? detail,
      required bool hasTabBar,
      bool showTopBar = true,
      bool hostsFaceRefresh = true,
    }) => KeyedSubtree(
      key: _listKey,
      child: LayoutBuilder(
        builder: (context, constraints) => _buildContent(
          context,
          constraints.maxWidth,
          detail: detail == null
              ? null
              : KeyedSubtree(key: _detailKey, child: detail),
          hasTabBar: hasTabBar,
          showTopBar: showTopBar,
          hostsFaceRefresh: hostsFaceRefresh,
        ),
      ),
    );

    if (fold.isNone ||
        (fold.isTabletop && stage == null) ||
        (fold.isBook && stage == null && detail == null)) {
      return _wrap(
        context,
        list(
          // A tabletop half is too short for list beside detail.
          detail: fold.isTabletop ? null : detail,
          hasTabBar: widget.hasTabBar,
        ),
      );
    }

    // Split at the fold. Each pane gets its own MediaQuery, so the list in
    // it lays out as the phone layout of that pane.
    final window = MediaQuery.of(context);
    final panes = fold.panes(
      window.size,
      direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
    final Widget first;
    final Widget second;
    final bool hasStagePane;
    if (fold.isBook && detail != null) {
      hasStagePane = false;
      // List in the start pane, under the tab bar. Detail in the end pane.
      first = list(detail: null, hasTabBar: widget.hasTabBar);
      second = AppDetailPane(
        child: KeyedSubtree(key: _detailKey, child: detail),
      );
    } else {
      // The stage holds still in the start pane or the top half, under the
      // top bar it names. The list scrolls in the other one, and only the
      // bottom half has the bar.
      hasStagePane = true;
      first = _StagePane(
        topBar: widget.topBar,
        topBarMaxTextScale: AppBarBackingScope.maybeOf(
          context,
        )?.topBarMaxTextScale,
        contentMaxWidth: widget.contentMaxWidth,
        child: stage!,
      );
      second = list(
        detail: null,
        hasTabBar: widget.hasTabBar && fold.isTabletop,
        showTopBar: false,
        hostsFaceRefresh: false,
      );
    }
    Widget split = Stack(
      children: [
        AppFoldPane(rect: panes.first, window: window, child: first),
        AppFoldPane(rect: panes.second, window: window, child: second),
      ],
    );
    // With a stage the top bar and the stage face are in the other pane from
    // the list, so the refresh host goes around both panes. The list's scroll
    // notifications reach it at depth 0: a fold pane adds no viewport.
    final onFaceRefresh = widget.onFaceRefresh;
    if (hasStagePane && onFaceRefresh != null) {
      split = RefreshFaceHost(onRefresh: onFaceRefresh, child: split);
    }
    return _wrap(context, split);
  }

  /// The ghosts behind [body] and the Scaffold around it, for the whole
  /// window.
  Widget _wrap(BuildContext context, Widget body) {
    final inAmbient = AmbientScope.isInAmbientScope(context);
    final canvas =
        widget.backgroundColor ??
        (inAmbient ? Colors.transparent : context.appColors.canvas);
    var wrapped = body;
    if (!inAmbient && widget.withGhosts) {
      wrapped = GhostField(opacity: widget.ghostOpacity, child: wrapped);
    }
    return Scaffold(
      backgroundColor: canvas,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: widget.resizeForKeyboard,
      body: wrapped,
    );
  }

  Widget _buildContent(
    BuildContext context,
    double boxWidth, {
    required Widget? detail,
    required bool hasTabBar,
    required bool showTopBar,
    required bool hostsFaceRefresh,
  }) {
    // In a fold split the stage pane draws the top bar, so the list does not.
    final topBar = showTopBar ? widget.topBar : null;
    final colors = context.appColors;
    final padding = MediaQuery.paddingOf(context);
    final inAmbient = AmbientScope.isInAmbientScope(context);
    final effectiveWithFades = !inAmbient && widget.withFades;
    final canvas =
        widget.backgroundColor ??
        (inAmbient ? Colors.transparent : colors.canvas);
    final size = AppSize.of(context);
    // Inside a fold pane this is no fold. On the window it is the one the
    // shell reads, so both agree on where the bar is.
    final fold = AppFold.of(context);
    final hasRail = navPlacementFor(size, fold) != AppNavPlacement.bottom;
    final columns = AppScreenColumns.resolve(
      boxWidth: boxWidth,
      size: size,
      padding: padding,
      fold: fold,
      hasTabBar: hasTabBar,
      hasDetail: detail != null,
      contentMaxWidth: widget.contentMaxWidth,
    );
    final twoPane = columns.twoPane;

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
    const backingConfig = BarBackingConfig.defaults;
    final isScoped = widget.barBacking == null && backing != null;

    final paneWidth = columns.listWidth;
    final gutter = columns.gutter;

    // What a pinned bottom bar keeps clear of on each side in one column.
    final sideClearance = twoPane ? 0.0 : columns.railClearance;

    final topInset =
        padding.top + (topBar == null ? 0 : AppScreenScaffold.topBarHeight);

    // A screen with no top bar of its own can sit under a bar the host draws
    // over it. The list keeps its own top padding, and the backing covers
    // the bar's height like a top bar's.
    final backedTopOrNull = AppScreenScaffold.backedTopHeight(
      hasTopBar: topBar != null,
      safeTop: padding.top,
      barOverTop: isScoped ? scope?.barOverTop : null,
    );
    final hasTopBacking = backedTopOrNull != null;
    final backedTop = backedTopOrNull ?? topInset;

    // The tab bar leaves room for itself, and so does a pinned bar.
    final tabBarRoom = hasTabBar && !hasRail
        ? AppFloatingTabBar.contentGapFor(size)
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
              child: isScoped && hasTopBacking
                  // At rest this is the quiet edge blur every screen has.
                  // Once a row is under the bar the same blur reaches a
                  // little further and gets stronger at the screen edge.
                  ? ValueListenableBuilder<double>(
                      valueListenable: _scrolledUnderTop,
                      builder: (context, amount, _) =>
                          topBar == null && amount <= 0
                          // The bar is the host's, so at rest the screen
                          // keeps the edge it always had.
                          ? SizedBox(
                              height: topInset + 16,
                              child: ProgressiveBlurEdge(
                                height: topInset + 16,
                                isTop: true,
                              ),
                            )
                          : _BarBlur(
                              style: backingConfig.top,
                              amount: amount,
                              bar: backedTop,
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
          if (effectiveWithFades && hasTabBar && !hasRail)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppScrollFade(
                edge: ScrollFadeEdge.bottom,
                height: padding.bottom + AppFloatingTabBar.fadeHeightFor(size),
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
                height: padding.top + AppScreenScaffold.topBarHeight + 16,
                color: canvas,
              ),
            ),
          if (backing != null && hasTopBacking)
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
                  bar: backedTop,
                  isTop: true,
                ),
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
                  child: SizedBox(
                    // 2 taller than the bar's 56 so a 48 tap box can sit
                    // centred on the line the bar's content is centred on (34
                    // from the top). The bar is drawn over the screen, and
                    // nothing measures this box.
                    height: AppScreenScaffold.topBarHeight + 2,
                    // The bar has one fixed height, so past a point larger
                    // text is cut by it.
                    child: topBarMaxTextScale == null
                        ? topBar
                        : MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: MediaQuery.textScalerOf(
                                context,
                              ).clamp(maxScaleFactor: topBarMaxTextScale),
                            ),
                            child: topBar,
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
                          constraints: BoxConstraints(
                            // A pinned action stays one thumb's reach wide on
                            // a tablet or a desktop window.
                            maxWidth: size.isCompact
                                ? AppSize.contentMaxWidth
                                : AppSize.actionMaxWidth,
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

    Widget body = KeyedSubtree(
      key: _bodyKey,
      child: widget.bottomBar == null
          ? buildBody(0)
          : ValueListenableBuilder<double>(
              valueListenable: _bottomBarHeight,
              builder: (context, barHeight, _) => buildBody(barHeight),
            ),
    );

    // Around the list and the top bar, so a spinner in the bar can follow the
    // refresh. The detail pane stays outside: its face is not this refresh.
    // In a split with a stage the host is around both panes instead.
    final onFaceRefresh = widget.onFaceRefresh;
    if (onFaceRefresh != null && hostsFaceRefresh) {
      body = RefreshFaceHost(onRefresh: onFaceRefresh, child: body);
    }

    if (twoPane) {
      // The rail and both panes sit inside the frame, and past
      // AppSize.frameMaxWidth the canvas shows on both sides.
      body = Padding(
        padding: EdgeInsets.only(
          left: columns.listLeft,
          right: boxWidth - columns.detailLeft - columns.detailWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: paneWidth, child: body),
            Expanded(child: AppDetailPane(child: detail!)),
          ],
        ),
      );
    }

    return body;
  }
}

/// Where [AppScreenScaffold] puts its list and detail across a box, worked
/// out from plain values so a screen can place things in step with it (the
/// ambient disc behind a hero face, for one).
///
/// All x values are from the left edge of the box, plus [originX] when the
/// box is a fold pane that does not start at the window edge.
@immutable
class AppScreenColumns {
  const AppScreenColumns._({
    required this.twoPane,
    required this.railOnRight,
    required this.railClearance,
    required this.listLeft,
    required this.listWidth,
    required this.gutter,
    required this.detailLeft,
    required this.detailWidth,
    this.originX = 0,
    this.originY = 0,
    this.inFoldPane = false,
  });

  /// The columns of one box [boxWidth] wide on a display of [size] whose
  /// safe area is [padding] and whose fold is [fold]. [hasTabBar] says the
  /// shell's bar or rail floats over the screen, [hasDetail] that the screen
  /// passes a detail.
  ///
  /// [fold] only decides where the bar is ([navPlacementFor]: book posture
  /// is always the bottom pill) and that a folded window never puts list and
  /// detail side by side in one box. The split into panes is
  /// [AppScreenColumns.of]'s job; inside a pane pass the pane's own values
  /// and no fold.
  factory AppScreenColumns.resolve({
    required double boxWidth,
    required AppSize size,
    required EdgeInsets padding,
    AppFold fold = AppFold.none,
    bool hasTabBar = true,
    bool hasDetail = false,
    double contentMaxWidth = AppSize.contentMaxWidth,
  }) {
    // On its side, or wide enough for two panes, the tab bar stands up as a
    // rail down one edge, so the screen keeps clear of it sideways instead of
    // above the bottom edge. The display's own safe area on that side, the
    // notch on a phone turned sideways, comes on top. Past the frame width
    // the rail sits at the frame's edge, in from the window edge.
    final placement = navPlacementFor(size, fold);
    final hasRail = placement != AppNavPlacement.bottom && hasTabBar;
    final railOnRight = placement == AppNavPlacement.right;
    final frameInset = boxWidth <= AppSize.frameMaxWidth
        ? 0.0
        : (boxWidth - AppSize.frameMaxWidth) / 2;
    final railGap = hasRail
        ? AppNavRail.contentGap + (railOnRight ? padding.right : padding.left)
        : 0.0;
    final railClearance = hasRail ? railGap + frameInset : 0.0;

    if (size.isExpanded && hasDetail && fold.isNone) {
      // Two panes have already narrowed the list, so it needs no gutter.
      final available = boxWidth - 2 * frameInset - railGap;
      final listWidth = AppScreenScaffold.listPaneWidth(available);
      final listLeft = frameInset + (railOnRight ? 0 : railGap);
      return AppScreenColumns._(
        twoPane: true,
        railOnRight: railOnRight,
        railClearance: railClearance,
        listLeft: listLeft,
        listWidth: listWidth,
        gutter: 0,
        detailLeft: listLeft + listWidth,
        detailWidth: available - listWidth,
      );
    }

    // A long row is hard to read, the eye has to travel, so cap the column.
    // One column keeps the rail's clearance on both sides, so it sits in the
    // middle of the display rather than in the middle of what the rail leaves.
    return AppScreenColumns._(
      twoPane: false,
      railOnRight: railOnRight,
      railClearance: railClearance,
      listLeft: 0,
      listWidth: boxWidth,
      gutter: math.max(railClearance, (boxWidth - contentMaxWidth) / 2),
      detailLeft: boxWidth,
      detailWidth: 0,
    );
  }

  /// The columns of the list of a top-level screen drawn in [context],
  /// folds included, laid out the way [AppScreenScaffold] lays it out:
  ///
  /// - Book posture with a detail: the start pane.
  /// - Book posture with a stage ([hasStage]) and no detail: the end pane,
  ///   with no tab bar (the bar is in the start pane).
  /// - Tabletop posture with a stage: the bottom half, with the bar.
  /// - Anything else: the whole window.
  ///
  /// [originX] and [originY] say where that box sits in the window.
  factory AppScreenColumns.of(
    BuildContext context, {
    bool hasTabBar = true,
    bool hasDetail = false,
    bool hasStage = false,
    double contentMaxWidth = AppSize.contentMaxWidth,
  }) => AppScreenColumns.forWindow(
    window: MediaQuery.sizeOf(context),
    padding: MediaQuery.paddingOf(context),
    fold: AppFold.of(context),
    isIphone: AppDeviceScope.isIphoneOf(context),
    direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
    hasTabBar: hasTabBar,
    hasDetail: hasDetail,
    hasStage: hasStage,
    contentMaxWidth: contentMaxWidth,
  );

  /// [AppScreenColumns.of] from plain values.
  factory AppScreenColumns.forWindow({
    required Size window,
    required EdgeInsets padding,
    AppFold fold = AppFold.none,
    bool isIphone = false,
    TextDirection direction = TextDirection.ltr,
    bool hasTabBar = true,
    bool hasDetail = false,
    bool hasStage = false,
    double contentMaxWidth = AppSize.contentMaxWidth,
  }) {
    final panes = fold.panes(window, direction: direction);
    final (Rect? pane, bool paneHasTabBar) = switch (fold.posture) {
      AppPosture.book when hasDetail => (panes.first, hasTabBar),
      AppPosture.book when hasStage => (panes.second, false),
      AppPosture.tabletop when hasStage => (panes.second, hasTabBar),
      _ => (null, hasTabBar),
    };
    if (pane != null) {
      final paneMedia = foldPaneMediaQuery(
        MediaQueryData(size: window, padding: padding),
        pane,
      );
      final inPane = AppScreenColumns.resolve(
        boxWidth: pane.width,
        size: AppSize.from(pane.size, isIphone: isIphone),
        padding: paneMedia.padding,
        hasTabBar: paneHasTabBar,
        contentMaxWidth: contentMaxWidth,
      );
      return AppScreenColumns._(
        twoPane: false,
        railOnRight: inPane.railOnRight,
        railClearance: inPane.railClearance,
        listLeft: inPane.listLeft,
        listWidth: inPane.listWidth,
        gutter: inPane.gutter,
        detailLeft: inPane.detailLeft,
        detailWidth: inPane.detailWidth,
        originX: pane.left,
        originY: pane.top,
        inFoldPane: true,
      );
    }
    return AppScreenColumns.resolve(
      boxWidth: window.width,
      size: AppSize.from(window, isIphone: isIphone),
      padding: padding,
      fold: fold,
      hasTabBar: hasTabBar,
      hasDetail: hasDetail,
      contentMaxWidth: contentMaxWidth,
    );
  }

  /// List beside detail on an expanded display.
  final bool twoPane;

  /// The rail is down the right edge (an unfolded iPhone Fold).
  final bool railOnRight;

  /// How far one column keeps clear of the window edge on each side for the
  /// rail: the rail's room plus the canvas outside the frame. 0 with no rail.
  final double railClearance;

  /// The list pane (two panes) or the whole box (one column).
  final double listLeft;
  final double listWidth;

  /// Room either side of the content inside the list.
  final double gutter;

  /// The detail pane. Zero wide in one column.
  final double detailLeft;
  final double detailWidth;

  /// Where the box starts in the window: the start pane of a book fold can
  /// sit right of it in a right to left layout.
  final double originX;

  /// Where the box starts in the window from the top: the bottom half of a
  /// tabletop fold starts below the band.
  final double originY;

  /// True when the list is one pane of a fold.
  final bool inFoldPane;

  /// True when the list is narrowed to a pane, so a hero in it stacks.
  bool get isPane => twoPane || inFoldPane;

  /// Where the content in the list starts, in window coordinates.
  double get contentLeft => originX + listLeft + gutter;

  /// How wide the content in the list is.
  double get contentWidth => listWidth - 2 * gutter;
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
    this.barOverTop,
    super.key,
  });

  /// The colour of the canvas behind the screens.
  final Color color;

  /// The most the system text size may grow what is in the top bar. Null
  /// leaves the top bar the full scale.
  final double? topBarMaxTextScale;

  /// How tall a bar is that the host draws over the top of a screen that
  /// passes no [AppScreenScaffold.topBar], measured below the status bar.
  /// Such a screen backs that height the way one with a top bar backs its
  /// own. Null when the host draws no bar there.
  final double? barOverTop;

  static AppBarBackingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBarBackingScope>();

  @override
  bool updateShouldNotify(AppBarBackingScope oldWidget) =>
      color != oldWidget.color ||
      topBarMaxTextScale != oldWidget.topBarMaxTextScale ||
      barOverTop != oldWidget.barOverTop;
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

/// The stage pane of a fold split: the screen's top bar along the top, where
/// the scaffold draws it on one column, and the stage under it.
class _StagePane extends StatelessWidget {
  const _StagePane({
    required this.topBar,
    required this.topBarMaxTextScale,
    required this.contentMaxWidth,
    required this.child,
  });

  final Widget? topBar;

  /// The text scale clamp the backing scope asks for, applied here so the
  /// bar keeps the pane's MediaQuery (its size and insets), not the window's.
  final double? topBarMaxTextScale;
  final double contentMaxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topBar = this.topBar;
    if (topBar == null) return child;
    final maxScale = topBarMaxTextScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lined up with the column the list in the other pane uses. No rail
        // runs down this pane, so it keeps no room for one.
        final columns = AppScreenColumns.resolve(
          boxWidth: constraints.maxWidth,
          size: AppSize.of(context),
          padding: MediaQuery.paddingOf(context),
          hasTabBar: false,
          contentMaxWidth: contentMaxWidth,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: columns.gutter),
                child: SizedBox(
                  height: AppScreenScaffold.topBarHeight + 2,
                  child: maxScale == null
                      ? topBar
                      : MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: MediaQuery.textScalerOf(
                              context,
                            ).clamp(maxScaleFactor: maxScale),
                          ),
                          child: topBar,
                        ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The second pane on an expanded display. It is a raised surface that runs
/// to the bottom edge, so the list beside it keeps the canvas.
class AppDetailPane extends StatelessWidget {
  const AppDetailPane({required this.child, super.key});

  /// Room between the pane's surface edges and its content, on each side.
  static const double gutter = 8;

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
      // A wide pane keeps its surface edge to edge, and the content in it
      // stops at a readable width in the middle. The surface runs to the
      // window edge, so the content keeps a gutter on both sides and a card
      // in it is never cut by that edge.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: gutter),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.detailMaxWidth,
            ),
            // The margin above already clears the status bar, so the page
            // in the pane must not leave room for it a second time.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ),
      ),
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
