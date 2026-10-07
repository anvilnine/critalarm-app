import 'dart:math' as math;

import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:flutter/material.dart';

/// The loop is this many seconds long.
const double appIconsPreviewLoop = 12;

/// The second a still preview rests on: the last icon, shades and a crown.
const double appIconsPreviewRestAt = 10.5;

/// The icons in the order the loop wears them: the standard one, then each
/// extra one. Each gets an equal share of [appIconsPreviewLoop].
const List<AppIcon> appIconsPreviewOrder = AppIcon.values;

/// Seconds each icon stays on.
double get appIconsPreviewStep =>
    appIconsPreviewLoop / appIconsPreviewOrder.length;

/// One frame of the app icons preview.
@immutable
class AppIconsPreviewFrame {
  const AppIconsPreviewFrame({
    required this.icon,
    required this.press,
    required this.slot,
  });

  /// The icon on the tile.
  final AppIcon icon;

  /// How far the tile is squeezed by the swap, 0 to 1.
  final double press;

  /// Where the pick mark is in the row of icons: 0 is the first icon, 1 the
  /// second, and a fraction is on its way between two.
  final double slot;
}

/// The frame of the app icons preview at clock second [t].
///
/// The tile is squeezed at each swap and the icon changes while it is
/// smallest, so the new one springs out.
AppIconsPreviewFrame appIconsPreviewFrameAt(double t) {
  final step = appIconsPreviewStep;
  final count = appIconsPreviewOrder.length;
  final local = loopT(t, appIconsPreviewLoop);

  // The swap this second is nearest to, and how far from it.
  final swap = (local / step).round();
  final since = local - swap * step;
  final index = (since >= 0 ? swap : swap - 1) % count;
  final before = (index + count - 1) % count;

  // The mark slides to the new icon as the tile springs back. From the
  // last icon it goes home to the first.
  final travel = AppCurves.easeSpring.transform(
    phase(local - index * step, 0, 0.3),
  );

  return AppIconsPreviewFrame(
    icon: appIconsPreviewOrder[index],
    press: pressAt(since, 0),
    slot: before + (index - before) * travel,
  );
}

