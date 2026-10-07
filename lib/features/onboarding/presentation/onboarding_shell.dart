import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_chapters.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/connect_gate.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/background_connect_copy.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_problem_card.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_tracker.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

export 'package:critalarm/features/onboarding/presentation/widgets/setup_tracker.dart'
    show TravellingFaceMood;

/// The connect that runs behind the user, when the app has one registered.
/// A test that mounts the shell alone has none, and the shell then shows
/// every step as it is.
BackgroundConnect? _appBackgroundConnect() =>
    getIt.isRegistered<BackgroundConnect>() ? getIt<BackgroundConnect>() : null;

/// The flow engine, when the app has one registered. A test that mounts the
/// shell alone has none, and the shell then draws no tracker and no Back.
OnboardingFlowEngine? _appFlowEngine() =>
    getIt.isRegistered<OnboardingFlowEngine>()
    ? getIt<OnboardingFlowEngine>()
    : null;

/// Controller coordinating ambient canvas step changes and direction within
/// the onboarding flow. It also carries what the step on screen asks of the
/// shell's top bar: the mood of the small face and whether Back is held.
class OnboardingAmbientController extends ChangeNotifier {
  OnboardingAmbientController({
    OnboardingAmbientStep initialStep = OnboardingAmbientStep.notifications,
  }) : _step = initialStep;

  OnboardingAmbientStep _step;
  AmbientDirection _direction = AmbientDirection.push;
  AmbientMotionVariant _variant = AmbientMotionVariant.drift;
  TravellingFaceMood? _faceMood;
  bool _isBackHeld = false;

  OnboardingAmbientStep get step => _step;
  AmbientDirection get direction => _direction;

  /// How the shapes move for the change that is playing. Drift inside a
  /// chapter. Only the shell passes sweep, for a step change that crosses
  /// from one chapter to the next.
  AmbientMotionVariant get variant => _variant;

  /// The mood the step on screen asked for, or null when it asked for none
  /// and the shell picks.
  TravellingFaceMood? get faceMood => _faceMood;

  /// True while the step on screen is in the middle of something Back must
  /// not walk away from, such as making the first topic.
  bool get isBackHeld => _isBackHeld;

  void setStep(
    OnboardingAmbientStep nextStep, [
    AmbientDirection? direction,
    AmbientMotionVariant variant = AmbientMotionVariant.drift,
  ]) {
    if (_step == nextStep) return;
    final resolvedDirection =
        direction ??
        (nextStep.index >= _step.index
            ? AmbientDirection.push
            : AmbientDirection.pop);
    _step = nextStep;
    _direction = resolvedDirection;
    _variant = variant;
    notifyListeners();
  }

  /// Sets the mood of the small face beside the tracker. Null hands the
  /// choice back to the shell. Call it from a listener or a callback, never
  /// while building.
  void setFaceMood(TravellingFaceMood? mood) {
    if (_faceMood == mood) return;
    _faceMood = mood;
    notifyListeners();
  }

  /// Takes the Back button away while [isHeld], and gives it back after.
  /// Call it from a listener or a callback, never while building.
  void holdBack({required bool isHeld}) {
    if (_isBackHeld == isHeld) return;
    _isBackHeld = isHeld;
    notifyListeners();
  }

  /// Another step is on screen, so what the last one asked for is over.
  /// The shell calls it on a route change, where it is about to rebuild.
  void resetForStep() {
    _faceMood = null;
    _isBackHeld = false;
  }
}

/// Inherited scope allowing child onboarding screens to report intra-screen
/// step and state changes to the surrounding ambient shell.
class OnboardingAmbientScope extends InheritedWidget {
  const OnboardingAmbientScope({
    required this.controller,
    required super.child,
    this.hasQuietLine = false,
    this.showsTracker = false,
    this.onBack,
    super.key,
  });

  final OnboardingAmbientController controller;

  /// True while the shell is showing its short status in the top corner.
  /// A step that draws something there of its own gives the corner up.
  final bool hasQuietLine;

  /// True while the shell draws the tracker, and Back when it is offered,
  /// where a step's top bar has its title. The step then leaves the title
  /// out. See [setupTopBarTitle].
  final bool showsTracker;

