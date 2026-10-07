import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The looks the drawn alarm screen tries on. Each one is the same alarm:
/// the same topic, ringing, with the same button.
enum AlarmScreenLook {
  /// The face on the ringing colour, as the app draws it today.
  classic,

  /// A terminal: light mono type on black, no face.
  terminal,

  /// A poster: two heavy words on yellow, the face in the corner.
  poster,
}

/// The loop is this many seconds long, and goes through the looks twice.
const double alarmScreensPreviewLoop = 9;

/// The looks in the order the loop shows them.
const List<AlarmScreenLook> alarmScreensPreviewOrder = AlarmScreenLook.values;

/// Seconds each look stays on.
double get alarmScreensPreviewStep =>
    alarmScreensPreviewLoop / (alarmScreensPreviewOrder.length * 2);

/// The second a still preview rests on: the terminal look, half way
/// through its stay, with the pick mark at home on its swatch.
double get alarmScreensPreviewRestAt => alarmScreensPreviewStep * 1.5;

/// One frame of the alarm screens preview.
@immutable
class AlarmScreensPreviewFrame {
  const AlarmScreensPreviewFrame({
    required this.look,
    required this.press,
    required this.slot,
    required this.tap,
    required this.tapSlot,
  });

  /// The look on the screen.
  final AlarmScreenLook look;

  /// How far the screen is squeezed by the change, 0 to 1.
  final double press;

  /// Where the pick mark is in the row of swatches: 0 is the first, and a
  /// fraction is on its way between two.
  final double slot;

  /// The drawn finger, and the swatch it lands on.
  final ({double size, double opacity}) tap;
  final int tapSlot;
}

/// The frame of the alarm screens preview at clock second [t].
///
/// A finger lands on the next swatch, the screen is squeezed, and the look
/// changes while it is smallest, so the new one springs out.
AlarmScreensPreviewFrame alarmScreensPreviewFrameAt(double t) {
  final step = alarmScreensPreviewStep;
  final count = alarmScreensPreviewOrder.length;
  final local = loopT(t, alarmScreensPreviewLoop);

  // The change this second is nearest to, and how far from it.
  final change = (local / step).round();
  final since = local - change * step;
  final index = (since >= 0 ? change : change - 1) % count;
  final before = (index + count - 1) % count;

  // The mark slides to the new swatch as the screen springs back. From
  // the last one it goes home to the first.
  final travel = AppCurves.easeSpring.transform(
    phase(local - (since >= 0 ? change : change - 1) * step, 0, 0.3),
  );

  return AlarmScreensPreviewFrame(
    look: alarmScreensPreviewOrder[index],
    press: pressAt(since, 0),
    slot: before + (index - before) * travel,
    // The finger comes down a moment before the change it makes.
    tap: tapAt(since, -0.04),
    tapSlot: change % count,
  );
}

/// Your own alarm screen: one alarm, trying on three looks.
///
/// Small, it is a phone on the shared tile. As a scene it is one alarm
/// screen in miniature over a row of swatches. A swatch is picked, the
/// screen changes its look and the pick mark moves along. The colours are
/// the looks' own and stay inside the miniature.
class AlarmScreensPreview extends StatelessWidget {
  const AlarmScreensPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    if (size.shortestSide < paywallPreviewSceneMinEdge) {
      return PreviewGlyphTile.mark(PreviewMark.alarmScreen, size: size);
    }
    final u = size.shortestSide;
    return ExtrasPreviewTile(
      size: size,
      color: context.appColors.cream,
      child: PaywallPreviewClock.seconds(
        restAt: alarmScreensPreviewRestAt,
        builder: (context, t) {
          final frame = alarmScreensPreviewFrameAt(t);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 - 0.1 * frame.press,
                  child: _Screen(u: u, look: frame.look),
                ),
                SizedBox(height: u * 0.06),
                _Swatches(u: u, frame: frame),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The fill of [look]'s screen, which is also its swatch.
Color _fillOf(AlarmScreenLook look, AppColors colors) => switch (look) {
  AlarmScreenLook.classic => colors.crit,
  AlarmScreenLook.terminal => colors.inkFixed,
  AlarmScreenLook.poster => colors.yellow,
};

/// The alarm screen in miniature, in one look.
class _Screen extends StatelessWidget {
  const _Screen({required this.u, required this.look});

  final double u;
  final AlarmScreenLook look;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasWords = u >= paywallPreviewLargeMinEdge;
    final width = u * 0.5;
    final height = u * 0.66;
    final pad = u * 0.05;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: _fillOf(look, colors),
        borderRadius: BorderRadius.circular(u * 0.085),
        border: Border.all(
          color: colors.inkFixed,
          width: math.max(1.5, u * 0.012),
        ),
      ),
      child: switch (look) {
        AlarmScreenLook.classic => _classic(colors, hasWords),
        AlarmScreenLook.terminal => _terminal(colors, hasWords),
        AlarmScreenLook.poster => _poster(colors, hasWords),
      },
    );
  }

