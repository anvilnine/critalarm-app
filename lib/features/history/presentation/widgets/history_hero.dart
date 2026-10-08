import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/components/jumping_text.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The top of History: a small still face perched on a wide dark card that
/// holds the week's bars and two numbers.
///
/// The face is 60 points, under the size where a face moves, so it stands
/// still. It is still the refresh face: a pull to refresh plays working,
/// success and failed on it, and the line beside it says what is going on
/// while that runs.
class HistoryHero extends StatefulWidget {
  const HistoryHero({
    required this.week,
    required this.isFiltered,
    super.key,
  });

  final WeekBars week;

  /// A filter is on. The card then says what the filter matches and makes no
  /// claim about the week.
  final bool isFiltered;

  /// The face's width and height.
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
    final name = DateFormat('EEEE').format(day.day);
    final label = day.isHidden
        ? LocaleKeys.history_hero_day_hidden.tr(namedArgs: {'day': name})
        : day.alarms == 0
        ? LocaleKeys.history_hero_day_none.tr(namedArgs: {'day': name})
        : (day.unanswered > 0
                  ? LocaleKeys.history_hero_day_unanswered
                  : LocaleKeys.history_hero_day_alarms)
              .plural(day.alarms, namedArgs: {'day': name});
    return AppStatDay(
      letter: DateFormat('EEEEE').format(day.day),
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

    final card = AppStatCard(
      days: [for (final day in week.days) _day(day)],
      firstValue: '${week.alarms}${week.mayBeShort ? '+' : ''}',
      firstCaption: widget.isFiltered
          ? LocaleKeys.history_hero_alarms_filtered.plural(week.alarms)
          : LocaleKeys.history_hero_alarms_days.plural(
              week.alarms,
              namedArgs: {'days': '${week.visibleDays}'},
            ),
      secondValue: longest == null
          ? LocaleKeys.history_hero_none.tr()
          : formatCompactDuration(longest),
      secondCaption: LocaleKeys.history_hero_longest_answered.tr(),
      semanticsLabel: widget.isFiltered
          ? LocaleKeys.history_hero_chart_label_filtered.tr()
          : LocaleKeys.history_hero_chart_label.tr(
              namedArgs: {'days': '${week.visibleDays}'},
            ),
    );

    const lift = HistoryHero.faceSize - HistoryHero.overlap;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: lift),
          child: card,
        ),
        Positioned(
          left: 8,
          top: 0,
          child: ExcludeSemantics(
            child: stageFace(
              context,
              state: week.face,
              size: HistoryHero.faceSize,
              isLive: false,
            ),
          ),
        ),
        if (status != null)
          Positioned(
            left: 8 + HistoryHero.faceSize + 12,
            right: 8,
            top: 0,
            height: lift,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: JumpingText(
                  status,
                  style: AppStage.horizontalSubStyle(colors),
                  gradient: [colors.cobalt, colors.crit, colors.high],
                  wave: _phase == RefreshFacePhase.working,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// How wide the disc behind the face is, in points.
const double _kDiscDiameter = 340;

/// Where the ambient canvas draws the disc behind the face on this display.
///
/// It follows the scaffold's column rules (a capped, centred column on a
/// medium display, a list pane beside the detail on an expanded one), the way
/// the Topics hero does, so the disc stays behind the face.
HeroDiscSpot historyDiscSpotOf(BuildContext context) {
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final size = AppSize.of(context);
  final isPane = size.isExpanded;
  final railOnRight = size.navPlacement == AppNavPlacement.right;
  final railGap = size.hasRail
      ? AppNavRail.contentGap + (railOnRight ? padding.right : padding.left)
      : 0.0;
  final available = screen.width - railGap;
  final paneWidth = isPane
      ? AppScreenScaffold.listPaneWidth(available)
      : screen.width;
  final gutter = isPane
      ? 0.0
      : math.max(railGap, (paneWidth - AppSize.contentMaxWidth) / 2);
  const half = HistoryHero.faceSize / 2;
  final centre = Offset(
    gutter + (isPane && !railOnRight ? railGap : 0) + 12 + 8 + half,
    padding.top + AppScreenScaffold.topBarHeight + Spacing.s3 + half,
  );
  return HeroDiscSpot(
    anchor: Alignment(
      centre.dx / screen.width * 2 - 1,
      centre.dy / screen.height * 2 - 1,
    ),
    discScale: math.min(_kDiscDiameter / screen.shortestSide, 2),
    ringScale: 0,
  );
}
