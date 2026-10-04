import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/connect_gate.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/background_connect_copy.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The connect that runs behind the user, when the app has one registered.
/// A test that mounts the shell alone has none, and the shell then shows
/// every step as it is.
BackgroundConnect? _appBackgroundConnect() =>
    getIt.isRegistered<BackgroundConnect>() ? getIt<BackgroundConnect>() : null;

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
    final resolvedDirection =
        direction ??
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
    this.backgroundConnect,
    super.key,
  });

  final GoRouterState state;
  final Widget child;

  /// The connect running behind the user. Null takes the app's own.
  final BackgroundConnect? backgroundConnect;

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  late final OnboardingAmbientController _controller;
  late final BackgroundConnect? _connect;
  StreamSubscription<BackgroundConnectState>? _connectChanges;

  /// How long the "connected" line stays up after a connect lands.
  static const _landedLineFor = Duration(seconds: 4);

  /// True for a few seconds after a connect lands while setup is on screen,
  /// so the result is reported on whichever step the user is on.
  bool _justLanded = false;
  Timer? _landedTimer;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingAmbientController(
      initialStep: onboardingStepForPath(widget.state.uri.path),
    );
    _controller.addListener(_handleControllerUpdate);
    _connect = widget.backgroundConnect ?? _appBackgroundConnect();
    _connectChanges = _connect?.stream.listen(_handleConnectChange);
  }

  void _handleConnectChange(BackgroundConnectState next) {
    if (!mounted) return;
    _landedTimer?.cancel();
    setState(() => _justLanded = next.isConnected);
    if (next.isConnected) {
      _landedTimer = Timer(_landedLineFor, () {
        if (mounted) setState(() => _justLanded = false);
      });
    }
  }

  /// The one line shown over a step that carries on while the connect runs:
  /// that it is on its way, or that it has just landed. Null for nothing.
  String? _quietLine() {
    final connect = _connect;
    if (connect == null) return null;
    final uri = widget.state.uri;
    if (_justLanded) {
      // The step that was waiting on the server has just appeared, and the
      // connect step shows its own result.
      final entry = OnboardingStepRegistry.entryForPath(uri.path);
      if (entry == null || entry.id == OnboardingStepId.connect) return null;
      return backgroundConnectLine(connect.state);
    }
    final gate = connectGateFor(
      state: connect.state,
      path: uri.path,
      isReplay: isOnboardingReplayUri(uri),
    );
    return gate == ConnectGate.quiet
        ? backgroundConnectLine(connect.state)
        : null;
  }

  @override
  void didUpdateWidget(covariant OnboardingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.uri.path != oldWidget.state.uri.path) {
      final routeStep = onboardingStepForPath(widget.state.uri.path);
      // Setup only moves forward, and the order of its routes is a flow, not
      // the order of the enum, so a route change is always a push.
      _controller.setStep(routeStep, AmbientDirection.push);
    }
  }

  @override
  void dispose() {
    _landedTimer?.cancel();
    unawaited(_connectChanges?.cancel());
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profiles = OnboardingAmbientProfiles.forColors(context.appColors);
    final currentProfile = profiles[_controller.step]!;
    final quietLine = _quietLine();

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
        // Under the buttons' reach and over no title: a strip at the very
        // bottom of the screen. It takes no taps.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: _ConnectQuietLine(
              message: quietLine,
              isLanded: _justLanded,
            ),
          ),
        ),
      ],
    );
  }
}

/// One line about the connect running behind the user, with the face
/// watching beside it. Fades in and out; holds still under reduce motion.
class _ConnectQuietLine extends StatelessWidget {
  const _ConnectQuietLine({required this.message, required this.isLanded});

