import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/presentation/maker/maker_guide_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The steps for this phone's maker, a button that opens the nearest
/// settings page, and "I did these".
///
/// The steps are text. Nothing here is a picture of another company's
/// settings. What each step says and where it came from is in
/// `domain/maker/guides/`.
class MakerGuideScreen extends StatelessWidget {
  const MakerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<MakerGuideCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _MakerGuideView(),
    );
  }
}

class _MakerGuideView extends StatelessWidget {
  const _MakerGuideView();

  Future<void> _openMore(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      // No browser to hand it to. The steps are on this page anyway.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<MakerGuideCubit, MakerGuideState>(
      builder: (context, state) {
        final cubit = context.read<MakerGuideCubit>();
        final guide = state.guide;
        return AppScreenScaffold(
          topBar: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: kChromeMaxTextScale),
            ),
            child: AppTopBar(
              title: guide == null ? '' : guide.nameKey.tr(),
              leading: AppIconButton(
                glyph: GlyphType.back,
                ariaLabel: LocaleKeys.maker_guide_back_aria_label.tr(),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/settings/reliability');
                  }
                },
              ),
            ),
          ),
          slivers: [
            if (guide != null) ...[
              SliverToBoxAdapter(
                child: AppStage.horizontal(
                  faceState: state.isDone ? FaceState.proud : FaceState.curious,
                  sub: state.isDone
                      ? LocaleKeys.maker_guide_done_line.tr()
                      : LocaleKeys.maker_guide_stage_line.tr(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 16),
                  child: AppSheet(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < guide.steps.length; i++) ...[
                          _StepRow(number: i + 1, step: guide.steps[i]),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: Spacing.s2),
                        AppButton(
                          label: LocaleKeys.maker_guide_open_settings.tr(),
                          isFullWidth: true,
                          onPressed: () {
                            AppHaptics.capture();
                            unawaited(cubit.openSettings());
                          },
                        ),
                        if (state.outcome == MakerOpenOutcome.appPage ||
                            state.outcome == MakerOpenOutcome.failed)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.s2),
                            child: Text(
                              state.outcome == MakerOpenOutcome.appPage
                                  ? LocaleKeys.maker_guide_opened_app_page.tr()
                                  : LocaleKeys.maker_guide_open_failed.tr(),
                              textAlign: TextAlign.center,
                              style: AppTypography.small(
                                colors.ink3,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const SizedBox(height: Spacing.s2),
                        AppButton(
                          label: state.isDone
                              ? LocaleKeys.maker_guide_not_yet.tr()
                              : LocaleKeys.maker_guide_did_these.tr(),
                          variant: AppButtonVariant.ghost,
                          isFullWidth: true,
                          onPressed: () {
                            AppHaptics.capture();
                            unawaited(
                              state.isDone
                                  ? cubit.markNotDone()
                                  : cubit.markDone(),
                            );
                          },
                        ),
                        const SizedBox(height: Spacing.s2),
                        AppButton(
                          label: LocaleKeys.maker_guide_more_link.tr(),
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          isFullWidth: true,
                          onPressed: () => unawaited(_openMore(guide.moreUrl)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final MakerStep step;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = step.textKey.tr();
    return Semantics(
      container: true,
      label:
          '${LocaleKeys.maker_guide_step_aria.tr(
            namedArgs: {'number': '$number'},
          )}, $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.ash,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.panel,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: AppTypography.monoBold(colors.onPanel, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: Spacing.s3),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  text,
                  style: AppTypography.body(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
