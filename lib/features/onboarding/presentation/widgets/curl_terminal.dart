import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/hero_haptic_cues.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/pages_above.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The terminal from the site hero: a dark card with three dots, a prompt,
/// as much of [command] as has been typed, and a caret.
///
/// It draws one moment and holds no clock. The How it rings story drives it
/// from its own timeline, and [TypedCurlTerminal] types it once.
class CurlTerminalCard extends StatelessWidget {
  const CurlTerminalCard({
    required this.command,
    required this.typed,
    required this.isCaretOn,
    this.wraps = false,
    super.key,
  });

  /// The whole command. Lines are broken by the caller.
  final String command;

  /// How many characters of [command] are on screen. Characters as a
  /// reader counts them, so a letter with an accent or an emoji in a topic
  /// name is typed whole and never cut in half.
  final int typed;
  final bool isCaretOn;

  /// False fits each line to the card by shrinking the type, for a command
  /// whose length is known to fit: the story's. True keeps the type at its
  /// size and wraps a long line, for a command built from the user's own
  /// address, which can be any length and still has to be read.
  final bool wraps;

  static const Color _panel = Color(0xFF1C1917);
  static const Color _dot = Color(0xFF57534E);
  static const Color _text = Color(0xFFFFFFFF);

  /// The first [count] characters of [text], whole.
  static String typedPart(String text, int count) {
    if (count <= 0) return '';
    return text.characters.take(count).toString();
  }

  /// How many characters [text] has, as [typedPart] counts them.
  static int lengthOf(String text) => text.characters.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mono = AppTypography.mono(_text, fontSize: 12);
    final line = Text.rich(
      TextSpan(
        style: mono,
        children: [
          TextSpan(
            text: r'$ ',
            style: mono.copyWith(color: colors.yellow),
          ),
          TextSpan(text: typedPart(command, typed)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 8,
              height: 15,
              color: isCaretOn ? colors.yellow : Colors.transparent,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: wraps ? double.infinity : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [_Dot(_dot), _Dot(_dot), _Dot(_dot)],
          ),
          const SizedBox(height: 10),
          if (wraps)
            line
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: line,
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// [CurlTerminalCard] typing [command] once.
///
/// The typing takes [typeFor]. With animations switched off nothing is
/// typed: the finished command is there from the first frame. A screen
/// reader gets [semanticLabel] and none of the keystrokes.
///
/// The phone ticks as it types and taps once when the command is whole,
/// with the same limits as the story terminal. Nothing plays when nothing
/// is typed, or while this screen is covered or the app is in the back.
class TypedCurlTerminal extends StatefulWidget {
  const TypedCurlTerminal({
    required this.command,
    required this.semanticLabel,
    this.typeFor = const Duration(milliseconds: 2600),
    this.isFinished = false,
    super.key,
  });

  final String command;
  final String semanticLabel;

  final Duration typeFor;

  /// Shows the end state with nothing typed, for a look at the screen.
  final bool isFinished;

  @override
  State<TypedCurlTerminal> createState() => _TypedCurlTerminalState();
}

class _TypedCurlTerminalState extends State<TypedCurlTerminal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing = AnimationController(vsync: this);
  late final int _length = CurlTerminalCard.lengthOf(widget.command);
  bool _started = false;

  /// The haptic cues of the typing, or null when nothing is typed.
  HeroCueClock? _cueClock;
  double _typeSeconds = 0;
  List<ModalRoute<Object?>> _pagesAbove = const [];

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pagesAbove = pagesAbove(context);
    if (_started) return;
    _started = true;
    final duration = context.motion(widget.typeFor);
    if (widget.isFinished || duration == Duration.zero) {
      _typing.value = 1;
      return;
    }
    _typeSeconds = duration.inMicroseconds / 1e6;
    _cueClock = HeroCueClock(
      typingCues(
        length: _length,
        isAndroid: defaultTargetPlatform == TargetPlatform.android,
        startsAt: 0,
        takes: _typeSeconds,
      ),
    );
    _typing
      ..addListener(_playCues)
      ..duration = duration;
    unawaited(_typing.forward());
  }

  /// Whether a haptic may play right now: this screen is the one on top and
  /// the app is in front.
  bool get _canPlayHaptics {
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    return mounted &&
        isOnTopOfAll(_pagesAbove) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  void _playCues() {
    // The clock moves on every frame, allowed to play or not, so a cue that
    // was missed is never kept for later.
    final cues = _cueClock?.advanceTo(_typing.value * _typeSeconds);
    if (cues == null || !_canPlayHaptics) return;
    for (final cue in cues) {
      if (cue == HeroCue.typeTick) AppHaptics.tick();
      if (cue == HeroCue.commandSent) AppHaptics.lightTap();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _typing,
        builder: (context, _) => CurlTerminalCard(
          command: widget.command,
          typed: (_typing.value * _length).floor(),
          isCaretOn: true,
          // The user's own address: any length, and it has to be read.
          wraps: true,
        ),
      ),
    );
  }
}
