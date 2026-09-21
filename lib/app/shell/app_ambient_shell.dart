import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
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
  @visibleForTesting
  static AmbientProfile profileForPath(String path, AppColors colors) {
    if (path == '/history') {
      return AmbientAppProfiles.history(colors);
    }
    if (path == '/settings') {
      return AmbientAppProfiles.settings(colors);
    }
    if (path == '/') {
      return AmbientAppProfiles.topics(colors);
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
    if (path.startsWith('/settings/')) {
      return AmbientAppProfiles.settingsDetail(colors);
    }
    return AmbientAppProfiles.topics(colors);
  }

  @override
  State<AppAmbientShell> createState() => _AppAmbientShellState();
}

class _AppAmbientShellState extends State<AppAmbientShell> {
  late String _currentPath;
  final List<String> _history = <String>[];
  AmbientDirection _direction = AmbientDirection.push;

  @override
  void initState() {
    super.initState();
    _currentPath = _resolvePath();
    _history.add(_currentPath);
    widget.router.routerDelegate.addListener(_handleRouteChanged);
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
    super.dispose();
  }

  String _resolvePath() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path;
    } on Object {
      return '/';
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
    final nextPath = _resolvePath();
    if (nextPath == _currentPath) return;

    final prevPath = _currentPath;
    _currentPath = nextPath;

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

  bool get _isSpecialFlow {
    return _currentPath.startsWith('/onboarding') ||
        _currentPath == '/alarm' ||
        _currentPath.startsWith('/incidents/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final profile = AppAmbientShell.profileForPath(_currentPath, colors);

    return Stack(
      children: [
        if (!_isSpecialFlow)
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
        Positioned.fill(
          child: AmbientScope(
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
