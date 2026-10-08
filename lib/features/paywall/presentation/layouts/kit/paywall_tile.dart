import 'dart:async';

import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The phone a tile draws its paywall on, in points, with the insets a
/// phone of that size has.
const Size paywallTilePhone = Size(390, 844);
const EdgeInsets paywallTilePhoneInsets = EdgeInsets.only(top: 47, bottom: 34);

/// The key of the name a person reads for [layout], in the picker's rows
/// and under its tiles. The wire key (`PaywallLayoutId.key`) is for routes
/// and remote values and is never shown.
String paywallLayoutNameKey(PaywallLayoutId layout) => switch (layout) {
  PaywallLayoutId.hero => LocaleKeys.paywall_picker_layout_names_hero,
  PaywallLayoutId.sheet => LocaleKeys.paywall_picker_layout_names_sheet,
  PaywallLayoutId.proof => LocaleKeys.paywall_picker_layout_names_proof,
  PaywallLayoutId.bento => LocaleKeys.paywall_picker_layout_names_bento,
  PaywallLayoutId.reel => LocaleKeys.paywall_picker_layout_names_reel,
  PaywallLayoutId.stage => LocaleKeys.paywall_picker_layout_names_stage,
  PaywallLayoutId.sentence => LocaleKeys.paywall_picker_layout_names_sentence,
  PaywallLayoutId.wipe => LocaleKeys.paywall_picker_layout_names_wipe,
  PaywallLayoutId.doors => LocaleKeys.paywall_picker_layout_names_doors,
  PaywallLayoutId.receipt => LocaleKeys.paywall_picker_layout_names_receipt,
};

/// The key of the name a person reads for [intro]. See
/// [paywallLayoutNameKey].
String paywallIntroNameKey(PaywallIntroId intro) => switch (intro) {
  PaywallIntroId.none => LocaleKeys.paywall_picker_intro_none,
  PaywallIntroId.falseAlarm =>
    LocaleKeys.paywall_picker_intro_names_false_alarm,
  PaywallIntroId.snooze => LocaleKeys.paywall_picker_intro_names_snooze,
  PaywallIntroId.wakeUp => LocaleKeys.paywall_picker_intro_names_wake_up,
  PaywallIntroId.curtain => LocaleKeys.paywall_picker_intro_names_curtain,
  PaywallIntroId.countdown => LocaleKeys.paywall_picker_intro_names_countdown,
};

/// The key of the name a person reads for [thanks]. See
/// [paywallLayoutNameKey].
String paywallThanksNameKey(PaywallThanksId thanks) => switch (thanks) {
  PaywallThanksId.none => LocaleKeys.paywall_thanks_names_none,
  PaywallThanksId.confetti => LocaleKeys.paywall_thanks_names_confetti,
  PaywallThanksId.unlock => LocaleKeys.paywall_thanks_names_unlock,
};

/// The names themselves.
String paywallLayoutName(PaywallLayoutId layout) =>
    paywallLayoutNameKey(layout).tr();
String paywallIntroName(PaywallIntroId intro) =>
    paywallIntroNameKey(intro).tr();
String paywallThanksName(PaywallThanksId thanks) =>
    paywallThanksNameKey(thanks).tr();

/// A small phone playing one layout, live, to pick it by.
///
/// It is the real layout widget on a made-up buy model, drawn at phone
/// size and scaled down. It takes no touch of its own, makes no sound, and
/// its clock runs only while the tile is built: put tiles in a lazy list
/// and the ones off screen cost nothing.
class PaywallLayoutTile extends StatelessWidget {
  const PaywallLayoutTile({
    required this.layout,
    required this.product,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.width = PaywallPhoneTile.defaultWidth,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallProduct product;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) => PaywallPhoneTile(
    layout: layout,
    product: product,
    label: label,
    isSelected: isSelected,
    onTap: onTap,
    width: width,
  );
}

/// A small phone playing one intro, then the layout it hands over to, and
/// round again.
///
/// [layout] is what the intro hands over to: `hero` unless the picker
/// knows which layout was chosen. `PaywallIntroId.none` plays the layout
/// alone. See [PaywallLayoutTile] for what a tile is.
class PaywallIntroTile extends StatelessWidget {
  const PaywallIntroTile({
    required this.intro,
    required this.product,
    required this.label,
    this.layout = PaywallLayoutId.hero,
    this.isSelected = false,
    this.onTap,
    this.width = PaywallPhoneTile.defaultWidth,
    super.key,
  });

