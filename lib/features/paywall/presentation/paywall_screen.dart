import 'dart:async';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// PaywallScreen matching Crit Alarm design system with RevenueCat.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<PaywallCubit>();
        unawaited(cubit.loadSubscriptionData());
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
        final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                        word: state.isPro
                            ? LocaleKeys.paywall_stage_word_pro_active.tr()
                            : LocaleKeys.paywall_stage_word_pro.tr(),
                        wordFontSize: 36,
                        sub: state.isPro
                            ? LocaleKeys.paywall_stage_sub_pro_active.tr()
                            : LocaleKeys.paywall_stage_sub_pro.tr(),
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
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        16 + bottomInset,
                      ),
                      child: AppSheet(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppFeatureBullet(
                              text: LocaleKeys.paywall_feature_rings_until_ack
                                  .tr(),
                              glyph: GlyphType.bell,
                            ),
                            const SizedBox(height: 12),
                            AppFeatureBullet(
                              text: LocaleKeys.paywall_feature_repeat_loop.tr(),
                              glyph: GlyphType.repeat,
                            ),
                            const SizedBox(height: 12),
                            AppFeatureBullet(
                              text: LocaleKeys.paywall_feature_escalate_call
                                  .tr(),
                              glyph: GlyphType.arrow,
                            ),
                            const SizedBox(height: 12),
                            AppFeatureBullet(
                              text: LocaleKeys.paywall_feature_unlimited_topics
                                  .tr(),
                            ),
                            const SizedBox(height: 18),
                            AppNote(
                              text: LocaleKeys.paywall_self_hosted_note.tr(),
                            ),
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
                              const SizedBox(height: 16),
                              AppButton(
                                label: LocaleKeys
                                    .paywall_manage_subscription_button
                                    .tr(),
                                size: AppButtonSize.lg,
                                isFullWidth: true,
                                onPressed: cubit.presentCustomerCenter,
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
                                tier: SubscriptionTier.yearly,
                                title: LocaleKeys.paywall_tier_yearly.tr(),
                                badge: LocaleKeys.paywall_badge_best_value.tr(),
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.yearly,
                                  fallback: LocaleKeys.paywall_price_yearly.tr(
                                    namedArgs: {'price': r'$19.99'},
                                  ),
                                ),
                                isSelected:
                                    state.selectedTier ==
                                    SubscriptionTier.yearly,
                                onTap: () =>
                                    cubit.selectTier(SubscriptionTier.yearly),
                              ),
                              const SizedBox(height: 8),
                              _TierCard(
                                tier: SubscriptionTier.monthly,
                                title: LocaleKeys.paywall_tier_monthly.tr(),
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.monthly,
                                  fallback: LocaleKeys.paywall_price_monthly.tr(
                                    namedArgs: {'price': r'$2.99'},
                                  ),
                                ),
                                isSelected:
                                    state.selectedTier ==
                                    SubscriptionTier.monthly,
                                onTap: () =>
                                    cubit.selectTier(SubscriptionTier.monthly),
                              ),
                              const SizedBox(height: 8),
                              _TierCard(
                                tier: SubscriptionTier.lifetime,
                                title: LocaleKeys.paywall_tier_lifetime.tr(),
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.lifetime,
                                  fallback: LocaleKeys.paywall_price_lifetime
                                      .tr(
                                        namedArgs: {'price': r'$49.99'},
                                      ),
                                ),
                                isSelected:
                                    state.selectedTier ==
                                    SubscriptionTier.lifetime,
                                onTap: () => cubit.selectTier(
                                  SubscriptionTier.lifetime,
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                label: LocaleKeys.paywall_upgrade_button.tr(
                                  namedArgs: {
                                    'tier': state.selectedTier.displayName,
                                  },
                                ),
                                size: AppButtonSize.lg,
                                isFullWidth: true,
                                isLoading:
                                    state.status == PaywallStatus.loading,
                                onPressed: cubit.upgradeToPro,
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                label: LocaleKeys.paywall_present_paywall_button
                                    .tr(),
                                variant: AppButtonVariant.ghost,
                                isFullWidth: true,
                                onPressed: cubit.presentNativePaywall,
                              ),
                            ],
                            const SizedBox(height: 10),
                            AppButton(
                              label: LocaleKeys.paywall_restore_purchases_button
                                  .tr(),
                              variant: AppButtonVariant.ghost,
                              isFullWidth: true,
                              isLoading:
                                  state.status == PaywallStatus.loading &&
                                  state.feedbackMessage == null,
                              onPressed: cubit.restorePurchases,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
            return LocaleKeys.paywall_price_yearly.tr(
              namedArgs: {'price': p.storeProduct.priceString},
            );
          }
        case SubscriptionTier.monthly:
          final p = currentOffering.monthly;
          if (p != null) {
            return LocaleKeys.paywall_price_monthly.tr(
              namedArgs: {'price': p.storeProduct.priceString},
            );
          }
        case SubscriptionTier.lifetime:
          final p = currentOffering.lifetime;
          if (p != null) {
            return LocaleKeys.paywall_price_lifetime.tr(
              namedArgs: {'price': p.storeProduct.priceString},
            );
          }
      }
    }
    return fallback;
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.title,
    required this.priceDescription,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final SubscriptionTier tier;
  final String title;
  final String priceDescription;
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
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                    priceDescription,
                    style: TextStyle(
                      color: colors.ink2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
