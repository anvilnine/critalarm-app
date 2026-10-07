import 'dart:async';

import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Home says once that the phone was updated and offers a test alarm.
///
/// The card is drawn in Home's notice slot. `InAppNoticeCubit` decides when
/// it shows. Closing it, or tapping the button, keeps it off Home until the
/// phone gets another update. It rings nothing: the button opens the test
/// alarm screen, where the user starts the test.
class SystemUpdateNoticeCard extends StatelessWidget {
  const SystemUpdateNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<InAppNoticeCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, Spacing.s3, 12, 0),
      child: AppHighlightCard(
        tone: AppHighlightTone.choice,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                  child: FaceWidget(state: FaceState.curious, size: 32),
                ),
                const SizedBox(width: Spacing.s3),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      LocaleKeys.notices_system_update_title.tr(),
                      style: AppTypography.body(
                        colors.onCanvas,
                      ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ),
                AppIconButton(
                  glyph: GlyphType.close,
                  ariaLabel: LocaleKeys.notices_system_update_dismiss.tr(),
                  glyphSize: 14,
                  color: colors.onCanvasMuted,
                  onPressed: () => unawaited(cubit.dismissCurrent()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LocaleKeys.notices_system_update_body.tr(),
                    style: AppTypography.small(colors.onCanvasMuted),
                  ),
                  const SizedBox(height: Spacing.s3),
                  AppButton(
                    label: LocaleKeys.notices_system_update_button.tr(),
                    size: AppButtonSize.sm,
                    isFullWidth: true,
                    onPressed: () async {
                      // Asked once, so the card is done as soon as it is
                      // acted on. The Reliability screen still lists the
                      // check until a test rings.
                      unawaited(cubit.dismissCurrent());
                      await context.pushNamed<void>(AppRoute.testRing);
                    },
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
