import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Controller coordinating ambient canvas step changes and direction within
/// the onboarding flow.
class OnboardingAmbientController extends ChangeNotifier {
  OnboardingAmbientController({
    OnboardingAmbientStep initialStep = OnboardingAmbientStep.notifications,
  }) : _step = initialStep;

  OnboardingAmbientStep _step;
  AmbientDirection _direction = AmbientDirection.push;

  OnboardingAmbientStep get step => _step;
  AmbientDirection get direction => _direction;

  void setStep(OnboardingAmbientStep nextStep, [AmbientDirection? direction]) {
    if (_step == nextStep) return;
    final resolvedDirection = direction ??
        (nextStep.index >= _step.index
            ? AmbientDirection.push
            : AmbientDirection.pop);
    _step = nextStep;
    _direction = resolvedDirection;
    notifyListeners();
  }
}

/// Inherited scope allowing child onboarding screens to report intra-screen
/// step and state changes to the surrounding ambient shell.
class OnboardingAmbientScope extends InheritedWidget {
  const OnboardingAmbientScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final OnboardingAmbientController controller;

  static OnboardingAmbientController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(covariant OnboardingAmbientScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// Shell widget providing a persistent, animated ambient canvas behind all
/// onboarding routes.
class OnboardingShell extends StatefulWidget {
  const OnboardingShell({
    required this.state,
    required this.child,
    super.key,
  });

  final GoRouterState state;
  final Widget child;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  late final OnboardingAmbientController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingAmbientController(
      initialStep: _stepForLocation(widget.state.uri.path),
    );
    _controller.addListener(_handleControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant OnboardingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.uri.path != oldWidget.state.uri.path) {
      final routeStep = _stepForLocation(widget.state.uri.path);
      _controller.setStep(routeStep);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (mounted) setState(() {});
  }

  OnboardingAmbientStep _stepForLocation(String path) {
    if (path.startsWith('/onboarding/connect')) {
      return OnboardingAmbientStep.connect;
    }
    if (path.startsWith('/onboarding/denied')) {
      return OnboardingAmbientStep.denied;
    }
    return OnboardingAmbientStep.notifications;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = OnboardingAmbientProfiles.forColors(context.appColors);
    final currentProfile = profiles[_controller.step]!;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AmbientCanvas(
              key: const ValueKey('onboarding-ambient-canvas'),
              profile: currentProfile,
              variant: AmbientMotionVariant.drift,
              direction: _controller.direction,
              reduceMotion: context.reduceMotion,
            ),
          ),
        ),
        Positioned.fill(
          child: AmbientScope(
            child: OnboardingAmbientScope(
              controller: _controller,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
