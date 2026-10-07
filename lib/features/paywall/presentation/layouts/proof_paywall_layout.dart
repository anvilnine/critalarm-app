import 'dart:math' as math;

import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_entrance.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_limit_bar.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_pro_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_replay.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_topic_card.dart';
import 'package:critalarm/features/paywall/presentation/layouts/proof/proof_topics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The Proof layout: no pitch, the app itself with the limit drawn on it.
///
/// Hosted replays the free cap on a topic list: the switch that will not
/// turn on, then the same tap working. The limits that are numbers are
/// bars under it, and they fill when the cap lifts. Pro has no cap to
/// replay, so its first benefit takes a dark stage and the others sit in a
/// strip under it.
class ProofPaywallLayout extends StatelessWidget {
  const ProofPaywallLayout({this.topics = proofDemoTopics, super.key});

  /// The topic list the Hosted replay is drawn on. Demo names until the
  /// caller hands in real ones. `proofTopicsFor` shapes whatever it gets.
  final List<ProofTopic> topics;

  static const double _side = 20;

  /// The empty end of the box that scrolls at a large text size. The fade
  /// at its edge is this tall, so it covers nothing while the content fits.
  static const double _scrollEnd = Spacing.s5;

  /// The least height the Pro side is drawn at when the text is large:
  /// the stage alone, and the stage over its strip of tiles.
  static const double _minScaledStage = 260;
  static const double _minScaledStageAndStrip = 400;

