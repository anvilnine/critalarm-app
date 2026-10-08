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
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The phone a tile draws its paywall on, in points, with the insets a
/// phone of that size has.
const Size paywallTilePhone = Size(390, 844);
const EdgeInsets paywallTilePhoneInsets = EdgeInsets.only(top: 47, bottom: 34);

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

/// The tile both pickers are made of: a phone shape with a paywall playing
/// in it, a label under it, and a mark when it is the one chosen.
class PaywallPhoneTile extends StatefulWidget {
  const PaywallPhoneTile({
    required this.layout,
    required this.product,
    required this.label,
    this.intro = PaywallIntroId.none,
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
class _TilePaywall extends StatelessWidget {
  const _TilePaywall({
    required this.layout,
    required this.intro,
    required this.product,
    super.key,
  });

  final PaywallLayoutId layout;
  final PaywallIntroId intro;
  final PaywallProduct product;

  @override
  Widget build(BuildContext context) => BlocProvider<PaywallBuyCubit>(
    create: (_) {
      final cubit = DemoPaywallBuyCubit(product);
      unawaited(cubit.load());
      return cubit;
    },
    child: PaywallRouteInfo(
      layout: layout,
      source: PaywallSource.direct,
      showsUnbuilt: true,
      child: PaywallLayoutView(layout: layout, product: product, intro: intro),
    ),
  );
}
