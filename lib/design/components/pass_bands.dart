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
    super.key,
  });

  final List<AppPassCard> cards;

  /// A handoff of the caller's own, in place of the one the stack makes.
  final PassHandoff? handoff;

  /// The spoken name of the group of cards.
  final String? groupLabel;

  /// Whether the cards sit [kPassCardInset] in from the sides.
  final bool hasInsets;

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
          body = SizedBox(
            width: width,
            height: layout.totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: layout.cardLeft,
                    width: layout.cardWidth,
                    top: layout.tops[i],
                    height: layout.heights[i],
                    // The next card covers the rest of this one.
                    child: i == cards.length - 1
                        ? PassCardEnd(child: cards[i])
                        : PassCardBand(height: layout.step, child: cards[i]),
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
