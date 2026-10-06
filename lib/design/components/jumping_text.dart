import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';

/// How long one letter takes to go up and land.
const Duration letterHopDuration = Duration(milliseconds: 360);

/// How long each letter waits after the one before it.
const Duration letterHopStagger = Duration(milliseconds: 22);

/// How high letter [index] is, [elapsed] into a run where letters hop one
/// after another: 0 on the line, 1 at the top of its hop. The same number
/// says how much of the gradient colour the letter wears.
double letterHop(Duration elapsed, int index) {
  final start = letterHopStagger * index;
  final local =
      (elapsed - start).inMicroseconds / letterHopDuration.inMicroseconds;
  if (local <= 0 || local >= 1) return 0;
  return math.sin(math.pi * local);
}

/// How far letter [index] is through leaving, [elapsed] into a run where
/// letters leave one after another: 0 still in place, 1 gone.
double letterLeave(Duration elapsed, int index) {
  final start = letterHopStagger * index;
  final local =
      (elapsed - start).inMicroseconds / letterHopDuration.inMicroseconds;
  return local.clamp(0.0, 1.0);
}

/// The colour at [position] (0 to 1) along a gradient through [stops].
Color gradientAt(List<Color> stops, double position) {
  if (stops.length == 1) return stops.first;
  final scaled = position.clamp(0.0, 1.0) * (stops.length - 1);
  final i = scaled.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
}

/// Text whose letters hop one after another when it changes, wearing a
/// gradient colour at the top of each hop. With [wave] on, a slow wave keeps
/// rolling through the letters until it is turned off.
///
/// When the new text is the old text with its start cut off, only the cut
/// letters move: they hop up, fade and shrink away, and the rest slides over.
///
/// The first text shown does not hop, so opening a screen stays calm. Wraps
/// between words, never inside one. Screen readers get the whole line once.
class JumpingText extends StatefulWidget {
  /// Shows [text] in [style]; hops wear [gradient] from the first letter to
  /// the last.
  const JumpingText(
    this.text, {
    required this.style,
    required this.gradient,
    this.wave = false,
    super.key,
  });

  /// The line to show.
  final String text;

  /// Style for every letter. Its colour is the resting colour.
  final TextStyle style;

  /// Colours a letter wears mid-hop, spread across the line.
  final List<Color> gradient;

  /// Keeps a slow wave rolling through the letters, for "still working".
  final bool wave;

  @override
  State<JumpingText> createState() => _JumpingTextState();
}

class _JumpingTextState extends State<JumpingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hops = AnimationController(vsync: this);

  /// How high a full hop goes, in logical pixels. The wave goes half as high.
  static const double _lift = 6;

  /// The pause between two waves, so a wave reads as a wave.
  static const Duration _wavePause = Duration(milliseconds: 500);

  /// The old text, shown while its first [_leaving] letters leave.
  String? _outgoing;
  int _leaving = 0;

  String get _shown => _outgoing ?? widget.text;

  int get _letterCount => _shown.length;

  Duration get _runLength =>
      letterHopDuration + letterHopStagger * math.max(0, _letterCount - 1);

  @override
  void initState() {
    super.initState();
    if (widget.wave) _play();
  }

  @override
  void didUpdateWidget(covariant JumpingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.text;
    final cutFromStart =
        old.length > widget.text.length && old.endsWith(widget.text);
    if (old != widget.text && cutFromStart && !widget.wave) {
      _leave(old);
    } else if (old != widget.text || oldWidget.wave != widget.wave) {
      _play();
    }
  }

  void _leave(String old) {
    _outgoing = old;
    _leaving = old.length - widget.text.length;
    _hops.duration =
        letterHopDuration + letterHopStagger * math.max(0, _leaving - 1);
    unawaited(
      _hops.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        // Back to the start, or the letters that stay would be drawn at the
        // leave's end time and freeze partway through a hop.
        _hops.value = 0;
        setState(() => _outgoing = null);
      }),
    );
  }

  void _play() {
    _outgoing = null;
    if (widget.wave) {
      _hops.duration = _runLength + _wavePause;
      _hops.value = 0;
      unawaited(_hops.repeat());
    } else {
      _hops.duration = _runLength;
      unawaited(_hops.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _hops.dispose();
    super.dispose();
  }

  Widget _letters() {
    final elapsed = (_hops.duration ?? Duration.zero) * _hops.value;
    final lift = widget.wave ? _lift / 2 : _lift;
    final resting =
        widget.style.color ?? DefaultTextStyle.of(context).style.color!;
    final last = math.max(1, _letterCount - 1);

    // Each word keeps its trailing space, so the Wrap breaks only between
    // words and the spacing stays the font's own.
    final words = _shown.split(' ');
    var index = 0;
    return Wrap(
      children: [
        for (var w = 0; w < words.length; w++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final letter
                  in (w < words.length - 1 ? '${words[w]} ' : words[w])
                      .split(''))
                if (_outgoing != null && index < _leaving)
                  _leavingLetter(letter, index++, elapsed, resting, last)
                else if (_outgoing != null)
                  _still(letter, index++)
                else
                  _letter(letter, index++, elapsed, lift, resting, last),
            ],
          ),
      ],
    );
  }

  Widget _letter(
    String letter,
    int index,
    Duration elapsed,
    double lift,
    Color resting,
    int last,
  ) {
    final hop = letterHop(elapsed, index);
    final tint = gradientAt(widget.gradient, index / last);
    return Transform.translate(
      offset: Offset(0, -hop * lift),
      child: Text(
        letter,
        style: widget.style.copyWith(color: Color.lerp(resting, tint, hop)),
      ),
    );
  }

  Widget _still(String letter, int index) => Text(letter, style: widget.style);

  Widget _leavingLetter(
    String letter,
    int index,
    Duration elapsed,
    Color resting,
    int last,
  ) {
    final out = letterLeave(elapsed, index);
    final tint = gradientAt(widget.gradient, index / last);
    // Shrinking the width is what slides the rest of the line over.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1 - Curves.easeInOut.transform(out),
      child: Opacity(
        opacity: 1 - out,
        child: Transform.translate(
          offset: Offset(0, -out * _lift),
          child: Text(
            letter,
            style: widget.style.copyWith(
              color: Color.lerp(resting, tint, math.sin(math.pi * out)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return AnimatedSwitcher(
        duration: AppDurations.base,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: Text(
          widget.text,
          key: ValueKey(widget.text),
          style: widget.style,
        ),
      );
    }

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _hops,
          builder: (context, _) => _letters(),
        ),
      ),
    );
  }
}