/// The app icon swapping between the icons the app ships.
///
/// Small, the tile is the icon. From [extrasPreviewFullEdge] up it is the
/// icon over the row it was picked from, with the pick mark moving along.
class AppIconsPreview extends StatelessWidget {
  const AppIconsPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final u = size.shortestSide;
    final isFull = u >= extrasPreviewFullEdge;
    return ExtrasPreviewTile(
      size: size,
      color: isFull ? context.appColors.cream : null,
      child: ExtrasPreviewClock(
        restAt: appIconsPreviewRestAt,
        builder: (context, t) {
          final frame = appIconsPreviewFrameAt(t);
          return Center(
            child: isFull ? _picker(context, frame) : _tile(frame, u),
          );
        },
      ),
    );
  }

  Widget _tile(
    AppIconsPreviewFrame frame,
    double edge, {
    List<BoxShadow>? shadow,
  }) => Transform.scale(
    scale: 1 - 0.14 * frame.press,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(edge * _AppIconPainter.corner),
        boxShadow: shadow,
      ),
      child: CustomPaint(
        size: Size.square(edge),
        painter: _AppIconPainter(frame.icon),
      ),
    ),
  );

  /// The icon in use over the row of all four.
  Widget _picker(BuildContext context, AppIconsPreviewFrame frame) {
    final colors = context.appColors;
    final u = size.shortestSide;
    final count = appIconsPreviewOrder.length;
    final isWide = size.width / size.height >= 1.6;

    // A wide tile puts the row beside the icon, so both keep their size.
    final big = u * (isWide ? 0.66 : 0.48);
    final room = isWide ? size.width - big - u * 0.44 : size.width - u * 0.24;
    final gap = u * 0.05;
    final small = math.min(
      u * (isWide ? 0.26 : 0.17),
      (room - gap * (count - 1)) / count,
    );
    final ring = math.max(1.5, small * 0.09);

    final row = SizedBox(
      width: small * count + gap * (count - 1),
      height: small,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, icon) in appIconsPreviewOrder.indexed)
            Positioned(
              left: i * (small + gap),
              child: CustomPaint(
                size: Size.square(small),
                painter: _AppIconPainter(icon),
              ),
            ),
          Positioned(
            left: frame.slot * (small + gap) - ring * 2,
            top: -ring * 2,
            child: Container(
              width: small + ring * 4,
              height: small + ring * 4,
              decoration: BoxDecoration(
                border: Border.all(color: colors.ink, width: ring),
                borderRadius: BorderRadius.circular(
                  (small + ring * 4) * _AppIconPainter.corner,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final icon = _tile(
      frame,
      big,
      shadow: AppShadows.shadowSm(
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    return isWide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              SizedBox(width: u * 0.14),
              row,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              SizedBox(height: u * 0.12),
              row,
            ],
          );
  }
}

/// One app icon, drawn from the same shapes as its artwork in
/// `assets/icon/src`, so it is sharp at any size and needs no image decoded.
/// The colours are the artwork's own and do not follow the theme: a home
/// screen icon looks the same in light and dark.
class _AppIconPainter extends CustomPainter {
  const _AppIconPainter(this.icon);

  final AppIcon icon;

  /// The home screen corner, as a share of the icon's edge.
  static const double corner = 230 / 1024;

  static const AppColors _art = AppColors.light;

  bool get _hasShades => icon == AppIcon.shades || icon == AppIcon.shadesCrown;
  bool get _hasCrown => icon == AppIcon.crowned || icon == AppIcon.shadesCrown;

  @override
  void paint(Canvas canvas, Size size) {
    // The artwork is drawn on a square 1024 units wide.
    canvas
      ..save()
      ..scale(size.shortestSide / 1024)
      ..clipRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          const Radius.circular(1024 * corner),
        ),
      )
      ..drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = _art.high,
      );

    final ink = Paint()
      ..color = _art.inkFixed
      ..style = PaintingStyle.stroke;
    final white = Paint()..color = _art.surface;

    // The head, coming in from the left edge.
    canvas
      ..drawPath(
        Path()
          ..moveTo(-20, 133)
          ..lineTo(250, 133)
          ..arcToPoint(
            const Offset(554, 437),
            radius: const Radius.circular(304),
          )
          ..lineTo(554, 639)
          ..arcToPoint(
            const Offset(250, 943),
            radius: const Radius.circular(304),
          )
          ..lineTo(-20, 943)
          ..close(),
        Paint()..color = _art.yellow,
      )
      ..drawPath(
        Path()
          ..moveTo(-20, 169)
          ..lineTo(250, 169)
          ..arcToPoint(
            const Offset(518, 437),
            radius: const Radius.circular(268),
          )
          ..lineTo(518, 639)
          ..arcToPoint(
            const Offset(250, 907),
            radius: const Radius.circular(268),
          )
          ..lineTo(-20, 907),
        ink..strokeWidth = 72,
      );

    if (_hasShades) {
      canvas
        ..drawLine(
          const Offset(-20, 452),
          const Offset(540, 452),
          ink..strokeWidth = 40,
        )
        ..drawPath(
          Path()
            ..moveTo(140, 440)
            ..lineTo(400, 440)
            ..quadraticBezierTo(404, 590, 270, 598)
            ..quadraticBezierTo(150, 592, 140, 440)
            ..close(),
          Paint()..color = _art.inkFixed,
        )
        ..drawLine(
          const Offset(200, 540),
          const Offset(250, 470),
          Paint()
            ..color = _art.surface
            ..strokeWidth = 22
            ..strokeCap = StrokeCap.round,
        )
        ..drawPath(
          Path()
            ..moveTo(50, 700)
            ..cubicTo(110, 740, 190, 720, 250, 640),
          ink
            ..strokeWidth = 62
            ..strokeCap = StrokeCap.round,
        );
    } else {
      canvas
        ..drawPath(
          Path()
            ..moveTo(178, 487)
            ..quadraticBezierTo(258, 543, 338, 487),
          ink
            ..strokeWidth = 68
            ..strokeCap = StrokeCap.round,
        )
        ..drawPath(
          Path()
            ..moveTo(65, 693)
            ..cubicTo(90, 712, 145, 712, 235, 656),
          ink..strokeWidth = 66,
        );
    }

    if (_hasCrown) {
      // The crown sits on the head's corner, leaning with it, as drawn.
      canvas
        ..save()
        ..translate(398, 182)
        ..rotate(27 * math.pi / 180)
        ..scale(0.9);
      final crown = Path()
        ..moveTo(-120, 0)
        ..lineTo(-135, -100)
        ..lineTo(-65, -55)
        ..lineTo(0, -120)
        ..lineTo(65, -55)
        ..lineTo(135, -100)
        ..lineTo(120, 0)
        ..close();
      canvas
        ..drawPath(crown, Paint()..color = _art.yellow)
        ..drawPath(
          crown,
          Paint()
            ..color = _art.inkFixed
            ..style = PaintingStyle.stroke
            ..strokeWidth = 33
            ..strokeJoin = StrokeJoin.round,
        )
        ..drawCircle(const Offset(0, -58), 22, Paint()..color = _art.crit)
        ..drawCircle(
          const Offset(0, -58),
          22,
          Paint()
            ..color = _art.inkFixed
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13,
        )
        ..restore();
    }

    // The exclamation mark.
    canvas
      ..drawLine(
        const Offset(840, 335),
        const Offset(695, 600),
        Paint()
          ..color = _art.surface
          ..strokeWidth = 140
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(const Offset(660, 771), 73, white)
      ..restore();
  }

  @override
  bool shouldRepaint(_AppIconPainter old) => icon != old.icon;
}
