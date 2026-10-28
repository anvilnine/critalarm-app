import 'package:critalarm/app/route_top.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Hosts a persistent, application-wide ambient canvas behind all visual
/// routes, providing continuous morphing transitions on forward push,
/// backward pop, and tab changes.
class AppAmbientShell extends StatefulWidget {
  const AppAmbientShell({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  /// The backdrop for each screen. A screen pushed on top of another needs a
  /// different profile from it, or the backdrop holds still on the push.
  ///
  /// [heroSpot] is where the Topics hero's disc sits on this display. Without
  /// it the disc sits where it does on a 390 by 844 phone.
  @visibleForTesting
  static AmbientProfile profileForPath(
    String path,
    AppColors colors, {
    HeroDiscSpot heroSpot = HeroDiscSpot.phone,
  }) {
    if (path == '/history') {
      return AmbientAppProfiles.history(colors);
    }
    if (path == '/settings') {
      return AmbientAppProfiles.settings(colors);
    }
    if (path == '/') {
      return AmbientAppProfiles.topicsHero(colors, spot: heroSpot);
    }
    if (path.startsWith('/topics/new')) {
      return AmbientAppProfiles.createTopic(colors);
    }
    if (path == '/sounds/crop' || path == '/sounds/record') {
      return AmbientAppProfiles.soundEditor(colors);
    }
    if (path.contains('/sounds')) {
      return AmbientAppProfiles.soundList(colors);
    }
    if (path.startsWith('/history/topics/')) {
      return AmbientAppProfiles.historyDetail(colors);
    }
    if (path.startsWith('/topics/')) {
      return AmbientAppProfiles.topicDetail(colors);
    }
    if (path == '/alarm' || path.startsWith('/incidents/')) {
      return AmbientAppProfiles.criticalAlarmRinging(colors);
    }
    // A full-screen Settings page off the root navigator.
    if (path.startsWith('/settings/') || path == '/app-icon') {
      return AmbientAppProfiles.settingsDetail(colors);
    }
    return AmbientAppProfiles.topicsHero(colors, spot: heroSpot);
  }

  /// Whether the shell leaves its canvas out for [routes]. Setup draws its
  /// own canvas, so the shell skips its one while setup is the whole stack.
  ///
  /// A `push` keeps the base uri in go_router, so a pushed `/alarm` over
  /// `/onboarding/permissions` still reads `/onboarding/permissions` there.
  /// The alarm routes are opaque and hide the setup canvas, so the top match
  /// decides too: the canvas stays when anything other than setup is on top,
  /// and when setup is pushed over a screen that needs the canvas under it.
  @visibleForTesting
  static bool skipsCanvasFor(RouteMatchList routes) {
    if (routes.matches.isEmpty) return false;
    final base = routes.uri.path;
    final top = topPathOf(routes);
    return _isSetupPath(base) && _isSetupPath(top);
  }

  static bool _isSetupPath(String path) => path.startsWith('/onboarding');

  @override
  State<AppAmbientShell> createState() => _AppAmbientShellState();
}

class _AppAmbientShellState extends State<AppAmbientShell> {
  late String _currentPath;
  late bool _skipsCanvas;
  final List<String> _history = <String>[];
  AmbientDirection _direction = AmbientDirection.push;
  late final AmbientController _controller = AmbientController();

  @override
  void initState() {
    super.initState();
    _currentPath = _resolvePath();
    _skipsCanvas = _resolveSkipsCanvas();
    _history.add(_currentPath);
    widget.router.routerDelegate.addListener(_handleRouteChanged);
    _controller.addListener(_handleOverrideChanged);
  }

  @override
  void didUpdateWidget(covariant AppAmbientShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.router != oldWidget.router) {
      oldWidget.router.routerDelegate.removeListener(_handleRouteChanged);
      widget.router.routerDelegate.addListener(_handleRouteChanged);
      _handleRouteChanged();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_handleRouteChanged);
    _controller
      ..removeListener(_handleOverrideChanged)
      ..dispose();
    super.dispose();
  }

  /// The override changed. A screen clears its override from `dispose`,
  /// which runs while the tree is locked at the end of a frame, and a
  /// `setState` there throws. So inside a frame it waits for the frame to
  /// end.
  void _handleOverrideChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _applyOverride(),
      );
      return;
    }
    _applyOverride();
  }

  void _applyOverride() {
    if (!mounted) return;
    setState(() {
      if (_controller.overrideDirection != null) {
        _direction = _controller.overrideDirection!;
      }
    });
  }

  String _resolvePath() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path;
    } on Object {
      return '/';
    }
  }

  bool _resolveSkipsCanvas() {
    try {
      return AppAmbientShell.skipsCanvasFor(
        widget.router.routerDelegate.currentConfiguration,
      );
    } on Object {
      return false;
    }
  }

  static bool _isRootTab(String path) {
    return path == '/' || path == '/history' || path == '/settings';
  }

  static int _tabIndex(String path) {
    if (path == '/history') return 1;
    if (path == '/settings') return 2;
    return 0;
  }

  void _handleRouteChanged() {
    final skipsCanvas = _resolveSkipsCanvas();
    if (skipsCanvas != _skipsCanvas) {
      _skipsCanvas = skipsCanvas;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    final nextPath = _resolvePath();
    if (nextPath == _currentPath) return;

    final prevPath = _currentPath;
    _currentPath = nextPath;

    _controller.clearOverride();

    final resolvedDirection = _computeDirection(prevPath, nextPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _direction = resolvedDirection;
        });
      }
    });
  }

  AmbientDirection _computeDirection(String prevPath, String nextPath) {
    // 1. Tab switches between the 3 root tabs
    if (_isRootTab(prevPath) && _isRootTab(nextPath)) {
      final prevIndex = _tabIndex(prevPath);
      final nextIndex = _tabIndex(nextPath);
      _history
        ..clear()
        ..add(nextPath);
      return tabDirection(current: prevIndex, next: nextIndex);
    }

    // 2. Popping back to a previously visited screen in the history stack
    final previousVisitIndex = _history.lastIndexOf(nextPath);
    if (previousVisitIndex != -1 && previousVisitIndex < _history.length - 1) {
      _history.removeRange(previousVisitIndex + 1, _history.length);
      return AmbientDirection.pop;
    }

    // 3. Returning directly to a root tab from an inner detail route
    if (_isRootTab(nextPath)) {
      _history
        ..clear()
        ..add(nextPath);
      return AmbientDirection.pop;
    }

    // 4. Pushing forward into a new route or deeper detail
    _history.add(nextPath);
    return AmbientDirection.push;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // A screen's own choice for its route (the Topics tab follows its card),
    // then the shell's.
    final profile =
        _controller.overrideProfile ??
        _controller.routeProfileFor(_currentPath) ??
        AppAmbientShell.profileForPath(
          _currentPath,
          colors,
          heroSpot: heroDiscSpotOf(context),
        );

    return Stack(
      children: [
        if (!_skipsCanvas)
          Positioned.fill(
            child: IgnorePointer(
              child: AmbientCanvas(
                key: const ValueKey('app-ambient-canvas'),
                profile: profile,
                direction: _direction,
                variant: AmbientMotionVariant.drift,
                reduceMotion: context.reduceMotion,
              ),
            ),
          ),
        // Keyed, so the routes keep their state when the canvas before it
        // comes or goes. Unkeyed, the canvas took this slot's place and the
        // whole navigator under it was built again.
        Positioned.fill(
          key: const ValueKey('app-ambient-content'),
          child: AmbientScope(
            controller: _controller,
            // The screens leave their background clear and sit on the canvas
            // above. Each backs its top bar with the canvas colour while a
            // row is scrolled under it, so the row does not run through the
            // title.
            child: AppBarBackingScope(
              color: profile.canvas,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
