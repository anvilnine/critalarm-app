import 'dart:math' as math;

import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:flutter/material.dart';

/// What a screen reader hears for the three parts of the editor. The screen
/// fills these in, so the component knows no strings. Each part has its
/// value now and the value one step up and one step down.
class CropEditorLabels {
  const CropEditorLabels({
    required this.window,
    required this.windowValue,
    required this.windowUp,
    required this.windowDown,
    required this.start,
    required this.startValue,
    required this.startUp,
    required this.startDown,
    required this.end,
    required this.endValue,
    required this.endUp,
    required this.endDown,
  });

  final String window;
  final String windowValue;
  final String windowUp;
  final String windowDown;
  final String start;
  final String startValue;
  final String startUp;
  final String startDown;
  final String end;
  final String endValue;
  final String endUp;
  final String endDown;
}

/// Screen reader steps. Each one moves by one fixed step, decided by the
/// screen.
class CropEditorNudges {
  const CropEditorNudges({
    required this.windowForward,
    required this.windowBack,
    required this.startForward,
    required this.startBack,
    required this.endForward,
    required this.endBack,
  });

  final VoidCallback windowForward;
  final VoidCallback windowBack;
  final VoidCallback startForward;
  final VoidCallback startBack;
  final VoidCallback endForward;
  final VoidCallback endBack;
}

/// The dark panel of the sound cropper: a thin strip of the whole file on
/// top, and a zoomed view of the selection under it with a trim handle at
/// each end.
///
/// Takes plain numbers only. Fractions on the strip are of the whole file.
/// Fractions in the zoomed view are of what the view shows, which is the
/// selection plus some room each side. Drags report where the thing being
/// dragged should now be, as a fraction of the same space.
class AppCropPanel extends StatelessWidget {
  const AppCropPanel({
    required this.overviewPeaks,
    required this.windowFrom,
    required this.windowTo,
    required this.onJump,
    required this.detailPeaks,
    required this.selectionFrom,
    required this.selectionTo,
    required this.labels,
    required this.nudges,
    required this.onMoveWindow,
    required this.onMoveStart,
    required this.onMoveEnd,
    this.contentFrom = 0,
    this.contentTo = 1,
    this.playhead,
    this.onDragStarted,
    this.onDragEnded,
    this.height = 300,
    super.key,
  });

  /// Bars for the whole file.
  final List<double> overviewPeaks;

  /// Where the selection sits on the strip, 0 to 1 of the file.
  final double windowFrom;
  final double windowTo;

  /// The user touched the strip at this fraction of the file.
  final ValueChanged<double> onJump;

  /// Bars for the zoomed view.
  final List<double> detailPeaks;

  /// Where the selection sits in the zoomed view, 0 to 1 of the view.
  final double selectionFrom;
  final double selectionTo;

  /// The part of the zoomed view the file covers. Near either end of the
  /// file the view runs past it, and no bars are drawn there.
  final double contentFrom;
  final double contentTo;

  /// 0 to 1 across the selection while playing, else null.
  final double? playhead;

  final CropEditorLabels labels;
  final CropEditorNudges nudges;

  /// Where the start of the selection should go, as a fraction of the view.
  final ValueChanged<double> onMoveWindow;
  final ValueChanged<double> onMoveStart;
  final ValueChanged<double> onMoveEnd;

  /// A drag began or ended. The screen holds the view still in between, so
  /// the frame does not slide away under the finger.
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(color: colors.panel, borderRadius: Radii.xlAll),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            width: double.infinity,
            child: _Minimap(
              peaks: overviewPeaks,
              from: windowFrom,
              to: windowTo,
              onJump: onJump,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _ZoomedEditor(panel: this),
          ),
        ],
      ),
    );
  }
}

class _Minimap extends StatelessWidget {
  const _Minimap({
    required this.peaks,
    required this.from,
    required this.to,
    required this.onJump,
  });

