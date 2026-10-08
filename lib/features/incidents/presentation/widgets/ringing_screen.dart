import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/ringing_layout_rules.dart';
import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The ringing takeover: pulse rings, face, incident detail, and the two
/// pinned actions (acknowledge and snooze).
///
/// It draws and nothing else. What a button does comes in as a callback,
/// so the alarm screen and the Personalize preview build the same widget:
/// the alarm screen hands in the cubit's calls, the preview hands in
/// nothing that reaches an incident.
///
/// How it looks comes from the [AlarmStyleScope] above it: the type, the
/// treatment of the buttons, the pulse ring and the largest face. Nothing
/// a look can reach moves a button, renames it or changes the order a
/// screen reader walks.
class RingingScreen extends StatelessWidget {
  const RingingScreen({
    required this.state,
    required this.colors,
    required this.ackButtonKey,
    required this.onAcknowledge,
    required this.onSilence,
    required this.onReadMessage,
    required this.onSelectAlarm,
    super.key,
  });

  final CriticalAlarmState state;
  final AppColors colors;
  final GlobalKey ackButtonKey;

  /// "I'm up".
  final VoidCallback onAcknowledge;

  /// "Silence".
  final VoidCallback onSilence;

  /// "Read the full message". Null draws the button with nothing to open.
  final VoidCallback? onReadMessage;

  /// A row picked in the sheet that lists the other open alarms.
  final ValueChanged<String> onSelectAlarm;

  // The order a screen reader walks the ringing screen in. "I'm up" is in
  // the pinned bar at the bottom and still comes first, because stopping the
  // alarm must not take a hunt. Then what is ringing, then the two quiet
  // buttons. Nothing moves on screen.
  static const _orderAcknowledge = OrdinalSortKey(0);
  static const _orderError = OrdinalSortKey(0.5);
  static const _orderContent = OrdinalSortKey(1);
  static const _orderSilence = OrdinalSortKey(2);
  static const _orderReadMessage = OrdinalSortKey(3);

  // Inside the content: the topic, how long it has rung, the pill when more
  // than one alarm is open, then the message.
  static const _orderTopic = OrdinalSortKey(0);
  static const _orderRingTime = OrdinalSortKey(1);
  static const _orderAlarmCount = OrdinalSortKey(2);
  static const _orderMessage = OrdinalSortKey(3);

  @override
  Widget build(BuildContext context) {
    final size = AppSize.of(context);
    final isWide = size.isExpanded || size.isShort;
    final look = AlarmStyleScope.of(context).ringing;

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.errorMessage != null) ...[
          Semantics(
            sortKey: _orderError,
            child: AppToast(
              faceState: FaceState.worried,
              message: state.errorMessage,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          key: ackButtonKey,
          sortKey: _orderAcknowledge,
          child: AppButton(
            label: LocaleKeys.critical_alarm_acknowledge_button.tr(),
            variant: look.acknowledgeButton,
            isFullWidth: true,
            isLoading: state.isAcknowledging,
            onPressed: onAcknowledge,
          ),
        ),
        const SizedBox(height: 8),
        // Silence is not an acknowledge. The noise stops, the incident stays
        // open, and the phone sets its own next ring for the same id.
        // No stroke: I'm up is the answer and this is the quiet one. It is
        // still a full-size pill, in a tint of the canvas.
        Semantics(
          sortKey: _orderSilence,
          child: AppButton(
            label: LocaleKeys.critical_alarm_silence_ringing_button.tr(),
            variant: look.quietButton,
            isFullWidth: true,
            onPressed: onSilence,
          ),
        ),
        const SizedBox(height: 8),
        // Hidden for a setup test, which is known by its incident id and never
        // by a topic name. The phone-only test's topic is on no server, and
        // the server-sent test rings halfway through setup, where a topic
        // screen would be a detour out of it.
        // The same quiet pill as Silence. With a stroke it would outrank
        // it, and the order of weight is I'm up, Silence, then this.
        if (!state.ackedExits.isSetupTest)
          Semantics(
            sortKey: _orderReadMessage,
            child: AppButton(
              label: LocaleKeys.critical_alarm_read_message_button.tr(),
              variant: look.quietButton,
              isFullWidth: true,
              // Reading is not acknowledging, so this leaves the alarm
              // ringing and takes the user to the messages on the topic.
              onPressed: onReadMessage,
            ),
          ),
      ],
    );

