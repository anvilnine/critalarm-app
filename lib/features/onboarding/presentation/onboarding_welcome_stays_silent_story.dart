part of 'onboarding_welcome_screen.dart';

// A first welcome page: it is 3:12 at night and the phone is silent. Three
// ordinary notifications queue up muted, then one alarm slams in, the others
// are pushed aside and dimmed, and only the alarm rings. The clock lives in
// welcome_stays_silent_timeline.dart. This file only paints a frame of it.

/// The name of the made-up topic the alarm comes from.
const String _silentTopicName = 'prod-db'; // l10n-ok: a made-up topic name

/// The face on the alarm card.
const FaceState _silentAlarmFace = FaceState.shocked;

/// Design units of the layout: where the pieces sit in a picture
/// [welcomeStaysSilentDesignWidth] by [welcomeStaysSilentDesignHeight].
const double _silentStatusTop = 16;
const double _silentRowsTop = 108;
const double _silentRowPitch = 72;
const double _silentRowHeight = 62;
const double _silentCardTop = 164;

/// Where the alarm card sits when the room is short and the rows are left
/// out (see [welcomeStaysSilentIsCompact]).
const double _silentCompactCardTop = 42;
const double _silentRowInset = 20;
const double _silentCardInset = 14;

/// The first welcome page, "everything else stays silent".
class _StaysSilentHero extends StatefulWidget {
  const _StaysSilentHero({required this.onDone, this.slide});

  /// Called once, when the first pass is over.
  final VoidCallback onDone;

  /// How far this page has moved off the screen, from 0 to 1, while the
  /// pager moves. The picture fades out and travels clear by it. Null for a
  /// page that does not move.
  final ValueListenable<double>? slide;

  @override
  State<_StaysSilentHero> createState() => _StaysSilentHeroState();
}

class _StaysSilentHeroState extends _ClockState<_StaysSilentHero> {
  @override
  double get restAt => 0;

  @override
  double? get loopTakes => welcomeStaysSilentLoopSeconds;

  /// One beat when the alarm lands. A page that is not in front, or a phone
  /// that asks for reduced motion, plays nothing (see [canPlayHaptics]).
  @override
  List<TimedCue> buildCues() => const [
    (at: welcomeStaysSilentAlarmLandsAt, cue: HeroCue.ringPulse),
  ];

  bool _hasSaidDone = false;

