part of 'critical_alarm_screen.dart';

/// Holds the confetti back until the screen knows it may fly.
///
/// The setup test reads `OnboardingOfferGate.outlook()` once, when the screen
/// appears, and keeps the answer. The read is local and cached: the store
/// check started with the real alarm step, and the answer is never waited
/// for. While the read is out, nothing is built, so no confetti flies and no
/// haptic plays (the haptic starts with the confetti). When an offer follows
/// and the store said it is on sale, the screen stays calm. When no offer
/// follows, and when the store had not answered, the confetti starts a few
/// frames after the screen opened. Every other exit builds it at once. See
/// [ackConfettiMayFly].
class _AckConfettiGate extends StatefulWidget {
  const _AckConfettiGate({
    required this.exits,
    required this.colors,
    this.setupProved = true,
  });

  final AckedExits exits;
  final AppColors colors;

  /// See [ackConfettiMayFly].
  final bool setupProved;

  @override
  State<_AckConfettiGate> createState() => _AckConfettiGateState();
}

class _AckConfettiGateState extends State<_AckConfettiGate> {
  /// Null until the gate has answered. Stays null for an exit that never asks.
  OfferOutlook? _offer;

  @override
  void initState() {
    super.initState();
    if (widget.exits == AckedExits.continueSetup) unawaited(_readOffer());
  }

  Future<void> _readOffer() async {
    OfferOutlook offer;
    try {
      offer = await getIt<OnboardingOfferGate>().outlook();
    } on Object {
      // The gate answers none itself when it cannot work it out.
      offer = OfferOutlook.none;
    }
    if (!mounted) return;
    setState(() => _offer = offer);
  }

  @override
  Widget build(BuildContext context) {
    final mayFly = ackConfettiMayFly(
      exits: widget.exits,
      offer: _offer,
      reduceMotion: context.reduceMotion,
      setupProved: widget.setupProved,
    );
    if (!mayFly) return const SizedBox.shrink();
    return _AckConfetti(colors: widget.colors);
  }
}

/// Two confetti bursts that fire once when the demo's acknowledged screen
/// appears. Under reduce motion nothing is thrown. Brand colours only, no
/// crit red.
class _AckConfetti extends StatefulWidget {
  const _AckConfetti({required this.colors});

  final AppColors colors;

  @override
  State<_AckConfetti> createState() => _AckConfettiState();
}

class _AckConfettiState extends State<_AckConfetti> {
  final _left = ConfettiController(duration: const Duration(seconds: 2));
  final _right = ConfettiController(duration: const Duration(seconds: 2));
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
    final c = widget.colors;
    final palette = [c.yellow, c.cobalt, c.surface, c.highlight];
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1, 0.35),
            child: ConfettiWidget(
              confettiController: _left,
              blastDirection: -math.pi / 3,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
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
              numberOfParticles: 14,
              maxBlastForce: 45,
              minBlastForce: 20,
              gravity: 0.25,
              colors: palette,
            ),
          ),
        ],
      ),
    );
  }
}
