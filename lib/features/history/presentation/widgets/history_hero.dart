import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/core/format/number_format.dart';
import 'package:critalarm/design/components/jumping_text.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/history/presentation/history_pane.dart';
import 'package:critalarm/features/topics/presentation/widgets/topic_hero_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

/// The top of History: a face perched on a wide dark card that holds the
/// week's bars and two numbers.
///
/// The face is 60 points on a phone and 120 on a tablet or a wide window
/// ([historyHeroFaceSize]). It is the refresh face: a pull to refresh plays
/// working, success and failed on it, and the line beside it says what is
/// going on while that runs. On a cover screen the face is 72 beside a
/// one-line panel with the two numbers, and the week's bars drop.
class HistoryHero extends StatefulWidget {
  const HistoryHero({
    required this.week,
    required this.isFiltered,
    this.isBeside = false,
    super.key,
  });

  final WeekBars week;

  /// A filter is on. The card then says what the filter matches and makes no
  /// claim about the week.
  final bool isFiltered;

  /// The face at 120 beside the card, overlapping its left edge, instead of
  /// perched on its corner: the top half of a tabletop fold, too short for
  /// the face on top of the card.
  final bool isBeside;

  /// The face's width and height on a phone. See [historyHeroFaceSize].
  static const double faceSize = 60;

  /// How far the card reaches up under the face.
  static const double overlap = 10;

  @override
  State<HistoryHero> createState() => _HistoryHeroState();
}

class _HistoryHeroState extends State<HistoryHero> {
  /// How long the result of a refresh stays on screen.
  static const Duration _resultHold = Duration(milliseconds: 1600);

  RefreshFaceController? _refresh;
  RefreshFacePhase _phase = RefreshFacePhase.idle;
  String? _result;
  Timer? _clearResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = RefreshFaceScope.maybeOf(context);
    if (refresh == _refresh) return;
    _refresh?.removeListener(_onRefresh);
    _refresh = refresh?..addListener(_onRefresh);
  }

  @override
  void dispose() {
    _refresh?.removeListener(_onRefresh);
    _clearResult?.cancel();
    super.dispose();
  }

  void _onRefresh() {
    final phase = _refresh!.phase;
    if (phase == _phase) return;
    _phase = phase;

    final result = switch (phase) {
      RefreshFacePhase.success => LocaleKeys.history_refresh_done.tr(),
      RefreshFacePhase.failed => LocaleKeys.history_refresh_failed.tr(),
      _ => null,
    };
    if (result != null) {
      _clearResult?.cancel();
      _clearResult = Timer(_resultHold, () {
        if (mounted) setState(() => _result = null);
      });
      setState(() => _result = result);
    } else if (phase == RefreshFacePhase.working) {
      _clearResult?.cancel();
      setState(() => _result = null);
    } else {
      setState(() {});
    }
  }

  /// The line beside the face: what the refresh is doing, then how it went.
  String? get _status => _phase == RefreshFacePhase.working
      ? LocaleKeys.history_refresh_checking.tr()
      : _result;

  AppStatDay _day(WeekBarDay day) {
    final name = DateFormat('EEEE', currentFormatLocale()).format(day.day);
    final label = day.isHidden
        ? LocaleKeys.history_hero_day_hidden.tr(namedArgs: {'day': name})
        : day.alarms == 0
        ? LocaleKeys.history_hero_day_none.tr(namedArgs: {'day': name})
        : (day.unanswered > 0
                  ? LocaleKeys.history_hero_day_unanswered
                  : LocaleKeys.history_hero_day_alarms)
              .plural(day.alarms, namedArgs: {'day': name});
    return AppStatDay(
      letter: DateFormat('EEEEE', currentFormatLocale()).format(day.day),
      alarms: day.alarms,
      isToday: day.isToday,
      hasUnanswered: day.unanswered > 0,
      isHidden: day.isHidden,
      semanticsLabel: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final week = widget.week;
    final longest = week.longestAnswered;
    final status = _status;
    final size = AppSize.of(context);
    final faceSize = historyHeroFaceSize(size, isBeside: widget.isBeside);
    final firstValue = '${week.alarms}${week.mayBeShort ? '+' : ''}';
    final firstCaption = widget.isFiltered
        ? LocaleKeys.history_hero_alarms_filtered.plural(week.alarms)
        : LocaleKeys.history_hero_alarms_days.plural(
            week.alarms,
            namedArgs: {'days': '${week.visibleDays}'},
          );
    final secondValue = longest == null
        ? LocaleKeys.history_hero_none.tr()
        : formatCompactDuration(longest);
    final secondCaption = LocaleKeys.history_hero_longest_answered.tr();

    final face = ExcludeSemantics(
      child: stageFace(
        context,
        state: week.face,
        size: faceSize,
        isLive: false,
      ),
    );

    if (size.isCover) {
      // The face beside one line: the count and the longest answer. The
      // refresh still plays on the face.
      return SizedBox(
        height: faceSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8 + faceSize - HistoryHero.overlap,
              right: 0,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroLinePanel(
                    parts: [
                      HeroLinePart(value: firstValue, words: firstCaption),
                      HeroLinePart(value: secondValue, words: secondCaption),
                    ],
                    semanticsLabel:
                        '$firstValue $firstCaption, '
                        '$secondValue $secondCaption',
                  ),
                ],
              ),
            ),
            Positioned(left: 8, top: 0, child: face),
          ],
        ),
      );
    }

    final card = AppStatCard(
      days: [for (final day in week.days) _day(day)],
      firstValue: firstValue,
      firstCaption: firstCaption,
      secondValue: secondValue,
      secondCaption: secondCaption,
      semanticsLabel: widget.isFiltered
          ? LocaleKeys.history_hero_chart_label_filtered.tr()
          : LocaleKeys.history_hero_chart_label.tr(
              namedArgs: {'days': '${week.visibleDays}'},
            ),
    );

    final statusLine = status == null
        ? null
        : Semantics(
            liveRegion: true,
            child: JumpingText(
              status,
              style: AppStage.horizontalSubStyle(colors),
              gradient: [colors.cobalt, colors.crit, colors.high],
              wave: _phase == RefreshFacePhase.working,
            ),
          );

    if (widget.isBeside) {
      // The card starts where the face ends, less the overlap, and a little
      // below the face's top, the way the Topics hero sits beside its card.
      final cardLeft = 8 + faceSize - HistoryHero.overlap;
      final cardTop = (faceSize * 0.176).roundToDouble();
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 8, top: 0, child: face),
          Padding(
            padding: EdgeInsets.only(left: cardLeft, top: cardTop),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: faceSize - cardTop),
              child: card,
            ),
          ),
          if (statusLine != null)
            Positioned(
              left: cardLeft + 20,
              right: 8,
              top: 0,
              height: cardTop,
              child: Align(alignment: Alignment.centerLeft, child: statusLine),
            ),
        ],
      );
    }

    final lift = faceSize - HistoryHero.overlap;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: lift),
          child: card,
        ),
        Positioned(left: 8, top: 0, child: face),
        if (statusLine != null)
          Positioned(
            left: 8 + faceSize + 12,
            right: 8,
            top: 0,
            height: lift,
            child: Align(alignment: Alignment.centerLeft, child: statusLine),
          ),
      ],
    );
  }
}

