import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_player.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/widgets.dart';

export 'package:critalarm/core/ui_sound/paywall_cues.dart' show PaywallCue;
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';

/// Plays one cue of the palette: its sound and its haptic together.
void playPaywallCue(PaywallCue cue) => getIt<PaywallCues>().play(cue);

/// Plays a layout's cues as its clock passes them. It draws nothing of
/// its own.
///
/// - Each of [beats] plays once, on the tick [clock] passes its second.
/// - With a [player] and a [turnCue], a change of benefit the loop makes
///   by itself plays [turnCue], through the first pass only and never once
///   the hand has taken over.
/// - Nothing plays when nothing may move, or in a thumbnail
///   (`PaywallMuted`), or once the step after a purchase has begun.
/// - After an intro the beats of the first moments are left out: the
///   intro's last cue still has the room.
///
/// Wrap a layout's composition in it. The seconds are the layout's own,
/// taken from its timeline, so a cue never fires on a rebuild.
class PaywallCueScore extends StatefulWidget {
  const PaywallCueScore({
    required this.clock,
    required this.child,
    this.beats = const [],
    this.player,
    this.turnCue,
    super.key,
  });

  final PaywallClock clock;
  final List<PaywallCueBeat> beats;

  /// The loop whose changes [turnCue] marks.
  final HeroPlayer? player;
  final PaywallCue? turnCue;
  final Widget child;

  @override
  State<PaywallCueScore> createState() => _PaywallCueScoreState();
}

class _PaywallCueScoreState extends State<PaywallCueScore> {
  late double _before = widget.clock.value;
  late final bool _isMuted = PaywallMuted.of(context);

  /// The clock second the turn on stage began, as last seen.
  double? _turn;

  /// How long the intro before this layout keeps it quiet.
  double get _quietUntil {
    final play = PaywallIntroPlay.peek(context);
    if (play == null || play.intro == PaywallIntroId.none) return 0;
    return play.handle.quietFor;
  }

  void _onTick() {
    final clock = widget.clock;
    final now = clock.value;
    final before = _before;
    _before = now;
    if (_isMuted || clock.isStill) return;
    // The step after a purchase has the sound once it has begun.
    if (PaywallThanksPlay.hasBegun(context)) return;

    final cues = paywallCuesBetween(
      widget.beats,
      before,
      now,
      quietUntil: _quietUntil,
    );
    final player = widget.player;
    final turnCue = widget.turnCue;
    var turns = false;
    if (player != null && turnCue != null) {
      final began = player.frameAt(now).turn;
      turns = paywallTurnCues(
        began: began,
        was: _turn,
        entranceEnd: player.loop.entranceEnd,
        period: player.loop.period,
        touched: player.hand != null,
      );
      _turn = began;
    }
    cues.forEach(playPaywallCue);
    if (turns && turnCue != null) playPaywallCue(turnCue);
  }

  @override
  void initState() {
    super.initState();
    widget.clock.addListener(_onTick);
  }

  @override
  void didUpdateWidget(PaywallCueScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.clock, widget.clock)) return;
    oldWidget.clock.removeListener(_onTick);
    widget.clock.addListener(_onTick);
    _before = widget.clock.value;
    _turn = null;
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
