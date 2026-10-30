import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/ringing_layout_rules.dart';
import 'package:critalarm/features/incidents/presentation/alarm_screen_reader.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Which shape the ringing screen takes on a display.
enum RingingLayout {
  /// An upright phone or a tablet in portrait: one column over the
  /// pinned buttons.
  tall,

  /// A phone on its side: the face beside the words, buttons pinned.
  sideways,

  /// A wide window: two columns, the buttons right under the card.
  expanded,

  /// A cover screen about as tall as it is wide (Razr).
  cover,

  /// A foldable held like a book: face and lines in the start pane, card
  /// and buttons in the end pane.
  book,

  /// A foldable held like a laptop: face, lines and card in the top half,
  /// buttons in the bottom half.
  tabletop,
}

/// The layout for a display of [size] held in [posture].
///
/// A fold wins over the size class, because nothing may sit on it. A
/// tabletop half is too short for the wide layout even when the window is
/// expanded.
RingingLayout ringingLayoutFor(AppSize size, AppPosture posture) {
  return switch (posture) {
    AppPosture.book => RingingLayout.book,
    AppPosture.tabletop => RingingLayout.tabletop,
    AppPosture.none when size.isCover => RingingLayout.cover,
    AppPosture.none when size.isExpanded => RingingLayout.expanded,
    AppPosture.none when size.isShort => RingingLayout.sideways,
    AppPosture.none => RingingLayout.tall,
  };
}

/// The widest the two expanded columns get together.
const double ringingExpandedMaxWidth = 800;

/// The widest the end column (lines, card, buttons) gets.
const double ringingEndColumnMaxWidth = 440;

/// Between the face and the end column on a wide window.
const double ringingExpandedGap = 56;

/// Kept clear above and below the expanded group.
const double ringingExpandedEdge = 24;

/// The face on a cover screen.
const double ringingCoverFaceSize = 88;

/// How much further in the cover's header row starts than the card, so
/// the face's pulse ring is whole on screen.
const double ringingCoverRingInset = 4;

/// Between the cover face's box and the word, wide enough that the word
/// stays clear of the pulse ring.
const double ringingCoverWordGap = 20;

/// The height the word gets on a cover screen. It scales down into it.
const double ringingCoverWordHeight = 40;

/// The face in the top half of a tabletop fold.
const double ringingTabletopFaceSize = 160;

/// How much wider the pulse ring is than the face it rings.
const double ringingPulseRingScale = 1.3;

/// The face on a wide window: 300, or 240 on a window under 800 tall. A
/// look may only cap it.
double ringingExpandedFaceSizeFor({
  required double windowHeight,
  double maxFace = double.infinity,
}) => math.min(windowHeight < 800 ? 240 : 300, maxFace).toDouble();

/// The face in the start pane of a book fold, or 0 when the pane is too
/// short for one.
///
/// It takes the room the lines under it leave in a pane of [paneWidth] by
/// [paneHeight] (inside its safe area), up to [ringingFaceMax], with its
/// pulse ring 24 in from each side and 24 above and below the group.
/// [headerHeight] is how tall the lines are. Under [ringingFaceFloor] the
/// face goes.
double ringingPaneFaceSizeFor({
  required double paneWidth,
  required double paneHeight,
  required double headerHeight,
  double maxFace = double.infinity,
}) {
  // The pulse ring reaches past the head, so the width leaves it room.
  final byWidth = (paneWidth - 48) / ringingPulseRingScale;
  final byHeight = paneHeight - 48 - headerHeight - ringingFaceGap;
  final size = math.min(math.min(byWidth, byHeight), ringingFaceMax);
  if (size < ringingFaceFloor) return 0;
  return math.min(size, maxFace);
}

