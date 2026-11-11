import 'dart:math' as math;

import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/components/pass_stack.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A card of the band stack is this tall, except the last.
const double kPassBandCardHeight = 190;

/// The last card of the band stack is this tall, with all four corners round.
const double kPassBandLastHeight = 124;

/// The least distance between two cards' tops in the band stack.
const double kPassBandMinStep = 104;

/// The height of a card's label and a value of one line at [textScale]. The
/// label stops growing at the chrome limit; the value does not.
double passBandOneLineHeight(double textScale) {
  final label = 11 * math.min(textScale, kChromeMaxTextScale) * 1.2;
  final value = kPassCardValueSize * textScale * 1.05;
  return label + 4 + value;
}

/// Where the cards of a band stack go in the width it is given. Pure.
///
/// The band stack is the compact form of the pass stack, for a page that has
/// a header and a scroll of its own. Below text scale 1.3 the cards overlap:
/// every card but the last is 190 tall and shows a band, the last is 124 tall
/// and ends the stack with all four corners round. From 1.3 the cards stop
/// overlapping and become full cards with a 10 point gap, which is the same
/// switch [PassStackLayout] makes.
///
/// On a 390 wide column the overlapped tops are 0, 104, 208 and 312 and the
/// stack is 436 tall.
@immutable
class PassBandsLayout {
  const PassBandsLayout._({
    required this.mode,
    required this.width,
    required this.cardLeft,
    required this.cardWidth,
    required this.step,
    required this.tops,
    required this.heights,
    required this.totalHeight,
  });

  /// Lays out [count] cards in a column [width] points wide.
  ///
  /// The cards fill the width, unless [hasInsets] asks for [kPassCardInset]
  /// on each side. [contentHeight] is the height of the label and one line of
  /// value, for the step; it defaults to [passBandOneLineHeight].
  factory PassBandsLayout.of({
    required double width,
    required double textScale,
    required int count,
    bool hasInsets = false,
    double? contentHeight,
  }) {
    final inset = hasInsets ? kPassCardInset : 0.0;
    final cardWidth = width - 2 * inset;
    final mode = textScale >= kChromeMaxTextScale
        ? PassStackMode.flat
        : PassStackMode.overlapped;
    if (mode == PassStackMode.flat) {
      return PassBandsLayout._(
        mode: mode,
        width: width,
        cardLeft: inset,
        cardWidth: cardWidth,
        step: 0,
        tops: const [],
        heights: const [],
        totalHeight: 0,
      );
    }
    final step = math.max(
      kPassBandMinStep,
      (contentHeight ?? passBandOneLineHeight(textScale)) + 30,
    );
    final tops = [for (var i = 0; i < count; i++) i * step];
    final heights = [
      for (var i = 0; i < count; i++)
        i == count - 1 ? kPassBandLastHeight : kPassBandCardHeight,
    ];
    return PassBandsLayout._(
      mode: mode,
      width: width,
      cardLeft: inset,
      cardWidth: cardWidth,
      step: step,
      tops: tops,
      heights: heights,
      totalHeight: count == 0 ? 0 : tops.last + heights.last,
    );
  }

  final PassStackMode mode;

  /// The width the layout was given.
  final double width;

  /// A card's left edge and width.
  final double cardLeft;
  final double cardWidth;

  /// The distance between two tops. Zero in flat mode.
  final double step;

  /// Each card's top and height. Empty in flat mode, where the cards size
  /// themselves.
  final List<double> tops;
  final List<double> heights;

  /// How tall the overlapped stack is. Zero in flat mode, where the column
  /// is as tall as its cards.
  final double totalHeight;

  bool get isFlat => mode == PassStackMode.flat;
}

/// The compact pass stack: cards from the Personalize kit, with no header, no
/// back ring and no scroll, to sit inside a page that has its own.
///
/// It takes the width it is given and sizes itself: [PassBandsLayout]'s
/// `totalHeight` while the cards overlap, and a column of full cards from text
/// scale 1.3. Every card but the last is wrapped in a [PassCardBand], the last
/// in a [PassCardEnd] so it draws all four corners round. It places the
/// [PassOriginScope] its cards read, so a tap hands the caller a [PassOrigin]
/// as it does in `AppPassStack`. Nothing here opens a page. The caller does,
/// with the origin as the route's `extra`.
///
/// [groupLabel] is the spoken name of the group, in stack order. [hasInsets]
/// sits the cards [kPassCardInset] in from the sides, for a parent that does
/// not pad.
class AppPassBands extends StatelessWidget {
  const AppPassBands({
    required this.cards,
    this.handoff,
    this.groupLabel,
    this.hasInsets = false,
    this.isLoose = false,
    super.key,
  });

  final List<AppPassCard> cards;

  /// A handoff of the caller's own, in place of the one the stack makes.
  final PassHandoff? handoff;

  /// The spoken name of the group of cards.
  final String? groupLabel;

  /// Whether the cards sit [kPassCardInset] in from the sides.
  final bool hasInsets;

