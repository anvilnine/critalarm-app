import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/entities/store_account_label.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_plan_picker.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_plan_picker.dart';

/// How one layout wants the buy block drawn. Sizes are not in here on
/// purpose: the button height and the legal text size are the same on every
/// layout.
@immutable
class PaywallBuyBlockStyle {
  const PaywallBuyBlockStyle({
    this.pickerStyle = PaywallPlanPickerStyle.segments,
    this.tone = PaywallTone.canvas,
    this.buttonVariant,
    this.showsPicker = true,
    this.horizontalPadding = 20,
  });

  final PaywallPlanPickerStyle pickerStyle;

  /// What the block sits on, which picks its text colours.
  final PaywallTone tone;

  /// Null takes the button that reads on [tone].
  final AppButtonVariant? buttonVariant;

  /// False when the layout places a `PaywallPlanPicker` of its own
  /// somewhere else on the screen.
  final bool showsPicker;
  final double horizontalPadding;
}

/// The product's name as copy says it.
String paywallProductName(PaywallProduct product) => switch (product) {
  PaywallProduct.hosted => LocaleKeys.paywall_kit_name_hosted.tr(),
  PaywallProduct.pro => LocaleKeys.paywall_kit_name_pro.tr(),
};

/// The bottom block of every layout, top to bottom: the plans, the button,
/// the own-server promise, the legal line, and one line with Restore, Terms
/// and Privacy. Every part keeps the same side inset.
///
/// The button is the only cobalt thing in it. A plan card is cream when
/// picked and a quiet tint when not, and the saving is a small ink badge.
/// It reads the `PaywallBuyCubit` above it and makes every purchase call,
/// so a layout holds no button, price or legal text of its own. Pro has no
/// plan card: its price is on the button, and nothing says how Pro is paid.
///
/// Its text stops growing at `paywallBuyMaxTextScale`. Nothing in it
/// scrolls or is cut: at a large text size it is taller and the layout
/// above gives up the height.
class PaywallBuyBlock extends StatelessWidget {
  const PaywallBuyBlock({
    this.style = const PaywallBuyBlockStyle(),
    this.onDone,
    super.key,
  });

  final PaywallBuyBlockStyle style;

  /// What the Done button does once the product is held. Closes the route
  /// when null.
  final VoidCallback? onDone;

  /// How tall the links line draws at the default text size.
  static const double linksHeight = 28;

  /// How far each link's tap area runs up past the line it is drawn on,
  /// over the legal line, to make 44 points.
  static const double linksTapOverlap = 44 - linksHeight;

