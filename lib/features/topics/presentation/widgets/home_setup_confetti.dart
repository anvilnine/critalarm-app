import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:flutter/material.dart';

/// One short throw of confetti over Home when the checklist finishes, the
/// same two side bursts the acknowledged screen uses. Under reduce motion
/// nothing is thrown. Brand colours only, no crit red.
class HomeSetupConfetti extends StatefulWidget {
  const HomeSetupConfetti({super.key});

  @override
  State<HomeSetupConfetti> createState() => _HomeSetupConfettiState();
}

class _HomeSetupConfettiState extends State<HomeSetupConfetti> {
  final _left = ConfettiController(duration: const Duration(seconds: 1));
  final _right = ConfettiController(duration: const Duration(seconds: 1));
  bool _started = false;

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) return;
    AppHaptics.success();
    _left.play();
    _right.play();
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final palette = [c.yellow, c.cobalt, c.surface, c.highlight];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(-1, 0.35),
              child: ConfettiWidget(
                confettiController: _left,
                blastDirection: -math.pi / 3,
                emissionFrequency: 0.08,
                numberOfParticles: 12,
                maxBlastForce: 45,
                minBlastForce: 20,
                gravity: 0.25,
                colors: palette,
              ),
            ),
            Align(
              alignment: const Alignment(1, 0.35),
              child: ConfettiWidget(
                confettiController: _right,
                blastDirection: -2 * math.pi / 3,
                emissionFrequency: 0.08,
                numberOfParticles: 12,
                maxBlastForce: 45,
                minBlastForce: 20,
                gravity: 0.25,
                colors: palette,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
