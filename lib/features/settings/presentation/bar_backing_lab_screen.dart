import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/device/dev_bar_backing_switch.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/bar_backing.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Developer options: tune what is drawn behind the top bar and the pinned
/// bottom bar while a row is scrolled under them.
///
/// Every change goes through [DevBarBackingSwitch], which redraws every
/// screen at once and keeps the choice on the phone. The page is long and
/// has a pinned button of its own, so both bars can be judged right here.
class BarBackingLabScreen extends StatelessWidget {
  const BarBackingLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final backing = getIt<DevBarBackingSwitch>();

    return ValueListenableBuilder<BarBackingConfig>(
      valueListenable: backing,
      builder: (context, config, _) => AppBarBackingScope(
        // The canvas this page sits on, with the pinned bar backed too.
        color: AppBarBackingScope.maybeOf(context)?.color ?? colors.canvas,
        coversBottomBar: true,
        child: AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.settings_developer_bar_backing_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings/developer');
                }
              },
            ),
          ),
          bottomBar: AppButton(
            label: LocaleKeys.settings_developer_bar_backing_reset.tr(),
            variant: AppButtonVariant.tinted,
            isFullWidth: true,
            onPressed: backing.isOverridden
                ? () => unawaited(backing.reset())
                : null,
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, Spacing.s3),
                      child: Text(
                        LocaleKeys.settings_developer_bar_backing_note.tr(),
                        style: AppTypography.small(colors.onCanvasMuted),
                      ),
                    ),
                    _StyleCard(
                      title: LocaleKeys.settings_developer_bar_backing_top.tr(),
                      style: config.top,
                      onChanged: (style) => unawaited(
                        backing.setConfig(config.copyWith(top: style)),
                      ),
                    ),
                    const SizedBox(height: Spacing.s3),
                    _StyleCard(
                      title: LocaleKeys.settings_developer_bar_backing_bottom
                          .tr(),
                      style: config.bottom,
                      onChanged: (style) => unawaited(
                        backing.setConfig(config.copyWith(bottom: style)),
                      ),
                    ),
                    const SizedBox(height: Spacing.s3),
                    // Something to scroll under the bars.
                    AppSheet(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var row = 1; row <= 12; row++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                LocaleKeys.settings_developer_bar_backing_sample
                                    .tr(args: ['$row']),
                                style: AppTypography.body(colors.ink),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar's mode and its three numbers.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.title,
    required this.style,
    required this.onChanged,
  });

  final String title;
  final BarBackingStyle style;
  final ValueChanged<BarBackingStyle> onChanged;

  static String _modeLabel(BarBackingMode mode) => switch (mode) {
    BarBackingMode.blur =>
      LocaleKeys.settings_developer_bar_backing_mode_blur.tr(),
    BarBackingMode.blurAndGradient =>
      LocaleKeys.settings_developer_bar_backing_mode_blur_and_gradient.tr(),
    BarBackingMode.gradient =>
      LocaleKeys.settings_developer_bar_backing_mode_gradient.tr(),
    BarBackingMode.solid =>
      LocaleKeys.settings_developer_bar_backing_mode_solid.tr(),
    BarBackingMode.none =>
      LocaleKeys.settings_developer_bar_backing_mode_none.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          for (final mode in BarBackingMode.values) ...[
            AppListRow(
              name: _modeLabel(mode),
              meta: '',
              faceState: null,
              trailing: mode == style.mode
                  ? AppGlyph(GlyphType.check, color: colors.highlight, size: 16)
                  : null,
              onTap: () => onChanged(style.copyWith(mode: mode)),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 8),
          _NumberSlider(
            label: LocaleKeys.settings_developer_bar_backing_blur.tr(),
            value: style.blurSigma,
            max: BarBackingStyle.maxBlurSigma,
            divisions: 80,
            decimals: 1,
            onChanged: (v) => onChanged(style.copyWith(blurSigma: v)),
          ),
          _NumberSlider(
            label: LocaleKeys.settings_developer_bar_backing_fade.tr(),
            value: style.fadeLength,
            max: BarBackingStyle.maxFadeLength,
            divisions: 96,
            decimals: 0,
            onChanged: (v) => onChanged(style.copyWith(fadeLength: v)),
          ),
          _NumberSlider(
            label: LocaleKeys.settings_developer_bar_backing_peak.tr(),
            value: style.gradientPeak,
            max: 1,
            divisions: 100,
            decimals: 2,
            onChanged: (v) => onChanged(style.copyWith(gradientPeak: v)),
          ),
        ],
      ),
    );
  }
}

/// A slider from 0 to [max] with its label and the number it is on.
class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.decimals,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final int divisions;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final number = value.toStringAsFixed(decimals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: AppTypography.small(colors.ink2)),
            ),
            Text(number, style: AppTypography.mono(colors.ink, fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primary,
            thumbColor: colors.primary,
            inactiveTrackColor: colors.hairline,
          ),
          child: Slider(
            value: value,
            max: max,
            divisions: divisions,
            label: number,
            semanticFormatterCallback: (_) => '$label $number',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
