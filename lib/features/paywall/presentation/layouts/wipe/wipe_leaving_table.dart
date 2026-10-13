import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

// The list under the stage of a Wipe for a plan that is leaving. Two
// columns, "Today" and the day the plan has ended, with a row each for the
// alarm history and the high priority pushes, and one sentence across both
// columns for the critical topics. No check marks, no buttons.
//
//             Today      21 Oct
// Alarm history        90 days    7 days
// High priority pushes 1,000      50
// Your 4 stay critical. No new ones past 2.

/// One figure row of the list.
@immutable
class WipeLeavingCells {
  const WipeLeavingCells({
    required this.label,
    required this.today,
    required this.after,
  });

  final String label;

  /// The figure on the colour side, and on the grey side.
  final String today;
  final String after;
}

/// The words of the list, ready to draw.
@immutable
class WipeLeavingText {
  const WipeLeavingText({
    required this.todayHead,
    required this.afterHead,
    required this.figures,
    required this.critical,
  });

  /// The two column heads: "Today" and the date.
  final String todayHead;
  final String afterHead;

  /// The history and pushes rows, in the table's order.
  final List<WipeLeavingCells> figures;

  /// The critical topics sentence, or null when the product has no such row.
  final String? critical;

  /// What a screen reader says for [cells].
  String spoken(WipeLeavingCells cells) =>
      '${cells.label}. $todayHead ${cells.today}. $afterHead ${cells.after}';
}

/// The words for [rows], from the strings and from `HostedBenefit.args`, so a
/// number is never typed here. [critical] is how many critical topics the
/// person has on, or null when it is not known.
WipeLeavingText wipeLeavingTextFor({
  required List<WipeLeavingRow> rows,
  required String afterHead,
  required int? critical,
}) {
  final args = HostedBenefit.args;
  String days(String key) => LocaleKeys.paywall_leaving_wipe_days.tr(
    namedArgs: {'value': args[key]!},
  );

  String? criticalLine() {
    if (!rows.contains(WipeLeavingRow.topics)) return null;
    final named = {...args, 'n': '${critical ?? 0}'};
    return switch (leavingCriticalLineFor(critical ?? 0)) {
      LeavingCriticalLine.many => LocaleKeys.paywall_leaving_wipe_critical.tr(
        namedArgs: named,
      ),
      LeavingCriticalLine.one =>
        LocaleKeys.paywall_leaving_wipe_critical_one.tr(namedArgs: named),
      LeavingCriticalLine.none =>
        LocaleKeys.paywall_leaving_wipe_critical_none.tr(namedArgs: named),
    };
  }

  return WipeLeavingText(
    todayHead: LocaleKeys.paywall_leaving_wipe_today.tr(),
    afterHead: afterHead,
    figures: [
      for (final row in rows)
        switch (row) {
          WipeLeavingRow.history => WipeLeavingCells(
            label: LocaleKeys.paywall_leaving_wipe_label_history.tr(),
            today: days('hosted_history_days'),
            after: days('free_history_days'),
          ),
          WipeLeavingRow.pushes => WipeLeavingCells(
            label: LocaleKeys.paywall_leaving_wipe_label_pushes.tr(),
            today: args['hosted_p4_daily']!,
            after: args['free_p4_daily']!,
          ),
          WipeLeavingRow.topics => null,
        },
    ].nonNulls.toList(),
    critical: criticalLine(),
  );
}

