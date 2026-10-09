import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/look/look_phone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The name of the look at [id], as the page shows it.
String lookNameOf(AlarmStyleId id) => id == AlarmStyleId.own
    ? LocaleKeys.alarm_styles_own.tr()
    : alarmStyleOf(id).nameKey.tr();

/// The deck of phones: one per look, side by side, the centred one living and
/// full size, its neighbours smaller, dimmer and upright. Dots under it move
/// the deck too.
///
/// The deck owns the scroll. It tells the page where it is through [page] (the
/// position as a number, following the finger) and [settled] (the whole page it
/// last came to rest on), and the page draws its colours from them. Nothing is
/// saved by moving the deck.
class LookDeck extends StatefulWidget {
  const LookDeck({
    required this.deck,
    required this.fade,
    required this.page,
    required this.settled,
    required this.centred,
    required this.clock,
    required this.inUse,
    required this.own,
    required this.height,
    required this.onTapCentred,
    required this.onOwnCorner,
    super.key,
  });

  /// The looks in order, Yours last.
  final List<AlarmStyleId> deck;

  /// The colours of the page between two looks.
  final LookFade fade;

  /// Where the deck is, as a page number with a fraction while it moves. The
  /// deck writes it. Its value on first build is the page the deck opens on.
  final ValueNotifier<double> page;

  /// The whole page the deck last came to rest on. The deck writes it.
  final ValueNotifier<int> settled;

  /// The page nearest the middle. The deck writes it.
  final ValueNotifier<int> centred;

  /// Seconds of the page's clock, for the rock of the centred phone. It reads
  /// 0 for good under reduce motion.
  final ValueListenable<double> clock;

  /// The look that rings now.
  final AlarmStyleId inUse;

  final OwnLookPhase own;

  /// The room the deck has, the dots included.
  final double height;

  /// A tap on the phone that is already in the middle.
  final void Function(AlarmStyleId id) onTapCentred;

  /// A tap on the pencil or the cross on Yours.
  final VoidCallback onOwnCorner;

  /// The room the dots take.
  static const double dotsHeight = 44;

  /// Room above and below a phone for its shadow.
  static const double _shadowRoom = 14;

  @override
  State<LookDeck> createState() => _LookDeckState();
}

class _LookDeckState extends State<LookDeck> {
  PageController? _controller;
  double _fraction = 0;

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    _controller?.dispose();
    super.dispose();
  }

  /// The controller for pages [fraction] of the deck's width apart. A new one
  /// is made when the layout changes the spacing, and it opens on the page the
  /// old one was on.
  PageController _controllerFor(double fraction) {
    final existing = _controller;
    if (existing != null && (fraction - _fraction).abs() < 0.0005) {
      return existing;
    }
    final at = widget.page.value.round().clamp(0, widget.deck.length - 1);
    final next = PageController(initialPage: at, viewportFraction: fraction)
      ..addListener(_onScroll);
    if (existing != null) {
      existing.removeListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
    }
    _fraction = fraction;
    _controller = next;
    return next;
  }

  bool _isPublishQueued = false;

  void _onScroll() {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (!position.haveDimensions) return;
    // A layout change gives the controller new dimensions while the page is
    // being built, and the page's builders must not be told then. Tell them
    // once the frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_isPublishQueued) return;
      _isPublishQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isPublishQueued = false;
        if (mounted) _onScroll();
      });
      return;
    }
    final page = controller.page;
    if (page == null) return;
    if (widget.page.value != page) widget.page.value = page;
    final centred = centredPage(page, widget.deck.length);
    if (widget.centred.value != centred) widget.centred.value = centred;
  }

  void _moveTo(int index) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    if (context.reduceMotion) {
      controller.jumpToPage(index);
      widget.settled.value = index;
      _onScroll();
      return;
    }
    unawaited(
      controller.animateToPage(
        index,
        duration: AppDurations.slow,
        curve: AppCurves.easeOut,
      ),
    );
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollEndNotification) {
      final page = _controller?.page;
      if (page != null) {
        widget.settled.value = centredPage(page, widget.deck.length);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // The phones are upright on any display.
      final screen = lookScreenSize(MediaQuery.sizeOf(context));
      final aspect = screen.width / screen.height;
      final phoneRoom = math
          .max(
            0,
            widget.height - LookDeck.dotsHeight - 2 * LookDeck._shadowRoom,
          )
          .toDouble();
      final phone = lookPhoneSize(
        columnWidth: box.maxWidth,
        availableHeight: phoneRoom,
        aspect: aspect,
      );
      final controller = _controllerFor(
        lookPhoneStep(phone.width) / box.maxWidth,
      );
      // On a display with more room than the phones need, the deck sits in
      // the middle of it and not at the top.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: phone.height + 2 * LookDeck._shadowRoom,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onNotification,
              child: PageView.builder(
                controller: controller,
                itemCount: widget.deck.length,
                clipBehavior: Clip.none,
                onPageChanged: (_) => AppHaptics.selection(),
                itemBuilder: (context, index) => _LookPhone(
                  deck: widget,
                  index: index,
                  size: phone,
                  onTap: () {
                    if (widget.centred.value == index) {
                      widget.onTapCentred(widget.deck[index]);
                    } else {
                      _moveTo(index);
                    }
                  },
                ),
              ),
            ),
          ),
          _LookDots(deck: widget, onTap: _moveTo),
        ],
      );
    },
  );
}

