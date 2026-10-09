import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "3:07" for a sound that is three minutes and seven seconds long.
String formatSoundLength(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}

/// Asks the picker's gate in front of an own sound: true when the tap goes
/// no further because the paywall opened (or there is nothing to do).
typedef SoundGate = Future<bool> Function(BuildContext context);

/// The white sheet under the wave: the page's reading surface.
///
/// It holds the sections the picker has always had, in the same order:
/// Built in, Sound packs, Your sounds. Rows are ink on the sheet, with a
/// hairline between them. The sheet reaches past the end of the scroll view
/// so no strip of the page's colour shows under the last row.
class SoundSheet extends StatelessWidget {
  const SoundSheet({
    required this.state,
    required this.progress,
    required this.heldBack,
    required this.onPickFile,
    required this.onRecord,
    super.key,
  });

  /// The sheet's top corners.
  static const double radius = 28;

  final SoundPickerState state;

  /// Where the preview has got, for the row that plays.
  final Animation<double> progress;

  /// The gate in front of an own sound row.
  final SoundGate heldBack;

  final Future<void> Function(BuildContext context) onPickFile;
  final Future<void> Function(BuildContext context) onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // The page ends its scroll view with a gap of this height in its own
    // colour. The sheet covers it.
    final reach = bottom + 24 + 2;
    final cubit = context.read<SoundPickerCubit>();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(radius),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280),
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
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
                        _Section(
                          title: LocaleKeys.sound_picker_bundled_header.tr(),
                          children: [
                            for (final sound in state.bundled)
                              SoundRow(
                                sound: sound,
                                state: state,
                                progress: progress,
                                heldBack: heldBack,
                              ),
                          ],
                        ),
                        if (state.packs.isNotEmpty)
                          _Section(
                            title: LocaleKeys.sound_picker_packs_header.tr(),
                            children: [
                              for (final entry in state.packs) ...[
                                _PackRow(entry: entry),
                                // A pack lists its sounds once they are on
                                // the device.
                                if (entry.status.state ==
                                    SoundPackState.downloaded)
                                  for (final sound in state.packSounds)
                                    if (entry.pack.contains(sound.id))
                                      SoundRow(
                                        sound: sound,
                                        state: state,
                                        progress: progress,
                                        heldBack: heldBack,
                                      ),
                              ],
                            ],
                          ),
                        if (state.userSounds.isNotEmpty ||
                            state.capabilities.canImportSounds)
                          _Section(
                            title: LocaleKeys.sound_picker_user_header.tr(),
                            trailing: LocaleKeys.sound_picker_user_local_only
                                .tr(),
                            footer: state.capabilities.canImportSounds
                                ? _WaysIn(
                                    onPickFile: () => onPickFile(context),
                                    onRecord: () => onRecord(context),
                                  )
                                : null,
                            children: [
                              for (final sound in state.userSounds)
                                Dismissible(
                                  key: ValueKey(sound.id),
                                  direction: DismissDirection.endToStart,
                                  background: _DeleteBackground(
                                    color: colors.crit,
                                  ),
                                  onDismissed: (_) {
                                    AppHaptics.destructive();
                                    unawaited(cubit.deleteUserSound(sound.id));
                                  },
                                  child: SoundRow(
                                    sound: sound,
                                    state: state,
                                    progress: progress,
                                    heldBack: heldBack,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -reach,
          height: reach + 1,
          child: ColoredBox(color: colors.surface),
        ),
      ],
    );
  }
}

/// A titled run of rows, a hairline between them.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.trailing,
    this.footer,
  });

  final String title;
  final String? trailing;
  final List<Widget> children;

  /// Under the last row, with no line before it.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 2,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.title(colors.ink),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: AppTypography.monoBold(colors.ink3, fontSize: 11),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _Hairline(),
            children[i],
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// The line between two rows, inset to start under the title.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 72, right: 20),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: context.appColors.hairline),
    ),
  );
}

