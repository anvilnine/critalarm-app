import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design_system/widgets/section_card.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
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
    if (!context.mounted) return;
    if (await _openedPaywall(context)) return;
    final file = await cubit.pickFile();
    if (file == null || !context.mounted) return;
    final result = await context.pushNamed<Object?>(
      AppRoute.soundCrop,
      extra: file,
    );
    await cubit.reloadAfterCrop(result is Future<void> ? result : null);
  }

  /// Record a clip, crop it, then read the list again. The recorder turns
  /// into the cropper inside its own route and pops the way the cropper
  /// does, with a future for a save that may still be running.
  static Future<void> _recordAndCrop(BuildContext context) async {
    final cubit = context.read<SoundPickerCubit>();
    await cubit.stopPreview();
    if (!context.mounted) return;
    if (await _openedPaywall(context)) return;
    if (!context.mounted) return;
    final result = await context.pushNamed<Object?>(AppRoute.soundRecord);
    if (result is Future<void>) await cubit.reloadAfterCrop(result);
  }

  /// The gate in front of every way to add or pick an own sound. With own
  /// sounds locked it opens the paywall and answers true, and the caller
  /// does nothing else.
  ///
  /// It waits for the plan to be read first, so a tap right after a cold
  /// start never shows a paywall to someone who holds Pro.
  static Future<bool> _openedPaywall(BuildContext context) async {
    final decision = await context
        .read<SoundPickerCubit>()
        .ownSoundsOnceReady();
    if (!ownSoundsLockedBy(decision)) return false;
    if (!context.mounted) return true;
    await openPaywallFor(context, decision, LockSource.sounds);
    return true;
  }

  /// The sound that really rings for this screen's choice: the saved one,
  /// or what stands in for a locked own sound.
  static AlarmSound? ringingSound(SoundPickerState state) {
    final id = state.ringingSoundId;
    for (final sound in state.allSounds) {
      if (sound.id == id) return sound;
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
        final selectedName = ringingSound(state)?.name ?? '';
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            semanticsLabel: LocaleKeys.common_loading.tr(),
                          ),
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
                          if (state.packs.isNotEmpty) ...[
                            const SizedBox(height: Spacing.s3),
                            SectionCard(
                              title: LocaleKeys.sound_picker_packs_header.tr(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final entry in state.packs) ...[
                                    _PackRow(entry: entry),
                                    // A pack lists its sounds once they
                                    // are on the device.
                                    if (entry.status.state ==
                                        SoundPackState.downloaded)
                                      for (final sound in state.packSounds)
                                        if (entry.pack.contains(sound.id))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: _SoundRow(
                                              sound: sound,
                                              state: state,
                                            ),
                                          ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
    // A pack sound is a file in the app's sound folder, as a user sound is,
    // so it rings the same way.
    final isLocalFile = isUserSound || sound.source == AlarmSoundSource.pack;
    final tooLong =
        isUserSound &&
        SoundImportLimits.tooLongToRing(state.platform, sound.duration);
    final notificationsOnly =
        isLocalFile && !state.capabilities.userSoundsRingAlarm;
    // Listed, and not selectable. A tap opens the paywall. The row is
    // dimmed by hand until the shared lock badge takes this over.
    final isLocked = state.isLocked(sound);
    final ringingName = _SoundPickerView.ringingSound(state)?.name ?? '';
    // With no name to give, the row says it is locked and no more.
    final isLockedChoice =
        isLocked && state.selectedSoundId == sound.id && ringingName.isNotEmpty;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final progress = isPreviewing ? _progress.value : null;
        final row = AppRadioRow(
          title: sound.name,
          meta: _SoundPickerView.formatLength(sound.duration),
          note: isLockedChoice
              ? LocaleKeys.sound_picker_row_locked_chosen.tr(
                  namedArgs: {'name': ringingName},
                )
              : isLocked
              ? LocaleKeys.sound_picker_row_locked.tr()
              : tooLong
              ? LocaleKeys.sound_picker_row_too_long_ios.tr()
              : notificationsOnly
              ? LocaleKeys.sound_picker_row_notifications_only.tr()
              : null,
          // The mark sits on the sound that rings, so a locked own choice
          // shows it on the sound standing in for it.
          selected: state.ringingSoundId == sound.id,
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
          // Only a waveform read from the sound itself. While it loads, or
          // when it cannot be read, the row shows the length and nothing
          // that looks like a waveform but is not one.
          waveform: sound.peaks == null || sound.peaks!.isEmpty
              ? null
              : WaveformBars(peaks: sound.peaks!, progress: progress),
          onTap: () {
            AppHaptics.selection();
            if (isUserSound) {
              // Asked again here, not read off the row: the row may have
              // been drawn before the plan was read.
              unawaited(() async {
                if (await _SoundPickerView._openedPaywall(context)) return;
                await cubit.select(sound.id);
              }());
              return;
            }
            unawaited(cubit.select(sound.id));
          },
        );
        return isLocked ? Opacity(opacity: 0.6, child: row) : row;
      },
    );
  }
}

/// One pack: its name, how many sounds it holds, where it is, and the
/// download action while there is something to download.
class _PackRow extends StatelessWidget {
  const _PackRow({required this.entry});

  final SoundPackEntry entry;

  static String packName(SoundPack pack) => pack.id == SoundPacks.library.id
      ? LocaleKeys.sound_picker_pack_names_sound_pack_library.tr()
      : pack.englishName;

  static String? statusLine(SoundPackStatus status) => switch (status.state) {
    SoundPackState.downloading =>
      status.progress == null
          ? LocaleKeys.sound_picker_pack_downloading.tr()
          : LocaleKeys.sound_picker_pack_downloading_percent.tr(
              namedArgs: {'percent': '${(status.progress! * 100).round()}'},
            ),
    SoundPackState.waitingForWifi =>
      LocaleKeys.sound_picker_pack_waiting_for_wifi.tr(),
    SoundPackState.downloaded => LocaleKeys.sound_picker_pack_downloaded.tr(),
    SoundPackState.failed => LocaleKeys.sound_picker_pack_failed.tr(),
    SoundPackState.unavailable => LocaleKeys.sound_picker_pack_unavailable.tr(),
    SoundPackState.needsNewerOs =>
      LocaleKeys.sound_picker_pack_needs_newer_os.tr(),
    SoundPackState.notDownloaded ||
    SoundPackState.needsConfirmation ||
    SoundPackState.unsupported => null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<SoundPickerCubit>();
    final status = entry.status;
    final name = packName(entry.pack);
    final line = statusLine(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                Text(
                  LocaleKeys.sound_picker_pack_sound_count.tr(
                    namedArgs: {'count': '${entry.pack.sounds.length}'},
                  ),
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontFamilyFallback: AppTypography.fontMonoFallbacks,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.ink3,
                  ),
                ),
                if (line != null)
                  Text(
                    line,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 13,
                      color: colors.ink2,
                    ),
                  ),
              ],
            ),
          ),
          if (status.state.canDownload)
            Semantics(
              label: LocaleKeys.sound_picker_pack_download_aria_label.tr(
                namedArgs: {'name': name},
              ),
              child: AppButton(
                label: LocaleKeys.sound_picker_pack_download.tr(),
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: () {
                  AppHaptics.selection();
                  unawaited(cubit.downloadPack(entry.pack.id));
                },
              ),
            )
          else if (status.state.isBusy)
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: status.progress,
                strokeWidth: 3,
                semanticsLabel: line,
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
