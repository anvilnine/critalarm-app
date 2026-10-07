import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:flutter/rendering.dart';

/// What the mascot wears on the stage, drawn over the face in its own 200
/// unit box: the crown and the shades of the extra app icons, headphones
/// while a sound is recorded, a bow tie for a dressed-up alarm screen.
///
/// Each prop drops on from above, past its place and back, by the amount
/// the frame gives it. Both sit upright.
class HeroPropsPainter extends CustomPainter {
  const HeroPropsPainter({
    required this.props,
    required this.fill,
    required this.stroke,
    required this.lens,
    required this.glint,
    required this.bow,
  });

  /// How far on each prop is, 0 to 1.
  final Map<HeroProp, double> props;

  /// The head's own fill and outline, so the crown belongs to it.
  final Color fill;
  final Color stroke;
  final Color lens;
  final Color glint;

  /// The bow tie's cloth.
  final Color bow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 200);
    if (props[HeroProp.shades] case final amount?) _shades(canvas, amount);
    if (props[HeroProp.crown] case final amount?) _crown(canvas, amount);
    if (props[HeroProp.headphones] case final amount?) {
      _headphones(canvas, amount);
    }
    if (props[HeroProp.bowTie] case final amount?) _bowTie(canvas, amount);
    canvas.restore();
  }

  /// How far above its place a prop still is, in units.
  static double _drop(double amount, double from) =>
      -from * (1 - AppCurves.easeBack.transform(amount));

  static double _alpha(double amount) => (amount * 3).clamp(0.0, 1.0);

  void _crown(Canvas canvas, double amount) {
    final alpha = _alpha(amount);
    canvas
      ..save()
      ..translate(100, 20 + _drop(amount, 46));
    // Low and wide, so its points stay clear of the status bar.
    final crown = Path()
      ..moveTo(-40, 0)
      ..lineTo(-46, -30)
      ..lineTo(-22, -15)
      ..lineTo(0, -38)
      ..lineTo(22, -15)
      ..lineTo(46, -30)
      ..lineTo(40, 0)
      ..close();
    canvas
      ..drawPath(crown, Paint()..color = fill.withValues(alpha: alpha))
      ..drawPath(
        crown,
        Paint()
          ..color = stroke.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(
        const Offset(0, -13),
        4.5,
        Paint()..color = stroke.withValues(alpha: alpha),
      )
      ..restore();
  }

  void _shades(Canvas canvas, double amount) {
    final alpha = _alpha(amount);
    canvas
      ..save()
      ..translate(0, _drop(amount, 34));
    final dark = Paint()..color = lens.withValues(alpha: alpha);
    final edge = Paint()
      ..color = stroke.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round;

    Path lensAt(double left, double right) {
      final mid = (left + right) / 2;
      return Path()
        ..moveTo(left, 76)
        ..lineTo(right, 76)
        ..quadraticBezierTo(right + 1, 112, mid, 114)
        ..quadraticBezierTo(left - 1, 112, left, 76)
        ..close();
    }

    // The band runs from one side of the head to the other.
    canvas.drawLine(
      const Offset(14, 82),
      const Offset(186, 82),
      Paint()
        ..color = stroke.withValues(alpha: alpha)
        ..strokeWidth = 8,
    );
    for (final (left, right) in const [(40.0, 94.0), (106.0, 160.0)]) {
      final path = lensAt(left, right);
      canvas
        ..drawPath(path, dark)
        ..drawPath(path, edge)
        ..drawLine(
          Offset(left + 16, 103),
          Offset(left + 28, 87),
          Paint()
            ..color = glint.withValues(alpha: alpha)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
    }
    canvas.restore();
  }

  /// A band over the top of the head and a cup on each side.
  void _headphones(Canvas canvas, double amount) {
    final alpha = _alpha(amount);
    canvas
      ..save()
      ..translate(0, _drop(amount, 40));
    final ink = Paint()
      ..color = stroke.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(6, 96)
        ..cubicTo(2, -34, 198, -34, 194, 96),
      ink,
    );
    for (final left in const [-12.0, 180.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 80, 32, 62),
        const Radius.circular(14),
      );
      canvas
        ..drawRRect(cup, Paint()..color = lens.withValues(alpha: alpha))
        ..drawRRect(
          cup.deflate(9),
          Paint()..color = fill.withValues(alpha: alpha),
        );
    }
    canvas.restore();
  }

  /// A bow under the chin: two wings and a knot. It pops out from its
  /// knot.
  void _bowTie(Canvas canvas, double amount) {
    final alpha = _alpha(amount);
    final grown = AppCurves.easeBack.transform(amount);
    canvas
      ..save()
      ..translate(100, 196)
      ..scale(grown);
    final wings = Path()
      ..moveTo(0, 0)
      ..lineTo(-44, -22)
      ..quadraticBezierTo(-52, 0, -44, 22)
      ..close()
      ..moveTo(0, 0)
      ..lineTo(44, -22)
      ..quadraticBezierTo(52, 0, 44, 22)
      ..close();
    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 28),
      const Radius.circular(8),
    );
    final edge = Paint()
      ..color = stroke.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(wings, Paint()..color = bow.withValues(alpha: alpha))
      ..drawPath(wings, edge)
      ..drawRRect(knot, Paint()..color = bow.withValues(alpha: alpha))
      ..drawRRect(knot, edge)
      ..restore();
  }

  @override
  bool shouldRepaint(HeroPropsPainter old) =>
      props.length != old.props.length ||
      props[HeroProp.crown] != old.props[HeroProp.crown] ||
      props[HeroProp.shades] != old.props[HeroProp.shades] ||
      props[HeroProp.headphones] != old.props[HeroProp.headphones] ||
      props[HeroProp.bowTie] != old.props[HeroProp.bowTie] ||
      bow != old.bow ||
      fill != old.fill ||
      stroke != old.stroke ||
      lens != old.lens ||
      glint != old.glint;
}
