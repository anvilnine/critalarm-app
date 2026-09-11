import 'dart:async';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
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
                  title: 'Crit Alarm Pro',
                  leading: AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: 'Back',
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
                        word: state.isPro ? 'Pro Active' : 'Crit Alarm Pro',
                        wordFontSize: 36,
                        sub: state.isPro
                            ? 'Your device is fully protected. '
                                  'Unlimited critical alarms unlocked.'
                            : 'Never miss a 3am page. '
                                  'Full repeat loop and escalation.',
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
                            const AppFeatureBullet(
                              text: 'Bypasses silent mode and Do Not Disturb',
                              glyph: GlyphType.bell,
                            ),
                            const SizedBox(height: 12),
                            const AppFeatureBullet(
                              text: 'Repeats every 30 s until acknowledged',
                              glyph: GlyphType.repeat,
                            ),
                            const SizedBox(height: 12),
                            const AppFeatureBullet(
                              text: 'Escalates to phone call after 5 minutes',
                              glyph: GlyphType.arrow,
                            ),
                            const SizedBox(height: 12),
                            const AppFeatureBullet(
                              text: 'Unlimited critical topics',
                            ),
                            const SizedBox(height: 18),
                            const AppNote(
                              text:
                                  'Running on your own infrastructure? '
                                  'Self-hosted server includes all critical '
                                  'alerts 100% free.',
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
                                      'Crit Alarm Pro is Active',
                                      style: TextStyle(
                                        color: colors.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Thank you for supporting Crit Alarm!',
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
                                label: 'Manage Subscription',
                                size: AppButtonSize.lg,
                                isFullWidth: true,
                                onPressed: cubit.presentCustomerCenter,
                              ),
                            ] else ...[
                              Text(
                                'Select Plan',
                                style: TextStyle(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _TierCard(
                                tier: SubscriptionTier.yearly,
                                title: 'Yearly',
                                badge: 'Best Value',
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.yearly,
                                  fallback: r'$19.99 / year',
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
                                title: 'Monthly',
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.monthly,
                                  fallback: r'$2.99 / month',
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
                                title: 'Lifetime',
                                priceDescription: _getPriceString(
                                  state,
                                  SubscriptionTier.lifetime,
                                  fallback: r'$49.99 one-time',
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
                                label:
                                    'Upgrade to Pro '
                                    '(${state.selectedTier.displayName})',
                                size: AppButtonSize.lg,
                                isFullWidth: true,
                                isLoading:
                                    state.status == PaywallStatus.loading,
                                onPressed: cubit.upgradeToPro,
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'Present RevenueCat Paywall',
                                variant: AppButtonVariant.ghost,
                                isFullWidth: true,
                                onPressed: cubit.presentNativePaywall,
                              ),
                            ],
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'Restore Purchases',
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
          if (p != null) return '${p.storeProduct.priceString} / year';
        case SubscriptionTier.monthly:
          final p = currentOffering.monthly;
          if (p != null) return '${p.storeProduct.priceString} / month';
        case SubscriptionTier.lifetime:
          final p = currentOffering.lifetime;
          if (p != null) return '${p.storeProduct.priceString} one-time';
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
