import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/device/fold_division_switches.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/developer_options_group.dart';
import 'package:flutter/material.dart';

/// Whether this build and this platform show the fold switches: a build
/// with Developer options, where a hinge can exist.
bool developerFoldIsShown() =>
    getIt<PlatformCapabilities>().canEmulateFoldDivision &&
    getIt.isRegistered<DevFoldDivisionSwitches>();

/// The fold switches of developer settings. They make a foldable render the
/// app as an iPhone Duo does (its window size, its safe area and its fold),
/// so iPhone Duo layouts can be checked on it.
///
/// Plain English, like the Plans and features lab: it only exists in a
/// build that has Developer options.
class DeveloperFoldSection extends StatelessWidget {
  const DeveloperFoldSection({super.key});

  @override
  Widget build(BuildContext context) {
    final switches = getIt<DevFoldDivisionSwitches>();
    return ListenableBuilder(
      listenable: switches,
      builder: (context, _) => DeveloperOptionsGroup(
        title: 'Folding display', // l10n-ok: developer option
        rows: [
          AppToggleRow(
            title: 'Render as an iPhone Duo', // l10n-ok: developer option
            subtitle:
                'Lay the app out in the iPhone Duo window, with its safe '
                'area and its fold', // l10n-ok: developer option
            value: switches.isOn,
            onChanged: (val) => unawaited(switches.setOn(isOn: val)),
          ),
          AppToggleRow(
            title:
                'Match the iPhone Duo screen '
                'size', // l10n-ok: developer option
            subtitle:
                'Off keeps the real screen size and takes the safe area '
                'only', // l10n-ok: developer option
            value: switches.matchesWindowSize,
            onChanged: (val) => unawaited(
              switches.setMatchesWindowSize(matchesWindowSize: val),
            ),
          ),
          AppToggleRow(
            title:
                'Keep the division on a flat '
                'device', // l10n-ok: developer option
            value: switches.staysOnFlat,
            onChanged: (val) =>
                unawaited(switches.setStaysOnFlat(staysOnFlat: val)),
          ),
          AppToggleRow(
            title: 'Show the division overlay', // l10n-ok: developer option
            value: switches.showsOverlay,
            onChanged: (val) =>
                unawaited(switches.setShowsOverlay(showsOverlay: val)),
          ),
        ],
      ),
    );
  }
}
