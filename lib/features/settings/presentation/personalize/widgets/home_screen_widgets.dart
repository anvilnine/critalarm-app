import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/settings/domain/personalize/widgets_page_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/widgets/widgets_ring_motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The edge of the Open incidents widget.
const double kOpenWidgetEdge = 160;

/// The edge of the Topic widget.
const double kTopicWidgetEdge = 168;

/// The gap between two widgets on the home screen.
const double kWidgetGap = 12;

/// The width of the whole home screen block: the two square widgets side by
/// side, and the wide one under them at the same width.
const double kWidgetsBlockWidth =
    kOpenWidgetEdge + kWidgetGap + kTopicWidgetEdge;

/// How many open incidents the drawn widgets report: the three rows of the
/// Topics widget.
const int kSampleOpenCount = 3;

const double _kRadius = 26;
const double _kPadding = 14;

/// The three home screen widgets as a phone draws them, upright, with sample
/// data: the Open incidents widget and the Topic widget side by side, the
/// Topics widget under them.
///
/// They are pictures: their words do not follow the text size, their faces
/// are yellow in both themes, and a screen reader meets each as one node
/// named for the widget. The face on the Open incidents widget rings (see
/// [widgetsRingAngle]); the other two are still.
class HomeScreenWidgets extends StatelessWidget {
  const HomeScreenWidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: kWidgetsBlockWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Named(
                  kind: HomeWidgetKind.openIncidents,
                  name: LocaleKeys.personalize_passes_widgets_name_open_count
                      .tr(),
                  child: const OpenIncidentsWidget(),
                ),
                const SizedBox(width: kWidgetGap),
                _Named(
                  kind: HomeWidgetKind.topic,
                  name: LocaleKeys.personalize_passes_widgets_name_topic.tr(),
                  child: const TopicWidget(),
                ),
              ],
            ),
            const SizedBox(height: kWidgetGap),
            _Named(
              kind: HomeWidgetKind.topics,
              name: LocaleKeys.personalize_passes_widgets_name_topics.tr(),
              child: const TopicsWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget keyed by its kind and named for a screen reader. What is drawn
/// inside it is sample data, so it stays out of the reading.
class _Named extends StatelessWidget {
  const _Named({required this.kind, required this.name, required this.child});

  final HomeWidgetKind kind;
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: name,
    child: ExcludeSemantics(
      child: KeyedSubtree(key: ValueKey('widget-${kind.name}'), child: child),
    ),
  );
}

/// The card every widget sits on: the surface colour, rounded, with a soft
/// shadow and a hairline so it stays a card in the dark theme.
class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.child, this.width, this.height});

  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_kPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: colors.hairline),
        boxShadow: [
          BoxShadow(
            color: colors.inkFixed.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The yellow face with its ink outline, the same in both themes.
class _WidgetFace extends StatelessWidget {
  const _WidgetFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => FaceWidget(
    state: FaceState.alarmed,
    size: size,
    overrideFillColor: AppColors.light.faceFill,
    overrideStrokeColor: AppColors.light.faceStroke,
    overrideInkColor: AppColors.light.faceInk,
  );
}

/// The small "Ringing" tag in the widget's red.
class _RingingPill extends StatelessWidget {
  const _RingingPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: colors.crit,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          LocaleKeys.paywall_previews_extras_widget_ringing.tr().toUpperCase(),
          maxLines: 1,
          softWrap: false,
          style: AppTypography.label(colors.inkFixed).copyWith(
            letterSpacing: 0.66,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// The face of the Open incidents widget. It rings by [widgetsRingAngle]
/// when the page appears, twice, and rests upright. Reduce motion, and a held
/// clock in a capture, show it upright.
class _RingingFace extends StatefulWidget {
  const _RingingFace({required this.size});

  final double size;

  @override
  State<_RingingFace> createState() => _RingingFaceState();
}

class _RingingFaceState extends State<_RingingFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(microseconds: (widgetsRingEnd * 1e6).round()),
  );
  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isStill = context.reduceMotion || PaywallStill.of(context);
    if (isStill) {
      _clock.value = 0;
    } else if (!_hasStarted) {
      _hasStarted = true;
      unawaited(_clock.forward());
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = _WidgetFace(size: widget.size);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        child: face,
        builder: (context, child) {
          final degrees = widgetsRingAngle(_clock.value * widgetsRingEnd);
          return Transform.rotate(
            angle: degrees * math.pi / 180,
            alignment: const Alignment(0, 0.2),
            child: child,
          );
        },
      ),
    );
  }
}

/// The Open incidents widget: the ringing face, the count of open incidents
/// and what it counts. 160 points square.
class OpenIncidentsWidget extends StatelessWidget {
  const OpenIncidentsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _WidgetCard(
      width: kOpenWidgetEdge,
      height: kOpenWidgetEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_RingingFace(size: 40), _RingingPill()],
          ),
          const Spacer(),
          Text(
            '$kSampleOpenCount',
            style: AppTypography.display(
              colors.onSurface,
              fontSize: 52,
            ).copyWith(height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            LocaleKeys.personalize_passes_widgets_open_label.tr(),
            maxLines: 1,
            style: AppTypography.small(
              colors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Topic widget: the face and its state, the topic, the alert title and
/// the I'm up button. 168 points square.
class TopicWidget extends StatelessWidget {
  const TopicWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _WidgetCard(
      width: kTopicWidgetEdge,
      height: kTopicWidgetEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_WidgetFace(size: 34), _RingingPill()],
          ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.personalize_sample_topic.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.mono(
              colors.onSurfaceMuted,
              fontSize: 12,
            ).copyWith(height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            LocaleKeys.personalize_sample_title.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small(
              colors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ),
          const Spacer(),
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: colors.crit,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                LocaleKeys.paywall_previews_extras_widget_im_up.tr(),
                maxLines: 1,
                softWrap: false,
                style: AppTypography.small(
                  colors.inkFixed,
                  fontSize: 13,
                ).copyWith(fontWeight: FontWeight.w700, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Topics widget: how many are open and three rows, ringing ones first.
/// As wide as the home screen block.
class TopicsWidget extends StatelessWidget {
  const TopicsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = [
      (
        LocaleKeys.personalize_sample_topic.tr(),
        LocaleKeys.personalize_sample_title.tr(),
        colors.crit,
      ),
      (
        LocaleKeys.personalize_passes_widgets_sample_topic_2.tr(),
        LocaleKeys.personalize_passes_widgets_sample_title_2.tr(),
        colors.crit,
      ),
      (
        LocaleKeys.personalize_passes_widgets_sample_topic_3.tr(),
        LocaleKeys.personalize_passes_widgets_sample_title_3.tr(),
        colors.highlight,
      ),
    ];
    return _WidgetCard(
      width: kWidgetsBlockWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.personalize_passes_widgets_open_header.tr(
              namedArgs: {'count': '$kSampleOpenCount'},
            ),
            style: AppTypography.small(
              colors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final (topic, title, fill) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  _StateMark(fill: fill),
                  const SizedBox(width: 8),
                  Text(
                    topic,
                    maxLines: 1,
                    style: AppTypography.small(
                      colors.onSurface,
                      fontSize: 13,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.small(
                        colors.onSurfaceMuted,
                        fontSize: 13,
                      ).copyWith(height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The small rounded square before a row: red while it rings, blue once
/// someone is awake. A mark, not a face.
class _StateMark extends StatelessWidget {
  const _StateMark({required this.fill});

  final Color fill;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 22,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.appColors.inkFixed, width: 2),
      ),
    ),
  );
}
