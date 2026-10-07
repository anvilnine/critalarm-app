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
    final cubit = context.read<InAppNoticeCubit>();

    return AppNoticeCard(
      face: needsLookFace,
      title: LocaleKeys.weekly_check_notice_title.tr(),
      lines: [LocaleKeys.weekly_check_notice_body.tr()],
      actionLabel: LocaleKeys.weekly_check_notice_button.tr(),
      onAction: () => unawaited(context.pushNamed<void>(AppRoute.testRing)),
      onDismiss: () => unawaited(cubit.dismissCurrent()),
      dismissLabel: LocaleKeys.weekly_check_notice_dismiss.tr(),
    );
  }
}
