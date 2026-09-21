import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_import.dart';
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
    'sourceTooLong' => LocaleKeys.sound_picker_error_source_too_long.tr(),
    'tooLarge' => LocaleKeys.sound_picker_error_too_large.tr(
      namedArgs: {
        'megabytes': '${SoundImportLimits.maxSourceBytes ~/ (1024 * 1024)}',
      },
    ),
    'unsupportedFormat' => LocaleKeys.sound_picker_error_unsupported.tr(),
    'unreadable' => LocaleKeys.sound_picker_error_unreadable.tr(),
    _ => LocaleKeys.sound_picker_error_copy_failed.tr(),
  };

  /// Pick a file, crop it, then read the list again. The cropper pops with
  /// a future for a save that may still be running, so a sound saved after
  /// the user left the cropper still shows up.
  static Future<void> _pickAndCrop(BuildContext context) async {
    final cubit = context.read<SoundPickerCubit>();
    await cubit.stopPreview();
    final file = await cubit.pickFile();
    if (file == null || !context.mounted) return;
    final result = await context.pushNamed<Object?>(
      AppRoute.soundCrop,
      extra: file,
    );
    await cubit.reloadAfterCrop(result is Future<void> ? result : null);
  }

  /// Record a clip, crop it, then read the list again. The recorder pops
  /// with the file and the list opens the cropper, so back from the cropper
  /// comes here, not to the recorder.
  static Future<void> _recordAndCrop(BuildContext context) async {
    final cubit = context.read<SoundPickerCubit>();
    await cubit.stopPreview();
    if (!context.mounted) return;
    final file = await context.pushNamed<Object?>(AppRoute.soundRecord);
    if (file is! PickedSoundFile || !context.mounted) return;
    final result = await context.pushNamed<Object?>(
      AppRoute.soundCrop,
      extra: file,
    );
    await cubit.reloadAfterCrop(result is Future<void> ? result : null);
  }

  static AlarmSound? selectedSound(SoundPickerState state) {
    for (final sound in [...state.bundled, ...state.userSounds]) {
      if (sound.id == state.selectedSoundId) return sound;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
        final colors = context.appColors;
        final cubit = context.read<SoundPickerCubit>();
        final selectedName = selectedSound(state)?.name ?? '';
        final content = AppScreenScaffold(
          topBar: AppTopBar(
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
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
                          if (state.userSounds.isNotEmpty ||
                              state.capabilities.canImportSounds) ...[
                            const SizedBox(height: Spacing.s3),
                            SectionCard(
                              title: LocaleKeys.sound_picker_user_header.tr(),
                              trailing: Text(
                                LocaleKeys.sound_picker_user_local_only.tr(),
                                style: TextStyle(
                                  fontFamily: AppTypography.fontMono,
                                  fontFamilyFallback:
                                      AppTypography.fontMonoFallbacks,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink3,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final sound in state.userSounds)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
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
                                  if (state.capabilities.canImportSounds) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppButton(
                                            label: LocaleKeys
                                                .sound_picker_pick_file
                                                .tr(),
                                            variant: AppButtonVariant.ghost,
                                            isFullWidth: true,
                                            icon: AppGlyph(
                                              GlyphType.plus,
                                              size: 16,
                                              color: colors.onCanvas,
                                            ),
                                            onPressed: () {
                                              AppHaptics.capture();
                                              unawaited(_pickAndCrop(context));
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AppButton(
                                            label: LocaleKeys
                                                .sound_picker_record
                                                .tr(),
                                            variant: AppButtonVariant.ghost,
                                            isFullWidth: true,
                                            icon: AppGlyph(
                                              GlyphType.record,
                                              size: 16,
                                              color: colors.crit,
                                            ),
                                            onPressed: () {
                                              AppHaptics.capture();
                                              unawaited(
                                                _recordAndCrop(context),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
                                context.go('/');
                              }
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );

        return content;
      },
    );
  }
}

class _SoundRow extends StatefulWidget {
  const _SoundRow({required this.sound, required this.state});

  final AlarmSound sound;
  final SoundPickerState state;

  @override
  State<_SoundRow> createState() => _SoundRowState();
}

/// Owns the preview progress. The platform does not report where playback
/// is, so the ring and the bars run off the sound's length, and the cubit
/// clears the row when the platform says the preview ended.
class _SoundRowState extends State<_SoundRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _length,
  );

  Duration get _length => widget.sound.duration > Duration.zero
      ? widget.sound.duration
      : const Duration(seconds: 1);

  bool _previewing(_SoundRow row) =>
      row.state.previewingSoundId == row.sound.id;

  @override
  void initState() {
    super.initState();
    if (_previewing(widget)) unawaited(_progress.forward());
  }

  @override
  void didUpdateWidget(_SoundRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress.duration = _length;
    final was = _previewing(oldWidget);
    final now = _previewing(widget);
    if (now && !was) unawaited(_progress.forward(from: 0));
    if (!now && was) _progress.reset();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SoundPickerCubit>();
    final sound = widget.sound;
    final state = widget.state;
    final isPreviewing = _previewing(widget);
    final isUserSound = sound.source == AlarmSoundSource.user;
    final tooLong =
        isUserSound &&
        SoundImportLimits.tooLongToRing(state.platform, sound.duration);
    final notificationsOnly =
        isUserSound && !state.capabilities.userSoundsRingAlarm;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final progress = isPreviewing ? _progress.value : null;
        return AppRadioRow(
          title: sound.name,
          meta: _SoundPickerView.formatLength(sound.duration),
          note: tooLong
              ? LocaleKeys.sound_picker_row_too_long_ios.tr()
              : notificationsOnly
              ? LocaleKeys.sound_picker_row_notifications_only.tr()
              : null,
          selected: state.selectedSoundId == sound.id,
          leading: AppPreviewButton(
            isPlaying: isPreviewing,
            progress: progress,
            progressLabel: progress == null
                ? null
                : LocaleKeys.sound_picker_preview_progress.tr(
                    namedArgs: {'percent': '${(progress * 100).round()}'},
                  ),
            playLabel: LocaleKeys.sound_picker_play_aria_label.tr(),
            stopLabel: LocaleKeys.sound_picker_stop_aria_label.tr(),
            onPressed: () {
              AppHaptics.selection();
              unawaited(cubit.togglePreview(sound));
            },
          ),
          waveform: WaveformBars(
            peaks: sound.peaks ?? const [],
            progress: progress,
          ),
          onTap: () {
            AppHaptics.selection();
            unawaited(cubit.select(sound.id));
          },
        );
      },
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
