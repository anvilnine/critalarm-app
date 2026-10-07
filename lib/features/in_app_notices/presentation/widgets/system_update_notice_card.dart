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
    final cubit = context.read<InAppNoticeCubit>();

    return AppNoticeCard(
      face: needsLookFace,
      title: LocaleKeys.notices_system_update_title.tr(),
      lines: [LocaleKeys.notices_system_update_body.tr()],
      actionLabel: LocaleKeys.notices_system_update_button.tr(),
      onAction: () async {
        // Asked once, so the card is done as soon as it is acted on. The
        // Reliability screen still lists the check until a test rings.
        unawaited(cubit.dismissCurrent());
        await context.pushNamed<void>(AppRoute.testRing);
      },
      onDismiss: () => unawaited(cubit.dismissCurrent()),
      dismissLabel: LocaleKeys.notices_system_update_dismiss.tr(),
    );
  }
}
