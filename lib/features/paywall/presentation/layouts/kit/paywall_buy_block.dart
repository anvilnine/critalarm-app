import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/entities/store_account_label.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_plan_picker.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_plan_picker.dart';

/// What the button says.
enum PaywallBuyLabel {
  /// "Get Hosted".
  name,

  /// "Get Hosted for" and the picked option's price.
  nameAndPrice,
}

/// How one layout wants the buy block drawn. Sizes are not in here on
/// purpose: the button height and the legal text size are the same on every
/// layout.
@immutable
class PaywallBuyBlockStyle {
  const PaywallBuyBlockStyle({
    this.pickerStyle = PaywallPlanPickerStyle.rows,
    this.tone = PaywallTone.canvas,
    this.buttonVariant,
    this.label = PaywallBuyLabel.name,
    this.showsPicker = true,
    this.horizontalPadding = 20,
  });

  final PaywallPlanPickerStyle pickerStyle;

  /// What the block sits on, which picks its text colours.
  final PaywallTone tone;

  /// Null takes the button that reads on [tone].
  final AppButtonVariant? buttonVariant;
  final PaywallBuyLabel label;

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

/// The bottom block of every layout: the plans, the button, the legal
/// lines, and one row with Restore, Terms and Privacy.
///
/// It reads the `PaywallBuyCubit` above it and makes every purchase call,
/// so a layout holds no button, price or legal text of its own. For Pro it
/// shows the store's title and price as they come and says nothing about
/// how Pro is paid.
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

  static bool _wasBuying(PaywallBuyState state) =>
      state.status == PaywallBuyStatus.purchasing ||
      state.status == PaywallBuyStatus.checking;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaywallBuyCubit, PaywallBuyState>(
      listenWhen: (before, after) =>
          _wasBuying(before) && after.status == PaywallBuyStatus.done,
      listener: (_, _) => getIt<PaywallCues>().bought(),
      builder: (context, state) {
        final tone = PaywallToneColors.of(context, style.tone);
        final side = EdgeInsets.symmetric(horizontal: style.horizontalPadding);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: side,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: paywallBuyMaxTextScale,
                    child: _Offer(
                      state: state,
                      style: style,
                      tone: tone,
                      onDone: onDone,
                    ),
                  ),
                ),
                if (_showsLegal(state)) ...[
                  const SizedBox(height: 6),
                  _LegalLines(product: state.product, color: tone.muted),
                ],
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: paywallBuyMaxTextScale,
                  child: _LinksRow(state: state, color: tone.muted),
                ),
              ],
            ),
            // A message floats over the bottom of the layout and takes no
            // room, so a failed purchase never squeezes what is above.
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
    final price = state.selected?.price;
    final label = isPaused
        ? LocaleKeys.paywall_kit_button_check_again.tr()
        : style.label == PaywallBuyLabel.nameAndPrice && price != null
        ? LocaleKeys.paywall_kit_button_get_price.tr(
            namedArgs: {'name': name, 'price': price},
          )
        : LocaleKeys.paywall_kit_button_get.tr(namedArgs: {'name': name});
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
        if (state.product == PaywallProduct.hosted) ...[
          Text(
            LocaleKeys.paywall_self_hosted_note.tr(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small(
              tone.muted,
              fontSize: 12.5,
            ).copyWith(height: 1.3),
          ),
          const SizedBox(height: Spacing.s2),
        ],
        if (style.showsPicker) ...[
          PaywallPlanPicker(style: style.pickerStyle),
          const SizedBox(height: Spacing.s2),
        ],
        Semantics(
          liveRegion: busyLabel != null,
          label: busyLabel,
          // 48 points. The 60 point size is for the alarm screen only.
          child: AppButton(
            label: label,
            variant: variant,
            isFullWidth: true,
            isLoading: state.isBusy,
            onPressed: isPaused
                ? () => unawaited(cubit.checkAgain())
                : state.canBuy
                ? () => unawaited(cubit.buy())
                : null,
          ),
        ),
      ],
    );
  }
}

/// What the store charges and, for Hosted, when it charges again. Ten
/// points, at most three lines at the default text size. At a larger size
/// it scrolls inside its own box, so the button never leaves the screen.
class _LegalLines extends StatelessWidget {
  const _LegalLines({required this.product, required this.color});

  final PaywallProduct product;
  final Color color;

  static const double _fontSize = 10;
  static const double _lineHeight = 1.35;
  static const int _lines = 3;

  @override
  Widget build(BuildContext context) {
    final store = storeAccountLabelFor(Theme.of(context).platform);
    final text = product == PaywallProduct.hosted
        ? LocaleKeys.paywall_renewal_disclosure.tr(namedArgs: {'store': store})
        : LocaleKeys.paywall_kit_legal_pro.tr(namedArgs: {'store': store});
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final line = _fontSize * _lineHeight * scale;
    // Three lines until the text outgrows the block's own limit, then as
    // many whole lines as that room holds, and never under two.
    final lines = math.max(
      2,
      (_lines * math.min(scale, paywallBuyMaxTextScale) / scale).floor(),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: line * lines + 1),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            color,
            fontSize: _fontSize,
          ).copyWith(height: _lineHeight),
        ),
      ),
    );
  }
}

/// Restore, Terms and Privacy on one line, each with a 44 point tap area.
/// With nothing on sale only Restore is left.
class _LinksRow extends StatelessWidget {
  const _LinksRow({required this.state, required this.color});

  final PaywallBuyState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaywallBuyCubit>();
    final isDone = state.status == PaywallBuyStatus.done;
    final onlyRestore = state.status == PaywallBuyStatus.notOnSale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isDone)
          _Link(
            label: LocaleKeys.paywall_restore_purchases_button.tr(),
            color: color,
            onTap: state.canRestore ? () => unawaited(cubit.restore()) : null,
          ),
        if (!onlyRestore) ...[
          _Link(
            label: LocaleKeys.paywall_terms_link.tr(),
            color: color,
            url: termsUrl,
          ),
          _Link(
            label: LocaleKeys.paywall_privacy_link.tr(),
            color: color,
            url: privacyUrl,
          ),
        ],
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.color,
    this.onTap,
    this.url,
  });

  final String label;
  final Color color;
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
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.s2),
              child: Center(
                widthFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.small(shown, fontSize: 11).copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1,
                      decoration: TextDecoration.underline,
                      decorationColor: shown,
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