/// How wide the disc behind the face is, in points.
const double _kDiscDiameter = 340;

/// Where the ambient canvas draws the disc behind the face on this display.
///
/// It follows the scaffold's column rules through [AppScreenColumns] (a
/// capped, centred column on a medium display, a list pane inside the frame
/// on an expanded one, the start pane in book posture), the way the Topics
/// hero does, so the disc stays behind the face. With [onStage] the hero is
/// in the fold stage (the top half in tabletop posture).
HeroDiscSpot historyDiscSpotOf(
  BuildContext context, {
  bool onStage = false,
  bool isBeside = false,
}) {
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final fold = AppFold.of(context);
  final panes = fold.panes(
    screen,
    direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
  );
  final Offset faceTopLeft;
  final double face;
  if (onStage) {
    final spot = foldStageHeroSpot(context);
    face = historyHeroFaceSize(
      AppSize.from(
        panes.first.size,
        isIphone: AppDeviceScope.isIphoneOf(context),
      ),
      isBeside: isBeside,
    );
    faceTopLeft = spot.origin + const Offset(12 + 8, 0);
  } else {
    final columns = AppScreenColumns.of(context, hasDetail: true);
    // The list's own box: the start pane in book posture, else the window.
    final listBox = fold.isBook ? panes.first.size : screen;
    face = historyHeroFaceSize(
      AppSize.from(listBox, isIphone: AppDeviceScope.isIphoneOf(context)),
    );
    // History trims the room over the hero on a cover screen.
    final above = AppSize.of(context).isCover ? Spacing.s2 : Spacing.s3;
    faceTopLeft = Offset(
      columns.contentLeft + 12 + 8,
      padding.top + AppScreenScaffold.topBarHeight + above,
    );
  }
  final centre = faceTopLeft + Offset(face / 2, face / 2);
  return HeroDiscSpot(
    anchor: Alignment(
      centre.dx / screen.width * 2 - 1,
      centre.dy / screen.height * 2 - 1,
    ),
    discScale: math.min(_kDiscDiameter / screen.shortestSide, 2),
    ringScale: 0,
  );
}
