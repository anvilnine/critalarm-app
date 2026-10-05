import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

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
    super.key,
  });

  /// The whole command. Lines are broken by the caller.
  final String command;

  /// How many characters of [command] are on screen.
  final int typed;
  final bool isCaretOn;

  static const Color _panel = Color(0xFF1C1917);
  static const Color _dot = Color(0xFF57534E);
  static const Color _text = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mono = AppTypography.mono(_text, fontSize: 12);
    final shown = typed.clamp(0, command.length);

    return Container(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: mono,
                children: [
                  TextSpan(
                    text: r'$ ',
                    style: mono.copyWith(color: colors.yellow),
                  ),
                  TextSpan(text: command.substring(0, shown)),
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
            ),
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
  bool _started = false;

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final duration = context.motion(widget.typeFor);
    if (widget.isFinished || duration == Duration.zero) {
      _typing.value = 1;
      return;
    }
    _typing.duration = duration;
    unawaited(_typing.forward());
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
          typed: (_typing.value * widget.command.length).floor(),
          isCaretOn: true,
        ),
      ),
    );
  }
}