  final PaywallIntroId intro;
  final PaywallLayoutId layout;
  final PaywallProduct product;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;

  /// How long the layout shows after the intro before it plays again.
  static const double secondsAfter = 3.2;

  @override
  Widget build(BuildContext context) {
    final seconds = paywallIntroBuilders[intro]?.seconds;
    return PaywallPhoneTile(
      layout: layout,
      intro: intro,
      product: product,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      width: width,
      replayEvery: seconds == null
          ? null
          : Duration(milliseconds: ((seconds + secondsAfter) * 1000).round()),
    );
  }
}

/// A small phone playing what comes after a purchase: the layout for a
/// moment, a purchase on the made-up buy model, the show, its resting
/// frame, and round again.
///
/// `PaywallThanksId.none` plays what a purchase ends on with no step of
/// its own. See [PaywallLayoutTile] for what a tile is.
class PaywallThanksTile extends StatelessWidget {
  const PaywallThanksTile({
    required this.thanks,
    required this.product,
    required this.label,
    this.layout = PaywallLayoutId.hero,
    this.isSelected = false,
    this.onTap,
    this.width = PaywallPhoneTile.defaultWidth,
    super.key,
  });

  final PaywallThanksId thanks;
  final PaywallLayoutId layout;
  final PaywallProduct product;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;

  /// How long the layout shows before the purchase, and how long the
  /// resting frame shows before it plays again.
  static const double secondsBefore = 1.6;
  static const double secondsAfter = 2.6;

  /// How long one round of the tile is.
  static double roundFor(PaywallThanksId thanks) =>
      secondsBefore +
      (paywallThanksBuilders[thanks]?.seconds ?? 0) +
      secondsAfter;

  @override
  Widget build(BuildContext context) => PaywallPhoneTile(
    layout: layout,
    thanks: thanks,
    buysAfter: const Duration(milliseconds: 1600),
    product: product,
    label: label,
    isSelected: isSelected,
    onTap: onTap,
    width: width,
    replayEvery: Duration(milliseconds: (roundFor(thanks) * 1000).round()),
  );
}

/// The tile every picker is made of: a phone shape with a paywall playing
/// in it, a label under it, and a mark when it is the one chosen.
class PaywallPhoneTile extends StatefulWidget {
  const PaywallPhoneTile({
    required this.layout,
    required this.product,
    required this.label,
    this.intro = PaywallIntroId.none,
    this.thanks = PaywallThanksId.none,
    this.buysAfter,
    this.isSelected = false,
    this.onTap,
    this.width = defaultWidth,
    this.replayEvery,
    super.key,
  });

  /// Wide enough for two and a half across a phone, so a row of them reads
  /// as something to swipe.
  static const double defaultWidth = 136;

  /// The height of a tile [width] points wide, label included.
  static double heightFor(double width) =>
      width * paywallTilePhone.height / paywallTilePhone.width + _labelRoom;

  static const double _labelRoom = 30;

  final PaywallLayoutId layout;
  final PaywallIntroId intro;
  final PaywallThanksId thanks;

  /// Buys on the made-up buy model this long after the paywall appears,
  /// to show what comes after. Null never buys.
  final Duration? buysAfter;
  final PaywallProduct product;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;

  /// Starts the paywall again this often, so an entrance that plays once
  /// can be watched more than once. Null lets it run on.
  final Duration? replayEvery;

