import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/shake_count.dart';
import 'package:critalarm/features/challenges/domain/shake_session.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shake the phone thirty times, with Crit getting dizzier on every one.
///
/// The count comes from the accelerometer through `ShakeCounter`
/// (`shake_count.dart` has the rule and its numbers), and `ShakeSession`
/// owns the sensor: on while this is on screen with the app in front, off
/// the moment it is passed, left, skipped or covered by another app.
///
/// Shaking is never the only way. A button to tap thirty times takes its
/// place from the start with a screen reader or reduce motion, and by
/// itself when the phone has no sensor or the sensor says nothing for five
/// seconds. It reads nothing from the alarm, and it plays no haptic and no
/// sound.
final class ShakeChallenge implements Challenge {
  const ShakeChallenge();

  @override
  ChallengeKind get kind => ChallengeKind.shake;

  @override
  String get nameKey => LocaleKeys.challenges_shake_name;

  @override
  String get promptKey => LocaleKeys.challenges_shake_prompt;

  /// A shake needs nothing from the alarm. Whether the phone can feel one
  /// is not known until the sensor is asked, and taps cover a phone that
  /// cannot.
  @override
  bool canRunFor(ChallengeIncident incident) => true;

  @override
  Widget build(BuildContext context, ChallengeRun run) => _Shake(run: run);
}

/// The face Crit wears for each mood of the run.
FaceState _faceFor(ShakeMood mood) => switch (mood) {
  ShakeMood.ready => FaceState.watching,
  ShakeMood.jolted => FaceState.surprised,
  ShakeMood.squeezed => FaceState.working,
  ShakeMood.dizzy => FaceState.dizzy,
};

class _Shake extends StatefulWidget {
  const _Shake({required this.run});

  final ChallengeRun run;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// The ring around the face, and the face inside it.
  static const double _ringSize = 168;
  static const double _faceSize = 116;

  /// Null on a Personalize picture, which starts no sensor and counts
  /// nothing.
  ShakeSession? _session;

  /// One rock of the face per shake. It always ends at zero.
  late final AnimationController _rock = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  );

  bool _didOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.run.isPicture) return;
    _session = ShakeSession(
      sensor: getIt<MotionSensor>(),
      onChanged: _counted,
      onPassed: widget.run.onPassed,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = _session;
    if (session == null) return;
    final onTaps = shakeOpensOnTaps(
      hasAssistiveNavigation: MediaQuery.accessibleNavigationOf(context),
      reducesMotion: context.reduceMotion,
    );
    if (!_didOpen) {
      _didOpen = true;
      final state = WidgetsBinding.instance.lifecycleState;
      session.open(
        onTaps: onTaps,
        isInFront: state == null || state == AppLifecycleState.resumed,
      );
    } else if (onTaps) {
      // A screen reader or reduce motion came on with the challenge open.
      session.useTaps();
    }
  }

  /// The sensor runs only while the app is the one in front. Control
  /// Centre, a call, the app switcher and the lock screen all turn it off.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _session?.appMoved(isInFront: state == AppLifecycleState.resumed);
  }

  void _counted() {
    if (!mounted) return;
    setState(() {});
    if (!context.reduceMotion) unawaited(_rock.forward(from: 0));
  }

  @override
  void dispose() {
    // Left, skipped, passed or covered: whatever took the challenge off the
    // screen, the sensor is off before anything else.
    _session?.close();
    WidgetsBinding.instance.removeObserver(this);
    _rock.dispose();
    super.dispose();
  }

  Widget _face(BuildContext context, int count) {
    final colors = context.appColors;
    // Crit is yellow here whatever the theme: the face is the point of
    // this challenge, and it sits on the acknowledged canvas.
    const palette = AppColors.light;
    final face = FaceWidget(
      state: _faceFor(shakeMoodFor(count)),
      size: _faceSize,
      isLive: !widget.run.isPicture,
      overrideFillColor: palette.faceFill,
      overrideStrokeColor: palette.faceStroke,
      overrideInkColor: palette.faceInk,
    );
    return SizedBox.square(
      dimension: _ringSize,
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: shakeProgress(count),
                  track: colors.canvasGhostStrong,
                  done: colors.onCanvas,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _rock,
              builder: (context, child) => Transform.rotate(
                angle: shakeRockAngle(count, _rock.value),
                child: child,
              ),
              child: face,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final session = _session;
    final count = session?.count ?? 0;
    final isOnTaps = session?.input == ShakeInput.taps;
    const target = '${ShakeRule.target}';
    final counted = LocaleKeys.challenges_shake_count.tr(
      namedArgs: {'count': '$count', 'target': target},
    );
    final hint = AppTypography.small(colors.onCanvas, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: ExcludeSemantics(child: _face(context, count))),
        const SizedBox(height: Spacing.s3),
        // The button says the count with a screen reader, so the number is
        // not read twice.
        ExcludeSemantics(
          excluding: isOnTaps,
          child: Text(
            counted,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppTypography.monoBold(colors.onCanvas, fontSize: 24),
          ),
        ),
        const SizedBox(height: Spacing.s2),
        if (isOnTaps) ...[
          Text(
            LocaleKeys.challenges_shake_hint_taps.tr(
              namedArgs: {'target': target},
            ),
            textAlign: TextAlign.center,
            style: hint,
          ),
          const SizedBox(height: Spacing.s3),
          Semantics(
            value: counted,
            child: AppButton(
              label: LocaleKeys.challenges_shake_tap.tr(),
              variant: AppButtonVariant.paper,
              isFullWidth: true,
              onPressed: session?.tap,
            ),
          ),
        ] else
          Text(
            LocaleKeys.challenges_shake_hint_shake.tr(),
            textAlign: TextAlign.center,
            style: hint,
          ),
      ],
    );
  }
}

/// The ring around the face: a quiet track, and over it how far the count
/// has come, starting at the top and going clockwise.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.done,
  });

  final double progress;
  final Color track;
  final Color done;

  static const double _width = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _width) / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, line);
    if (progress <= 0) return;
    line.color = done;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.done != done;
}
