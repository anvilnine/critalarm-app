import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence/sentence_rules.dart';
import 'package:flutter/widgets.dart';

/// An ending rolls into the sentence: one tick and one light tap. Played
/// when the first ending lands in the entrance, and when the hand rolls to
/// another. The loop rolling by itself is silent.
void sentenceRollCue() {
  AppHaptics.selection();
  getIt<PaywallCues>().tick();
}

/// Calls [onReached] once, on the frame [clock] passes the second [at].
///
/// Nothing is called when nothing may move, or in a thumbnail. A clock
/// that starts again plays the moment again.
class SentenceMoment extends StatefulWidget {
  const SentenceMoment({
    required this.clock,
    required this.at,
    required this.onReached,
    required this.child,
    super.key,
  });

  final PaywallClock clock;
  final double at;
  final VoidCallback onReached;
  final Widget child;

  @override
  State<SentenceMoment> createState() => _SentenceMomentState();
}

class _SentenceMomentState extends State<SentenceMoment> {
  late double _before = widget.clock.value;
  late final bool _isMuted = PaywallMuted.of(context);

  void _onTick() {
    final clock = widget.clock;
    final now = clock.value;
    final reached = sentenceReached(_before, now, widget.at);
    _before = now;
    if (reached && !clock.isStill && !_isMuted) widget.onReached();
  }

  @override
  void initState() {
    super.initState();
    widget.clock.addListener(_onTick);
  }

  @override
  void didUpdateWidget(SentenceMoment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.clock, widget.clock)) return;
    oldWidget.clock.removeListener(_onTick);
    widget.clock.addListener(_onTick);
    _before = widget.clock.value;
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