  Widget _topic(Color color, {TextAlign align = TextAlign.start}) => Text(
    'prod-db', // l10n-ok: a made-up topic name
    maxLines: 1,
    softWrap: false,
    textAlign: align,
    style: AppTypography.monoBold(color, fontSize: u * 0.052).copyWith(
      height: 1,
    ),
  );

  /// The one button every look keeps.
  Widget _button({
    required Color ink,
    required bool hasWords,
    Color? fill,
    Color? stroke,
    bool isMono = false,
  }) {
    final height = u * 0.11;
    final style = isMono
        ? AppTypography.monoBold(ink, fontSize: height * 0.42)
        : AppTypography.title(ink, fontSize: height * 0.44);
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: fill,
        shape: StadiumBorder(
          side: stroke == null
              ? BorderSide.none
              : BorderSide(color: stroke, width: math.max(1, u * 0.01)),
        ),
      ),
      child: hasWords
          ? Text(
              LocaleKeys.paywall_previews_extras_widget_im_up.tr(),
              maxLines: 1,
              softWrap: false,
              style: style.copyWith(height: 1),
            )
          : null,
    );
  }

  Widget _classic(AppColors colors, bool hasWords) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Spacer(),
      Center(
        child: FaceWidget(state: FaceState.alarmed, size: u * 0.25),
      ),
      if (hasWords) ...[
        SizedBox(height: u * 0.035),
        _topic(colors.inkFixed, align: TextAlign.center),
      ],
      const Spacer(),
      _button(
        ink: colors.onHighlight,
        fill: colors.inkFixed,
        hasWords: hasWords,
      ),
    ],
  );

  Widget _terminal(AppColors colors, bool hasWords) {
    final type = colors.yellow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: u * 0.01),
        if (hasWords) ...[
          _topic(type),
          SizedBox(height: u * 0.025),
          Text(
            'critical', // l10n-ok: a priority name, a machine's string
            maxLines: 1,
            softWrap: false,
            style: AppTypography.mono(
              type.withValues(alpha: 0.6),
              fontSize: u * 0.045,
            ).copyWith(height: 1),
          ),
        ],
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '03:07', // l10n-ok: a made-up time on a drawn screen
              maxLines: 1,
              softWrap: false,
              style: AppTypography.monoBold(
                type,
                fontSize: u * 0.105,
              ).copyWith(height: 1, letterSpacing: -u * 0.004),
            ),
            SizedBox(width: u * 0.012),
            // The cursor block after the time.
            Container(width: u * 0.03, height: u * 0.085, color: type),
          ],
        ),
        const Spacer(),
        _button(ink: type, stroke: type, hasWords: hasWords, isMono: true),
      ],
    );
  }

  Widget _poster(AppColors colors, bool hasWords) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Text(
                  LocaleKeys.paywall_previews_extras_screen_wake_up
                      .tr()
                      .toUpperCase()
                      .replaceFirst(' ', '\n'),
                  maxLines: 2,
                  style: AppTypography.display(
                    colors.inkFixed,
                    fontSize: u * 0.125,
                  ).copyWith(height: 0.88, letterSpacing: -u * 0.005),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: u * 0.03,
              child: FaceWidget(state: FaceState.wakesUp, size: u * 0.17),
            ),
          ],
        ),
      ),
      _button(
        ink: colors.onHighlight,
        fill: colors.inkFixed,
        hasWords: hasWords,
      ),
    ],
  );
}

/// The row of looks, as swatches, with a ring around the one picked.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.u, required this.frame});

  final double u;
  final AlarmScreensPreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final count = alarmScreensPreviewOrder.length;
    final edge = u * 0.115;
    final gap = u * 0.07;
    final ring = math.max(1.5, u * 0.012);
    final reach = ring * 2.4;

    return SizedBox(
      width: edge * count + gap * (count - 1),
      height: edge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, look) in alarmScreensPreviewOrder.indexed)
            Positioned(
              left: i * (edge + gap),
              child: Container(
                width: edge,
                height: edge,
                decoration: BoxDecoration(
                  color: _fillOf(look, colors),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.inkFixed.withValues(alpha: 0.18),
                    width: math.max(1, u * 0.006),
                  ),
                ),
              ),
            ),
          Positioned(
            left: frame.slot * (edge + gap) - reach,
            top: -reach,
            child: Container(
              width: edge + reach * 2,
              height: edge + reach * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.ink, width: ring),
              ),
            ),
          ),
          Positioned(
            left: frame.tapSlot * (edge + gap),
            top: 0,
            width: edge,
            height: edge,
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: ExtrasPreviewTap(tap: frame.tap, diameter: edge * 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
