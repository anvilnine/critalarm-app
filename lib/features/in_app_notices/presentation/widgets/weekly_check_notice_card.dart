import 'dart:async';

import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Home says that weekly checks stopped arriving on this phone.
///
/// The card is drawn in Home's notice slot. `InAppNoticeCubit` decides when
/// it shows: two rounds missed in a row, by the relay's count or by this
/// phone's own clock. Closing it keeps it off Home until a check arrives
/// and a later run of misses begins. The card says what happened in its
/// title and the next step in its body. The button opens the test alarm
/// screen, where the person starts the test, and closes nothing. It is a
/// card: it rings nothing and posts no notification.
class WeeklyCheckNoticeCard extends StatelessWidget {
  const WeeklyCheckNoticeCard({super.key});

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
                  child: FaceWidget(state: FaceState.shakeHead, size: 32),
                ),
                const SizedBox(width: Spacing.s3),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      LocaleKeys.weekly_check_notice_title.tr(),
                      style: AppTypography.body(
                        colors.onCanvas,
                      ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ),
                AppIconButton(
                  glyph: GlyphType.close,
                  ariaLabel: LocaleKeys.weekly_check_notice_dismiss.tr(),
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
                    LocaleKeys.weekly_check_notice_body.tr(),
                    style: AppTypography.small(colors.onCanvasMuted),
                  ),
                  const SizedBox(height: Spacing.s3),
                  AppButton(
                    label: LocaleKeys.weekly_check_notice_button.tr(),
                    size: AppButtonSize.sm,
                    isFullWidth: true,
                    onPressed: () =>
                        unawaited(context.pushNamed<void>(AppRoute.testRing)),
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
