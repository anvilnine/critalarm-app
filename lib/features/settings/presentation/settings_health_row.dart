import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// What the Health row on Settings says about the device permissions.
///
/// It lives apart from the widget so it can be unit tested. The screen used to
/// hardcode a worried face and "1 issue" whatever the real state was, so
/// granting everything still read as broken.
@immutable
class SettingsHealthRow {
  const SettingsHealthRow._({
    required this.isHealthy,
    required this.faceState,
    required this.issueCount,
    required this.subtitle,
  });

  factory SettingsHealthRow.from(ShellHealth health) {
    if (health.isHealthy) {
      return SettingsHealthRow._(
        isHealthy: true,
        faceState: FaceState.calm,
        issueCount: 0,
        subtitle: LocaleKeys.settings_health_row_subtitle_ok.tr(),
      );
    }

    final missing = health.missing;
    return SettingsHealthRow._(
      isHealthy: false,
      faceState: health.hasWarningsOnly
          ? FaceState.watching
          : FaceState.worried,
      issueCount: missing.length,
      // Same wording as the notice on Home, so the two never disagree.
      subtitle: missing.length == 1
          ? LocaleKeys.setup_health_banner_one.tr(
              namedArgs: {'name': missing.first.title},
            )
          : LocaleKeys.setup_health_banner_many.tr(
              namedArgs: {'count': '${missing.length}'},
            ),
    );
  }

  final bool isHealthy;
  final FaceState faceState;
  final int issueCount;
  final String subtitle;
}