  @override
  Widget build(BuildContext context) {
    return _BuyCues(
      child: BlocBuilder<PaywallBuyCubit, PaywallBuyState>(
        builder: (context, held) {
          // With a step of its own after the purchase, the block keeps
          // the look it had while confirming: that step grows out of the
          // button, so nothing here may move under it.
          final state =
              held.status == PaywallBuyStatus.done &&
                  PaywallThanksPlay.takesOver(context)
              ? held.copyWith(status: PaywallBuyStatus.checking)
              : held;
          final tone = PaywallToneColors.of(context, style.tone);
          final side = EdgeInsets.symmetric(
            horizontal: style.horizontalPadding,
          );

          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: paywallBuyMaxTextScale,
            child: Builder(
              builder: (context) {
                final linksLine =
                    linksHeight * MediaQuery.textScalerOf(context).scale(1);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: side,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Offer(
                            state: state,
                            style: style,
                            tone: tone,
                            onDone: onDone,
                          ),
                          if (_showsLegal(state))
                            _LegalLine(state: state, color: tone.muted)
                          else
                            // The links' tap area must not reach the button.
                            const SizedBox(height: linksTapOverlap),
                          SizedBox(height: linksLine),
                        ],
                      ),
                    ),
                    // Over the bottom of the column, so each link gets its
                    // full tap area and the line still draws short.
                    Positioned(
                      left: style.horizontalPadding,
                      right: style.horizontalPadding,
                      bottom: 0,
                      height: linksLine + linksTapOverlap,
                      child: _LinksLine(
                        state: state,
                        color: tone.muted,
                        lineHeight: linksLine,
                      ),
                    ),
                    // A message floats over the bottom of the layout and
                    // takes no room, so a failed purchase never squeezes
                    // what is above.
                    if (state.messageKey case final key?)
                      Positioned(
                        left: style.horizontalPadding,
                        right: style.horizontalPadding,
                        top: -Spacing.s2,
                        child: FractionalTranslation(
                          translation: const Offset(0, -1),
                          child: _Message(text: key.tr()),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  static bool _showsLegal(PaywallBuyState state) =>
      state.status != PaywallBuyStatus.done &&
      state.status != PaywallBuyStatus.notOnSale;
}

/// The part above the legal lines: the plans and the button, or the one
/// line that stands in for them.
class _Offer extends StatelessWidget {
  const _Offer({
    required this.state,
    required this.style,
    required this.tone,
    required this.onDone,
  });

  final PaywallBuyState state;
  final PaywallBuyBlockStyle style;
  final PaywallToneColors tone;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaywallBuyCubit>();
    final variant = style.buttonVariant ?? paywallButtonVariantFor(style.tone);
    final name = paywallProductName(state.product);
    final strong = AppTypography.small(
      tone.ink,
      fontSize: 15,
    ).copyWith(fontWeight: FontWeight.w700);

    if (state.status == PaywallBuyStatus.done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              state.product == PaywallProduct.hosted
                  ? LocaleKeys.paywall_kit_done_hosted.tr()
                  : LocaleKeys.paywall_kit_done_pro.tr(),
              textAlign: TextAlign.center,
              style: strong,
            ),
          ),
          const SizedBox(height: Spacing.s2),
          AppButton(
            label: LocaleKeys.paywall_kit_button_done.tr(),
            variant: variant,
            isFullWidth: true,
            onPressed: onDone ?? () => unawaited(Navigator.maybePop(context)),
          ),
        ],
      );
    }

    if (state.status == PaywallBuyStatus.notOnSale) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s2),
        child: Text(
          LocaleKeys.paywall_kit_not_on_sale.tr(namedArgs: {'name': name}),
          textAlign: TextAlign.center,
          style: strong,
        ),
      );
    }

    final isPaused =
        state.status == PaywallBuyStatus.checking && state.isPaused;
    // What a screen reader hears while the button only shows a spinner.
    final busyLabel = switch (state.status) {
      PaywallBuyStatus.purchasing => LocaleKeys.paywall_kit_at_store.tr(),
      PaywallBuyStatus.checking when !isPaused =>
        LocaleKeys.paywall_kit_checking.tr(),
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style.showsPicker && planCardCount(state) > 0) ...[
          PaywallPlanPicker(style: style.pickerStyle, tone: style.tone),
          const SizedBox(height: Spacing.s2),
        ],
        Semantics(
          liveRegion: busyLabel != null,
          label: busyLabel,
          // 48 points. The 60 point size is for the alarm screen only.
          child: AppButton(
            label: buyButtonLabel(state, name: name),
            variant: variant,
            isFullWidth: true,
            isLoading: state.isBusy,
            // Finger down on the main button.
            onPressDown: () => getIt<PaywallCues>().play(PaywallCue.press),
            onPressed: isPaused
                ? () => unawaited(cubit.checkAgain())
                : state.canBuy
                ? () => unawaited(cubit.buy())
                : null,
          ),
        ),
        const SizedBox(height: Spacing.s2),
        // After the action it reads as a promise: nothing is lost by not
        // buying.
        if (state.product == PaywallProduct.hosted) ...[
          Text(
            LocaleKeys.paywall_self_hosted_note.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.small(
              tone.note,
              fontSize: 12.5,
            ).copyWith(height: 1.3),
          ),
          const SizedBox(height: Spacing.s1),
        ],
      ],
    );
  }
}

/// What the store does with the money, in whole sentences: for Hosted,
/// that it renews, at what price and where to cancel. Ten points, two
/// lines at the default text size. It is never cut and never scrolls.
class _LegalLine extends StatelessWidget {
  const _LegalLine({required this.state, required this.color});

