import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_anchor.dart';
import 'package:critalarm/features/tour/presentation/tour_layout.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Runs the "How to use the app" tour over the whole app.
///
/// For each step it opens the right screen, waits until that screen has
/// finished arriving, scrolls the spot into view, waits for it to stop
/// moving, and only then draws the spotlight. Until then the screen is dimmed
/// with no spotlight, so a half-drawn page is never pointed at.
///
/// While the tour is up, every tap on the app is swallowed. Only the card's
/// own buttons work, so tapping a spotlit button can never navigate away in
/// the middle of a step.
class TourHost extends StatefulWidget {
  const TourHost({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  @override
  State<TourHost> createState() => _TourHostState();
}

class _TourHostState extends State<TourHost> {
  /// How long a step waits for its spot to turn up before it is skipped.
  static const Duration _findTimeout = Duration(seconds: 5);

  /// How long a step waits for its spot to stop moving. After this it is
  /// drawn where it is.
  static const Duration _settleTimeout = Duration(seconds: 3);

  /// Frames in a row the spot must hold still before it counts as settled.
  static const int _stillFrames = 3;

  /// How often a drawn spotlight checks that its spot has not moved.
  static const Duration _followEvery = Duration(milliseconds: 250);

  /// Room the floating tab bar takes at the bottom of the screen.
  static const double _bottomBarRoom = 110;

  final TourCubit _tour = getIt<TourCubit>();
  StreamSubscription<TourState>? _sub;

  /// Where the spotlight is. Null while the tour is moving between spots.
  Rect? _hole;

  /// The last spotlight drawn, so the next one closes into its middle
  /// rather than into a corner.
  Rect? _lastHole;

  /// Goes up on every step change, so a wait for an old step gives up.
  int _run = 0;

  /// True while the tour is moving to a step's screen. Route changes on the
  /// way there are the tour's own, not the user leaving.
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _sub = _tour.stream.listen(_onTour);
    widget.router.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  /// The page on top. The router's own address stays on the page underneath
  /// after a push, so it is read off the top page instead.
  String get _currentPath {
    final delegate = widget.router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return '';
    return delegate.state.uri.path;
  }

  void _onTour(TourState tour) {
    switch (tour.status) {
      case TourStatus.requested:
        unawaited(_begin());
      case TourStatus.running:
        unawaited(_showStep(tour.stepIndex));
      case TourStatus.idle:
        _run++;
        _moving = false;
        if (mounted) setState(() => _hole = null);
    }
  }

  /// An alarm always wins. If anything takes the user to the alarm screen,
  /// the tour gets out of the way.
  ///
  /// Any other move the tour did not make itself is the Android back button,
  /// since every tap is swallowed. That counts as skipping the tour. Android
  /// 15 does not ask the app about back on a screen with nothing to pop, so
  /// back cannot be turned into "previous step" reliably.
  void _onRoute() {
    final tour = _tour.state;
    if (tour.status == TourStatus.idle) return;
    final path = _currentPath;
    if (path.startsWith('/incidents') ||
        path == '/alarm' ||
        path == '/lockscreen' ||
        path.startsWith('/onboarding')) {
      _tour.stop();
      return;
    }
    if (tour.isRunning &&
        !_moving &&
        path != tourPath(tour.step.place, tour.topicName)) {
      _tour.finish();
    }
  }

  Future<void> _begin() async {
    final topics = getIt<TopicsCubit>();
    await topics.ensureLoaded();
    final list = topics.state.topics;
    _tour.begin(firstTopicName: list.isEmpty ? null : list.first.name);
  }

  Future<void> _showStep(int index) async {
    final run = ++_run;
    setState(() => _hole = null);

    final tour = _tour.state;
    final step = tour.step;
    final path = tourPath(step.place, tour.topicName);
    if (_currentPath != path) {
      _moving = true;
      if (step.place == TourPlace.createTopic) {
        // Opened over Topics, the way the + button opens it, so back lands
        // on Topics instead of closing the app.
        if (_currentPath != '/') widget.router.go('/');
        unawaited(widget.router.push<void>(path));
      } else {
        widget.router.go(path);
      }
    }

    final anchor = await _waitForAnchor(step.anchor, run);
    if (run == _run) _moving = false;
    if (run != _run || !mounted) return;
    if (anchor == null || !anchor.mounted) {
      _tour.skipMissing(index);
      return;
    }

    await _scrollIntoView(anchor);
    if (run != _run || !mounted) return;

    final rect = await _settledRect(step.anchor, run);
    if (run != _run || !mounted || rect == null) return;
    _place(rect);
    unawaited(_follow(step.anchor, run));
  }

  void _place(Rect rect) {
    setState(() {
      _hole = tourHoleFor(rect, MediaQuery.sizeOf(context));
      _lastHole = _hole;
    });
  }

  /// Keeps the spotlight on its spot after it is drawn. A screen can still
  /// shift once it has settled, such as a line of text above the spot
  /// loading in late and pushing it down.
  Future<void> _follow(TourAnchorId id, int run) async {
    while (true) {
      await Future<void>.delayed(_followEvery);
      if (run != _run || !mounted) return;
      final anchor = TourAnchors.visible(id);
      if (anchor == null || !anchor.mounted) continue;
      final rect = _rectOf(anchor);
      if (rect == null) continue;
      final hole = tourHoleFor(rect, MediaQuery.sizeOf(context));
      if (hole != _hole) _place(rect);
    }
  }

  /// The anchor, once its screen has finished its entrance.
  Future<BuildContext?> _waitForAnchor(TourAnchorId id, int run) async {
    final deadline = DateTime.now().add(_findTimeout);
    while (run == _run && DateTime.now().isBefore(deadline)) {
      final anchor = TourAnchors.visible(id);
      if (anchor != null && anchor.mounted && _routeArrived(anchor)) {
        return anchor;
      }
      await _nextFrame();
    }
    return null;
  }

  static bool _routeArrived(BuildContext anchor) {
    final route = ModalRoute.of(anchor);
    if (route == null) return true;
    final coming = route.animation;
    final covered = route.secondaryAnimation;
    return (coming == null || coming.status == AnimationStatus.completed) &&
        (covered == null || !covered.isAnimating);
  }

  Future<void> _scrollIntoView(BuildContext anchor) async {
    if (Scrollable.maybeOf(anchor) == null) return;
    final rect = _rectOf(anchor);
    final padding = MediaQuery.paddingOf(context);
    if (rect != null &&
        tourRectOnScreen(
          rect,
          MediaQuery.sizeOf(context),
          topInset: padding.top,
          bottomInset: padding.bottom + _bottomBarRoom,
        )) {
      return;
    }
    await Scrollable.ensureVisible(
      anchor,
      alignment: 0.3,
      duration: context.motion(AppDurations.slow),
      curve: AppCurves.easeOut,
    );
  }

  /// Where the anchor is once it has held still for a few frames in a row.
  Future<Rect?> _settledRect(TourAnchorId id, int run) async {
    final deadline = DateTime.now().add(_settleTimeout);
    Rect? last;
    var still = 0;
    while (run == _run) {
      final anchor = TourAnchors.visible(id);
      final rect = anchor == null || !anchor.mounted ? null : _rectOf(anchor);
      if (rect != null && rect == last) {
        still++;
        if (still >= _stillFrames) return rect;
      } else {
        still = 0;
      }
      last = rect;
      if (DateTime.now().isAfter(deadline)) return rect;
      await _nextFrame();
    }
    return null;
  }

  /// The anchor's box on screen. Goes through the full transform, so a bar
  /// scaled down to fit a narrow screen is measured at the size it is drawn.
  static Rect? _rectOf(BuildContext anchor) {
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  static Future<void> _nextFrame() {
    SchedulerBinding.instance.scheduleFrame();
    return SchedulerBinding.instance.endOfFrame;
  }

  void _next() {
    AppHaptics.selection();
    if (_tour.state.isLastStep) {
      _done();
    } else {
      _tour.next();
    }
  }

  void _back() {
    AppHaptics.selection();
    _tour.back();
  }

  /// Skip and the last step's button. Both hand the user back to Topics.
  void _done() {
    _tour.finish();
    widget.router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        StreamBuilder<TourState>(
          stream: _tour.stream,
          initialData: _tour.state,
          builder: (context, snapshot) {
            final tour = snapshot.data ?? _tour.state;
            if (!tour.isRunning) return const SizedBox.shrink();
            return Positioned.fill(child: _overlay(tour));
          },
        ),
      ],
    );
  }

  Widget _overlay(TourState tour) {
    final screen = MediaQuery.sizeOf(context);
    final hole = _hole;

    return Stack(
      children: [
        // Swallows every touch that is not on the card.
        Positioned.fill(
          child: AbsorbPointer(
            // Between steps the old spotlight closes into its middle, and the
            // new one opens out of its own.
            child: TweenAnimationBuilder<Rect?>(
              // Never null: the builder cannot start from nothing. With no
              // spot yet, it is a zero size box, which draws as no hole.
              tween: RectTween(
                end:
                    hole ??
                    Rect.fromCenter(
                      center: (_lastHole ?? Offset.zero & screen).center,
                      width: 0,
                      height: 0,
                    ),
              ),
              duration: context.motion(AppDurations.base),
              curve: AppCurves.easeOut,
              builder: (context, rect, _) => CustomPaint(
                size: screen,
                painter: _ScrimPainter(
                  hole: rect,
                  scrim: Colors.black.withValues(alpha: 0.62),
                  ring: context.appColors.highlight,
                ),
              ),
            ),
          ),
        ),
        if (hole != null) _card(tour, hole, screen),
        // Always there, on every step, so leaving never depends on a back
        // button. iOS has none.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.panel,
              shape: BoxShape.circle,
              border: Border.all(color: context.appColors.panelLine),
            ),
            child: AppIconButton(
              glyph: GlyphType.close,
              ariaLabel: LocaleKeys.tour_skip.tr(),
              color: context.appColors.onPanel,
              onPressed: _done,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(TourState tour, Rect hole, Size screen) {
    final padding = MediaQuery.paddingOf(context);
    final above = tourCardGoesAbove(hole, screen);
    final width = (screen.width - 32).clamp(0.0, 420.0);
    final left = (screen.width - width) / 2;

    final card = _TourCard(
      key: ValueKey(tour.stepIndex),
      tour: tour,
      onNext: _next,
      onBack: tour.isFirstStep ? null : _back,
      onSkip: _done,
    );

    return above
        ? Positioned(
            left: left,
            width: width,
            bottom: (screen.height - hole.top + tourCardGap).clamp(
              padding.bottom + 16,
              screen.height,
            ),
            child: card,
          )
        : Positioned(
            left: left,
            width: width,
            top: (hole.bottom + tourCardGap).clamp(
              padding.top + 16,
              screen.height,
            ),
            child: card,
          );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    super.key,
  });

  final TourState tour;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = tour.step;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppDurations.medium),
      curve: AppCurves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: Radii.lgAll,
            border: Border.all(color: colors.panelLine),
            boxShadow: AppShadows.shadowLg(isDark: isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    LocaleKeys.tour_progress.tr(
                      namedArgs: {
                        'step': '${tour.stepIndex + 1}',
                        'count': '${TourCubit.stepCount}',
                      },
                    ),
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onPanelMuted,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      LocaleKeys.tour_skip.tr(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onPanelMuted,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                step.titleKey.tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: colors.onPanel,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.bodyKeyFor(usingExamples: tour.usingExamples).tr(),
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 14,
                  height: 1.4,
                  color: colors.onPanel,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onBack != null)
                    AppButton(
                      label: LocaleKeys.tour_back.tr(),
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      onPressed: onBack,
                    ),
                  const Spacer(),
                  AppButton(
                    label: tour.isLastStep
                        ? LocaleKeys.tour_done.tr()
                        : LocaleKeys.tour_next.tr(),
                    size: AppButtonSize.sm,
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims the screen and cuts a rounded hole where the spotlit widget is.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.hole,
    required this.scrim,
    required this.ring,
  });

  final Rect? hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final rect = hole;
    if (rect == null || rect.isEmpty) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final cut = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas
      ..drawPath(
        Path.combine(PathOperation.difference, screen, Path()..addRRect(cut)),
        Paint()..color = scrim,
      )
      ..drawRRect(
        cut,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring;
}