/// One sound: its play button, its name and length, its waveform, the plan
/// badge and the notes, and the radio dot.
///
/// The play button is a try on every row, locked or not. A tap on the row
/// saves the choice. A locked own sound goes through [heldBack] first, which
/// opens the paywall.
class SoundRow extends StatelessWidget {
  const SoundRow({
    required this.sound,
    required this.state,
    required this.progress,
    required this.heldBack,
    super.key,
  });

  final AlarmSound sound;
  final SoundPickerState state;
  final Animation<double> progress;
  final SoundGate heldBack;

  @override
  Widget build(BuildContext context) {
    final isPreviewing = state.previewingSoundId == sound.id;
    final isLocked = state.isLocked(sound);
    // The lock draws the badge on the row and nothing else: it takes no tap.
    final row = AccessLock.inline(
      feature: AppFeature.ownSounds,
      source: LockSource.sounds,
      // Only an own sound is locked by this. Every other row is open.
      decide: (_) => isLocked ? state.ownSounds : const FeatureDecision.open(),
      child: Builder(
        builder: (context) => isPreviewing
            ? AnimatedBuilder(
                animation: progress,
                builder: (context, _) =>
                    _body(context, progress: progress.value),
              )
            : _body(context),
      ),
    );
    return row;
  }

  Widget _body(BuildContext context, {double? progress}) {
    final colors = context.appColors;
    final cubit = context.read<SoundPickerCubit>();
    final isUserSound = sound.source == AlarmSoundSource.user;
    // A pack sound is a file in the app's sound folder, as a user sound is,
    // so it rings the same way.
    final isLocalFile = isUserSound || sound.source == AlarmSoundSource.pack;
    final tooLong =
        isUserSound &&
        SoundImportLimits.tooLongToRing(state.platform, sound.duration);
    final notificationsOnly =
        isLocalFile && !state.capabilities.userSoundsRingAlarm;
    final isLocked = state.isLocked(sound);
    final ringing = state.allSounds.where((s) => s.id == state.ringingSoundId);
    final ringingName = ringing.isEmpty ? '' : ringing.first.name;
    // With no name to give, the row says it is locked and no more.
    final isLockedChoice =
        isLocked && state.selectedSoundId == sound.id && ringingName.isNotEmpty;
    final isSelected = state.ringingSoundId == sound.id;
    final note = isLockedChoice
        ? LocaleKeys.sound_picker_row_locked_chosen.tr(
            namedArgs: {'name': ringingName},
          )
        : tooLong
        ? LocaleKeys.sound_picker_row_too_long_ios.tr()
        : notificationsOnly
        ? LocaleKeys.sound_picker_row_notifications_only.tr()
        : null;
    final hasWave = sound.peaks != null && sound.peaks!.isNotEmpty;
    final length = Text(
      formatSoundLength(sound.duration),
      style: AppTypography.mono(
        colors.ink3,
        fontSize: 11,
      ).copyWith(fontFeatures: AppTypography.tabularFigures),
    );
    final scope = FeatureLockScope.maybeOf(context);
    final spoken = scope != null && scope.isLocked
        ? featureLockSpoken(
            name: sound.name,
            lockedWord: LocaleKeys.feature_lock_locked.tr(),
            planWord: scope.planWord,
          )
        : sound.name;

    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: spoken,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppHaptics.selection();
            if (isUserSound) {
              // Asked again here, not read off the row: the row may have
              // been drawn before the plan was read.
              unawaited(() async {
                if (await heldBack(context)) return;
                await cubit.select(sound.id);
              }());
              return;
            }
            unawaited(cubit.select(sound.id));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: context.motion(AppDurations.quick),
              curve: AppCurves.easeSpring,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? colors.ash : null,
                borderRadius: Radii.mdAll,
              ),
              child: Row(
                children: [
                  AppPreviewButton(
                    isPlaying: progress != null,
                    progress: progress,
                    progressLabel: progress == null
                        ? null
                        : LocaleKeys.sound_picker_preview_progress.tr(
                            namedArgs: {
                              'percent': '${(progress * 100).round()}',
                            },
                          ),
                    playLabel: LocaleKeys.sound_picker_play_aria_label.tr(),
                    stopLabel: LocaleKeys.sound_picker_stop_aria_label.tr(),
                    onPressed: () {
                      AppHaptics.selection();
                      unawaited(cubit.togglePreview(sound));
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              sound.name,
                              style: AppTypography.body(
                                colors.ink,
                                fontSize: 14,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (hasWave) length,
                            const FeatureLockBadge(),
                          ],
                        ),
                        // Only a waveform read from the sound itself. While
                        // it loads, or when it cannot be read, the row shows
                        // the length and nothing that looks like a waveform
                        // but is not one.
                        if (hasWave) ...[
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 22,
                            width: double.infinity,
                            child: WaveformBars(
                              peaks: sound.peaks!,
                              progress: progress,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 2),
                          length,
                        ],
                        if (note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            style: AppTypography.small(
                              colors.ink2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppRadio(selected: isSelected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Pick a file" and "Record", side by side where there is room.
class _WaysIn extends StatelessWidget {
  const _WaysIn({required this.onPickFile, required this.onRecord});

  final Future<void> Function() onPickFile;
  final Future<void> Function() onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pick = _WayIn(
      label: LocaleKeys.sound_picker_pick_file.tr(),
      icon: AppGlyph(GlyphType.plus, size: 16, color: colors.ink),
      onPressed: onPickFile,
    );
    final record = _WayIn(
      label: LocaleKeys.sound_picker_record.tr(),
      icon: AppGlyph(GlyphType.record, size: 16, color: colors.crit),
      onPressed: onRecord,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: LayoutBuilder(
        builder: (context, box) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final isStacked = textScale >= 1.25 || box.maxWidth < 300;
          return isStacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pick, const SizedBox(height: 8), record],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: pick),
                      const SizedBox(width: 8),
                      Expanded(child: record),
                    ],
                  ),
                );
        },
      ),
    );
  }
}