/// The face in the start pane of a book [fold] in a window described by
/// [window], or 0 when the pane is too short for one.
///
/// The pane is the fold's start pane inside its own safe area, the way
/// `AppFoldSplit` and the scaffold's fold stage lay it out. The ringing
/// screen draws this face, and the canvas owner asks the same sum through
/// `RingingScreen.drawsFace`, so the two always agree.
double ringingBookFaceSizeFor({
  required MediaQueryData window,
  required AppFold fold,
  required int openAlarms,
  TextDirection direction = TextDirection.ltr,
  double maxFace = double.infinity,
}) {
  if (!fold.isBook) return 0;
  final pane = fold.panes(window.size, direction: direction).first;
  final media = foldPaneMediaQuery(window, pane);
  final textScale = media.textScaler.scale(16) / 16;
  return ringingPaneFaceSizeFor(
    paneWidth: media.size.width - media.padding.horizontal,
    paneHeight: media.size.height - media.padding.vertical,
    headerHeight: ringingHeaderHeightFor(
      textScale: textScale,
      openAlarms: openAlarms,
    ),
    maxFace: maxFace,
  );
}

/// How far the buttons rise off the foot of the end pane of a book fold, so
/// the card and the buttons sit as one group in the middle of the pane, the
/// card's top across from the face in the start pane.
///
/// [paneHeight] is the end pane inside its safe area and [cardHeight] how
/// tall the card comes out with this message at this text size. 0 when the
/// card fills the room above the buttons.
double ringingBookLiftFor({
  required double paneHeight,
  required double textScale,
  required double cardHeight,
  int pinnedButtons = 3,
}) {
  final room =
      paneHeight -
      ringingBarHeightFor(textScale: textScale, pinnedButtons: pinnedButtons) -
      ringingBarClearance -
      16;
  return math.max(0, (room - cardHeight) / 2).toDouble();
}

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

  // The card in the end pane of a book fold comes after the lines in the
  // start pane and before Silence.
  static const _orderCard = OrdinalSortKey(1.5);

  @override
  Widget build(BuildContext context) {
    final layout = ringingLayoutFor(
      AppSize.of(context),
      AppFold.of(context).posture,
    );
    final look = AlarmStyleScope.of(context).ringing;
    // A look whose quiet wash cannot be seen on its canvas says so, and
    // the two quiet buttons get a thin edge. Null draws nothing.
    final quietEdge = look.quietButtonEdge?.call(
      colors,
      Theme.of(context).brightness,
    );
    final bottomBar = _buttons(
      look,
      quietEdge,
      quietSideBySide: layout == RingingLayout.cover,
    );

    // The message scrolls under the pinned buttons when it is longer than
    // the screen. While it does, the buttons get a backing in the canvas
    // colour, so no line of it shows through a tinted button.
    return AppBarBackingScope(
      color: colors.canvas,
      child: switch (layout) {
        RingingLayout.tall => _tall(look, bottomBar),
        RingingLayout.sideways => _wide(context, look, bottomBar),
        RingingLayout.expanded => _expanded(context, look, bottomBar),
        RingingLayout.cover => _cover(look, bottomBar),
        RingingLayout.book => _book(context, look, bottomBar),
        RingingLayout.tabletop => _tabletop(look, bottomBar),
      },
    );
  }

  /// "I'm up", Silence and Read the full message, in that order of weight.
  ///
  /// [quietSideBySide] puts the two quiet pills in one row under "I'm up",
  /// for a cover screen too short for three rows above the card.
  Widget _buttons(
    AlarmRingingLook look,
    Color? quietEdge, {
    bool quietSideBySide = false,
  }) {
    // Silence is not an acknowledge. The noise stops, the incident stays
    // open, and the phone sets its own next ring for the same id.
    // No stroke: I'm up is the answer and this is the quiet one. It is
    // still a full-size pill, in a tint of the canvas.
    final silence = Semantics(
      sortKey: _orderSilence,
      child: _quietEdge(
        quietEdge,
        AppButton(
          label: LocaleKeys.critical_alarm_silence_ringing_button.tr(),
          variant: look.quietButton,
          isFullWidth: true,
          onPressed: onSilence,
        ),
      ),
    );
    // Hidden for a setup test, which is known by its incident id and never
    // by a topic name. The phone-only test's topic is on no server, and
    // the server-sent test rings halfway through setup, where a topic
    // screen would be a detour out of it.
    // The same quiet pill as Silence. With a stroke it would outrank
    // it, and the order of weight is I'm up, Silence, then this.
    final readMessage = state.ackedExits.isSetupTest
        ? null
        : Semantics(
            sortKey: _orderReadMessage,
            child: _quietEdge(
              quietEdge,
              AppButton(
                label: LocaleKeys.critical_alarm_read_message_button.tr(),
                variant: look.quietButton,
                isFullWidth: true,
                // Reading is not acknowledging, so this leaves the alarm
                // ringing and takes the user to the messages on the topic.
                onPressed: onReadMessage,
              ),
            ),
          );
    return Column(
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
        if (quietSideBySide && readMessage != null)
          Row(
            children: [
              Expanded(child: silence),
              const SizedBox(width: 8),
              Expanded(child: readMessage),
            ],
          )
        else ...[
          silence,
          if (readMessage != null) ...[
            const SizedBox(height: 8),
            readMessage,
          ],
        ],
      ],
    );
  }

  /// The word, the topic, the count of open alarms and how long it has
  /// rung, in one column.
  Widget _header(
    BuildContext context,
    AlarmRingingLook look, {
    required TextAlign align,
    double gap = Spacing.s2,
    double? wordHeight,
  }) {
    final isStart = align != TextAlign.center;
    var word = _word(look, align);
    if (wordHeight != null) {
      // A short screen gives the word a height, and the word scales down
      // to fit it and the width beside the face.
      word = SizedBox(
        height: wordHeight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isStart
              ? AlignmentDirectional.centerStart
              : Alignment.center,
          child: word,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        word,
        SizedBox(height: gap),
        _topic(look, align),
        _alarmCountPill(context),
        SizedBox(height: gap),
        _subtext(look, align),
      ],
    );
  }

  /// A wide window: two columns centred in it, [ringingExpandedMaxWidth]
  /// across at most. The face on the start side, and on the end side the
  /// lines, the card and the three buttons right under it, so the answer
  /// sits next to the message it answers. The group centres vertically.
  /// The card takes the height the rest leaves and scrolls inside itself,
  /// so a long message never pushes "I'm up" off the window.
  Widget _expanded(
    BuildContext context,
    AlarmRingingLook look,
    Widget buttons,
  ) {
    final media = MediaQuery.of(context);
    // The scaffold keeps 16 under the list.
    final room = math
        .max(
          0,
          media.size.height -
              media.padding.vertical -
              16 -
              2 * ringingExpandedEdge,
        )
        .toDouble();
    final faceSize = ringingExpandedFaceSizeFor(
      windowHeight: media.size.height,
      maxFace: look.maxFace,
    );
    return AppScreenScaffold(
      hasTabBar: false,
      contentMaxWidth: ringingExpandedMaxWidth,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: ringingExpandedEdge,
            ),
            child: SizedBox(
              height: room,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _face(look, faceSize),
                    const SizedBox(width: ringingExpandedGap),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ringingEndColumnMaxWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: Semantics(
                                container: true,
                                explicitChildNodes: true,
                                sortKey: _orderContent,
                                child: _linesAndCard(context, look),
                              ),
                            ),
                            const SizedBox(height: Spacing.s5),
                            buttons,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The lines above the card, start aligned, then the card, which scrolls
  /// inside itself when the column is too short for it.
  Widget _linesAndCard(BuildContext context, AlarmRingingLook look) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _header(context, look, align: TextAlign.start),
        ),
        const SizedBox(height: Spacing.s4),
        Flexible(child: _detailSheet(look, scrolls: true)),
      ],
    );
  }

  /// The Razr cover, about 384 square. The face at [ringingCoverFaceSize]
  /// beside the word, topic and ringing time, the card with the title only
  /// under them, and the buttons pinned at the bottom: "I'm up" across the
  /// screen, Silence and Read the full message side by side under it. A
  /// screen reader still hears the whole message on the card.
  Widget _cover(AlarmRingingLook look, Widget buttons) {
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderContent,
      slivers: [
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) => Padding(
              // The face's pulse ring reaches past its box, so the row
              // starts a little further in and leaves the word more room,
              // and the ring is whole and clear of the word.
              padding: const EdgeInsets.fromLTRB(
                _cardInset + ringingCoverRingInset,
                Spacing.s3,
                _cardInset,
                0,
              ),
              child: Row(
                children: [
                  _face(look, math.min(ringingCoverFaceSize, look.maxFace)),
                  const SizedBox(width: ringingCoverWordGap),
                  Expanded(
                    child: _header(
                      context,
                      look,
                      align: TextAlign.start,
                      gap: Spacing.s1,
                      wordHeight: ringingCoverWordHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _cardInset,
              Spacing.s3,
              _cardInset,
              0,
            ),
            child: _detailSheet(look, titleOnly: true),
          ),
        ),
      ],
      bottomBar: buttons,
    );
  }

  /// A foldable held like a book. The start pane holds the face and the
  /// lines, the end pane the card with the buttons pinned to its foot.
  /// Nothing sits on the fold. Each pane lays out at its own size, so the
  /// end pane's buttons keep the phone's widths.
  Widget _book(BuildContext context, AlarmRingingLook look, Widget buttons) {
    // The same sum the canvas owner makes through [drawsFace].
    final faceSize = _bookFaceSize(context, state, look);
    final lift = _bookLift(context, look);
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderCard,
      foldStage: Semantics(
        container: true,
        explicitChildNodes: true,
        sortKey: _orderContent,
        child: SafeArea(
          child: Builder(
            builder: (context) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (faceSize > 0) ...[
                        _face(look, faceSize),
                        const SizedBox(height: ringingFaceGap),
                      ],
                      _header(context, look, align: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      slivers: [
        // Built in the end pane, so the room is the pane's.
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final room = math
                  .max(
                    0,
                    media.size.height -
                        media.padding.vertical -
                        ringingBarHeightFor(
                          textScale: media.textScaler.scale(16) / 16,
                          pinnedButtons: state.ackedExits.isSetupTest ? 2 : 3,
                        ) -
                        ringingBarClearance -
                        16 -
                        lift,
                  )
                  .toDouble();
              // At the foot of the room, right over "I'm up", so the answer
              // sits under the message it answers.
              return ConstrainedBox(
                constraints: BoxConstraints(minHeight: room),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _cardInset),
                    child: _detailSheet(look),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      // Still pinned, lifted so the card and the buttons sit in the middle
      // of the pane as one group instead of in its bottom part.
      bottomBar: Padding(
        padding: EdgeInsets.only(bottom: lift),
        child: buttons,
      ),
    );
  }

  /// How far the book layout lifts its buttons, read from the window
  /// [context] is drawn in. See [ringingBookLiftFor].
  double _bookLift(BuildContext context, AlarmRingingLook look) {
    final window = MediaQuery.of(context);
    final fold = AppFold.of(context);
    if (!fold.isBook) return 0;
    final pane = fold
        .panes(
          window.size,
          direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
        )
        .second;
    final media = foldPaneMediaQuery(window, pane);
    // The page in the end pane is the pane less its gutters, which hold a
    // side inset that reaches the pane.
    final pageWidth = AppScreenColumns.resolve(
      boxWidth: media.size.width,
      size: AppSize.from(
        media.size,
        isIphone: AppDeviceScope.isIphoneOf(context),
      ),
      padding: media.padding,
      hasTabBar: false,
    ).contentWidth;
    final card = _measureCard(
      context,
      state,
      look,
      pageWidth,
      inherited: DefaultTextStyle.of(context).style,
    );
    return ringingBookLiftFor(
      paneHeight: media.size.height - media.padding.vertical,
      textScale: media.textScaler.scale(16) / 16,
      cardHeight: card.height,
      pinnedButtons: state.ackedExits.isSetupTest ? 2 : 3,
    );
  }

  /// A foldable held like a laptop. The top half holds the face at
  /// [ringingTabletopFaceSize] beside the lines and the card. The bottom
  /// half, the one lying on the table, holds the three buttons. The card
  /// scrolls inside itself when the half is too short for it.
  Widget _tabletop(AlarmRingingLook look, Widget buttons) {
    return AppScreenScaffold(
      hasTabBar: false,
      // The empty list in the bottom half still has a node of its own. With
      // a key it joins the order the keys set, so "I'm up" stays first.
      contentSortKey: _orderCard,
      foldStage: Semantics(
        container: true,
        explicitChildNodes: true,
        sortKey: _orderContent,
        child: SafeArea(
          bottom: false,
          child: Builder(
            builder: (context) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: Spacing.s3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _face(
                      look,
                      math.min(ringingTabletopFaceSize, look.maxFace),
                    ),
                    const SizedBox(width: Spacing.s6),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ringingEndColumnMaxWidth,
                        ),
                        child: _linesAndCard(context, look),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      slivers: const [],
      // Pinned, so a screen reader still reaches "I'm up" first and Silence
      // and Read after the message. Built in the bottom half, where it is
      // lifted to sit in the middle of the half rather than at its foot.
      bottomBar: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          final bar = ringingBarHeightFor(
            textScale: media.textScaler.scale(16) / 16,
            pinnedButtons: state.ackedExits.isSetupTest ? 2 : 3,
          );
          final lift = math
              .max(
                0,
                (media.size.height - media.padding.vertical - bar) / 2 -
                    AppScreenScaffold.bottomBarGap,
              )
              .toDouble();
          return Padding(
            padding: EdgeInsets.only(bottom: lift),
            child: buttons,
          );
        },
      ),
    );
  }

  /// A tablet or a phone on its side: the face beside the words.
  ///
  /// The row sits in the middle of the room above the pinned buttons. The
  /// scaffold leaves the buttons' room under the list, so a message taller
  /// than that room scrolls clear of them and never ends under "I'm up".
  Widget _wide(BuildContext context, AlarmRingingLook look, Widget bottomBar) {
    final media = MediaQuery.of(context);
    // The room above the buttons, by the same sums the upright phone uses.
    // A wrong guess only moves the row off the middle or lets the page
    // scroll a little: the scaffold measures the real bar for the room it
    // leaves, so nothing is hidden either way.
    final room = math
        .max(
          0,
          media.size.height -
              media.padding.vertical -
              ringingBarHeightFor(
                textScale: media.textScaler.scale(16) / 16,
                pinnedButtons: state.ackedExits.isSetupTest ? 2 : 3,
              ) -
              ringingBarClearance,
        )
        .toDouble();
    // On a phone on its side the face gives way to the room there is.
    final faceSize = math
        .min(
          math.min(300, look.maxFace),
          math.max(ringingFaceFloor, room),
        )
        .toDouble();
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderContent,
      slivers: [
        SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: room),
            child: Row(
              children: [
                _face(look, faceSize),
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
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// Marks the edge of a quiet button, so a test can find it.
  @visibleForTesting
  static const Key quietButtonEdgeKey = ValueKey('ringing-quiet-button-edge');

  /// [button] with a thin edge in [edge] around its pill, or [button] as
  /// it is when the look asks for none.
  ///
  /// The edge is drawn over the button and takes no touch. It is one and
  /// a half pixels of a faint colour, so "I'm up", which is filled, stays
  /// the heaviest thing in the bar.
  static Widget _quietEdge(Color? edge, Widget button) {
    if (edge == null) return button;
    return DecoratedBox(
      key: quietButtonEdgeKey,
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.fullAll,
        border: Border.all(color: edge, width: 1.5),
      ),
      child: button,
    );
  }

  /// Whether the ringing screen draws its face for [state] on this
  /// display, in [look].
  ///
  /// For the owner of the canvas, which draws a shape behind the face and
  /// leaves it out when the face is (`AlarmRingingLook.ambientFor`). It is
  /// the same sum the screen does, on the width the scaffold gives the
  /// page. Called from above the screen's own scaffold, so the text style
  /// the card's lines inherit is the theme's.
  static bool drawsFace(
    BuildContext context, {
    required CriticalAlarmState state,
    required AlarmRingingLook look,
  }) {
    final size = AppSize.of(context);
    switch (ringingLayoutFor(size, AppFold.of(context).posture)) {
      case RingingLayout.tall:
        break;
      // A short start pane at a large text size leaves the face out.
      case RingingLayout.book:
        return _bookFaceSize(context, state, look) > 0;
      // The other layouts always keep a place for the face.
      case RingingLayout.sideways:
      case RingingLayout.expanded:
      case RingingLayout.cover:
      case RingingLayout.tabletop:
        return true;
    }
    // The width the scaffold gives the page: the column, less a side inset
    // deeper than its gutter (the iPhone Duo's strip).
    final layout = _tallLayoutFor(
      context,
      state,
      look,
      AppScreenColumns.of(context, hasTabBar: false).contentWidth,
      inherited:
          Theme.of(context).textTheme.bodyMedium ??
          DefaultTextStyle.of(context).style,
    );
    return math.min(layout.faceSize, look.maxFace) > 0;
  }

  /// The face in the start pane of a book fold, read from the window
  /// [context] is drawn in, or 0 when the pane is too short for one.
  static double _bookFaceSize(
    BuildContext context,
    CriticalAlarmState state,
    AlarmRingingLook look,
  ) {
    final media = MediaQuery.of(context);
    return ringingBookFaceSizeFor(
      window: media,
      fold: AppFold.of(context),
      direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
      openAlarms: state.openIncidents.length,
      maxFace: look.maxFace,
    );
  }

  /// The upright phone: everything in one column over the pinned buttons.
  ///
  /// The message wins the room. The face takes what is left once the whole
  /// card sits above the buttons, and goes away when that is too little. If
  /// the title still ends under the buttons, the lines above the card drop
  /// to a smaller text size. A card that is still too tall for the room
  /// scrolls inside it, so it never ends under a button. The rules are in
  /// `ringing_layout_rules.dart`.
  Widget _tall(AlarmRingingLook look, Widget bottomBar) {
    return AppScreenScaffold(
      hasTabBar: false,
      contentSortKey: _orderContent,
      slivers: [
        // Built inside the page, where the width of the card and the text
        // style its lines inherit are known.
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final layout = _tallLayoutFor(
              context,
              state,
              look,
              constraints.crossAxisExtent,
              inherited: DefaultTextStyle.of(context).style,
            );
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
            final top = Padding(
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
            Widget card(Widget child) => Padding(
              padding: const EdgeInsets.fromLTRB(
                _cardInset,
                Spacing.s4,
                _cardInset,
                0,
              ),
              child: child,
            );
            final cardRoom = layout.cardScrollRoom;
            if (cardRoom == null) {
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(child: top),
                  SliverToBoxAdapter(child: card(_detailSheet(look))),
                ],
              );
            }
            // The card is taller than the room above the buttons, so it
            // takes what the header leaves, whatever the header came out at,
            // and scrolls inside it. A screen too small to leave the card
            // its least room lets the page scroll instead.
            final media = MediaQuery.of(context);
            final textScale = media.textScaler.scale(16) / 16;
            final maxHeight = math.max(
              media.size.height -
                  media.padding.vertical -
                  ringingBarHeightFor(
                    textScale: textScale,
                    pinnedButtons: state.ackedExits.isSetupTest ? 2 : 3,
                  ) -
                  ringingBarClearance,
              ringingHeaderHeightFor(
                    textScale: textScale,
                    openAlarms: state.openIncidents.length,
                    isCompact: layout.isCompact,
                  ) +
                  ringingCardMinRoom,
            );
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    top,
                    Flexible(child: card(_detailSheet(look, scrolls: true))),
                  ],
                ),
              ),
            );
          },
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
  ///
  /// [inherited] is the text style the card's lines inherit where they
  /// are drawn. Only sizes are read, so no colour is needed.
  static ({double faceSize, bool isCompact, double? cardScrollRoom})
  _tallLayoutFor(
    BuildContext context,
    CriticalAlarmState state,
    AlarmRingingLook look,
    double width, {
    required TextStyle inherited,
  }) {
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(16) / 16;
    final (:titleBottom, height: cardHeight) = _measureCard(
      context,
      state,
      look,
      width,
      inherited: inherited,
    );
    final viewportHeight = media.size.height - media.padding.vertical;
    // A setup test has no Read the full message button.
    final pinnedButtons = state.ackedExits.isSetupTest ? 2 : 3;
    final openAlarms = state.openIncidents.length;
    final isCompact = ringingHeaderIsCompact(
      viewportHeight: viewportHeight,
      textScale: textScale,
      openAlarms: openAlarms,
      titleBottom: titleBottom,
      pinnedButtons: pinnedButtons,
    );
    return (
      faceSize: ringingFaceSizeFor(
        viewportHeight: viewportHeight,
        textScale: textScale,
        openAlarms: openAlarms,
        cardHeight: cardHeight,
        pinnedButtons: pinnedButtons,
      ),
      isCompact: isCompact,
      cardScrollRoom: ringingCardScrollRoomFor(
        viewportHeight: viewportHeight,
        textScale: textScale,
        openAlarms: openAlarms,
        cardHeight: cardHeight,
        isCompact: isCompact,
        pinnedButtons: pinnedButtons,
      ),
    );
  }

  /// How tall the card comes out with this message on a page [width] wide,
  /// and how far below its top the title ends. The text size is the one
  /// [context] has. [inherited] is the text style the card's lines inherit.
  static ({double titleBottom, double height}) _measureCard(
    BuildContext context,
    CriticalAlarmState state,
    AlarmRingingLook look,
    double width, {
    required TextStyle inherited,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textWidth = width - 2 * _cardInset - _cardPadding.horizontal;
    double lines(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: inherited.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: math.max(0, textWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleBottom =
        _cardPadding.top + lines(state.title, look.type.messageTitle);
    return (
      titleBottom: titleBottom,
      height:
          titleBottom +
          _titleGap +
          lines(state.body, look.type.messageBody) +
          _bodyGap +
          lines(state.meta, look.type.messageMeta) +
          _cardPadding.bottom,
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
                    strokeColor: look.faceOutline,
                    // The waves are drawn beside the head, on the canvas,
                    // so they take the colour of the words on it. The
                    // features' ink is dark in every look and would be
                    // lost on a dark canvas.
                    canvasInkColor: colors.onCanvas,
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

  Widget _detailSheet(
    AlarmRingingLook look, {
    bool scrolls = false,
    bool titleOnly = false,
  }) {
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
      child: titleOnly
          ? AppSheet(
              child: Text(
                state.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(look),
              ),
            )
          : scrolls
          ? _scrollingCard(look)
          : _detailCard(look),
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
    return AppSheet(child: _cardLines(look));
  }

  /// The card for a message too tall for the room above the buttons: the
  /// same card, with its words scrolling inside it.
  Widget _scrollingCard(AlarmRingingLook look) {
    return _ScrollingCard(
      padding: _cardPadding,
      fadeColor: colors.surface,
      child: _cardLines(look),
    );
  }

  Widget _cardLines(AlarmRingingLook look) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(state.title, style: _titleStyle(look)),
        const SizedBox(height: _titleGap),
        Text(state.body, style: _bodyStyle(look)),
        const SizedBox(height: _bodyGap),
        Text(state.meta, style: _metaStyle(look)),
      ],
    );
  }
}

/// The message card with its words in a scroll view, for a message that is
/// taller than the room it has. The card keeps its shape and shadow. A soft
/// edge at the bottom says there is more while there is.
class _ScrollingCard extends StatefulWidget {
  const _ScrollingCard({
    required this.child,
    required this.padding,
    required this.fadeColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color fadeColor;

  @override
  State<_ScrollingCard> createState() => _ScrollingCardState();
}

class _ScrollingCardState extends State<_ScrollingCard> {
  /// The card only scrolls when it is too tall, so it starts with more
  /// below it.
  bool _hasMore = true;
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification note) {
    _readMore(note.metrics);
    return false;
  }

  /// Also read once the card has its size, so a message that fits gets no
  /// fade at its foot.
  bool _onMetrics(ScrollMetricsNotification note) {
    _readMore(note.metrics);
    return false;
  }

  void _readMore(ScrollMetrics metrics) {
    final hasMore = metrics.extentAfter > 0.5;
    if (hasMore != _hasMore) setState(() => _hasMore = hasMore);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: Radii.xlAll,
        child: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                // The thumb stays up, so a card that ends mid-message says it
                // scrolls.
                child: Scrollbar(
                  controller: _controller,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _controller,
                    physics: const ClampingScrollPhysics(),
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            if (_hasMore)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppScrollFade(
                  edge: ScrollFadeEdge.bottom,
                  height: 32,
                  color: widget.fadeColor,
                ),
              ),
          ],
        ),
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
