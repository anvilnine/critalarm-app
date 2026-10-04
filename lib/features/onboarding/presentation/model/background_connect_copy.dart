import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// The one line that says where a connect running behind the user stands.
///
/// Null when there is nothing to say: no connect was asked for.
String? backgroundConnectLine(BackgroundConnectState state) {
  return switch (state.status) {
    BackgroundConnectStatus.idle => null,
    BackgroundConnectStatus.connecting =>
      LocaleKeys.onboarding_connect_background_connecting.tr(),
    BackgroundConnectStatus.waitingForNetwork =>
      LocaleKeys.onboarding_connect_background_waiting_network.tr(),
    BackgroundConnectStatus.waitingForPushToken =>
      LocaleKeys.onboarding_connect_background_waiting_push.tr(),
    BackgroundConnectStatus.connected =>
      LocaleKeys.onboarding_connect_background_connected.tr(),
    BackgroundConnectStatus.failed => switch (state.failure) {
      BackgroundConnectFailure.versionUnsupported =>
        LocaleKeys.onboarding_connect_background_failed_version.tr(
          namedArgs: {'version': state.serverVersion ?? ''},
        ),
      BackgroundConnectFailure.needsAdminToken =>
        LocaleKeys.onboarding_connect_background_failed_admin_token.tr(),
      BackgroundConnectFailure.refused ||
      null => LocaleKeys.onboarding_connect_background_failed_refused.tr(),
    },
  };
}