  final List<double> peaks;
  final double from;
  final double to;
  final ValueChanged<double> onJump;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, box) {
        void jump(Offset at) => onJump((at.dx / box.maxWidth).clamp(0.0, 1.0));
        // The zoomed editor below carries the same thing for screen readers.
        return ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => jump(d.localPosition),
            onHorizontalDragUpdate: (d) => jump(d.localPosition),
            child: CustomPaint(
              painter: _MinimapPainter(
                peaks: peaks,
                from: from,
                to: to,
                idle: colors.onPanel.withValues(alpha: .25),
                active: colors.onPanel.withValues(alpha: .9),
                frame: colors.cobaltOnDark,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
    required this.peaks,
    required this.from,
    required this.to,
    required this.idle,
    required this.active,
    required this.frame,
  });

  final List<double> peaks;
  final double from;
  final double to;
  final Color idle;
  final Color active;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final count = peaks.length;
    if (count > 0) {
      // Each bar gets an equal slot, so any number of bars fits the width.
      final slot = size.width / count;
      final width = math.max<double>(0.5, slot * .6);
      final dim = Paint()..color = idle;
      final lit = Paint()..color = active;
      for (var i = 0; i < count; i++) {
        final f = (i + .5) / count;
        final h = math.max<double>(
          2,
          peaks[i].clamp(0.0, 1.0) * (size.height - 4),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(i * slot, (size.height - h) / 2, width, h),
            Radius.circular(width / 2),
          ),
          f >= from && f <= to ? lit : dim,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          from * size.width - 2,
          0,
          math.max(to * size.width, from * size.width + 4) + 2,
          size.height,
        ),
        const Radius.circular(6),
      ),
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) =>
      old.from != from ||
      old.to != to ||
      old.idle != idle ||
      old.active != active ||
      old.frame != frame ||
      !identical(old.peaks, peaks);
}

class _ZoomedEditor extends StatefulWidget {
  const _ZoomedEditor({required this.panel});

  final AppCropPanel panel;

  @override
  State<_ZoomedEditor> createState() => _ZoomedEditorState();
}

enum _Drag { window, start, end }

class _ZoomedEditorState extends State<_ZoomedEditor> {
  /// Touch width of each handle, wider than it looks so a thumb finds it.
  static const handleHitWidth = 44.0;

  /// Where the dragged thing is, as a fraction of the view. Built up from
  /// the finger's movement, so the report never depends on where inside the
  /// hit area the finger landed.
  double _at = 0;

  void _begin(_Drag drag) {
    final panel = widget.panel;
    _at = drag == _Drag.end ? panel.selectionTo : panel.selectionFrom;
    panel.onDragStarted?.call();
  }

  void _update(_Drag drag, DragUpdateDetails details, double width) {
    if (width <= 0) return;
    _at += details.delta.dx / width;
    final panel = widget.panel;
    switch (drag) {
      case _Drag.window:
        panel.onMoveWindow(_at);
      case _Drag.start:
        panel.onMoveStart(_at);
      case _Drag.end:
        panel.onMoveEnd(_at);
    }
  }

  void _end() => widget.panel.onDragEnded?.call();

