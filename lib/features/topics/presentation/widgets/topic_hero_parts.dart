import 'package:critalarm/core/format/when_label.dart';
import 'package:critalarm/design/ambient/hero_disc.dart';
import 'package:critalarm/design/components/hero_scene.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/shadows.dart';
import 'package:critalarm/design/tokens/spacing.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:critalarm/features/topics/domain/topic_hero_card.dart';
import 'package:critalarm/features/topics/domain/topic_summary.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

/// The name's size and line height. A name that does not fit on two lines at
/// the first size steps down through the others until it does.
const List<double> _kNameSizes = [25, 21, 18, 16, 14];
const double _kNameLine = 1.25;

/// The summary's size and line height.
const double _kSummarySize = 14.5;
const double _kSummaryLine = 1.35;

/// The gap between the name and the summary.
const double _kHeaderGap = 2;

/// How many lines the summary may take: two once the text is large (the
/// chrome cap or more), or when [summary] does not fit one line of [width]
/// points. The time at its end is the point of the line, so it is not cut.
///
/// [summary] is null when the caller does not know it yet. Then only the text
/// size decides.
int _summaryLines(
  BuildContext context, {
  required double width,
  String? summary,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  if (scaler.scale(16) / 16 >= kChromeMaxTextScale) return 2;
  if (summary == null || summary.isEmpty) return 1;
  final room = width > 2 * _kHeaderSide ? width - 2 * _kHeaderSide : 0.0;
  final painter = TextPainter(
    text: TextSpan(
      text: summary,
      style: DefaultTextStyle.of(context).style.merge(
        AppTypography.small(
          context.appColors.onCanvasMuted,
          fontSize: _kSummarySize,
        ).copyWith(height: _kSummaryLine),
      ),
    ),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout(maxWidth: room);
  final exceeds = painter.didExceedMaxLines;
  painter.dispose();
  return exceeds ? 2 : 1;
}

/// The side padding of [TopicHeader].
const double _kHeaderSide = 20;

/// The most lines a name takes before it ends in an ellipsis.
const int _kNameMaxLines = 2;

TextStyle _nameStyle(AppColors colors, double size) => AppTypography.monoBold(
  colors.onCanvas,
  fontSize: size,
).copyWith(height: _kNameLine, letterSpacing: -size / 100);

/// How a name is set in a header: its type size and how many lines it takes.
@immutable
class TopicNameFit {
  const TopicNameFit({required this.size, required this.lines});

  final double size;
  final int lines;
}

/// The biggest size at which [name] fits on two lines in a header [width]
/// points wide, and the lines it takes there. A long name wraps at its
/// hyphens, and a word with none breaks where the line ends. The smallest
/// size ends in an ellipsis if the name still does not fit.
TopicNameFit topicNameFit(
  BuildContext context,
  String name, {
  required double width,
}) {
  final colors = context.appColors;
  final direction = Directionality.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final room = width > 2 * _kHeaderSide ? width - 2 * _kHeaderSide : 0.0;
  var lines = 1;
  for (final size in _kNameSizes) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: _nameStyle(colors, size)),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: room);
    lines = painter.computeLineMetrics().length;
    painter.dispose();
    if (lines <= _kNameMaxLines) {
      return TopicNameFit(size: size, lines: lines);
    }
  }
  return TopicNameFit(size: _kNameSizes.last, lines: _kNameMaxLines);
}

