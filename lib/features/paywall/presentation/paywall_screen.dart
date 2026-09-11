import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// PaywallScreen matching docs/design-system/index.html mobile mockup.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PaywallCubit>(),
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
                const SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: Spacing.s2),
                      AppStage(
                        faceState: FaceState.acked,
                        faceSize: 140,
                        word: 'Crit Alarm Pro',
                        wordFontSize: 36,
                        sub:
                            'Never miss a 3am page. '
                            'Full critical repeat loop and escalation.',
                        padding: EdgeInsets.fromLTRB(24, Spacing.s2, 24, 0),
                      ),
                      SizedBox(height: Spacing.s4),
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
                            AppButton(
                              label: 'Upgrade to Pro',
                              size: AppButtonSize.lg,
                              isFullWidth: true,
                              isLoading:
                                  state.status == PaywallStatus.loading &&
                                  state.feedbackMessage == null,
                              onPressed: cubit.upgradeToPro,
                            ),
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'Restore Purchases',
                              variant: AppButtonVariant.ghost,
                              isFullWidth: true,
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
}