  Widget _dragArea(_Drag drag, double width, Widget child) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => _begin(drag),
    onHorizontalDragUpdate: (d) => _update(drag, d, width),
    onHorizontalDragEnd: (_) => _end(),
    onHorizontalDragCancel: _end,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final panel = widget.panel;
    final labels = panel.labels;
    final nudges = panel.nudges;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final x0 = panel.selectionFrom * width;
        final x1 = panel.selectionTo * width;
        const half = handleHitWidth / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EditorPainter(
                  peaks: panel.detailPeaks,
                  selectionFrom: panel.selectionFrom,
                  selectionTo: panel.selectionTo,
                  contentFrom: panel.contentFrom,
                  contentTo: panel.contentTo,
                  playhead: panel.playhead,
                  bar: colors.onPanel,
                  frame: colors.cobaltOnDark,
                ),
              ),
            ),
            Positioned(
              left: x0 + half,
              width: math.max(0, x1 - x0 - handleHitWidth),
              top: 0,
              bottom: 0,
              child: Semantics(
                slider: true,
                label: labels.window,
                value: labels.windowValue,
                increasedValue: labels.windowUp,
                decreasedValue: labels.windowDown,
                onIncrease: nudges.windowForward,
                onDecrease: nudges.windowBack,
                child: _dragArea(_Drag.window, width, const SizedBox.expand()),
              ),
            ),
            Positioned(
              left: x0 - half,
              width: handleHitWidth,
              top: 0,
              bottom: 0,
              child: Semantics(
                slider: true,
                label: labels.start,
                value: labels.startValue,
                increasedValue: labels.startUp,
                decreasedValue: labels.startDown,
                onIncrease: nudges.startForward,
                onDecrease: nudges.startBack,
                child: _dragArea(_Drag.start, width, const SizedBox.expand()),
              ),
            ),
            Positioned(
              left: x1 - half,
              width: handleHitWidth,
              top: 0,
              bottom: 0,
              child: Semantics(
                slider: true,
                label: labels.end,
                value: labels.endValue,
                increasedValue: labels.endUp,
                decreasedValue: labels.endDown,
                onIncrease: nudges.endForward,
                onDecrease: nudges.endBack,
                child: _dragArea(_Drag.end, width, const SizedBox.expand()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The zoomed selection with trim handles joined top and bottom, so the
/// selection reads as one frame. Outside the selection is dimmed.
class _EditorPainter extends CustomPainter {
  const _EditorPainter({
    required this.peaks,
    required this.selectionFrom,
    required this.selectionTo,
    required this.contentFrom,
    required this.contentTo,
    required this.playhead,
    required this.bar,
    required this.frame,
  });

  final List<double> peaks;
  final double selectionFrom;
  final double selectionTo;
  final double contentFrom;
  final double contentTo;
  final double? playhead;
  final Color bar;
  final Color frame;

  static const knob = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = selectionFrom * size.width;
    final x1 = selectionTo * size.width;
    const top = knob;
    final bottom = size.height - knob;
    final wave = Rect.fromLTRB(0, top + 8, size.width, bottom - 8);
    final playheadX = playhead == null ? null : x0 + (x1 - x0) * playhead!;

    final count = peaks.length;
    if (count > 0) {
      const gap = 2.0;
      final width = math.max<double>(
        1,
        (size.width - gap * (count - 1)) / count,
      );
      final outside = Paint()..color = bar.withValues(alpha: .22);
      final inside = Paint()..color = bar.withValues(alpha: .9);
      final played = Paint()..color = bar;
      final unplayed = Paint()..color = bar.withValues(alpha: .4);
      for (var i = 0; i < count; i++) {
        final x = i * (width + gap);
        final mid = x + width / 2;
        final f = mid / size.width;
        if (f < contentFrom || f > contentTo) continue;
        final Paint paint;
        if (mid < x0 || mid > x1) {
          paint = outside;
        } else if (playheadX == null) {
          paint = inside;
        } else {
          paint = mid < playheadX ? played : unplayed;
        }
        final h = math.max<double>(3, peaks[i].clamp(0.0, 1.0) * wave.height);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, wave.center.dy - h / 2, width, h),
            Radius.circular(width / 2),
          ),
          paint,
        );
      }
    }

    final framePaint = Paint()..color = frame;
    canvas
      ..drawRect(
        Rect.fromLTRB(x0, top, x1, bottom),
        Paint()..color = frame.withValues(alpha: .08),
      )
      ..drawRect(Rect.fromLTRB(x0, top - 1, x1, top + 1), framePaint)
      ..drawRect(Rect.fromLTRB(x0, bottom - 1, x1, bottom + 1), framePaint);
    for (final x in [x0, x1]) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - 3, top, x + 3, bottom),
            const Radius.circular(3),
          ),
          framePaint,
        )
        ..drawCircle(Offset(x, top), knob, framePaint)
        ..drawCircle(Offset(x, bottom), knob, framePaint);
    }

    if (playheadX != null) {
      canvas.drawRect(
        Rect.fromLTRB(playheadX - 1, top + 2, playheadX + 1, bottom - 2),
        Paint()..color = bar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter old) =>
      old.selectionFrom != selectionFrom ||
      old.selectionTo != selectionTo ||
      old.contentFrom != contentFrom ||
      old.contentTo != contentTo ||
      old.playhead != playhead ||
      old.bar != bar ||
      old.frame != frame ||
      !identical(old.peaks, peaks);
}