  final PaywallBuyState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      legalLine(
        state,
        store: storeAccountLabelFor(Theme.of(context).platform),
      ),
      textAlign: TextAlign.center,
      style: AppTypography.body(color, fontSize: 10).copyWith(height: 1.35),
    );
  }
}

/// Restore, Terms and Privacy as one quiet line with dots between. Each
/// has a 44 point tap area that runs up past the drawn line. With nothing
/// on sale only Restore is left.
class _LinksLine extends StatelessWidget {
  const _LinksLine({
    required this.state,
    required this.color,
    required this.lineHeight,
  });

  final PaywallBuyState state;
  final Color color;

  /// The height the words are centred in, at the bottom of the tap area.
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaywallBuyCubit>();
    final isDone = state.status == PaywallBuyStatus.done;
    final onlyRestore = state.status == PaywallBuyStatus.notOnSale;
    final style = AppTypography.small(
      color,
      fontSize: 11,
    ).copyWith(fontWeight: FontWeight.w500, height: 1);

    final links = [
      if (!isDone)
        _Link(
          text: LocaleKeys.paywall_kit_link_restore.tr(),
          label: LocaleKeys.paywall_restore_purchases_button.tr(),
          style: style,
          lineHeight: lineHeight,
          onTap: state.canRestore ? () => unawaited(cubit.restore()) : null,
        ),
      if (!onlyRestore) ...[
        _Link(
          text: LocaleKeys.paywall_kit_link_terms.tr(),
          label: LocaleKeys.paywall_terms_link.tr(),
          style: style,
          lineHeight: lineHeight,
          url: termsUrl,
        ),
        _Link(
          text: LocaleKeys.paywall_kit_link_privacy.tr(),
          label: LocaleKeys.paywall_privacy_link.tr(),
          style: style,
          lineHeight: lineHeight,
          url: privacyUrl,
        ),
      ],
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, link) in links.indexed) ...[
          if (i > 0)
            ExcludeSemantics(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: lineHeight,
                  child: Center(
                    child: Text('·', style: style), // l10n-ok: a separator
                  ),
                ),
              ),
            ),
          link,
        ],
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.text,
    required this.label,
    required this.style,
    required this.lineHeight,
    this.onTap,
    this.url,
  });

  /// The short word drawn.
  final String text;

  /// What a screen reader says: the long form.
  final String label;
  final TextStyle style;
  final double lineHeight;
  final VoidCallback? onTap;

  /// A page to open. When set, the link is read as a link.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final onTap = url == null
        ? this.onTap
        : () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView),
          );
    final color = style.color!;
    final shown = onTap == null ? color.withValues(alpha: 0.5) : color;

    return Flexible(
      child: Semantics(
        button: url == null,
        link: url != null,
        linkUrl: url == null ? null : Uri.tryParse(url),
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.bottomCenter,
                widthFactor: 1,
                child: SizedBox(
                  height: lineHeight,
                  child: Center(
                    widthFactor: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        maxLines: 1,
                        style: style.copyWith(color: shown),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One plain line about the last thing that happened: a purchase that did
/// not finish, a restore that found nothing, a check that is still open.
class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.ink, width: 1.5),
          boxShadow: AppShadows.shadowMd(isDark: isDark),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.small(
            colors.ink,
            fontSize: 13,
          ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
        ),
      ),
    );
  }
}

/// Plays the cue of each change of the buy state that has one: the
/// product bought or restored, a problem at the store, a restore that
/// found nothing. `paywallBuyCue` is the rule. Silent in a thumbnail.
class _BuyCues extends StatefulWidget {
  const _BuyCues({required this.child});

  final Widget child;

  @override
  State<_BuyCues> createState() => _BuyCuesState();
}

class _BuyCuesState extends State<_BuyCues> {
  late PaywallBuyState _before = context.read<PaywallBuyCubit>().state;

  void _onChange(BuildContext context, PaywallBuyState after) {
    final cue = paywallBuyCue(
      _before,
      after,
      action: context.read<PaywallBuyCubit>().lastAction,
    );
    _before = after;
    if (cue == null || PaywallMuted.of(context)) return;
    getIt<PaywallCues>().play(cue);
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<PaywallBuyCubit, PaywallBuyState>(
        listener: _onChange,
        child: widget.child,
      );
}