/// The list measured before it is drawn: the styles, the column widths and
/// each row's fixed height, so the stage above takes what is left.
class WipeLeavingMetrics {
  WipeLeavingMetrics.measure(
    BuildContext context, {
    required this.text,
    required this.width,
    required this.sizes,
    PaywallTone tone = PaywallTone.canvas,
  }) : ink = PaywallToneColors.of(context, tone).ink,
       scaler = MediaQuery.textScalerOf(context) {
    head = AppTypography.label(ink);
    todayStyle = AppTypography.small(
      ink,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.3);
    afterStyle = AppTypography.small(
      ink,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w500, height: 1.3);
    labelStyle = todayStyle.copyWith(fontWeight: FontWeight.w600);
    sentenceStyle = AppTypography.small(
      ink,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w600, height: 1.3);

    var widest = math.max(
      _widthOf(text.todayHead, head),
      _widthOf(text.afterHead, head),
    );
    for (final cells in text.figures) {
      widest = math.max(
        widest,
        math.max(
          _widthOf(cells.today, todayStyle),
          _widthOf(cells.after, afterStyle),
        ),
      );
    }
    column = math.max(minColumn, widest.ceilToDouble());
    final room = width - column * 2 - labelGap;

    headHeight = paywallTextHeight(context, text.todayHead, head, column);
    figureHeight = paywallTextHeight(context, '0', todayStyle, column);
    stacked = [
      for (final cells in text.figures)
        _widthOf(cells.label, labelStyle) * labelShrinkLeast > room,
    ];
    rowHeights = [
      for (final (i, cells) in text.figures.indexed)
        stacked[i]
            ? paywallTextHeight(context, cells.label, labelStyle, width) +
                  figureHeight
            : figureHeight,
    ];
    final critical = text.critical;
    criticalHeight = critical == null
        ? 0
        : paywallTextHeight(context, critical, sentenceStyle, width);
  }

  /// The least width of a figure column, at the default text size.
  static const double minColumn = 72;

  /// Between the label and the first column.
  static const double labelGap = 8;

  /// Under the column heads.
  static const double headGap = 4;

  /// A label that would shrink to less than this share of its size to fit
  /// beside the columns goes on a line of its own above its figures.
  static const double labelShrinkLeast = 0.7;

  final WipeLeavingText text;
  final double width;
  final HeroSizes sizes;
  final Color ink;
  final TextScaler scaler;

  late final TextStyle head;
  late final TextStyle todayStyle;
  late final TextStyle afterStyle;
  late final TextStyle labelStyle;
  late final TextStyle sentenceStyle;

  /// The width of each figure column, and the room the label has.
  late final double column;

  late final double headHeight;
  late final double figureHeight;

  /// Per figure row: the label did not fit beside the columns, so it has the
  /// full width above its figures.
  late final List<bool> stacked;
  late final List<double> rowHeights;
  late final double criticalHeight;

  double _widthOf(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: ui.TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  /// The height of the whole list, gaps included.
  double get height {
    final items = text.figures.length + (text.critical == null ? 0 : 1);
    return headHeight +
        headGap +
        rowHeights.fold<double>(0, (sum, h) => sum + h) +
        criticalHeight +
        sizes.rowGap * math.max(0, items - 1);
  }
}

/// The list. Nothing in it is a button.
class WipeLeavingTable extends StatelessWidget {
  const WipeLeavingTable({required this.metrics, super.key});

  final WipeLeavingMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final text = m.text;

    Widget figure(String value, TextStyle style) => SizedBox(
      width: m.column,
      child: Text(
        value,
        style: style,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
      ),
    );

    Widget head(String value) => SizedBox(
      width: m.column,
      child: Text(
        value,
        style: m.head,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The heads are read with their rows.
        ExcludeSemantics(
          child: SizedBox(
            height: m.headHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [head(text.todayHead), head(text.afterHead)],
            ),
          ),
        ),
        const SizedBox(height: WipeLeavingMetrics.headGap),
        for (final (i, cells) in text.figures.indexed) ...[
          if (i > 0) SizedBox(height: m.sizes.rowGap),
          Semantics(
            container: true,
            label: text.spoken(cells),
            child: ExcludeSemantics(
              child: SizedBox(
                height: m.rowHeights[i],
                child: m.stacked[i]
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(cells.label, style: m.labelStyle),
                          SizedBox(
                            height: m.figureHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                figure(cells.today, m.todayStyle),
                                figure(cells.after, m.afterStyle),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                cells.label,
                                style: m.labelStyle,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: WipeLeavingMetrics.labelGap),
                          figure(cells.today, m.todayStyle),
                          figure(cells.after, m.afterStyle),
                        ],
                      ),
              ),
            ),
          ),
        ],
        if (text.critical case final sentence?) ...[
          if (text.figures.isNotEmpty) SizedBox(height: m.sizes.rowGap),
          Text(sentence, style: m.sentenceStyle),
        ],
      ],
    );
  }
}
