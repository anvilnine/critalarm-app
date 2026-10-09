import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_style.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/own_look_thumbnail.dart';
import 'package:critalarm/features/settings/presentation/personalize/ringing_preview.dart';
import 'package:flutter/material.dart';

/// The look a position of the deck draws, for the ground and the text it
/// gives the page.
///
/// Yours is the person's photo while it is held. With none held it is the
/// own look built with nothing in it, which has the same canvas and the same
/// words, so the page keeps one colour for Yours whatever the phone holds.
AlarmStyle lookStyleFor(AlarmStyleId id) {
  if (id == AlarmStyleId.own) return heldOwnAlarmStyle ?? _emptyOwnStyle;
  return alarmStyleOf(id);
}

final AlarmStyle _emptyOwnStyle = buildOwnAlarmStyle(
  photo: OwnLookPhoto(null),
  measure: OwnPhotoMeasure(
    columns: OwnPhotoMeasure.gridColumns,
    rows: OwnPhotoMeasure.gridRows,
    peaks: List<int>.filled(
      OwnPhotoMeasure.gridColumns * OwnPhotoMeasure.gridRows,
      0,
    ),
    lows: List<int>.filled(
      OwnPhotoMeasure.gridColumns * OwnPhotoMeasure.gridRows,
      0,
    ),
  ),
  accent: ownLookAccents.first,
);

/// The edge of the square that takes a tap on the own look's corner button.
const double lookCornerTarget = 44;

/// One phone of the deck: the look's own ringing screen in a rounded frame.
///
/// The frame is as wide as [size] and carries a border in [border], a soft
/// shadow, and a wash of [scrim] over the picture that dims a phone that is
/// not in the centre. The wash is the ground at some opacity, which looks the
/// same as fading the phone and costs no extra layer.
class LookPhoneFrame extends StatelessWidget {
  const LookPhoneFrame({
    required this.size,
    required this.border,
    required this.scrim,
    required this.child,
    this.isEmpty = false,
    super.key,
  });

  final Size size;
  final Color border;
  final Color scrim;
  final Widget child;

  /// An empty slot: no solid border and no shadow. Its [child] draws its own
  /// dashed outline.
  final bool isEmpty;

  /// The corner follows the frame's width, as a phone's does.
  static double radiusFor(Size size) => size.width * 0.14;

  /// The width of the border.
  static const double borderWidth = 3;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(radiusFor(size));
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isEmpty
              ? null
              : [
                  BoxShadow(
                    color: context.appColors.inkFixed.withValues(alpha: 0.35),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: isEmpty
                ? null
                : Border.all(color: border, width: borderWidth),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (scrim.a > 0) IgnorePointer(child: ColoredBox(color: scrim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a position of the deck draws inside its frame.
///
/// A fixed look, and Yours while its photo is held, are the real ringing
/// screen. Only the centred phone is live: the others hold one still frame,
/// so the page has one large living thing. Yours with a photo saved and not
/// drawable is a small copy of the photo. Yours with nothing is a dashed
/// outline with a plus.
class LookPhoneFace extends StatelessWidget {
  const LookPhoneFace({
    required this.id,
    required this.own,
    required this.isLive,
    required this.height,
    required this.fade,
    super.key,
  });

  final AlarmStyleId id;
  final OwnLookPhase own;
  final bool isLive;
  final double height;

  /// The colours of the page.
  final LookFade fade;

  @override
  Widget build(BuildContext context) {
    // A phone is a picture of the alarm screen: it does not grow with the
    // text size of this page.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: _face(context),
    );
  }

  Widget _face(BuildContext context) {
    // The phone is upright on any display, laid out for an upright screen.
    final screen = lookScreenSize(MediaQuery.sizeOf(context));
    // The face shuffles between expressions. Under reduce motion the resting
    // frame is the one that reads as ringing, the same on every visit.
    Widget still(Widget picture) => context.reduceMotion
        ? RingingFacePin(style: RingingStyle.classic, child: picture)
        : picture;
    if (id != AlarmStyleId.own) {
      return still(
        RingingPreview(
          style: alarmStyleOf(id),
          isStill: !isLive,
          screenSize: screen,
        ),
      );
    }
    return switch (own) {
      OwnLookPhase.held => still(
        RingingPreview(
          style: heldOwnAlarmStyle,
          isStill: !isLive,
          screenSize: screen,
        ),
      ),
      OwnLookPhase.saved => OwnLookThumbnail(
        key: const ValueKey('look-own-thumbnail'),
        store: getIt<OwnLookStore>(),
        height: height,
        fallback: ColoredBox(color: fade.grounds.last),
      ),
      OwnLookPhase.none => _EmptyOwnFace(fade: fade),
    };
  }
}

/// Yours with no photo: an empty slot the shape of a phone, cream with a
/// dashed outline and a plus in ink.
class _EmptyOwnFace extends StatelessWidget {
  const _EmptyOwnFace({required this.fade});

  final LookFade fade;

  @override
  Widget build(BuildContext context) =>
      // Cream with an ink outline and one plus, whatever ground the page
      // has, so the empty slot reads as a card to fill on every look.
      CustomPaint(
        foregroundPainter: _DashedEdgePainter(color: fade.ink),
        child: ColoredBox(
          color: fade.cream,
          child: Center(
            child: AppGlyph(GlyphType.plus, size: 44, color: fade.ink),
          ),
        ),
      );
}

class _DashedEdgePainter extends CustomPainter {
  const _DashedEdgePainter({required this.color});

  final Color color;

  static const double _dash = 12;
  static const double _gap = 9;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = LookPhoneFrame.borderWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.max(0, LookPhoneFrame.radiusFor(size) - inset)),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = LookPhoneFrame.borderWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + _dash, metric.length)),
          paint,
        );
        at += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdgePainter old) => old.color != color;
}

/// The button on the corner of the centred Yours phone: a small disc in the
/// theme's ink with its glyph in the theme's surface, inside a full-size
/// target. A pencil opens the sheet that changes the photo or the colour, a
/// cross opens it with only "Remove photo" in it.
class LookOwnCorner extends StatelessWidget {
  const LookOwnCorner({
    required this.glyph,
    required this.label,
    required this.onTap,
    super.key,
  });

  final GlyphType glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: lookCornerTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Center(
                child: AppGlyph(glyph, color: colors.surface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
