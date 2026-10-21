import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What the screen answers when it closes: ring the test again.
const bool alarmLoudnessRingAgain = true;

/// iPhone only. Opened by "No" under "Loud enough?" after a test alarm.
///
/// An iPhone alarm rings at the Ringtone and Alerts volume, and no app can
/// read or set it. So this is two steps the user does in Settings, a button
/// that opens Settings, and "Ring again". The screen closes with
/// [alarmLoudnessRingAgain] from that button; whoever opened it rings the
/// test again. Back closes it with nothing.
///
/// iOS opens Settings on this app's own page, never on Sounds & Haptics, so
/// a line under the button says how to get there.
class AlarmLoudnessScreen extends StatefulWidget {
  const AlarmLoudnessScreen({super.key, this.openSettings});

  /// Opens Settings. Answers whether it opened. Defaults to the app's own
  /// page in Settings.
  final Future<bool> Function()? openSettings;

  @override
  State<AlarmLoudnessScreen> createState() => _AlarmLoudnessScreenState();
}

enum _Opened { notYet, opened, failed }

class _AlarmLoudnessScreenState extends State<AlarmLoudnessScreen> {
  _Opened _opened = _Opened.notYet;

  Future<bool> _openAppSettings() async {
    try {
      final result = await getIt<DevicePermissionsRepository>()
          .openAppSettings();
      return result.getOrNull() ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  Future<void> _open() async {
    AppHaptics.capture();
    final opened = await (widget.openSettings ?? _openAppSettings)();
    if (!mounted) return;
    setState(() => _opened = opened ? _Opened.opened : _Opened.failed);
  }

  void _close([bool? ringAgain]) {
    if (context.canPop()) {
      context.pop(ringAgain);
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final steps = [
      LocaleKeys.alarm_loudness_step_1.tr(),
      LocaleKeys.alarm_loudness_step_2.tr(),
    ];
    final note = switch (_opened) {
      _Opened.notYet => null,
      _Opened.opened => LocaleKeys.alarm_loudness_opened_note.tr(),
      _Opened.failed => LocaleKeys.alarm_loudness_open_failed.tr(),
    };
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: kChromeMaxTextScale),
        ),
        child: AppTopBar(
          title: LocaleKeys.alarm_loudness_title.tr(),
          leading: AppIconButton(
            glyph: GlyphType.back,
            ariaLabel: LocaleKeys.alarm_loudness_back_aria.tr(),
            onPressed: _close,
          ),
        ),
      ),
      bottomBar: AppButton(
        label: LocaleKeys.alarm_loudness_ring_again.tr(),
        variant: AppButtonVariant.crit,
        isFullWidth: true,
        onPressed: () {
          AppHaptics.capture();
          _close(alarmLoudnessRingAgain);
        },
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AppStage.horizontal(
            faceState: FaceState.determined,
            sub: LocaleKeys.alarm_loudness_line.tr(),
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
                  for (var i = 0; i < steps.length; i++) ...[
                    _StepRow(number: i + 1, text: steps[i]),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: Spacing.s2),
                  AppButton(
                    label: LocaleKeys.alarm_loudness_open_settings.tr(),
                    isFullWidth: true,
                    onPressed: () => unawaited(_open()),
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.s2),
                      // Said when it appears: the result of the button
                      // above, which shows only as text.
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          note,
                          textAlign: TextAlign.center,
                          style: AppTypography.small(colors.ink3, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      container: true,
      label:
          '${LocaleKeys.alarm_loudness_step_aria.tr(
            namedArgs: {'number': '$number'},
          )}, $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: colors.ash, borderRadius: Radii.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The number sits in a fixed circle, so its text stops growing
            // at the chrome limit instead of spilling out of it.
            ExcludeSemantics(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: kChromeMaxTextScale,
                child: Container(
                  width: 28,
                  height: 28,
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
