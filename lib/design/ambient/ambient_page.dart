import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds synchronized slide and fade transitions for routes over an ambient
/// canvas.
Widget buildAmbientTransitions({
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  if (context.reduceMotion) {
    return child;
  }

  final primarySlide = animation.drive(
    Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: AppCurves.easeOut)),
  );
  final primaryFade = animation.drive(
    Tween<double>(
      begin: 0,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOut)),
  );

  final secondarySlide = secondaryAnimation.drive(
    Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.08, 0),
    ).chain(CurveTween(curve: AppCurves.easeOut)),
  );
  final secondaryFade = secondaryAnimation.drive(
    Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: Curves.easeOut)),
  );

  return SlideTransition(
    position: secondarySlide,
    child: FadeTransition(
      opacity: secondaryFade,
      child: SlideTransition(
        position: primarySlide,
        child: FadeTransition(
          opacity: primaryFade,
          child: child,
        ),
      ),
    ),
  );
}

/// A transparent, flicker-free [CustomTransitionPage] designed for [GoRoute].
class AmbientPage<T> extends CustomTransitionPage<T> {
  AmbientPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.fullscreenDialog,
  }) : super(
         opaque: false,
         transitionDuration: AppDurations.slow,
         reverseTransitionDuration: AppDurations.slow,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return buildAmbientTransitions(
             context: context,
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
           );
         },
       );
}

/// A transparent [PageRoute] for standard [Navigator] pushes.
class AmbientPageRoute<T> extends PageRoute<T> {
  AmbientPageRoute({
    required this.builder,
    super.settings,
  });

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => AppDurations.slow;

  @override
  Duration get reverseTransitionDuration => AppDurations.slow;

  @override
  bool get opaque => false;

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
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildAmbientTransitions(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
