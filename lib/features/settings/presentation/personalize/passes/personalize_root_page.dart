import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/widgets.dart';

/// The go_router page of the Personalize root.
///
/// It slides and fades in like every ambient page, with the iOS edge swipe
/// back, and it is opaque. What it leaves out is the slide and fade the
/// ambient transition gives the page below when another route covers it. A
/// pass page grows out of a card and takes the other cards with it, so the
/// root must not also drift left and fade on its own: the two together left
/// a ghost of the stack at the edge of the screen on the way in and washed
/// the cards out on the way back.
class PersonalizeRootPage extends Page<void> {
  const PersonalizeRootPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) =>
      _PersonalizeRootRoute(page: this);
}

class _PersonalizeRootRoute extends PageRoute<void>
    with AmbientRoutePopGestureMixin<void> {
  _PersonalizeRootRoute({required PersonalizeRootPage page})
    : _page = page,
      super(settings: page);

  final PersonalizeRootPage _page;

  // Reads MediaQuery without depending on it, since a route's durations are
  // read outside build. Under reduce motion the route does not run.
  Duration get _duration {
    final query = navigator?.context
        .getInheritedWidgetOfExactType<MediaQuery>();
    return (query?.data.disableAnimations ?? false)
        ? Duration.zero
        : AppDurations.slow;
  }

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildAmbientRouteTransitions(
    context: context,
    animation: animation,
    // Whatever covers the root moves the root itself, or nothing does.
    secondaryAnimation: kAlwaysDismissedAnimation,
    child: child,
  );
}
