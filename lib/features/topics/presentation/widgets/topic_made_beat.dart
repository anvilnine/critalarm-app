import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/topics/domain/topic_made_beat.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What setup shows for a beat once the first topic is made: the topic as a
/// row that drops into a small picture of Home, so the user sees where it
/// lives. Calls [onDone] when the beat is over.
///
/// The row is the one moving thing. Under reduced motion it is drawn already
/// in place, nothing moves and nothing is felt. The screen around this
/// widget owns the tap that skips it.
class TopicMadeBeat extends StatefulWidget {
  const TopicMadeBeat({
    required this.topicName,
    required this.ringsThroughSilent,
    required this.onDone,
    super.key,
  });

  /// The user's own topic, as they named it.
  final String topicName;

  /// Critical delivery is on for the topic, so its row says it rings.
  final bool ringsThroughSilent;

  final VoidCallback onDone;

  @override
  State<TopicMadeBeat> createState() => _TopicMadeBeatState();
}

class _TopicMadeBeatState extends State<TopicMadeBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: topicMadeBeatTakes,
  );
  Timer? _stillTimer;
  bool _hasStarted = false;
  bool _isStill = false;
  Duration _lastTick = Duration.zero;

  Duration get _elapsed => topicMadeBeatTakes * _clock.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted) return;
    _hasStarted = true;
    _isStill = context.reduceMotion;
    if (_isStill) {
      _stillTimer = Timer(topicMadeStillTakes, widget.onDone);
      return;
    }
    _clock
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });
    unawaited(_clock.forward());
  }

  void _onTick() {
    final now = _elapsed;
    if (topicCardLandsBetween(_lastTick, now)) AppHaptics.lightTap();
    _lastTick = now;
  }

  @override
  void dispose() {
    _stillTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screen = MediaQuery.sizeOf(context);
    final pictureWidth = topicMadePictureWidthFor(
      roomWidth: screen.width - 2 * Spacing.s5,
      viewportHeight: screen.height,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.s5,
        Spacing.s4,
        Spacing.s5,
        Spacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: AppFittedTitle(
              LocaleKeys.create_topic_made_title.tr(),
              minFontSize: setupTitleMinFontSize,
              style: AppTypography.headline(colors.onCanvas, fontSize: 30),
            ),
          ),
          const SizedBox(height: Spacing.s3),
          // A picture, so a screen reader hears the line above and no more.
          ExcludeSemantics(
            child: IgnorePointer(
              child: SizedBox(
                width: pictureWidth,
                child: AspectRatio(
                  aspectRatio:
                      topicMadePictureDesignWidth /
                      topicMadePictureDesignHeight,
                  child: FittedBox(
                    child: SizedBox(
                      width: topicMadePictureDesignWidth,
                      height: topicMadePictureDesignHeight,
                      // Drawn at real sizes and scaled as one, so the text
                      // size of the phone does not reflow it.
                      child: MediaQuery.withNoTextScaling(
                        child: AnimatedBuilder(
                          animation: _clock,
                          builder: (context, _) => _MiniHome(
                            topicName: widget.topicName,
                            ringsThroughSilent: widget.ringsThroughSilent,
                            shown: _isStill ? 1 : topicCardShownAt(_elapsed),
                            drop: _isStill
                                ? 1
                                : AppCurves.easeOut.transform(
                                    topicCardDropAt(_elapsed),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top of a phone showing Home, with the user's topic as its one row.
///
/// Every size is the real one from the Home screen, laid out on a
/// [topicMadePictureDesignWidth] wide frame. The row is the real
/// [AppListRow], so it matches Home by construction.
class _MiniHome extends StatelessWidget {
  const _MiniHome({
    required this.topicName,
    required this.ringsThroughSilent,
    required this.shown,
    required this.drop,
  });

  final String topicName;
  final bool ringsThroughSilent;

  /// 0 to 1: how far the row has faded in.
  final double shown;

  /// 0 to 1: how far the row has dropped. 1 is in its place.
  final double drop;

  /// The phone body, the same one the welcome stories draw.
  static const Color _body = Color(0xFF1C1917);
  static const double _bezel = 14;
  static const double _bodyRadius = 58;

  /// Room above the phone, where the row starts its drop.
  static const double _headroom = 44;

  /// Measured from the top of the phone's screen.
  static const double _titleTop = 52;
  static const double _faceTop = 96;
  static const double _faceSize = 96;
  static const double _wordTop = 202;
  static const double _sheetTop = 260;

  /// The gap Home keeps on each side of its list sheet.
  static const double _sheetSide = 12;

  /// `AppSheet` padding: 16 at the sides, 18 on top.
  static const double _sheetPadSide = 16;
  static const double _sheetPadTop = 18;

  /// How much bigger the row is while it is in the air.
  static const double _lift = 0.06;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const screenLeft = _bezel;
    const screenTop = _headroom + _bezel;
    const screenWidth = topicMadePictureDesignWidth - 2 * _bezel;
    const rowLeft = screenLeft + _sheetSide + _sheetPadSide;
    const rowTop = screenTop + _sheetTop + _sheetPadTop;
    const rowWidth = screenWidth - 2 * (_sheetSide + _sheetPadSide);

    final phone = Container(
      padding: const EdgeInsets.fromLTRB(_bezel, _bezel, _bezel, 0),
      decoration: const BoxDecoration(
        color: _body,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_bodyRadius + _bezel),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_bodyRadius),
        ),
        child: ColoredBox(
          color: colors.canvas,
          child: Stack(
            children: [
              Positioned(
                top: _titleTop,
                left: 16,
                right: 16,
                // The Home top bar title, in its own style.
                child: Text(
                  LocaleKeys.topics_list_title.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.02 * 18,
                    color: colors.onCanvas,
                  ),
                ),
              ),
              const Positioned(
                top: _faceTop,
                left: 0,
                right: 0,
                // Still. The row is the one thing that moves here.
                child: Center(
                  child: FaceWidget(state: FaceState.calm, size: _faceSize),
                ),
              ),
              Positioned(
                top: _wordTop,
                left: 24,
                right: 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    LocaleKeys.home_stage_word_clear.tr(),
                    maxLines: 1,
                    style: AppTypography.headline(
                      colors.onCanvas,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _sheetTop,
                left: _sheetSide,
                right: _sheetSide,
                bottom: 0,
                // The list sheet. It runs off the bottom of the picture.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.xl),
                    ),
                    boxShadow: AppShadows.lg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // In the air the row is a little bigger and casts a shadow. Both are
    // gone when it lands, where it sits flat in the sheet like on Home.
    final inAir = 1 - drop;
    final row = Opacity(
      opacity: shown.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -rowTop * inAir),
        child: Transform.scale(
          scale: 1 + _lift * inAir,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Radii.mdAll,
              boxShadow: drop >= 1
                  ? null
                  : BoxShadow.lerpList(AppShadows.lg, const [], drop),
            ),
            child: AppListRow(
              name: topicName,
              meta: LocaleKeys.home_meta_quiet.tr(),
              trailing: AppDeliveryChip(
                rings: ringsThroughSilent,
                label: ringsThroughSilent
                    ? LocaleKeys.home_delivery_rings.tr()
                    : LocaleKeys.home_delivery_normal.tr(),
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: _headroom,
          left: 0,
          right: 0,
          bottom: 0,
          // The phone fades out towards the bottom: it is the top of a
          // phone, not a short one.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.78, 1],
            ).createShader(bounds),
            child: phone,
          ),
        ),
        Positioned(left: rowLeft, top: rowTop, width: rowWidth, child: row),
      ],
    );
  }
}
