import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/store_account_label.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:critalarm/features/paywall/presentation/widgets/paywall_pitch.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// PaywallScreen matching Crit Alarm design system with RevenueCat.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({this.source = PaywallAnalytics.directSource, super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<PaywallCubit>();
        unawaited(cubit.loadSubscriptionData(source: source));
        return cubit;
      },
      child: const _PaywallScreenContent(),
    );
  }
}

class _PaywallScreenContent extends StatelessWidget {
  const _PaywallScreenContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<PaywallCubit, PaywallState>(
      listener: (context, state) {
        if (state.feedbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              content: Center(
                child: AppToast(
                  message: state.feedbackMessage,
                  variant: AppToastVariant.ack,
                ),
              ),
            ),
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              content: Center(
                child: AppToast(
                  message: state.errorMessage,
                  variant: AppToastVariant.crit,
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<PaywallCubit>();

        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                AppSliverTopBar(
                  title: LocaleKeys.paywall_title.tr(),
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.paywall_back_aria_label.tr(),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: Spacing.s2),
                      AppStage(
                        faceState: state.isPro
                            ? FaceState.calm
                            : FaceState.acked,
                        faceSize: 140,
                        word: LocaleKeys.paywall_stage_word.tr(),
                        wordFontSize: 36,
                        sub: _stageSub(state),
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          Spacing.s2,
                          24,
                          0,
                        ),
                      ),
                      const SizedBox(height: Spacing.s4),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        16,
                      ),
                      child: AppSheet(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PaywallPitch(variant: state.variant),
                            const SizedBox(height: 20),
                            if (state.isPro) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.highlight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      LocaleKeys.paywall_active_title.tr(),
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      LocaleKeys.paywall_active_subtitle.tr(),
                                      style: TextStyle(
                                        color: colors.ink2,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Text(
                                LocaleKeys.paywall_select_plan_header.tr(),
                                style: TextStyle(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _TierCard(
                                title: SubscriptionTier.yearly.displayName,
                                duration: SubscriptionTier.yearly.durationName,
                                badge: LocaleKeys.paywall_badge_best_value.tr(),
                                price: _getPriceString(
                                  state,
                                  SubscriptionTier.yearly,
                                  fallback: r'$39.99',
                                ),
                                isSelected:
                                    state.selectedTier ==
                                    SubscriptionTier.yearly,
                                onTap: () =>
                                    cubit.selectTier(SubscriptionTier.yearly),
                              ),
                              const SizedBox(height: 8),
                              _TierCard(
                                title: SubscriptionTier.monthly.displayName,
                                duration: SubscriptionTier.monthly.durationName,
                                price: _getPriceString(
                                  state,
                                  SubscriptionTier.monthly,
                                  fallback: r'$4.99',
                                ),
                                isSelected:
                                    state.selectedTier ==
                                    SubscriptionTier.monthly,
                                onTap: () =>
                                    cubit.selectTier(SubscriptionTier.monthly),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                12,
                Spacing.s5,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isPro)
                    AppButton(
                      label: LocaleKeys.paywall_manage_subscription_button.tr(),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      onPressed: cubit.presentCustomerCenter,
                    )
                  else
                    AppButton(
                      label: LocaleKeys.paywall_upgrade_button.tr(),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      isLoading: state.status == PaywallStatus.loading,
                      onPressed: cubit.upgradeToPro,
                    ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: LocaleKeys.paywall_restore_purchases_button.tr(),
                    variant: AppButtonVariant.ghost,
                    isFullWidth: true,
                    isLoading:
                        state.status == PaywallStatus.loading &&
                        state.feedbackMessage == null,
                    onPressed: cubit.restorePurchases,
                  ),
                  const SizedBox(height: 8),
                  const _RenewalDisclosure(),
                  const SizedBox(height: 8),
                  const _LegalLinksRow(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _getPriceString(
    PaywallState state,
    SubscriptionTier tier, {
    required String fallback,
  }) {
    final currentOffering = state.offerings?.current;
    if (currentOffering != null) {
      switch (tier) {
        case SubscriptionTier.yearly:
          final p = currentOffering.annual;
          if (p != null) {
            return p.storeProduct.priceString;
          }
        case SubscriptionTier.monthly:
          final p = currentOffering.monthly;
          if (p != null) {
            return p.storeProduct.priceString;
          }
      }
    }
    return fallback;
  }

  /// The line under the word on the stage. Only the one job layout needs one;
  /// the others say it in the pitch right below and would repeat themselves.
  static String? _stageSub(PaywallState state) {
    if (state.isPro) {
      return LocaleKeys.paywall_stage_sub_active.tr();
    }
    return state.variant == PaywallVariant.oneJob
        ? LocaleKeys.paywall_stage_sub_one_job.tr()
        : null;
  }
}

/// What the store charges and when it charges again. App Store review
/// guideline 3.1.2 wants this on the screen that sells the subscription, not
/// one tap away.
class _RenewalDisclosure extends StatelessWidget {
  const _RenewalDisclosure();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Text(
      LocaleKeys.paywall_renewal_disclosure.tr(
        namedArgs: {'store': storeAccountLabelFor(Theme.of(context).platform)},
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 11,
        height: 1.35,
        color: colors.ink3,
      ),
    );
  }
}

/// Terms and Privacy, small and muted under the purchase buttons. App Store
/// review guideline 3.1.2 wants both reachable from the screen that sells the
/// subscription.
class _LegalLinksRow extends StatelessWidget {
  const _LegalLinksRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegalLink(
          label: LocaleKeys.paywall_terms_link.tr(),
          url: termsUrl,
        ),
        const SizedBox(width: 16),
        _LegalLink(
          label: LocaleKeys.paywall_privacy_link.tr(),
          url: privacyUrl,
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$label: $url',
      button: true,
      child: GestureDetector(
        onTap: () => unawaited(
          launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            color: colors.ink3,
            decoration: TextDecoration.underline,
            decorationColor: colors.ink3,
          ),
        ),
      ),
    );
  }
}

/// One plan row. The billed amount is the biggest thing in it, because App
/// Store review guideline 3.1.2 asks for the amount that will actually be
/// charged to be the most prominent price element.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.duration,
    required this.price,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String duration;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.cream : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.highlight : colors.hairline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.highlight : colors.ink3,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.highlight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: colors.onHighlight,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration,
                    style: TextStyle(
                      color: colors.ink3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: TextStyle(
                color: colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