/// One phone in the deck, posed by where the deck is.
class _LookPhone extends StatelessWidget {
  const _LookPhone({
    required this.deck,
    required this.index,
    required this.size,
    required this.onTap,
  });

  final LookDeck deck;
  final int index;
  final Size size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = deck.deck[index];
    final face = ValueListenableBuilder<int>(
      valueListenable: deck.centred,
      builder: (context, centred, _) {
        final isCentred = centred == index;
        return Stack(
          fit: StackFit.expand,
          children: [
            LookPhoneFace(
              id: id,
              own: deck.own,
              isLive: isCentred,
              height: size.height,
              fade: deck.fade,
            ),
            if (isCentred &&
                id == AlarmStyleId.own &&
                deck.own != OwnLookPhase.none)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: LookOwnCorner(
                  key: ValueKey(
                    deck.own == OwnLookPhase.held
                        ? 'look-own-edit'
                        : 'look-own-remove',
                  ),
                  glyph: deck.own == OwnLookPhase.held
                      ? GlyphType.pencil
                      : GlyphType.close,
                  label: deck.own == OwnLookPhase.held
                      ? LocaleKeys.alarm_styles_own_edit_label.tr()
                      : LocaleKeys.alarm_styles_own_remove_photo.tr(),
                  onTap: deck.onOwnCorner,
                ),
              ),
          ],
        );
      },
    );
    final plan = id.isFree
        ? null
        : lockedPlanWord(AppFeature.alarmScreenStyles);
    final isEmptyOwn = id == AlarmStyleId.own && deck.own == OwnLookPhase.none;
    final name = lookNameOf(id);
    final label = id == deck.inUse
        ? LocaleKeys.personalize_passes_look_card_label_in_use.tr(
            namedArgs: {'name': name},
          )
        : plan != null
        ? LocaleKeys.personalize_passes_look_card_label_locked.tr(
            namedArgs: {'name': name, 'plan': plan},
          )
        : LocaleKeys.personalize_passes_look_card_label.tr(
            namedArgs: {'name': name},
          );
    return Semantics(
      button: true,
      label: label,
      hint: LocaleKeys.personalize_passes_look_card_hint_move.tr(),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([deck.page, deck.clock]),
          child: RepaintBoundary(child: face),
          builder: (context, face) {
            final page = deck.page.value;
            final pose = lookPoseAt(index, page);
            // The rock belongs to the phone in the middle and fades out as
            // another comes to it.
            final weight = 1 - math.min(1.0, (index - page).abs());
            final degrees = pose.tilt + lookRock(deck.clock.value) * weight;
            final ground = deck.fade.groundAt(page);
            return Center(
              child: Transform.rotate(
                angle: degrees * math.pi / 180,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: pose.scale,
                  child: LookPhoneFrame(
                    size: size,
                    isEmpty: isEmptyOwn,
                    border: deck.fade.textAt(page),
                    scrim: ground.withValues(alpha: 1 - pose.opacity),
                    child: face!,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One dot per look. Each is 8 points drawn in a 44 point target and a
/// labelled button, and the one for the look in the middle is stretched.
/// The others keep 3 to 1 with the page.
class _LookDots extends StatelessWidget {
  const _LookDots({required this.deck, required this.onTap});

  final LookDeck deck;
  final void Function(int index) onTap;

  /// The drawn size of a dot, and how wide the one in the middle is.
  static const double _dot = 8;
  static const double _wide = 22;

  @override
  Widget build(BuildContext context) {
    final count = deck.deck.length;
    return SizedBox(
      height: LookDeck.dotsHeight,
      child: ValueListenableBuilder<int>(
        valueListenable: deck.centred,
        builder: (context, centred, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Semantics(
                button: true,
                selected: centred == i,
                label: LocaleKeys.personalize_passes_look_dot_label.tr(
                  namedArgs: {
                    'index': '${i + 1}',
                    'count': '$count',
                    'name': lookNameOf(deck.deck[i]),
                  },
                ),
                onTap: () => onTap(i),
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('look-dot-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: SizedBox(
                    width: LookDeck.dotsHeight,
                    height: LookDeck.dotsHeight,
                    child: Center(
                      child: ListenableBuilder(
                        listenable: deck.page,
                        builder: (context, _) {
                          final near =
                              1.0 - math.min(1.0, (i - deck.page.value).abs());
                          final page = deck.page.value;
                          return Container(
                            width: _dot + (_wide - _dot) * near,
                            height: _dot,
                            decoration: BoxDecoration(
                              color: lookDotColor(
                                text: deck.fade.textAt(page),
                                ground: deck.fade.groundAt(page),
                                near: near,
                              ),
                              borderRadius: BorderRadius.circular(_dot / 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