  /// Goes back one step. Null when Back is not offered on this step.
  final VoidCallback? onBack;

  /// Whether the shell's status is in the top corner right now. False
  /// outside the shell.
  static bool hasQuietLineOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
          ?.hasQuietLine ??
      false;

  /// Whether the shell is drawing the tracker over the top bar right now.
  /// False outside the shell.
  static bool showsTrackerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
          ?.showsTracker ??
      false;

  /// What Back does on this step, or null when it is not offered. Null
  /// outside the shell.
  static VoidCallback? onBackOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
      ?.onBack;

  static OnboardingAmbientController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OnboardingAmbientScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(covariant OnboardingAmbientScope oldWidget) {
    return controller != oldWidget.controller ||
        hasQuietLine != oldWidget.hasQuietLine ||
        showsTracker != oldWidget.showsTracker ||
        (onBack == null) != (oldWidget.onBack == null);
  }
}

/// The title a setup step gives its top bar: the app name, or none while
/// the shell draws the tracker there.
String? setupTopBarTitle(BuildContext context) =>
    OnboardingAmbientScope.showsTrackerOf(context)
    ? null
    : LocaleKeys.app_title.tr();

/// Where the step on screen is in a step change.
enum _StepMotionPhase { rest, leaving, entering }

/// Shell widget providing a persistent, animated ambient canvas behind all
/// onboarding routes, and the tracker, the small face and Back over them.
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