    // The message scrolls under the pinned buttons when it is longer than
    // the screen. While it does, the buttons get a backing in the canvas
    // colour, so no line of it shows through a tinted button.
    return AppBarBackingScope(
      color: colors.canvas,
      child: isWide ? _wide(context, look, bottomBar) : _tall(look, bottomBar),
    );
  }

  /// A tablet or a phone on its side: the face beside the words.
  Widget _wide(BuildContext context, AlarmRingingLook look, Widget bottomBar) {
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderContent,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Row(
            children: [
              _face(look, math.min(300, look.maxFace)),
              const SizedBox(width: 40),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _word(look, TextAlign.left),
                      const SizedBox(height: Spacing.s2),
                      _topic(look, TextAlign.left),
                      _alarmCountPill(context),
                      const SizedBox(height: Spacing.s2),
                      _subtext(look, TextAlign.left),
                      const SizedBox(height: Spacing.s4),
                      _detailSheet(look),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// The upright phone: everything in one column over the pinned buttons.
  ///
  /// The message wins the room. The face takes what is left once the whole
  /// card sits above the buttons, and goes away when that is too little. If
  /// the title still ends under the buttons, the lines above the card drop
  /// to a smaller text size. The rules are in `ringing_layout_rules.dart`.
  Widget _tall(AlarmRingingLook look, Widget bottomBar) {
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderContent,
      slivers: [
        SliverToBoxAdapter(
          // Built inside the page, where the width of the card and the text
          // style its lines inherit are known.
          child: LayoutBuilder(
            builder: (context, box) {
              final layout = _tallLayout(context, look, box.maxWidth);
              // The layout decides the face. A look may only cap it.
              final faceSize = math.min(layout.faceSize, look.maxFace);
              final header = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _word(look, TextAlign.center),
                  const SizedBox(height: Spacing.s2),
                  _topic(look, TextAlign.center),
                  _alarmCountPill(context),
                  const SizedBox(height: Spacing.s2),
                  _subtext(look, TextAlign.center),
                ],
              );
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  _cardInset,
                  layout.isCompact ? ringingCompactTopGap : ringingTopGap,
                  _cardInset,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (faceSize > 0) ...[
                      _face(look, faceSize),
                      const SizedBox(height: ringingFaceGap),
                    ],
                    if (layout.isCompact)
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: MediaQuery.textScalerOf(context).clamp(
                            maxScaleFactor: ringingCompactTextScale,
                          ),
                        ),
                        child: header,
                      )
                    else
                      header,
                  ],
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _cardInset,
              Spacing.s4,
              _cardInset,
              0,
            ),
            child: _detailSheet(look),
          ),
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// The room on each side of the card, and the padding inside it, which
  /// is the sheet's own.
  static const double _cardInset = 16;
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 18, 16, 16);

  /// The size of the face and whether the header is compact, for a page
  /// [width] wide. The card is measured with the message it holds, because
  /// the length of the message is what decides the room.
  ({double faceSize, bool isCompact}) _tallLayout(
    BuildContext context,
    AlarmRingingLook look,
    double width,
  ) {
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(16) / 16;
    final textWidth = width - 2 * _cardInset - _cardPadding.horizontal;
    double lines(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: math.max(0, textWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleBottom =
        _cardPadding.top + lines(state.title, _titleStyle(look));
    final cardHeight =
        titleBottom +
        _titleGap +
        lines(state.body, _bodyStyle(look)) +
        _bodyGap +
        lines(state.meta, _metaStyle(look)) +
        _cardPadding.bottom;
    final viewportHeight = media.size.height - media.padding.vertical;
    // A setup test has no Read the full message button.
    final pinnedButtons = state.ackedExits.isSetupTest ? 2 : 3;
    final openAlarms = state.openIncidents.length;
    return (
      faceSize: ringingFaceSizeFor(
        viewportHeight: viewportHeight,
        textScale: textScale,
        openAlarms: openAlarms,
        cardHeight: cardHeight,
        pinnedButtons: pinnedButtons,
      ),
      isCompact: ringingHeaderIsCompact(
        viewportHeight: viewportHeight,
        textScale: textScale,
        openAlarms: openAlarms,
        titleBottom: titleBottom,
        pinnedButtons: pinnedButtons,
      ),
    );
  }

  /// How much wider the ringing face's stage is than its head.
  static const double _ringingStageScale = RingingFacePainter.stageUnits / 200;

  Widget _face(AlarmRingingLook look, double faceSize) {
    // A setup test takes the face over from the setup screen it came from.
    final isDemo = state.ackedExits.isSetupTest;
    // The face and its pulse ring are a picture of the state. The words say
    // the same thing, so a screen reader passes over both.
    return ExcludeSemantics(
      child: _faceStage(look, faceSize, isDemo: isDemo),
    );
  }

  Widget _faceStage(
    AlarmRingingLook look,
    double faceSize, {
    required bool isDemo,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: faceSize,
        height: faceSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (look.showsPulseRing) PulseRingWidget(size: faceSize),
            Hero(
              tag: isDemo
                  ? 'onboarding-face'
                  : 'alarm-face-${state.incident?.id}',
              flightShuttleBuilder: faceFlightShuttleBuilder,
              // The ringing face's stage is wider than its head, to leave
              // room for sweat, stars and steam. This keeps the head the
              // size the old face was and lets the extras spill out.
              child: SizedBox.square(
                dimension: faceSize,
                child: OverflowBox(
                  maxWidth: faceSize * _ringingStageScale,
                  maxHeight: faceSize * _ringingStageScale,
                  child: ShufflingRingingFace(
                    size: faceSize * _ringingStageScale,
                    isLive: state.isLive,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _word(AlarmRingingLook look, TextAlign align) {
    // Read together with the topic name, which comes first there.
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          state.word,
          textAlign: align,
          style: look.type.word.copyWith(color: colors.onCanvas),
        ),
      ),
    );
  }

  Widget _topic(AlarmRingingLook look, TextAlign align) {
    return Semantics(
      sortKey: _orderTopic,
      label: spokenTopic(topic: state.topic, word: state.word),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          state.topic,
          textAlign: align,
          style: look.type.topic.copyWith(color: colors.onCanvas),
        ),
      ),
    );
  }

  /// How long the alarm has been ringing. The line counts seconds for the
  /// eye. A screen reader gets whole minutes, so what it holds changes once a
  /// minute, and it is not a live region: nothing is read out on its own.
  Widget _subtext(AlarmRingingLook look, TextAlign align) {
    return Semantics(
      sortKey: _orderRingTime,
      label: state.ringTimeSpoken.isEmpty
          ? state.subtext
          : state.ringTimeSpoken,
      excludeSemantics: true,
      child: Text(
        state.subtext,
        textAlign: align,
        style: look.type.time.copyWith(color: colors.onCanvas),
      ),
    );
  }

  /// The "2 alarms" pill under the topic name. Hidden until a second incident
  /// is open; tapping it opens the sheet that lists the others.
  Widget _alarmCountPill(BuildContext context) {
    final count = state.openIncidents.length;
    if (count <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s2),
      child: Semantics(
        button: true,
        sortKey: _orderAlarmCount,
        child: GestureDetector(
          onTap: () => unawaited(_showOtherAlarms(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.hairline.withValues(alpha: 0.5)),
            ),
            child: Text(
              LocaleKeys.critical_alarm_alarm_count_pill.plural(count),
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontFamilyFallback: AppTypography.fontMonoFallbacks,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: colors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lists every open incident that is not the one on screen. Tapping a row
  /// swaps it to the top and answers nothing; the person still has to tap
  /// "I'm up" for the one they picked.
  Future<void> _showOtherAlarms(BuildContext context) async {
    final shownId = state.incident?.id;
    final others = state.openIncidents
        .where((i) => i.id != shownId)
        .toList(growable: false);
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.critical_alarm_alarm_others_sheet_title.tr(),
      content: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final incident in others)
            _OtherAlarmRow(
              incident: incident,
              onTap: () {
                onSelectAlarm(incident.id);
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _detailSheet(AlarmRingingLook look) {
    // One stop for the whole message, so it is one swipe to hear it and one
    // more to reach Silence.
    return Semantics(
      container: true,
      sortKey: _orderMessage,
      label: spokenMessage(
        title: state.title,
        body: state.body,
        meta: state.meta,
      ),
      excludeSemantics: true,
      child: _detailCard(look),
    );
  }

  // The card's three lines. The layout measures the same styles, so the
  // face is sized for the card that is drawn.
  TextStyle _titleStyle(AlarmRingingLook look) =>
      look.type.messageTitle.copyWith(color: colors.ink);

  TextStyle _bodyStyle(AlarmRingingLook look) =>
      look.type.messageBody.copyWith(color: colors.ink2);

  TextStyle _metaStyle(AlarmRingingLook look) =>
      look.type.messageMeta.copyWith(color: colors.ink3);

  static const double _titleGap = 6;
  static const double _bodyGap = 8;

  Widget _detailCard(AlarmRingingLook look) {
    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(state.title, style: _titleStyle(look)),
          const SizedBox(height: _titleGap),
          Text(state.body, style: _bodyStyle(look)),
          const SizedBox(height: _bodyGap),
          Text(state.meta, style: _metaStyle(look)),
        ],
      ),
    );
  }
}

/// One row in the "other alarms" sheet: the topic, the page title and how long
/// the incident has been open.
class _OtherAlarmRow extends StatelessWidget {
  const _OtherAlarmRow({required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = incident.messages.firstOrNull?.title ?? incident.topic;
    final openedAt = incident.openedAt;
    final age = openedAt == null
        ? ''
        : formatRingDuration(DateTime.now().difference(openedAt));

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.topic,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                age,
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontFamilyFallback: AppTypography.fontMonoFallbacks,
                  fontSize: 12,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
