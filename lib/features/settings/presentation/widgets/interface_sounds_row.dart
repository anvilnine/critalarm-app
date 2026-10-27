import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/ui_sound/interface_sounds_setting.dart';
import 'package:critalarm/core/ui_sound/playing_paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The Interface sounds switch. Drawn only where the build can play them, so
/// the web shows nothing to switch.
class InterfaceSoundsRow extends StatelessWidget {
  const InterfaceSoundsRow({super.key});

  @override
  Widget build(BuildContext context) {
    if (!platformPlaysUiSounds(getIt<PlatformCapabilities>())) {
      return const SizedBox.shrink();
    }
    final setting = getIt<InterfaceSoundsSetting>();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ValueListenableBuilder<bool>(
        valueListenable: setting.listenable,
        builder: (context, isOn, _) => AppToggleRow(
          title: LocaleKeys.paywall_sounds_settings_title.tr(),
          subtitle: LocaleKeys.paywall_sounds_settings_subtitle.tr(),
          value: isOn,
          onChanged: (value) {
            unawaited(setting.set(isOn: value));
            AppHaptics.selection();
          },
        ),
      ),
    );
  }
}