  @override
  void onClock(double seconds) {
    if (_hasSaidDone || seconds < welcomeStaysSilentLoopSeconds) return;
    _hasSaidDone = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final night = _NightColors(colors);
    final frame = welcomeStaysSilentFrameAt(t, reducedMotion: _isStill);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final height = box.maxHeight;
        final pageWidth = width + 2 * _IntroLayout.sidePadding;
        final unit = welcomeStaysSilentUnit(width, height);
        final isCompact = welcomeStaysSilentIsCompact(width, height);

        // The picture sits in the middle of the room it has.
        final top = math.max<double>(
          0,
          (height -
                  (isCompact
                          ? welcomeStaysSilentCompactDesignHeight
                          : welcomeStaysSilentDesignHeight) *
                      unit) /
              2,
        );

        final rowLabels = [
          LocaleKeys.welcome_first_pages_silent_row_chat.tr(),
          LocaleKeys.welcome_first_pages_silent_row_mail.tr(),
          LocaleKeys.welcome_first_pages_silent_row_monitoring.tr(),
        ];

        Widget row(int index) {
          final each = frame.rows[index];
          return Positioned(
            left: _silentRowInset * unit,
            right: _silentRowInset * unit,
            top: top + (_silentRowsTop + index * _silentRowPitch) * unit,
            height: _silentRowHeight * unit,
            child: Opacity(
              opacity: each.opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, each.offset * unit),
                child: Transform.scale(
                  scale: each.scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: night.rowFill,
                      borderRadius: BorderRadius.circular(20 * unit),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * unit),
                      child: Row(
                        children: [
                          AppGlyph(
                            GlyphType.bellOff,
                            size: 20 * unit,
                            color: night.dimInk,
                            strokeWidth: 2.2,
                          ),
                          SizedBox(width: 12 * unit),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 150 * unit),
                            child: Text(
                              rowLabels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                night.dimInk,
                                fontSize: 14 * unit,
                              ),
                            ),
                          ),
                          SizedBox(width: 12 * unit),
                          Expanded(
                            child: SizedBox(
                              height: 10 * unit,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: night.rowBar,
                                  borderRadius: BorderRadius.circular(5 * unit),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final alarm = frame.alarm;
        final glowSpread = welcomeStaysSilentGlowSpread * unit * alarm.glow;
        final glowAlpha = welcomeStaysSilentGlowOpacity * (1 - alarm.glow);
        final card = Positioned(
          left: _silentCardInset * unit,
          right: _silentCardInset * unit,
          top:
              top + (isCompact ? _silentCompactCardTop : _silentCardTop) * unit,
          child: Opacity(
            opacity: alarm.opacity,
            child: Transform.scale(
              scale: alarm.scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.crit,
                  borderRadius: BorderRadius.circular(26 * unit),
                  boxShadow: [
                    BoxShadow(
                      color: colors.crit.withValues(alpha: glowAlpha),
                      spreadRadius: glowSpread,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18 * unit,
                    16 * unit,
                    18 * unit,
                    16 * unit,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Transform.rotate(
                            angle: alarm.shiver,
                            child: FaceWidget(
                              state: FaceState.calm,
                              shape: _shape(_silentAlarmFace),
                              size: 72 * unit,
                              overrideFillColor: colors.yellow,
                              overrideStrokeColor: colors.inkFixed,
                              overrideInkColor: colors.inkFixed,
                            ),
                          ),
                          SizedBox(width: 14 * unit),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  LocaleKeys.onboarding_welcome_story_critical
                                      .tr(),
                                  maxLines: 1,
                                  softWrap: false,
                                  style:
                                      AppTypography.display(
                                        colors.inkFixed,
                                        fontSize: 30 * unit,
                                      ).copyWith(
                                        height: 1,
                                        letterSpacing: -0.025 * 30 * unit,
                                      ),
                                ),
                                SizedBox(height: 3 * unit),
                                Text(
                                  _silentTopicName,
                                  style: AppTypography.monoBold(
                                    colors.inkFixed,
                                    fontSize: 12 * unit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12 * unit),
                      Text(
                        LocaleKeys.onboarding_welcome_story_alarm_title.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          colors.inkFixed,
                          fontSize: 16 * unit,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12 * unit),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.highlight,
                          borderRadius: Radii.fullAll,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12 * unit),
                          child: Text(
                            LocaleKeys.onboarding_welcome_story_im_up.tr(),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              colors.onHighlight,
                              fontSize: 15 * unit,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final panel = Transform.translate(
          offset: Offset(frame.jolt * unit, 0),
          child: ClipRRect(
            borderRadius: Radii.xlAll,
            child: ColoredBox(
              color: night.sky,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top + _silentStatusTop * unit,
                    child: Opacity(
                      opacity: 0.7,
                      child: Text(
                        LocaleKeys.welcome_first_pages_silent_status.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.mono(
                          night.text,
                          fontSize: math.max<double>(10, 12 * unit),
                        ),
                      ),
                    ),
                  ),
                  if (!isCompact)
                    for (var i = 0; i < welcomeStaysSilentRowCount; i++) row(i),
                  card,
                ],
              ),
            ),
          ),
        );

        return SizedBox(
          width: width,
          height: height,
          // The panel fades out and travels clear while the pager moves,
          // instead of being cut by the screen's edge.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _PartingLayer(
                  slide: widget.slide,
                  pageWidth: pageWidth,
                  partingAt: _backdropParting,
                  child: panel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
