import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

/// One line of a [ProofList]: a few words, and whether the alarm proved
/// them.
typedef ProofListLine = ({String text, bool isProved});

/// The short list under "It works": one line per thing the alarm proved,
/// each with a tick, and one muted line with no tick for each thing it did
/// not.
///
/// The ticks draw one after another, once, when the list first shows. With
/// animations switched off they are all there from the first frame.
///
/// It sits straight on the acknowledged canvas, so it takes the canvas
/// text colours.
class ProofList extends StatefulWidget {
  const ProofList({required this.lines, super.key});

  final List<ProofListLine> lines;

  @override
  State<ProofList> createState() => _ProofListState();
}

class _ProofListState extends State<ProofList> {
  /// How many of the proved lines have their tick.
  int _ticked = 0;
  Timer? _timer;
  bool _started = false;

  int get _provedCount => widget.lines.where((line) => line.isProved).length;

  // Started here rather than in initState because it reads MediaQuery.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final step = context.motion(AppDurations.base);
    if (step == Duration.zero) {
      _ticked = _provedCount;
      return;
    }
    // The screen settles first, then one tick per beat.
    _timer = Timer(step * 2, () => _tickNext(step));
  }

  void _tickNext(Duration step) {
    if (!mounted) return;
    setState(() => _ticked++);
    if (_ticked < _provedCount) {
      _timer = Timer(step, () => _tickNext(step));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    var provedSoFar = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, line) in widget.lines.indexed) ...[
          if (index > 0) const SizedBox(height: Spacing.s3),
          _ProofRow(
            line: line,
            isTicked: line.isProved && provedSoFar++ < _ticked,
            colors: colors,
          ),
        ],
      ],
    );
  }
}

class _ProofRow extends StatelessWidget {
  const _ProofRow({
    required this.line,
    required this.isTicked,
    required this.colors,
  });

  final ProofListLine line;
  final bool isTicked;
  final AppColors colors;

  static const double _markSize = 26;

  @override
  Widget build(BuildContext context) {
    final muted = colors.onCanvas.withValues(alpha: 0.72);
    return Semantics(
      container: true,
      label: line.text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (line.isProved)
              AppAnimatedTick(
                done: isTicked,
                size: _markSize,
                // On this canvas the highlight is the canvas, so the disc
                // takes the text colour and the tick the canvas.
                fillColor: colors.onCanvas,
                tickColor: colors.canvas,
                ringColor: colors.onCanvas.withValues(alpha: 0.5),
              )
            else
              // No tick and no ring: a dash, so it cannot be read as a
              // tick that has not drawn yet.
              SizedBox.square(
                dimension: _markSize,
                child: Center(
                  child: AppGlyph(GlyphType.minus, size: 16, color: muted),
                ),
              ),
            const SizedBox(width: Spacing.s3),
            Flexible(
              child: Text(
                line.text,
                style: AppTypography.body(
                  line.isProved ? colors.onCanvas : muted,
                  fontSize: 18,
                ).copyWith(fontWeight: FontWeight.w600, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