  final String? message;
  final bool isLanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final line = message;
    return AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      switchOutCurve: AppCurves.easeOut,
      child: line == null
          ? const SizedBox.shrink(key: ValueKey('connect-quiet-none'))
          : SafeArea(
              key: ValueKey('connect-quiet-$line'),
              top: false,
              minimum: const EdgeInsets.only(bottom: Spacing.s2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.s5),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaceWidget(
                        state: isLanded
                            ? FaceState.success
                            : FaceState.watching,
                        size: 20,
                        isLive: true,
                      ),
                      const SizedBox(width: Spacing.s2),
                      Flexible(
                        child: Text(
                          line,
                          style: AppTypography.small(colors.onCanvasMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Wraps one setup step. While a connect is still running behind the user
/// and the step needs the server, the waiting face and one line stand in for
/// the step. When the connect gave up, the reason and a way back to the
/// connect step do.
///
/// The step itself is not built until it may show, so a screen that talks to
/// the server never starts without one.
class OnboardingStepGate extends StatelessWidget {
  const OnboardingStepGate({
    required this.builder,
    this.backgroundConnect,
    super.key,
  });

  final WidgetBuilder builder;

  /// The connect running behind the user. Null takes the app's own.
  final BackgroundConnect? backgroundConnect;

  @override
  Widget build(BuildContext context) {
    final connect = backgroundConnect ?? _appBackgroundConnect();
    if (connect == null) return builder(context);
    final uri = GoRouterState.of(context).uri;
    return StreamBuilder<BackgroundConnectState>(
      stream: connect.stream,
      initialData: connect.state,
      builder: (context, snapshot) {
        // Read from the object, not the snapshot: a change between the
        // build and the subscription would otherwise be missed.
        final state = connect.state;
        final gate = connectGateFor(
          state: state,
          path: uri.path,
          isReplay: isOnboardingReplayUri(uri),
        );
        return AnimatedSwitcher(
          duration: context.motion(AppDurations.base),
          switchInCurve: AppCurves.easeOut,
          switchOutCurve: AppCurves.easeOut,
          child: switch (gate) {
            ConnectGate.none || ConnectGate.quiet => KeyedSubtree(
              key: const ValueKey('connect-gate-step'),
              child: builder(context),
            ),
            ConnectGate.waiting => _ConnectGateScreen(
              key: const ValueKey('connect-gate-waiting'),
              message: backgroundConnectLine(state) ?? '',
              isFailure: false,
            ),
            ConnectGate.failed => _ConnectGateScreen(
              key: const ValueKey('connect-gate-failed'),
              message: backgroundConnectLine(state) ?? '',
              isFailure: true,
            ),
          },
        );
      },
    );
  }
}

/// What stands in for a step: the face, one line, and the ways on.
class _ConnectGateScreen extends StatelessWidget {
  const _ConnectGateScreen({
    required this.message,
    required this.isFailure,
    super.key,
  });

  final String message;
  final bool isFailure;

  /// Leaves setup for Home. A connect still pending carries on from there.
  Future<void> _setUpLater(BuildContext context) async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      // Opened on its own after setup: back to whatever opened it.
      router.pop();
      return;
    }
    await getIt<CompleteOnboardingUsecase>()(const NoParams());
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: Spacing.s3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s5),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: isFailure
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Hero(
                                tag: 'onboarding-face',
                                flightShuttleBuilder: faceFlightShuttleBuilder,
                                child: FaceWidget(
                                  state: FaceState.worried,
                                  size: 96,
                                  isLive: true,
                                ),
                              ),
                              const SizedBox(height: Spacing.s3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 380,
                                ),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body(colors.onCanvas),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : AppWaitingFace(
                            message: message,
                            heroTag: 'onboarding-face',
                          ),
                  ),
                ),
              ),
              if (isFailure) ...[
                AppButton(
                  label: LocaleKeys.onboarding_connect_background_failed_button
                      .tr(),
                  size: AppButtonSize.lg,
                  isFullWidth: true,
                  onPressed: () =>
                      context.go(OnboardingEntryPoint.connectServer),
                ),
                const SizedBox(height: Spacing.s3),
              ],
              TextButton(
                onPressed: () => unawaited(_setUpLater(context)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  LocaleKeys.onboarding_connect_skip_for_now.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onCanvas,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
