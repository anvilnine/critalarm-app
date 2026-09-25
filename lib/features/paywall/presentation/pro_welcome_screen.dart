import 'dart:async';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where a purchase lands: three happy faces, confetti, one button.
///
/// The store has already said Pro by the time this opens, so the app is Pro
/// here. The server catches up in the background and never holds this screen.
///
/// The button starts the app over at home: it tells every screen that the
/// plan and the account changed, so each one reads them again, and `go('/')`
/// drops the old page stack.
class ProWelcomeScreen extends StatefulWidget {
  const ProWelcomeScreen({super.key});

  /// How long the faces, the words and the button take to arrive.
  static const entrance = Duration(milliseconds: 1600);

  @override
  State<ProWelcomeScreen> createState() => _ProWelcomeScreenState();
}

class _ProWelcomeScreenState extends State<ProWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ProWelcomeScreen.entrance,
  );

  /// A slow bob that keeps the faces alive once they have landed.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  final _leftBurst = ConfettiController(duration: const Duration(seconds: 2));
  final _rightBurst = ConfettiController(duration: const Duration(seconds: 2));
  final _topRain = ConfettiController(duration: const Duration(seconds: 4));

  bool _started = false;

  @override
  void initState() {
    super.initState();
    AppHaptics.success();
  }

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Under reduce motion the faces are simply there: no fly-in, no bob, no
    // confetti.
    if (context.reduceMotion) {
      _entrance.value = 1;
      return;
    }
    unawaited(_entrance.forward());
    unawaited(_bob.repeat(reverse: true));
    _topRain.play();
    // The side bursts go off as the middle face lands.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _leftBurst.play();
      _rightBurst.play();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _bob.dispose();
    _leftBurst.dispose();
    _rightBurst.dispose();
    _topRain.dispose();
    super.dispose();
  }

  void _finish() {
    AppHaptics.capture();
    appPlanChanges.bump();
    appAccountIdentityChanges.bump();
    context.go('/');
  }

  /// A slice of the entrance, eased.
  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final confettiColors = [
      colors.yellow,
      colors.cobalt,
      colors.highlight,
      colors.crit,
      colors.surface,
    ];

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _FaceRow(
                    bob: _bob,
                    left: _slice(0.05, 0.4, Curves.elasticOut),
                    middle: _slice(0, 0.35, Curves.elasticOut),
                    right: _slice(0.12, 0.47, Curves.elasticOut),
                  ),
                  const SizedBox(height: 36),
                  _Rise(
                    animation: _slice(0.4, 0.7, Curves.easeOutCubic),
                    child: Text(
                      LocaleKeys.paywall_welcome_title.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontDisplay,
                        fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: colors.onCanvas,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Rise(
                    animation: _slice(0.5, 0.8, Curves.easeOutCubic),
                    child: Text(
                      LocaleKeys.paywall_welcome_body.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 16,
                        height: 1.4,
                        color: colors.onCanvasMuted,
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  _Rise(
                    animation: _slice(0.7, 1, Curves.easeOutBack),
                    child: AppButton(
                      label: LocaleKeys.paywall_welcome_button.tr(),
                      isFullWidth: true,
                      size: AppButtonSize.lg,
                      onPressed: _finish,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _topRain,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 8,
              maxBlastForce: 12,
              minBlastForce: 4,
              gravity: 0.15,
              colors: confettiColors,
            ),
          ),
          Align(
            alignment: const Alignment(-1, 0.35),
            child: ConfettiWidget(
              confettiController: _leftBurst,
              blastDirection: -math.pi / 3,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
              maxBlastForce: 45,
              minBlastForce: 20,
              gravity: 0.25,
              colors: confettiColors,
            ),
          ),
          Align(
            alignment: const Alignment(1, 0.35),
            child: ConfettiWidget(
              confettiController: _rightBurst,
              blastDirection: -2 * math.pi / 3,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
              maxBlastForce: 45,
              minBlastForce: 20,
              gravity: 0.25,
              colors: confettiColors,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three faces in a row. The middle one is big and lands first; the two small
/// ones pop in on either side, tilted toward it.
class _FaceRow extends StatelessWidget {
  const _FaceRow({
    required this.bob,
    required this.left,
    required this.middle,
    required this.right,
  });

  final Animation<double> bob;
  final Animation<double> left;
  final Animation<double> middle;
  final Animation<double> right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Pop(
          scale: left,
          bob: bob,
          bobPhase: 0.5,
          child: const FaceWidget(
            state: FaceState.laughing,
            size: 72,
            tiltAngle: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        _Pop(
          scale: middle,
          bob: bob,
          bobPhase: 0,
          child: const FaceWidget(state: FaceState.success, size: 128),
        ),
        const SizedBox(width: 8),
        _Pop(
          scale: right,
          bob: bob,
          bobPhase: 1,
          child: const FaceWidget(
            state: FaceState.happy,
            size: 72,
            tiltAngle: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Scales a face up from nothing, then lets it float a few pixels.
class _Pop extends StatelessWidget {
  const _Pop({
    required this.scale,
    required this.bob,
    required this.bobPhase,
    required this.child,
  });

  final Animation<double> scale;
  final Animation<double> bob;

  /// Where in the bob this face starts, 0 to 1, so the three do not move in
  /// step.
  final double bobPhase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scale, bob]),
      builder: (context, child) {
        final t = (bob.value + bobPhase) % 1;
        final dy = math.sin(t * math.pi * 2) * 4;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale.value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Fades a child in while it slides up a little.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