class _OnboardingShellState extends State<OnboardingShell>
    with SingleTickerProviderStateMixin {
  late final OnboardingAmbientController _controller;
  late final BackgroundConnect? _connect;
  late final OnboardingFlowEngine? _engine;
  StreamSubscription<BackgroundConnectState>? _connectChanges;

  /// How long the "connected" line stays up after a connect lands.
  static const _landedLineFor = Duration(seconds: 4);

  /// How far a step slides, as a share of the screen width: out by the
  /// first, in from the second. The same two the ambient pages use.
  static const _leaveSlide = 0.08;
  static const _enterSlide = 0.12;

  /// True for a few seconds after a connect lands while setup is on screen,
  /// so the result is reported on whichever step the user is on.
  bool _justLanded = false;
  Timer? _landedTimer;

  /// Drives the step on screen out and the next one in.
  late final AnimationController _motion;
  _StepMotionPhase _phase = _StepMotionPhase.rest;

  /// Which way the step change on screen runs.
  bool _movesBack = false;

  /// Set by [_leave] for the route change it comes before.
  bool _nextChangeIsBack = false;

  /// Counts step changes, so the end of one that was cut short does not
  /// settle the one that replaced it.
  int _motionRun = 0;

  /// Brings the step back if the route never changes after a [_leave].
  Timer? _leaveGuard;

  /// What the tracker shows on this route. Null on a route that is not a
  /// setup step, and with no flow engine.
  OnboardingTrackerFill? _fill;

  /// The step Back goes to from here, as last read. Null for none.
  String? _backStep;

  /// False once it is known that setup is complete and this is no replay:
  /// the screen was opened on its own and there is no run to track.
  bool _isRun = true;

  /// True when the route sits on top of another screen, which is how a
  /// setup screen is opened on its own. It keeps its own top bar then.
  bool _opensOnItsOwn = false;
  bool _hasReadRoute = false;

  bool _isGoingBack = false;

  /// True while a step with no top bar of its own is scrolled, so its rows
  /// run under the tracker.
  bool _isScrolledUnder = false;

  Uri get _uri => widget.state.uri;
  bool get _isReplay => isOnboardingReplayUri(_uri);
  OnboardingStepEntry? get _entry =>
      OnboardingStepRegistry.entryForPath(_uri.path);

  @override
  void initState() {
    super.initState();
    _controller = OnboardingAmbientController(
      initialStep: onboardingStepForPath(widget.state.uri.path),
    );
    _controller.addListener(_handleControllerUpdate);
    _connect = widget.backgroundConnect ?? _appBackgroundConnect();
    _connectChanges = _connect?.stream.listen(_handleConnectChange);
    _engine = _appFlowEngine();
    _motion = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
      value: 1,
    );
    _fill = _readFill();
    attachOnboardingStepLeave(_leave);
    unawaited(_refreshStanding());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasReadRoute) return;
    _hasReadRoute = true;
    _opensOnItsOwn = _readOpensOnItsOwn();
  }

  bool _readOpensOnItsOwn() => GoRouter.maybeOf(context)?.canPop() ?? false;

  /// The tracker for the step on this route, from the flow the user is in.
  OnboardingTrackerFill? _readFill() {
    final engine = _engine;
    final entry = _entry;
    if (engine == null || entry == null) return null;
    final flow = _isReplay ? engine.chooseFlow() : engine.runningFlow();
    return onboardingTrackerFillFor(
      currentStep: entry.id,
      flowSteps: flow.steps,
    );
  }

  /// Reads whether a setup run is on screen and where Back goes from here.
  /// Both are local reads, so the answer is there within the frame.
  Future<void> _refreshStanding() async {
    final engine = _engine;
    final entry = _entry;
    if (engine == null || entry == null) return;
    final path = _uri.path;
    final isReplay = _isReplay;
    final isComplete =
        !isReplay &&
        ((await engine.getOnboardingCompleted(const NoParams())).getOrNull() ??
            false);
    final back = await engine.backStepFrom(entry.id, isReplay: isReplay);
    if (!mounted || _uri.path != path) return;
    if (_isRun == !isComplete && _backStep == back) return;
    setState(() {
      _isRun = !isComplete;
      _backStep = back;
    });
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
    final oldPath = oldWidget.state.uri.path;
    if (widget.state.uri.path == oldPath) return;

    final isBack = _nextChangeIsBack;
    _nextChangeIsBack = false;
    _leaveGuard?.cancel();

    final from = OnboardingStepRegistry.entryForPath(oldPath);
    final to = _entry;
    final crossesChapter =
        from != null &&
        to != null &&
        onboardingStepChangeCrossesChapter(from.id, to.id);
    // The order of the routes is a flow, not the order of the enum, so the
    // direction comes from which way the user moved.
    _controller
      ..resetForStep()
      ..setStep(
        onboardingStepForPath(widget.state.uri.path),
        isBack ? AmbientDirection.pop : AmbientDirection.push,
        crossesChapter
            ? AmbientMotionVariant.sweep
            : AmbientMotionVariant.drift,
      );

    final before = _fill;
    final after = _readFill();
    _fill = after;
    _opensOnItsOwn = _readOpensOnItsOwn();
    _isScrolledUnder = false;

    final reduceMotion = context.reduceMotion;
    // A tick as a bar gains a step. An animation cue, so there is none
    // under reduce motion.
    if (!reduceMotion &&
        !isBack &&
        before != null &&
        after != null &&
        after.position > before.position) {
      AppHaptics.selection();
    }
    _playEnter(isBack: isBack, reduceMotion: reduceMotion);
    unawaited(_refreshStanding());
  }

  /// The new step comes in: from the end for a step forward, from the
  /// start for Back.
  void _playEnter({required bool isBack, required bool reduceMotion}) {
    final wasLeaving = _phase == _StepMotionPhase.leaving;
    final run = ++_motionRun;
    if (reduceMotion) {
      _phase = _StepMotionPhase.rest;
      _motion.value = 1;
      return;
    }
    _movesBack = isBack;
    _phase = _StepMotionPhase.entering;
    // Out and in together take the one slow beat. A change that had no way
    // out played first, such as the first step after launch, gets all of it.
    _motion.duration = wasLeaving
        ? AppDurations.slow - AppDurations.quick
        : AppDurations.slow;
    _motion.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || run != _motionRun) return;
      setState(() => _phase = _StepMotionPhase.rest);
    });
  }

  /// The step on screen goes out of the way for the route change that is
  /// about to come. What the navigation helpers call before they move.
  Future<void> _leave({required bool isBack}) async {
    if (!mounted) return;
    _nextChangeIsBack = isBack;
    _leaveGuard?.cancel();
    _leaveGuard = Timer(const Duration(seconds: 1), _settle);
    if (context.reduceMotion) return;
    ++_motionRun;
    setState(() {
      _movesBack = isBack;
      _phase = _StepMotionPhase.leaving;
    });
    _motion.duration = AppDurations.quick;
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The shell went away, or another change took over.
    }
  }

  /// The route did not change after a [_leave], so the step comes back.
  void _settle() {
    if (!mounted) return;
    _nextChangeIsBack = false;
    if (_phase != _StepMotionPhase.leaving) return;
    ++_motionRun;
    _motion.value = 1;
    setState(() => _phase = _StepMotionPhase.rest);
  }

  Future<void> _goBack() async {
    final entry = _entry;
    if (entry == null || _isGoingBack) return;
    _isGoingBack = true;
    try {
      final went = await goBackInOnboarding(
        GoRouter.of(context),
        entry.id,
        isReplay: _isReplay,
      );
      // Back is no longer offered here: stop showing it.
      if (!went) await _refreshStanding();
    } finally {
      _isGoingBack = false;
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final isUnder = notification.metrics.pixels > 0;
    if (isUnder == _isScrolledUnder) return false;
    void show() {
      if (mounted && isUnder != _isScrolledUnder) {
        setState(() => _isScrolledUnder = isUnder);
      }
    }

    // A list can move while the frame is being laid out, and nothing may be
    // rebuilt then, so that one waits for the frame to finish.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    } else {
      show();
    }
    return false;
  }

  @override
  void dispose() {
    detachOnboardingStepLeave(_leave);
    _leaveGuard?.cancel();
    _landedTimer?.cancel();
    unawaited(_connectChanges?.cancel());
    _motion.dispose();
    _controller
      ..removeListener(_handleControllerUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// The mood of the small face: what the step asked for, or else watching
  /// while a connect runs behind the user, acknowledged once every chapter
  /// is done, and calm the rest of the time.
  TravellingFaceMood _moodFor(OnboardingTrackerFill fill) {
    final asked = _controller.faceMood;
    if (asked != null) return asked;
    if (_connect?.state.isPending ?? false) return TravellingFaceMood.watching;
    return fill.isAllDone
        ? TravellingFaceMood.acknowledged
        : TravellingFaceMood.calm;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = OnboardingAmbientProfiles.forColors(context.appColors);
    final currentProfile = profiles[_controller.step]!;
    final quietLine = _quietLine();
    final fill = _fill;
    // A setup run is on screen, so the shell has the top bar's title room.
    final showsTracker = fill != null && _isRun && !_opensOnItsOwn;
    final onBack = showsTracker && _backStep != null && !_controller.isBackHeld
        ? () => unawaited(_goBack())
        : null;
    final barHeight =
        MediaQuery.paddingOf(context).top + AppScreenScaffold.topBarHeight;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AmbientCanvas(
              key: const ValueKey('onboarding-ambient-canvas'),
              profile: currentProfile,
              variant: _controller.variant,
              direction: _controller.direction,
              reduceMotion: context.reduceMotion,
            ),
          ),
        ),
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            // The step slides and fades out, and the next one in. The canvas
            // behind and the tracker above hold still. The widgets here stay
            // the same at rest, so a step keeps its state through a change.
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final towards = _movesBack ? -1.0 : 1.0;
                final (opacity, shift) = switch (_phase) {
                  _StepMotionPhase.rest => (1.0, 0.0),
                  _StepMotionPhase.leaving => () {
                    final gone = Curves.easeIn.transform(_motion.value);
                    return (1 - gone, -towards * _leaveSlide * gone);
                  }(),
                  _StepMotionPhase.entering => () {
                    final here = AppCurves.easeOut.transform(_motion.value);
                    return (here, towards * _enterSlide * (1 - here));
                  }(),
                };
                return IgnorePointer(
                  // A step on its way out takes no more taps.
                  ignoring: _phase == _StepMotionPhase.leaving,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: FractionalTranslation(
                      translation: Offset(shift, 0),
                      child: child,
                    ),
                  ),
                );
              },
              child: AmbientScope(
                // Every step sits on this canvas with a clear background, so
                // each one backs its bars with the canvas colour while a row
                // is scrolled under them, and at rest when the text is too
                // large for the step to fit. The app name keeps to the top
                // bar's height.
                child: AppBarBackingScope(
                  color: currentProfile.canvas,
                  topBarMaxTextScale: setupTopBarMaxTextScale,
                  child: OnboardingAmbientScope(
                    controller: _controller,
                    hasQuietLine: quietLine != null,
                    showsTracker: showsTracker,
                    onBack: onBack,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
        // A step with no top bar of its own has nothing behind the tracker
        // once its rows scroll under it, so the shell backs it here.
        if (showsTracker && !(_entry?.hasTopBar ?? true))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: barHeight + 16,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isScrolledUnder ? 1 : 0,
                duration: context.motion(AppDurations.quick),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        currentProfile.canvas,
                        currentProfile.canvas,
                        currentProfile.canvas.withValues(alpha: 0),
                      ],
                      stops: [0, barHeight / (barHeight + 16), 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Where a step's top bar has its title: Back when it is offered,
        // the small face and the three bars. Beside them, in the empty
        // corner, the word or three about the connect. Only Back takes
        // taps.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            // The bar is 56 high whatever the text size, like a step's own.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: setupTopBarMaxTextScale,
              child: SizedBox(
                height: AppScreenScaffold.topBarHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _BackSlot(onPressed: onBack),
                      IgnorePointer(
                        // Faded out, it is not read out either.
                        child: ExcludeSemantics(
                          excluding: !showsTracker,
                          child: AnimatedOpacity(
                            opacity: showsTracker ? 1 : 0,
                            duration: context.motion(AppDurations.base),
                            curve: AppCurves.easeOut,
                            child: fill == null
                                ? const SizedBox.shrink()
                                : SizedBox(
                                    width: SetupTracker.width,
                                    child: SetupTracker(
                                      fill: fill,
                                      mood: _moodFor(fill),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: IgnorePointer(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _ConnectQuietLine(message: quietLine),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Back, in the first place of the top bar. It is there only while Back is
/// offered, never greyed out, and the tracker slides along to make room.
class _BackSlot extends StatelessWidget {
  const _BackSlot({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return AnimatedSize(
      duration: context.motion(AppDurations.slow),
      curve: AppCurves.easeOut,
      alignment: AlignmentDirectional.centerStart,
      child: onPressed == null
          ? const SizedBox(height: 40)
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: Spacing.s3),
              child: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.common_back.tr(),
                onPressed: onPressed,
              ),
            ),
    );
  }
}

/// A word or three about the connect running behind the user. The small
/// face beside the tracker does the watching, so there is no face in here.
/// Fades in and out; holds still under reduce motion.
class _ConnectQuietLine extends StatelessWidget {
  const _ConnectQuietLine({required this.message});

  final String? message;

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
          : Semantics(
              key: ValueKey('connect-quiet-$line'),
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The shell sits above every route, so there is no text
                  // style to inherit here.
                  style: AppTypography.small(
                    colors.ink,
                  ).copyWith(decoration: TextDecoration.none),
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
          // A failure has its reason under "Could not connect". With no
          // failure to name, the step is simply missing its server.
          title: backgroundConnectLine(state) == null
              ? LocaleKeys.onboarding_connect_background_no_server_title.tr()
              : LocaleKeys.onboarding_connect_background_failed_title.tr(),
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

/// What stands in for a step: the face, one card with the line and the way
/// back to the connect step, and the way out.
class _ConnectGateScreen extends StatelessWidget {
  const _ConnectGateScreen({
    required this.message,
    required this.face,
    required this.connect,
    this.title,
    super.key,
  });

  /// What is wrong, in a few words. Null for a wait, which is one line.
  final String? title;
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
    final face = this.face;
    // The same scaffold as the steps it stands in for, so the face, the
    // buttons and their insets sit where they do on every other step.
    return AppScreenScaffold(
      backgroundColor: Colors.transparent,
      withGhosts: false,
      withFades: false,
      hasTabBar: false,
      topBar: AppTopBar(title: setupTopBarTitle(context)),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            // One card either way: the wait and its line, or the reason
            // and the one button back to the connect step.
            child: face == null
                ? SetupProblemCard.waiting(message: message)
                : SetupProblemCard(
                    face: face,
                    title: title,
                    line: message,
                    actionLabel: LocaleKeys
                        .onboarding_connect_background_failed_button
                        .tr(),
                    onAction: () =>
                        context.go(OnboardingEntryPoint.connectServer),
                  ),
          ),
        ),
      ],
    );
  }
}
