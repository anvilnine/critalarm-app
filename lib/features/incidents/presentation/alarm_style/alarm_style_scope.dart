import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The look the alarm screen under it is drawn in.
///
/// `RingingScreen` and `AcknowledgedScreen` read it for everything a look
/// may change. With no scope above them they draw the standard look.
class AlarmStyleScope extends InheritedWidget {
  const AlarmStyleScope({
    required this.style,
    required super.child,
    super.key,
  });

  final AlarmStyle style;

  static AlarmStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlarmStyleScope>()?.style ??
      standardAlarmStyle;

  @override
  bool updateShouldNotify(AlarmStyleScope oldWidget) =>
      oldWidget.style != style;
}

/// Draws [child], one stage of the alarm screen, in [style].
///
/// The one place a look is applied. It does three things and nothing
/// else:
///
/// - retints the palette under it with the look's colours for [stage],
///   the way `SeverityScope` does;
/// - puts the look's background painter behind [child], where it takes no
///   touch and a screen reader never meets it;
/// - sets the [AlarmStyleScope] the two screens read.
///
/// The tree it builds has the same shape whatever the colours are, so a
/// severity that changes mid-alarm keeps every widget under it mounted. A
/// look whose colours throw is drawn as the standard look for that build,
/// and a background that throws paints nothing: the alarm screen stays up.
///
/// The canvas is not drawn here. The owner hands the look's ambient
/// profile to the canvas it already has.
class AlarmStyleStage extends StatelessWidget {
  const AlarmStyleStage({
    required this.style,
    required this.stage,
    required this.severity,
    required this.child,
    this.isStill = false,
    super.key,
  });

  final AlarmStyle style;
  final AlarmStage stage;

  /// The incident's severity. The acknowledged stage is always drawn in
  /// the acknowledged one, whatever this says.
  final SeverityMode severity;

  /// Holds the background on its resting frame, for a picture of the
  /// screen that is not the screen.
  final bool isStill;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = context.appColors;
    var style = this.style;
    AppColors colors;
    try {
      colors = style.colorsFor(
        stage,
        base: base,
        severity: severity,
        brightness: theme.brightness,
      );
    } on Object catch (_) {
      // The owner checks a look before it gets here (`drawableAlarmStyle`).
      // This is the same answer for one that slipped past.
      style = standardAlarmStyle;
      colors = style.colorsFor(
        stage,
        base: base,
        severity: severity,
        brightness: theme.brightness,
      );
    }
    final backdrop = style.backdrop;
    Widget content = AlarmStyleScope(style: style, child: child);
    if (backdrop != null) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: _Backdrop(
                  painter: backdrop,
                  stage: stage,
                  colors: colors,
                  moves: style.backdropMoves && !isStill,
                ),
              ),
            ),
          ),
          content,
        ],
      );
    }
    // The palette a severity leaves alone is the app's own, and the theme
    // goes on unchanged. The Theme stays in the tree all the same.
    return Theme(
      data: identical(colors, base)
          ? theme
          : theme.copyWith(
              scaffoldBackgroundColor: colors.canvas,
              colorScheme: theme.colorScheme.copyWith(
                surface: colors.surface,
                onSurface: colors.onCanvas,
                primary: colors.highlight,
              ),
              extensions: [
                ...theme.extensions.values.where((ext) => ext is! AppColors),
                colors,
              ],
            ),
      child: content,
    );
  }
}

/// The painter of a look's background for [frame], or null when making it
/// throws. What it paints is guarded too: a throw in the middle of a paint
/// ends that paint and nothing else.
CustomPainter? guardedAlarmBackdrop(
  AlarmBackdropPainter painter,
  AlarmBackdropFrame frame,
) {
  try {
    return _GuardedPainter(painter(frame));
  } on Object catch (_) {
    return null;
  }
}

class _GuardedPainter extends CustomPainter {
  const _GuardedPainter(this._inner);

  final CustomPainter _inner;

  @override
  void paint(Canvas canvas, Size size) {
    // Whatever the painter left half done (a save, a clip) is undone, so
    // nothing of it reaches the alarm screen drawn over it.
    final saves = canvas.getSaveCount();
    try {
      _inner.paint(canvas, size);
    } on Object catch (_) {
      // Nothing more is painted this frame.
    } finally {
      canvas.restoreToCount(saves);
    }
  }

  @override
  bool shouldRepaint(covariant _GuardedPainter oldDelegate) {
    try {
      return _inner.shouldRepaint(oldDelegate._inner);
    } on Object catch (_) {
      return true;
    }
  }
}

/// A look's background. One resting frame under reduce motion and for a
/// look that does not move, else a frame per tick.
class _Backdrop extends StatefulWidget {
  const _Backdrop({
    required this.painter,
    required this.stage,
    required this.colors,
    required this.moves,
  });

  final AlarmBackdropPainter painter;
  final AlarmStage stage;
  final AppColors colors;
  final bool moves;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    setState(() => _elapsed = elapsed);
  });
  Duration _elapsed = Duration.zero;
  bool _reduceMotion = false;

  bool get _animating => widget.moves && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Backdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_animating && !_ticker.isActive) {
      unawaited(_ticker.start());
    } else if (!_animating && _ticker.isActive) {
      _ticker.stop();
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStill = !_animating;
    return RepaintBoundary(
      child: CustomPaint(
        painter: guardedAlarmBackdrop(
          widget.painter,
          AlarmBackdropFrame(
            stage: widget.stage,
            colors: widget.colors,
            elapsed: isStill ? Duration.zero : _elapsed,
            isStill: isStill,
          ),
        ),
      ),
    );
  }
}
