import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
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
    this.hasQuietLine = false,
    super.key,
  });

  final OnboardingAmbientController controller;

  /// True while the shell is showing its short status in the top corner.
  /// A step that draws something there of its own gives the corner up.
  final bool hasQuietLine;

  /// Whether the shell's status is in the top corner right now. False
  /// outside the shell.
  static bool hasQuietLineOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
          ?.hasQuietLine ??
      false;

  static OnboardingAmbientController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(covariant OnboardingAmbientScope oldWidget) {
    return controller != oldWidget.controller ||
        hasQuietLine != oldWidget.hasQuietLine;
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
      return backgroundConnectShortLine(connect.state);
    }
    final gate = connectGateFor(
      state: connect.state,
      path: uri.path,
      isReplay: isOnboardingReplayUri(uri),
      // Only the quiet line is read here, and it does not depend on this.
      hasConnection: true,
    );
    return gate == ConnectGate.quiet
        ? backgroundConnectShortLine(connect.state)
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
              hasQuietLine: quietLine != null,
              child: widget.child,
            ),
          ),
        ),
        // In the empty corner beside the app title: over no title and no
        // button. It takes no taps.
        Positioned(
          top: 0,
          right: 0,
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

/// A word or three about the connect running behind the user, with the face
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
              bottom: false,
              left: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: Spacing.s3,
                  right: Spacing.s4,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaceWidget(
                          state: isLanded
                              ? FaceState.success
                              : FaceState.watching,
                          size: 22,
                          isLive: true,
                        ),
                        const SizedBox(width: Spacing.s2),
                        Text(
                          line,
                          // The shell sits above every route, so there is
                          // no text style to inherit here.
                          style: AppTypography.small(
                            colors.ink,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                      ],
                    ),
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
class OnboardingStepGate extends StatefulWidget {
  const OnboardingStepGate({
    required this.builder,
    this.backgroundConnect,
    this.readHasConnection,
    super.key,
  });

  final WidgetBuilder builder;

  /// The connect running behind the user. Null takes the app's own.
  final BackgroundConnect? backgroundConnect;

  /// Whether a server connection is saved. Null takes the app's own read.
  final Future<bool> Function()? readHasConnection;

  @override
  State<OnboardingStepGate> createState() => _OnboardingStepGateState();
}

class _OnboardingStepGateState extends State<OnboardingStepGate> {
  late final BackgroundConnect? _connect;
  StreamSubscription<BackgroundConnectState>? _changes;

  /// Null until the first read answers. It is one prefs read.
  bool? _hasConnection;

  @override
  void initState() {
    super.initState();
    _connect = widget.backgroundConnect ?? _appBackgroundConnect();
    if (_connect == null) return;
    _changes = _connect.stream.listen((_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final read =
        widget.readHasConnection ??
        () async =>
            (await getIt<GetConnectionUsecase>()(
              const NoParams(),
            )).getOrNull() !=
            null;
    final has = await read();
    if (mounted) setState(() => _hasConnection = has);
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connect = _connect;
    if (connect == null) return widget.builder(context);
    final uri = GoRouterState.of(context).uri;
    final state = connect.state;
    final hasConnection = _hasConnection;
    final entry = OnboardingStepRegistry.entryForPath(uri.path);
    final needsServer =
        entry != null && entry.requires.contains(OnboardingStepId.connect);
    final Widget child;
    if (hasConnection == null && needsServer && !isOnboardingReplayUri(uri)) {
      // A step that talks to the server is not built before the read says
      // there is one. One frame or two of the canvas alone.
      child = const SizedBox.expand(key: ValueKey('connect-gate-reading'));
    } else {
      final gate = connectGateFor(
        state: state,
        path: uri.path,
        isReplay: isOnboardingReplayUri(uri),
        hasConnection: hasConnection ?? false,
      );
      child = switch (gate) {
        ConnectGate.none || ConnectGate.quiet => KeyedSubtree(
          key: const ValueKey('connect-gate-step'),
          child: widget.builder(context),
        ),
        ConnectGate.waiting => _ConnectGateScreen(
          key: const ValueKey('connect-gate-waiting'),
          message: backgroundConnectLine(state) ?? '',
          face: null,
          connect: connect,
        ),
        ConnectGate.failed => _ConnectGateScreen(
          key: const ValueKey('connect-gate-failed'),
          // With no failure to name, the step is simply missing its server.
          message:
              backgroundConnectLine(state) ??
              LocaleKeys.onboarding_connect_background_no_server.tr(),
          // Missing, not broken, when there is no failure to name.
          face: backgroundConnectLine(state) == null
              ? FaceState.sad
              : FaceState.worried,
          connect: connect,
        ),
      };
    }
    return AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      switchOutCurve: AppCurves.easeOut,
      child: child,
    );
  }
}

/// What stands in for a step: the face, one line, and the ways on.
class _ConnectGateScreen extends StatelessWidget {
  const _ConnectGateScreen({
    required this.message,
    required this.face,
    required this.connect,
    super.key,
  });

  final String message;

  /// The face of a step that cannot go on. Null while the connect is still
  /// on its way, which is a wait and gets the waiting face.
  final FaceState? face;
  final BackgroundConnect connect;

  /// Leaves setup for Home. A connect still pending carries on from there.
  Future<void> _setUpLater(BuildContext context) async {
    final router = GoRouter.of(context);
    // The user has seen the failure and is leaving it behind. A connect
    // still pending is untouched and carries on.
    connect.dismissFailure();
    if (router.canPop()) {
      // Opened on its own after setup: back to whatever opened it.
      router.pop();
      return;
    }
    await getIt<SetUpLaterUsecase>()();
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final face = this.face;
    // The same scaffold as the steps it stands in for, so the face, the
    // buttons and their insets sit where they do on every other step.
    return AppScreenScaffold(
      backgroundColor: Colors.transparent,
      withGhosts: false,
      withFades: false,
      hasTabBar: false,
      topBar: AppTopBar(title: LocaleKeys.app_title.tr()),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (face != null) ...[
            AppButton(
              label: LocaleKeys.onboarding_connect_background_failed_button
                  .tr(),
              size: AppButtonSize.lg,
              isFullWidth: true,
              onPressed: () => context.go(OnboardingEntryPoint.connectServer),
            ),
            const SizedBox(height: Spacing.s3),
          ],
          AppButton(
            label: LocaleKeys.onboarding_connect_skip_for_now.tr(),
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            onPressed: () => unawaited(_setUpLater(context)),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s5,
            Spacing.s4,
            Spacing.s5,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: face == null
                ? Center(
                    child: AppWaitingFace(
                      message: message,
                      faceSize: 80,
                      heroTag: 'onboarding-face',
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'onboarding-face',
                        flightShuttleBuilder: faceFlightShuttleBuilder,
                        child: FaceWidget(state: face, size: 80, isLive: true),
                      ),
                      const SizedBox(height: Spacing.s3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
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
                  ),
          ),
        ),
      ],
    );
  }
}
