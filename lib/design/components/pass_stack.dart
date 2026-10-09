import 'dart:math' as math;

import 'package:critalarm/design/components/pass_card.dart';
import 'package:critalarm/design/components/pass_page.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A card is this tall, except the last.
const double kPassCardHeight = 260;

/// The last card is at least this tall, and bleeds off the bottom edge.
const double kPassLastCardMinHeight = 220;

/// How far past the display's bottom edge the last card reaches.
const double kPassCardBleed = 34;

/// The least distance between two cards' tops.
const double kPassMinStep = 134;

/// A card's distance from the sides of the column.
const double kPassCardInset = 12;

/// The gap between the header ring and the first card.
const double kPassStackGap = 26;

/// The gap between cards in the flat stack.
const double kPassFlatGap = 10;

/// The height of a card's label and value, for a two-line value at
/// [textScale]. The label stops growing at the chrome limit; the value does
/// not.
double passBandContentHeight(double textScale) {
  final label = 11 * math.min(textScale, kChromeMaxTextScale) * 1.2;
  final value = 2 * kPassCardValueSize * textScale * 1.05;
  return label + 4 + value;
}

/// How the stack is laid out.
enum PassStackMode {
  /// Cards overlap, each showing a band. Text scale under 1.3.
  overlapped,

  /// Cards are a column of full cards with a gap. Text scale 1.3 and above.
  flat,
}

/// Where the header and the cards of the stack go on one display. Pure.
///
/// On a 390 by 844 phone with a 47 point inset, the cards' tops are 122, 256,
/// 390, 524 and 658; each is 260 tall except the last, which is 220 and
/// bleeds off the bottom edge. A stack with fewer cards ends the last one
/// lower, so it reaches the bottom edge all the same. All positions are
/// relative to the display; the cards sit [cardLeft] from its left edge and
/// are [cardWidth] wide.
@immutable
class PassStackLayout {
  const PassStackLayout._({
    required this.mode,
    required this.columnWidth,
    required this.columnLeft,
    required this.headerTop,
    required this.stackTop,
    required this.step,
    required this.tops,
    required this.heights,
    required this.scrollExtent,
    required this.bottomPadding,
  });

  /// Lays out [count] cards on a display [width] by [height] points.
  ///
  /// [safeTop] is the inset at the top of the display and [safeBottom] the
  /// one at the bottom. [contentHeight] is the height of the tallest card's
  /// label and value, for the band step; it defaults to a two-line value at
  /// [textScale] ([passBandContentHeight]).
  factory PassStackLayout.of({
    required double width,
    required double height,
    required double textScale,
    required int count,
    double safeTop = 0,
    double safeBottom = 0,
    double? contentHeight,
  }) {
    final columnWidth = math.min(width, AppSize.contentMaxWidth);
    final columnLeft = (width - columnWidth) / 2;
    final headerTop = safeTop + kPassRingTop;
    final stackTop = headerTop + kPassRingSize + kPassStackGap;
    final mode = textScale >= kChromeMaxTextScale
        ? PassStackMode.flat
        : PassStackMode.overlapped;
    if (mode == PassStackMode.flat) {
      return PassStackLayout._(
        mode: mode,
        columnWidth: columnWidth,
        columnLeft: columnLeft,
        headerTop: headerTop,
        stackTop: stackTop,
        step: 0,
        tops: const [],
        heights: const [],
        scrollExtent: 0,
        bottomPadding: safeBottom + 24,
      );
    }
    final step = math.max(
      kPassMinStep,
      (contentHeight ?? passBandContentHeight(textScale)) + 30,
    );
    final tops = [for (var i = 0; i < count; i++) stackTop + i * step];
    final heights = [
      for (var i = 0; i < count; i++)
        i == count - 1
            ? math.max(
                kPassLastCardMinHeight,
                height - tops[i] + kPassCardBleed,
              )
            : kPassCardHeight,
    ];
    final lastBottom = count == 0 ? stackTop : tops.last + heights.last;
    return PassStackLayout._(
      mode: mode,
      columnWidth: columnWidth,
      columnLeft: columnLeft,
      headerTop: headerTop,
      stackTop: stackTop,
      step: step,
      tops: tops,
      heights: heights,
      // The bleed is meant to hang off the edge, so it needs no scroll.
      scrollExtent: math.max(height, lastBottom - kPassCardBleed),
      bottomPadding: 0,
    );
  }