/// How tall [TopicHeader] is for the text size of [context] and the way
/// [name] is set at [width]. Pass [summary] when it is known, so a summary
/// that needs two lines at a normal text size is counted.
///
/// Fixed once the name is known, because the canvas draws the hero's disc and
/// has to know where the scene starts: a name is never taller than two lines,
/// whatever it says.
double topicHeaderHeight(
  BuildContext context, {
  required String name,
  required double width,
  String? summary,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final fit = topicNameFit(context, name, width: width);
  final summaryLines = _summaryLines(context, width: width, summary: summary);
  return fit.lines * scaler.scale(fit.size) * _kNameLine +
      _kHeaderGap +
      summaryLines * scaler.scale(_kSummarySize) * _kSummaryLine;
}

/// The topic's name in mono and the one line under it.
///
/// The name takes up to two lines, in a smaller type when it needs the room,
/// and ends in an ellipsis only past that. The summary takes one line (two at
/// large text, or when one line cannot hold it). A screen reader gets both
/// in full.
class TopicHeader extends StatelessWidget {
  const TopicHeader({
    required this.name,
    required this.summary,
    super.key,
  });

  final String name;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      header: true,
      label: '$name. $summary',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kHeaderSide),
          child: LayoutBuilder(
            builder: (context, box) {
              final fit = topicNameFit(
                context,
                name,
                width: box.maxWidth + 2 * _kHeaderSide,
              );
              final summaryLines = _summaryLines(
                context,
                width: box.maxWidth + 2 * _kHeaderSide,
                summary: summary,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: fit.lines * scaler.scale(fit.size) * _kNameLine,
                    child: Text(
                      name,
                      maxLines: _kNameMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: _nameStyle(colors, fit.size),
                    ),
                  ),
                  const SizedBox(height: _kHeaderGap),
                  SizedBox(
                    height:
                        summaryLines *
                        scaler.scale(_kSummarySize) *
                        _kSummaryLine,
                    child: Text(
                      summary,
                      maxLines: summaryLines,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.small(
                        colors.onCanvasMuted,
                        fontSize: _kSummarySize,
                      ).copyWith(height: _kSummaryLine),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The line under the name, for [summary].
String topicSummaryText(TopicSummary summary) {
  if (summary.isEmpty) return LocaleKeys.topic_hero_summary_nothing.tr();
  final count = summary.today == 0
      ? LocaleKeys.topic_hero_summary_none_today.tr()
      : LocaleKeys.topic_hero_summary_today.plural(summary.today);
  final at = summary.lastAlarmAt;
  if (at == null) return count;
  // Said inside a sentence, so the day before is in lower case.
  final time = formatWhen(
    at: at,
    now: DateTime.now(),
    yesterday: LocaleKeys.topic_hero_summary_yesterday.tr(),
  );
  final last = LocaleKeys.topic_hero_summary_last_alarm.tr(
    namedArgs: {'time': time},
  );
  return LocaleKeys.topic_hero_summary_join.tr(
    namedArgs: {'count': count, 'last': last},
  );
}

/// The foot of the card for [foot].
String topicFootText(TopicHeroFoot foot) => switch (foot) {
  TopicHeroFoot.ringsThroughSilent =>
    LocaleKeys.topic_hero_foot_rings_through_silent.tr(),
  TopicHeroFoot.timeSensitive => LocaleKeys.topic_hero_foot_time_sensitive.tr(),
  TopicHeroFoot.normalPush => LocaleKeys.topic_hero_foot_normal_push.tr(),
  TopicHeroFoot.needsAlarm => LocaleKeys.topic_hero_foot_needs_alarm.tr(),
};

/// The dark card with the Critical delivery switch.
///
/// The numeral is On in yellow or Off muted. The switch is in the card's
/// trailing slot, in the panel variant so its off track shows on the dark
/// card. A tap on the card body opens the info dialog.
class TopicCriticalCard extends StatefulWidget {
  const TopicCriticalCard({
    required this.card,
    required this.onChanged,
    required this.onInfo,
    super.key,
  });

  final TopicHeroCard card;

  /// Null leaves the switch still.
  final ValueChanged<bool>? onChanged;

  /// Opens the explanation of Critical delivery.
  final VoidCallback onInfo;

  @override
  State<TopicCriticalCard> createState() => _TopicCriticalCardState();
}

class _TopicCriticalCardState extends State<TopicCriticalCard> {
  /// The numeral that was on the card before this build was dots. The step
  /// from dots to the real answer is the screen finishing loading, not news,
  /// so it does not pop.
  bool _cameFromLoading = false;

  @override
  void didUpdateWidget(covariant TopicCriticalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cameFromLoading = oldWidget.card.isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final foot = card.foot;
    final numeral = card.isLoading
        ? '···'
        : card.isOn
        ? LocaleKeys.topic_hero_numeral_on.tr()
        : LocaleKeys.topic_hero_numeral_off.tr();
    return AppStatusCard(
      label: LocaleKeys.topic_hero_card_label.tr().toUpperCase(),
      numeral: numeral,
      numeralTone: card.isOn ? AppStatusTone.yellow : AppStatusTone.muted,
      foot: foot == null ? null : topicFootText(foot),
      footMaxLines: 2,
      popsOnChange: !_cameFromLoading,
      onTap: card.isLoading ? null : widget.onInfo,
      trailing: AppSwitch(
        value: card.isOn,
        variant: AppSwitchVariant.panel,
        onChanged: widget.onChanged,
        semanticLabel: LocaleKeys.topic_detail_critical_toggle_title.tr(),
        semanticHint: foot == null ? null : topicFootText(foot),
      ),
    );
  }
}

/// The column a fold stage lays its hero in, worked out the way the scaffold
/// lines up the stage's top bar: the stage pane's own size, no rail. With
/// [boxWidth] the stage pane's width.
AppScreenColumns foldStageColumnsFor(BuildContext context, double boxWidth) =>
    AppScreenColumns.resolve(
      boxWidth: boxWidth,
      size: AppSize.of(context),
      padding: MediaQuery.paddingOf(context),
      hasTabBar: false,
    );

/// What a screen hands `AppScreenScaffold.foldStage`: [children] stacked at
/// the top of the stage pane, in the same column as the stage's top bar.
///
/// The stage holds still. Only a stage taller than its pane (large text in a
/// book start pane) scrolls, and that scroll stays inside the stage: its
/// notifications stop here, so it never drives the shared refresh face the
/// list in the other pane pulls.
class FoldStageColumn extends StatelessWidget {
  const FoldStageColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = foldStageColumnsFor(context, constraints.maxWidth);
      return NotificationListener<Notification>(
        onNotification: (notification) =>
            notification is ScrollNotification ||
            notification is ScrollMetricsNotification ||
            notification is OverscrollIndicatorNotification,
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: columns.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    },
  );
}

/// Where the stage pane of the window [context] is drawn on puts the top of
/// its content, and the column it uses: the start pane in book posture, the
/// top half in tabletop. In window coordinates. [above] is the room between
/// the top bar and the hero (a topic's name, for one).
({Offset origin, double width}) foldStageHeroSpot(
  BuildContext context, {
  double above = 0,
}) {
  final window = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final pane = AppFold.of(context)
      .panes(
        window,
        direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
      )
      .first;
  final paneMedia = foldPaneMediaQuery(
    MediaQueryData(size: window, padding: padding),
    pane,
  );
  final columns = AppScreenColumns.resolve(
    boxWidth: pane.width,
    size: AppSize.from(pane.size, isIphone: AppDeviceScope.isIphoneOf(context)),
    padding: paneMedia.padding,
    hasTabBar: false,
  );
  return (
    origin: Offset(
      pane.left + columns.contentLeft,
      pane.top +
          paneMedia.padding.top +
          AppScreenScaffold.topBarHeight +
          Spacing.s3 +
          above,
    ),
    width: columns.contentWidth,
  );
}

/// The ambient disc behind a hero face drawn in a fold stage. The scaffold's
/// own [heroDiscSpotOf] follows the list, which on a fold is in the other
/// pane.
HeroDiscSpot foldStageDiscSpotOf(BuildContext context, {double above = 0}) {
  final spot = foldStageHeroSpot(context, above: above);
  return heroDiscSpot(
    screen: MediaQuery.sizeOf(context),
    sceneOrigin: spot.origin,
    sceneWidth: spot.width,
    textScale: MediaQuery.textScalerOf(context).scale(16) / 16,
  );
}

/// How a part of a [HeroLinePanel] is set.
enum HeroLineText {
  /// The status card's mono caps label.
  label,

  /// A plain caption, the stat card's.
  caption,
}

/// One value in a [HeroLinePanel], with its words before or after it.
@immutable
class HeroLinePart {
  const HeroLinePart({
    required this.value,
    this.words,
    this.wordsFirst = false,
    this.wordsStyle = HeroLineText.caption,
    this.tone = AppStatusTone.yellow,
  });

  final String value;
  final String? words;
  final bool wordsFirst;
  final HeroLineText wordsStyle;
  final AppStatusTone tone;
}

/// The dark hero panel cut to one line, for a cover screen: the words and the
/// value it answers with, nothing under them. Beside a 72 face it leaves the
/// list room for two rows above the tab bar.
///
/// A tap runs [onTap], so a card whose full version has a button keeps it:
/// the screen hands the button's action here.
class HeroLinePanel extends StatelessWidget {
  const HeroLinePanel({
    required this.parts,
    this.onTap,
    this.semanticsLabel,
    this.liveRegion = false,
    super.key,
  });

  final List<HeroLinePart> parts;
  final VoidCallback? onTap;

  /// True announces the panel's words when they change, as the full card
  /// does for a card whose kind changes while it is on screen.
  final bool liveRegion;

  /// What a screen reader says for the panel. Defaults to the parts' words.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    final surface = statusCardSurface(colors, brightness);
    final isDark = brightness == Brightness.dark;

    TextStyle words(HeroLineText style) => switch (style) {
      HeroLineText.label => TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        height: 1.2,
        letterSpacing: 0.88,
        color: colors.onPanelMuted,
      ),
      HeroLineText.caption => TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 13,
        height: 1.25,
        color: colors.onPanelMuted,
      ),
    };
    TextStyle value(AppStatusTone tone) => TextStyle(
      fontFamily: AppTypography.fontDisplay,
      fontFamilyFallback: AppTypography.fontDisplayFallbacks,
      fontWeight: FontWeight.w800,
      fontSize: 24,
      height: 1.05,
      letterSpacing: -0.03 * 24,
      color: tone.color(colors),
    );

    final spoken = [
      for (final part in parts)
        part.wordsFirst
            ? '${part.words ?? ''} ${part.value}'
            : '${part.value} ${part.words ?? ''}',
    ].join(', ');

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          if (parts[i].wordsFirst && parts[i].words != null) ...[
            Text(parts[i].words!, style: words(parts[i].wordsStyle)),
            const SizedBox(width: 10),
          ],
          Text(parts[i].value, maxLines: 1, style: value(parts[i].tone)),
          if (!parts[i].wordsFirst && parts[i].words != null) ...[
            const SizedBox(width: 6),
            Text(parts[i].words!, style: words(parts[i].wordsStyle)),
          ],
        ],
      ],
    );

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      liveRegion: liveRegion,
      label: semanticsLabel ?? spoken,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface.fill,
              borderRadius: Radii.xlAll,
              border: surface.line == null
                  ? null
                  : Border.all(color: surface.line!),
              boxShadow: isDark ? const [] : AppShadows.lightMd,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: line,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
