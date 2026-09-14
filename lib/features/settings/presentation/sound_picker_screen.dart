import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design_system/widgets/section_card.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pick the sound an alarm rings with.
///
/// Opened twice: from settings with no topic, which sets the default, and
/// from topic detail with a topic name, which sets that topic only. The
/// choice never leaves the device.
class SoundPickerScreen extends StatelessWidget {
  const SoundPickerScreen({super.key, this.topicName});

  final String? topicName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SoundPickerCubit>();
        unawaited(cubit.load(topicName: topicName));
        return cubit;
      },
      child: const _SoundPickerView(),
    );
  }
}

class _SoundPickerView extends StatelessWidget {
  const _SoundPickerView();

  static String formatLength(Duration d) {
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$seconds';
  }

  static String errorMessage(String code) => switch (code) {
    'tooLong' => LocaleKeys.sound_picker_error_too_long.tr(),
    'tooLarge' => LocaleKeys.sound_picker_error_too_large.tr(),
    'unsupportedFormat' => LocaleKeys.sound_picker_error_unsupported.tr(),
    'unreadable' => LocaleKeys.sound_picker_error_unreadable.tr(),
    _ => LocaleKeys.sound_picker_error_copy_failed.tr(),
  };

  static AlarmSound? selectedSound(SoundPickerState state) {
    for (final sound in [...state.bundled, ...state.userSounds]) {
      if (sound.id == state.selectedSoundId) return sound;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<SoundPickerCubit, SoundPickerState>(
      listenWhen: (was, now) => now.errorCode != null && was.errorCode == null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(errorMessage(state.errorCode!))),
          );
        context.read<SoundPickerCubit>().clearError();
      },
      builder: (context, state) {
        final cubit = context.read<SoundPickerCubit>();
        final selectedName = selectedSound(state)?.name ?? '';
        return AppScreenScaffold(
          topBar: AppTopBar(
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
            title: LocaleKeys.sound_picker_title_default.tr(),
            trailing: state.isPerTopic
                ? AppTopicChip(text: state.topicName!)
                : null,
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: state.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hint(state: state),
                          const SizedBox(height: Spacing.s2),
                          SectionCard(
                            title: LocaleKeys.sound_picker_bundled_header.tr(),
                            child: Column(
                              children: [
                                for (final sound in state.bundled)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _SoundRow(
                                      sound: sound,
                                      state: state,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),
                          SectionCard(
                            title: LocaleKeys.sound_picker_user_header.tr(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (state.userSounds.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      LocaleKeys.sound_picker_user_empty.tr(),
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontBody,
                                        fontFamilyFallback:
                                            AppTypography.fontBodyFallbacks,
                                        fontSize: 13,
                                        color: colors.ink3,
                                      ),
                                    ),
                                  ),
                                for (final sound in state.userSounds)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Dismissible(
                                      key: ValueKey(sound.id),
                                      direction: DismissDirection.endToStart,
                                      background: _DeleteBackground(
                                        color: colors.crit,
                                      ),
                                      onDismissed: (_) {
                                        AppHaptics.destructive();
                                        unawaited(
                                          cubit.deleteUserSound(sound.id),
                                        );
                                      },
                                      child: _SoundRow(
                                        sound: sound,
                                        state: state,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                AppButton(
                                  label: LocaleKeys.sound_picker_add_own.tr(),
                                  variant: AppButtonVariant.ghost,
                                  isFullWidth: true,
                                  icon: AppGlyph(
                                    GlyphType.plus,
                                    size: 16,
                                    color: colors.onCanvas,
                                  ),
                                  onPressed: state.isImporting
                                      ? null
                                      : () {
                                          AppHaptics.capture();
                                          unawaited(cubit.importSound());
                                        },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),
                          AppButton(
                            label: LocaleKeys.sound_picker_use_button.tr(
                              namedArgs: {'name': selectedName},
                            ),
                            isFullWidth: true,
                            onPressed: () {
                              AppHaptics.success();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/settings');
                              }
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The one-line explanation shown when this platform will not ring an alarm
/// with a sound the user brought in.
class _Hint extends StatelessWidget {
  const _Hint({required this.state});

  final SoundPickerState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lines = <String>[
      if (state.isPerTopic) LocaleKeys.sound_picker_topic_hint.tr(),
      if (!state.capabilities.userSoundsRingAlarm)
        LocaleKeys.sound_picker_notifications_only.tr(),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontFamilyFallback: AppTypography.fontBodyFallbacks,
                  fontSize: 12,
                  color: colors.ink3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.sound, required this.state});

  final AlarmSound sound;
  final SoundPickerState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SoundPickerCubit>();
    final isPreviewing = state.previewingSoundId == sound.id;
    final notificationsOnly =
        sound.source == AlarmSoundSource.user &&
        !state.capabilities.userSoundsRingAlarm;

    return AppRadioRow(
      title: sound.name,
      meta: _SoundPickerView.formatLength(sound.duration),
      note: notificationsOnly
          ? LocaleKeys.sound_picker_row_notifications_only.tr()
          : null,
      selected: state.selectedSoundId == sound.id,
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewButton(
            isPlaying: isPreviewing,
            onPressed: () {
              AppHaptics.selection();
              unawaited(cubit.togglePreview(sound));
            },
          ),
          if (isPreviewing) ...[
            const SizedBox(height: 6),
            const _PlayingBadge(),
          ],
        ],
      ),
      onTap: () {
        AppHaptics.selection();
        unawaited(cubit.select(sound.id));
      },
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: isPlaying
          ? LocaleKeys.sound_picker_stop_aria_label.tr()
          : LocaleKeys.sound_picker_play_aria_label.tr(),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlaying ? colors.highlight : colors.surface,
            border: Border.all(color: colors.hairline),
          ),
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: isPlaying ? colors.surface : colors.ink,
          ),
        ),
      ),
    );
  }
}

/// Chip next to the sound row that is currently previewing.
class _PlayingBadge extends StatelessWidget {
  const _PlayingBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.highlight,
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(GlyphType.check, size: 11, color: colors.onHighlight),
          const SizedBox(width: 4),
          Text(
            LocaleKeys.sound_picker_badge_playing.tr(),
            style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontFamilyFallback: AppTypography.fontMonoFallbacks,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.onHighlight,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: color, borderRadius: Radii.mdAll),
      child: Text(
        LocaleKeys.sound_picker_delete.tr(),
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.appColors.onPanel,
        ),
      ),
    );
  }
}