  /// Whether the overlapped cards sit visibly off square, like cards
  /// pushed into a wallet by hand. See [looseCard]. The flat column stays
  /// square.
  final bool isLoose;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = PassBandsLayout.of(
          width: width,
          textScale: scale,
          count: cards.length,
          hasInsets: hasInsets,
        );
        final Widget body;
        if (layout.isFlat) {
          body = Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.cardLeft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: kPassFlatGap),
                  cards[i],
                ],
              ],
            ),
          );
        } else {
          final room = isLoose ? looseCardRoomFor(layout.cardWidth) : 0.0;
          final cardWidth = layout.cardWidth - 2 * room;
          LooseCardPose? poseOf(int i) => isLoose
              ? looseCardPoseFor(index: i, cardWidth: cardWidth, room: room)
              : null;
          body = SizedBox(
            width: width,
            height: layout.totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: layout.cardLeft + room,
                    width: cardWidth,
                    top: layout.tops[i],
                    height: isLoose && i < cards.length - 1
                        ? looseCoveredHeight(
                            top: layout.tops[i],
                            height: layout.heights[i],
                            stackBottom: layout.totalHeight,
                            pose: poseOf(i)!,
                          )
                        : layout.heights[i],
                    // The next card covers the rest of this one.
                    child: i == cards.length - 1
                        ? looseCard(
                            PassCardEnd(child: cards[i]),
                            pose: poseOf(i),
                          )
                        : looseCard(
                            PassCardBand(height: layout.step, child: cards[i]),
                            pose: poseOf(i),
                            isCovered: true,
                          ),
                  ),
              ],
            ),
          );
        }
        return PassOriginScope(
          handoff: handoff,
          child: PassCardLayout(
            isFlat: layout.isFlat,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: groupLabel,
              child: body,
            ),
          ),
        );
      },
    );
  }
}

/// How far in from each side a loose card sits, in points, so its shift and
/// tilt never reach past the column the stack was given. The flat column
/// keeps the full width.
const double kLooseCardRoom = 10;

/// The least room a loose card keeps on each side, on the narrowest column.
const double kLooseCardMinRoom = 4;

/// A loose card gives up its room before it narrows past this width, so a
/// label, its plan badge and the value beside them still fit on a small
/// phone.
const double kLooseCardMinWidth = 312;

/// The most a tilted card's top corner may rise or fall, in points. A wide
/// card turns less, so the corner never climbs into the band above it.
const double kLooseCardMaxLift = 12;

/// The loose pattern, top card first, repeating past the fourth: the tilt in
/// degrees (positive turns clockwise) and the shift of the card's top in
/// points (positive to the right). The tilt and the shift always share a
/// sign, so a card's top leans one way and its foot swings back under the
/// stack. Neighbours always lean opposite ways, and no two in a row share a
/// size, so the stack reads as placed by hand rather than drawn askew.
const List<(double, double)> kLooseCardPattern = [
  (-2.5, -8),
  (3, 9),
  (-2, -7),
  (3.5, 9),
];

/// The room a loose card keeps on each side when the square card would be
/// [squareWidth] wide. Pure. [kLooseCardRoom], less on a column so narrow
/// that the card would drop under [kLooseCardMinWidth], and never under
/// [kLooseCardMinRoom].
double looseCardRoomFor(double squareWidth) =>
    ((squareWidth - kLooseCardMinWidth) / 2).clamp(
      kLooseCardMinRoom,
      kLooseCardRoom,
    );

/// The tilt in radians and the shift in points of one loose card, and the
/// room it has on each side.
@immutable
class LooseCardPose {
  const LooseCardPose({
    required this.tilt,
    required this.shift,
    this.room = kLooseCardRoom,
  });

  /// The turn in radians, about the card's top centre. Positive is clockwise.
  final double tilt;

  /// How far the card moves sideways, in points. Positive is to the right.
  final double shift;

  /// How far in from each side of the column the card sits.
  final double room;

  /// The tallest this card can be before its foot swings past [room].
  /// Infinite for a card that does not turn.
  double get maxHeight {
    final sine = math.sin(tilt.abs());
    if (sine == 0) return double.infinity;
    return (room + shift.abs()) / sine;
  }
}

/// The pose of the [index]th loose card of a stack whose cards are
/// [cardWidth] wide with [room] on each side. Pure.
///
/// It follows [kLooseCardPattern], so a card keeps its pose from visit to
/// visit. A wide card turns less, so its top corner never rises or falls more
/// than [kLooseCardMaxLift]. The shift stays a point inside [room].
LooseCardPose looseCardPoseFor({
  required int index,
  required double cardWidth,
  double room = kLooseCardRoom,
}) {
  final (degrees, shift) = kLooseCardPattern[index % kLooseCardPattern.length];
  final tilt = degrees * math.pi / 180;
  final half = cardWidth / 2;
  final maxTilt = half <= kLooseCardMaxLift
      ? tilt.abs()
      : math.asin(kLooseCardMaxLift / half);
  final reach = math.max(0, room - 1).toDouble();
  return LooseCardPose(
    tilt: tilt.sign * math.min(tilt.abs(), maxTilt),
    shift: shift.clamp(-reach, reach),
    room: room,
  );
}

/// How tall a covered loose card is: down to [kPassCardRadius] above the
/// stack's bottom, and never shorter than its own [height]. The card runs
/// most of the stack, so what shows past a tilted edge is the long side of a
/// card, as in a wallet, and the card is whole when it grows into its page.
/// It stops at [pose]'s `maxHeight`, so a long stack never swings a foot past
/// the column.
double looseCoveredHeight({
  required double top,
  required double height,
  required double stackBottom,
  required LooseCardPose pose,
}) => math.max(
  height,
  math.min(stackBottom - kPassCardRadius - top, pose.maxHeight),
);

/// [card] with [pose]'s tilt and shift, or as it is when [pose] is null. A
/// covered card also rounds its foot, which can peek out past the tilted card
/// in front of it. It turns on the card's top centre, so the band's top edge
/// is where the eye reads the lean.
Widget looseCard(
  Widget card, {
  required LooseCardPose? pose,
  bool isCovered = false,
}) {
  if (pose == null) return card;
  return Transform.translate(
    offset: Offset(pose.shift, 0),
    child: Transform.rotate(
      angle: pose.tilt,
      alignment: Alignment.topCenter,
      child: isCovered ? PassCardEnd(child: card) : card,
    ),
  );
}