/// One way to bring in an own sound. Drawn at full colour; while own sounds
/// are locked the plan badge sits under the label and a tap goes to the
/// picker's gate, which opens the paywall. Open, the same tap goes in.
class _WayIn extends StatelessWidget {
  const _WayIn({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final Future<void> Function() onPressed;

  void _go() {
    AppHaptics.capture();
    unawaited(onPressed());
  }

  @override
  Widget build(BuildContext context) {
    return AccessLock(
      feature: AppFeature.ownSounds,
      source: LockSource.sounds,
      name: label,
      // The tile places the badge itself, where its words can wrap first.
      drawsBadge: false,
      // Drawn locked or not, a tap runs the same way in, which asks the
      // picker's own gate once the plan is read. So a badge drawn before the
      // first read never leads a Pro holder to a paywall.
      onLockedTap: _go,
      child: Builder(
        builder: (context) {
          final colors = context.appColors;
          final scope = FeatureLockScope.maybeOf(context);
          final showsBadge =
              scope != null && scope.isLocked && scope.planWord != null;
          return Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _go,
              child: Container(
                // The lock's stack loosens the width, so the tile asks for
                // all of it.
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: Radii.mdAll,
                  border: Border.all(
                    color: colors.ink.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              colors.ink,
                              fontSize: 14,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (showsBadge) ...[
                      const SizedBox(height: 6),
                      const FeatureLockBadge(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One pack: its name, how many sounds it holds, where it is, and the
/// download action while there is something to download. Packs are free.
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.body(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  LocaleKeys.sound_picker_pack_sound_count.tr(
                    namedArgs: {'count': '${entry.pack.sounds.length}'},
                  ),
                  style: AppTypography.monoBold(colors.ink3, fontSize: 11),
                ),
                if (line != null)
                  Text(
                    line,
                    style: AppTypography.small(colors.ink2, fontSize: 13),
                  ),
              ],
            ),
          ),
          if (status.state.canDownload) ...[
            const SizedBox(width: 12),
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
            ),
          ] else if (status.state.isBusy) ...[
            const SizedBox(width: 12),
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                value: status.progress,
                strokeWidth: 3,
                semanticsLabel: line,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: color, borderRadius: Radii.mdAll),
      child: Text(
        LocaleKeys.sound_picker_delete.tr(),
        style: AppTypography.body(
          context.appColors.onPanel,
          fontSize: 13,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