  /// How tall [text] is in [style] at this text size, [width] wide.
  static double _heightOf(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The end of the replay: every switch on.
      restAt: proofRestAt,
      // The plans side by side, so the list keeps the height.
      buyStyle: const PaywallBuyBlockStyle(
        pickerStyle: PaywallPlanPickerStyle.segments,
      ),
      builder: (context, scope) {
        final colors = context.appColors;
        final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
        final isScaled = scale > 1.01;
        final bottom = scope.isCompact ? Spacing.s2 : Spacing.s3;
        final gap = scope.isCompact ? Spacing.s2 : Spacing.s3;

        final headline = _headline(scope);
        final headlineStyle = AppTypography.headline(
          colors.onCanvas,
          fontSize: scope.isCompact ? 27 : 30,
        );
        // The close cross has the corner above the headline.
        final crossRow = scope.isCompact ? 38.0 : 42.0;

        final head = <Widget>[
          SizedBox(height: crossRow),
          ProofEntrance(
            clock: scope.clock,
            at: 0,
            seconds: 0.5,
            child: Semantics(
              header: true,
              child: Text(headline, style: headlineStyle),
            ),
          ),
          SizedBox(height: gap),
        ];

        // At the default text size everything shares the room and nothing
        // scrolls. At a larger one each part takes the height it needs and
        // the whole composition scrolls in its own box.
        if (!isScaled) {
          return Padding(
            padding: EdgeInsets.fromLTRB(_side, 0, _side, bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...head,
                Expanded(
                  child: scope.isHosted
                      ? _HostedProof(scope: scope, topics: topics)
                      : LayoutBuilder(
                          builder: (context, box) => ProofProStage(
                            benefits: scope.benefits,
                            clock: scope.clock,
                            height: box.maxHeight,
                            isCompact: scope.isCompact,
                          ),
                        ),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(_side, 0, _side, Spacing.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...head,
                    if (scope.isHosted)
                      _HostedProof(
                        scope: scope,
                        topics: topics,
                        textScale: scale,
                      )
                    else
                      ProofProStage(
                        benefits: scope.benefits,
                        clock: scope.clock,
                        // The room the headline leaves, so the stage
                        // only scrolls once that is too little to draw in.
                        height: math.max(
                          scope.benefits.length > 1
                              ? _minScaledStageAndStrip
                              : _minScaledStage,
                          scope.size.height -
                              crossRow -
                              gap -
                              _scrollEnd -
                              _heightOf(
                                context,
                                headline,
                                headlineStyle,
                                scope.size.width - _side * 2,
                              ),
                        ),
                        isCompact: scope.isCompact,
                      ),
                  ],
                ),
              ),
            ),
            // The rows dissolve into the canvas where the box ends.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppScrollFade(
                edge: ScrollFadeEdge.bottom,
                height: _scrollEnd,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _headline(PaywallLayoutScope scope) {
    if (scope.isHosted) {
      return LocaleKeys.paywall_proof_headline_hosted.tr(
        namedArgs: HostedBenefit.args,
      );
    }
    if (scope.benefits.isEmpty) {
      return LocaleKeys.paywall_kit_plain_headline_pro.tr();
    }
    final first = scope.benefits.first.title;
    final more = scope.benefits.length - 1;
    return switch (more) {
      0 => LocaleKeys.paywall_proof_headline_pro_one.tr(
        namedArgs: {'benefit': first},
      ),
      1 => LocaleKeys.paywall_proof_headline_pro_two.tr(
        namedArgs: {'benefit': first},
      ),
      _ => LocaleKeys.paywall_proof_headline_pro_many.tr(
        namedArgs: {'benefit': first, 'count': '$more'},
      ),
    };
  }
}

/// The Hosted side: the topic list, then a bar for each limit that is a
/// number, then the benefits that are neither.
class _HostedProof extends StatelessWidget {
  const _HostedProof({
    required this.scope,
    required this.topics,
    this.textScale,
  });

  final PaywallLayoutScope scope;
  final List<ProofTopic> topics;

  /// Null at the default text size, where the list takes the room that is
  /// left. Set at a larger one, where it takes the height it needs.
  final double? textScale;

  @override
  Widget build(BuildContext context) {
    final rows = proofTopicsFor(
      topics,
      // A short phone has the room for three rows.
      rows: scope.isCompact ? 3 : 4,
      cap: AccountCaps.free.criticalTopics ?? 2,
    );
    final paidName = paywallProductName(PaywallProduct.hosted);
    final gap = scope.isCompact ? 6.0 : 10.0;

    // What each benefit is drawn as. The topics one is the list itself.
    final bars = <(PaywallBenefit, HostedBenefit)>[];
    final extras = <PaywallBenefit>[];
    for (final benefit in scope.benefits) {
      if (benefit.id == PaywallBenefitId.topics) continue;
      final limit = _limitOf(benefit);
      if (limit != null) {
        bars.add((benefit, limit));
      } else {
        extras.add(benefit);
      }
    }

    Widget card(double height) => ProofEntrance(
      clock: scope.clock,
      at: 0.12,
      kind: ProofEntranceKind.fromRight,
      child: ProofTopicCard(
        topics: rows,
        clock: scope.clock,
        height: height,
        lockedLabel: paidName,
      ),
    );

    final scale = textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: scale == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (scale == null)
          Flexible(
            child: LayoutBuilder(
              builder: (context, box) => card(
                math.min(
                  box.maxHeight,
                  ProofTopicCard.maxHeightFor(rows.length),
                ),
              ),
            ),
          )
        else
          card(ProofTopicCard.naturalHeightFor(rows.length, scale)),
        for (final (i, (benefit, limit)) in bars.indexed)
          Padding(
            // The first bar stands clear of the card's shadow.
            padding: EdgeInsets.only(top: i == 0 ? Spacing.s3 : gap),
            child: ProofEntrance(
              clock: scope.clock,
              at: 0.3 + i * 0.12,
              kind: ProofEntranceKind.fromRight,
              child: ProofLimitBar(
                label: benefit.title,
                freeText: limit.compareFreeKey.tr(
                  namedArgs: HostedBenefit.args,
                ),
                paidText: limit.compareHostedKey.tr(
                  namedArgs: HostedBenefit.args,
                ),
                paidName: paidName,
                freeShare: limit.freeValue! / limit.hostedValue!,
                clock: scope.clock,
              ),
            ),
          ),
        if (extras.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: ProofEntrance(
              clock: scope.clock,
              at: 0.6,
              seconds: 0.5,
              child: _Extras(benefits: extras, isCompact: scope.isCompact),
            ),
          ),
      ],
    );
  }

  /// The Hosted limit behind [benefit], when it has a free number and a
  /// paid one to draw a bar from.
  static HostedBenefit? _limitOf(PaywallBenefit benefit) {
    for (final hosted in HostedBenefit.all) {
      if (hosted.id.name != benefit.id.name) continue;
      final free = hosted.freeValue;
      final paid = hosted.hostedValue;
      if (free == null || paid == null || paid <= 0) return null;
      return hosted;
    }
    return null;
  }
}

/// The benefits that are not a limit: each one a small preview and its
/// name, side by side.
class _Extras extends StatelessWidget {
  const _Extras({required this.benefits, required this.isCompact});

  final List<PaywallBenefit> benefits;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final edge = isCompact ? 26.0 : 32.0;

    return Wrap(
      spacing: Spacing.s4,
      runSpacing: Spacing.s1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final benefit in benefits)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaywallPreview(benefit.previewId, size: Size.square(edge)),
              const SizedBox(width: Spacing.s2),
              Flexible(
                child: Text(
                  benefit.title,
                  style: AppTypography.small(
                    colors.onCanvas,
                    fontSize: 12.5,
                  ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
