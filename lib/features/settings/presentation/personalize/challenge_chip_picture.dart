import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/widgets.dart';

/// The `LocaleKeys` key of the one word a challenge's chip shows on the
/// Personalize page. The challenge's full name stays as what a screen
/// reader says, and as the title on the challenge itself.
String challengeChipWordKey(ChallengeKind kind) => switch (kind) {
  ChallengeKind.typeTopicName => LocaleKeys.personalize_challenge_chips_topic,
  ChallengeKind.typeAlertTitle => LocaleKeys.personalize_challenge_chips_title,
  ChallengeKind.opsMath => LocaleKeys.personalize_challenge_chips_math,
  ChallengeKind.scratchCard => LocaleKeys.personalize_challenge_chips_scratch,
  ChallengeKind.shake => LocaleKeys.personalize_challenge_chips_shake,
};

/// The small picture on a challenge's chip, drawn with the same round
/// stroke on the same 24 unit box as the app's other glyphs.
class ChallengeChipPicture extends StatelessWidget {
  const ChallengeChipPicture({
    required this.kind,
    required this.color,
    this.size = 16,
    super.key,
  });

  final ChallengeKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ChipPicturePainter(kind, color)),
  );
}

class _ChipPicturePainter extends CustomPainter {
  const _ChipPicturePainter(this.kind, this.color);

  final ChallengeKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    switch (kind) {
      case ChallengeKind.typeTopicName:
        // A hash, the mark of a topic.
        path
          ..moveTo(9.5, 4)
          ..lineTo(7.5, 20)
          ..moveTo(16.5, 4)
          ..lineTo(14.5, 20)
          ..moveTo(4.5, 9)
          ..lineTo(20, 9)
          ..moveTo(4, 15)
          ..lineTo(19.5, 15);
      case ChallengeKind.typeAlertTitle:
        // A capital T, the first letter of a title.
        path
          ..moveTo(5, 8)
          ..lineTo(5, 5)
          ..lineTo(19, 5)
          ..lineTo(19, 8)
          ..moveTo(12, 5)
          ..lineTo(12, 20)
          ..moveTo(9, 20)
          ..lineTo(15, 20);
      case ChallengeKind.opsMath:
        // A plus and an equals sign.
        path
          ..moveTo(3, 12)
          ..lineTo(11, 12)
          ..moveTo(7, 8)
          ..lineTo(7, 16)
          ..moveTo(15, 9.5)
          ..lineTo(21, 9.5)
          ..moveTo(15, 14.5)
          ..lineTo(21, 14.5);
      case ChallengeKind.scratchCard:
        // A card with a scratch mark across it.
        path
          ..addRRect(
            RRect.fromLTRBR(3, 6, 21, 18, const Radius.circular(3)),
          )
          ..moveTo(7, 14)
          ..lineTo(10, 10)
          ..lineTo(12, 14)
          ..lineTo(15, 10)
          ..lineTo(17, 14);
      case ChallengeKind.shake:
        // A phone with a move line on each side.
        path
          ..addRRect(
            RRect.fromLTRBR(8.5, 4, 15.5, 20, const Radius.circular(2.2)),
          )
          ..moveTo(4.5, 9)
          ..lineTo(4.5, 15)
          ..moveTo(19.5, 9)
          ..lineTo(19.5, 15)
          ..moveTo(1.5, 11)
          ..lineTo(1.5, 13)
          ..moveTo(22.5, 11)
          ..lineTo(22.5, 13);
    }
    canvas
      ..drawPath(path, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_ChipPicturePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