  final PassStackMode mode;

  /// `min(width, 560)`.
  final double columnWidth;

  /// Where the column starts.
  final double columnLeft;

  /// The back ring's top: the inset plus 5.
  final double headerTop;

  /// The first card's top: the ring's bottom plus 26.
  final double stackTop;

  /// The distance between two tops. Zero in flat mode.
  final double step;

  /// Each card's top and height. Empty in flat mode, where the cards size
  /// themselves.
  final List<double> tops;
  final List<double> heights;

  /// How tall the scrolled content is in overlapped mode.
  final double scrollExtent;

  /// The space under the last card in flat mode: the bottom inset plus 24.
  final double bottomPadding;

  /// A card's left edge and width.
  double get cardLeft => columnLeft + kPassCardInset;
  double get cardWidth => columnWidth - 2 * kPassCardInset;
}

/// The Personalize root: a header row and a stack of [AppPassCard]s.
///
/// The header is a ringed back button (44 points, at 16 from the left,
/// 5 below the inset) and [title] in Bricolage 24 beside it. Under it the
/// cards overlap, each showing a 134 point band, with the last bleeding off
/// the bottom edge. From text scale 1.3 they stop overlapping and become a
/// column of full cards, so a long value is never cut. The stack scrolls, and
/// sits in a column `min(width, 560)` wide, centred.
///
/// Give it the cards in order, top to bottom. A pass that does not exist on
/// the phone is left out by the caller. The stack places the
/// [PassOriginScope] its cards read, so the card that is opened can hide
/// while its page is up and the others can slide away.
///
/// The group is labelled [groupLabel] for a screen reader, in stack order.
class AppPassStack extends StatelessWidget {
  const AppPassStack({
    required this.title,
    required this.backLabel,
    required this.cards,
    this.onBack,
    this.groupLabel,
    this.safeTop,
    this.safeBottom,
    this.controller,
    this.handoff,
    super.key,
  });

  /// The header, such as "Personalize".
  final String title;

  /// The back ring's spoken name, such as "Back to Settings".
  final String backLabel;

  final List<AppPassCard> cards;

  /// What the back ring does. Defaults to popping the route.
  final VoidCallback? onBack;

  /// The spoken name of the group of cards.
  final String? groupLabel;

  /// Override the insets. They default to the display's.
  final double? safeTop;
  final double? safeBottom;

  final ScrollController? controller;

  /// A handoff of the caller's own, in place of the one the stack makes.
  final PassHandoff? handoff;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final layout = PassStackLayout.of(
          width: constraints.maxWidth,
          height: height,
          textScale: scale,
          count: cards.length,
          safeTop: safeTop ?? padding.top,
          safeBottom: safeBottom ?? padding.bottom,
        );
        final isFlat = layout.mode == PassStackMode.flat;
        final header = _Header(
          layout: layout,
          title: title,
          backLabel: backLabel,
          onBack: onBack ?? () => Navigator.of(context).maybePop(),
        );
        final Widget body;
        if (isFlat) {
          body = Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: layout.columnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: layout.stackTop,
                    child: Stack(children: [header]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kPassCardInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: kPassFlatGap),
                          cards[i],
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: layout.bottomPadding),
                ],
              ),
            ),
          );
        } else {
          body = SizedBox(
            width: constraints.maxWidth,
            height: layout.scrollExtent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                header,
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: layout.cardLeft,
                    width: layout.cardWidth,
                    top: layout.tops[i],
                    height: layout.heights[i],
                    child: cards[i],
                  ),
              ],
            ),
          );
        }
        return PassOriginScope(
          handoff: handoff,
          child: PassCardLayout(
            isFlat: isFlat,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: groupLabel,
              child: SingleChildScrollView(
                controller: controller,
                child: body,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.layout,
    required this.title,
    required this.backLabel,
    required this.onBack,
  });

  final PassStackLayout layout;
  final String title;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.onCanvas;
    final capped = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kChromeMaxTextScale);
    return Stack(
      children: [
        Positioned(
          left: layout.columnLeft + kPassRingLeft,
          top: layout.headerTop,
          child: PassBackRing(color: color, label: backLabel, onTap: onBack),
        ),
        Positioned(
          left: layout.columnLeft + 72,
          right: 0,
          top: layout.headerTop,
          height: kPassRingSize,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: capped),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.02 * 24,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
