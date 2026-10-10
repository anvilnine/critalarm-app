import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:flutter/material.dart';

/// The page of the tab shell: the Topics, History and Settings tabs and the
/// floating tab bar, as one route on the root navigator.
///
/// It is a [MaterialPage] in every way but one. When an [AmbientTabCover] that
/// leaves the tab behind opens over it, such as a Settings sub screen, the
/// shell fades and drifts out the way a Topics list does under a Topic. A
/// plain [MaterialPage] never does: the Material route lets only Material
/// routes move it, so the tab sat still and fully drawn until the new screen
/// was opaque, then vanished.
///
/// Any other route over the shell, a dialog or a full-screen page that has not
/// asked for it, leaves the shell exactly as it was.
class TabShellPage extends MaterialPage<void> {
  const TabShellPage({
    required super.child,
    super.key,
    super.name,
    super.restorationId,
  });

  @override
  Route<void> createRoute(BuildContext context) => _TabShellRoute(page: this);
}

/// Whether [route] is a cover that wants the tab shell to leave.
@visibleForTesting
bool coverLeavesTabBehind(Object? route) =>
    route is AmbientTabCover && route.leavesTabBehind;

class _TabShellRoute extends MaterialPageRoute<void> {
  _TabShellRoute({required TabShellPage page})
    : super(
        settings: page,
        builder: (context) => page.child,
        allowSnapshotting: page.allowSnapshotting,
      );

  // Read from the settings every time: the router hands the route a new page
  // each time the shell rebuilds, and a copy kept from the first one would
  // show a stale shell.
  TabShellPage get _page => settings as TabShellPage;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  /// Whether the route above is a cover that makes the shell leave.
  bool _isCovered = false;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      coverLeavesTabBehind(nextRoute) || super.canTransitionTo(nextRoute);

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    _isCovered = coverLeavesTabBehind(nextRoute);
    super.didChangeNext(nextRoute);
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    _isCovered = coverLeavesTabBehind(nextRoute);
    super.didPopNext(nextRoute);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The same wrappers whether or not a cover is open, only driven by a
    // different animation. A wrapper that came and went would rebuild the
    // whole shell and its tab navigators under it.
    final material = super.buildTransitions(
      context,
      animation,
      _isCovered ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
    return buildAmbientCoveredTransition(
      context: context,
      secondaryAnimation: _isCovered
          ? secondaryAnimation
          : kAlwaysDismissedAnimation,
      isPopGestureInProgress: navigator?.userGestureInProgress ?? false,
      child: material,
    );
  }
}