  @override
  State<PaywallPhoneTile> createState() => _PaywallPhoneTileState();
}

class _PaywallPhoneTileState extends State<PaywallPhoneTile> {
  Timer? _replay;

  /// Which showing this is. A new number builds the paywall afresh.
  int _showing = 0;
  bool? _wasStill;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isStill = context.reduceMotion;
    if (isStill == _wasStill) return;
    _wasStill = isStill;
    _arm();
  }

  @override
  void didUpdateWidget(PaywallPhoneTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayEvery != widget.replayEvery) _arm();
  }

  /// Nothing replays when nothing may move: the tile is the resting frame.
  void _arm() {
    _replay?.cancel();
    _replay = null;
    final every = widget.replayEvery;
    if (every == null || (_wasStill ?? false)) return;
    _replay = Timer.periodic(every, (_) {
      if (mounted) setState(() => _showing++);
    });
  }

  @override
  void dispose() {
    _replay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(widget.width * 0.13);
    final screen = MediaQuery.of(context).copyWith(
      size: paywallTilePhone,
      padding: paywallTilePhoneInsets,
      viewPadding: paywallTilePhoneInsets,
      viewInsets: EdgeInsets.zero,
      textScaler: TextScaler.noScaling,
    );

    return Semantics(
      button: widget.onTap != null,
      selected: widget.isSelected,
      label: widget.isSelected
          ? LocaleKeys.paywall_picker_selected.tr(
              namedArgs: {'name': widget.label},
            )
          : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: paywallTilePhone.aspectRatio,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: widget.isSelected
                                ? colors.ink
                                : colors.hairline,
                            width: widget.isSelected ? 3 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: radius,
                          child: RepaintBoundary(
                            child: FittedBox(
                              child: SizedBox.fromSize(
                                size: paywallTilePhone,
                                child: IgnorePointer(
                                  child: PaywallMuted(
                                    child: MediaQuery(
                                      data: screen,
                                      child: _TilePaywall(
                                        key: ValueKey(_showing),
                                        layout: widget.layout,
                                        intro: widget.intro,
                                        thanks: widget.thanks,
                                        // Nothing may move: the frame
                                        // after the purchase, at once.
                                        buysAfter: (_wasStill ?? false)
                                            ? Duration.zero
                                            : widget.buysAfter,
                                        product: widget.product,
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
                    if (widget.isSelected)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 2,
                            ),
                          ),
                          child: AppGlyph(
                            GlyphType.check,
                            color: colors.surface,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.s2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    AppTypography.small(
                      widget.isSelected ? colors.ink : colors.ink3,
                      fontSize: 13,
                    ).copyWith(
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One paywall on a made-up buy model: what a tile scales down.
class _TilePaywall extends StatefulWidget {
  const _TilePaywall({
    required this.layout,
    required this.intro,
    required this.thanks,
    required this.buysAfter,
    required this.product,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallIntroId intro;
  final PaywallThanksId thanks;
  final Duration? buysAfter;
  final PaywallProduct product;

  @override
  State<_TilePaywall> createState() => _TilePaywallState();
}

class _TilePaywallState extends State<_TilePaywall> {
  late final DemoPaywallBuyCubit _cubit = DemoPaywallBuyCubit(widget.product)
    ..isTryOut = true;
  Timer? _buys;

  @override
  void initState() {
    super.initState();
    unawaited(_cubit.load());
    final after = widget.buysAfter;
    if (after == null) return;
    // Nothing is charged and nothing unlocked: the made-up model only
    // walks the states a purchase does.
    _buys = Timer(after, () => unawaited(_cubit.buy()));
  }

  @override
  void dispose() {
    _buys?.cancel();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<PaywallBuyCubit>.value(
    value: _cubit,
    child: PaywallRouteInfo(
      layout: widget.layout,
      source: PaywallSource.direct,
      showsUnbuilt: true,
      child: PaywallLayoutView(
        layout: widget.layout,
        product: widget.product,
        intro: widget.intro,
        thanks: widget.thanks,
      ),
    ),
  );
}
