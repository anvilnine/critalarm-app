import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Critical blocker notice displayed on the home page when onboarding server
/// configuration was skipped or no server is connected.
class NoServerNoticeCard extends StatelessWidget {
  const NoServerNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNoticeCard(
      face: FaceState.worried,
      title: LocaleKeys.notices_no_server_title.tr(),
      lines: [LocaleKeys.notices_no_server_body.tr()],
      actionLabel: LocaleKeys.notices_no_server_button.tr(),
      // The connect screen closes back to Home. Ask again then, so a user
      // who just connected is not told they have no server.
      onAction: () async {
        final notices = context.read<InAppNoticeCubit?>();
        await GoRouter.of(
          context,
        ).push<void>(OnboardingEntryPoint.connectServer);
        if (notices != null && !notices.isClosed) {
          await notices.refresh();
        }
      },
    );
  }
}
