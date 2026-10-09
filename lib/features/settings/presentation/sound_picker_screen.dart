import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/sound_hero_rules.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_state.dart';
import 'package:critalarm/features/settings/presentation/personalize/sound/sound_hero.dart';
import 'package:critalarm/features/settings/presentation/personalize/sound/sound_sheet.dart';
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
///
/// It is the Sound pass of Personalize: the page's blue ground, the wave of
/// the sound that rings, and the list on a white sheet. A choice is saved the
/// moment it is made, so the back ring is the only way out.
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

class _SoundPickerView extends StatefulWidget {
  const _SoundPickerView();

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
    if (await _heldBack(context)) return;
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
    if (await _heldBack(context)) return;
    if (!context.mounted) return;
    final result = await context.pushNamed<Object?>(AppRoute.soundRecord);
    if (result is Future<void>) await cubit.reloadAfterCrop(result);
  }

  /// The gate in front of every way to add or pick an own sound. These are
  /// the acts that keep or use one, so the rule is `keep`: with own sounds
  /// locked it opens the paywall and answers true, and the caller does
  /// nothing else. Open, it answers false and the caller goes ahead.
  ///
  /// It waits for the plan to be read first, so a tap right after a cold
  /// start never shows a paywall to someone who holds Pro.
  static Future<bool> _heldBack(BuildContext context) async {
    // Brings the picker's own copy of the decision up to the read plan, so a
    // row drawn before the read is drawn true.
    await context.read<SoundPickerCubit>().ownSoundsOnceReady();
    if (!context.mounted) return true;
    final isFree = await keepOrOpenPaywall(
      context,
      AppFeature.ownSounds,
      LockSource.sounds,
    );
    return !isFree;
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
  State<_SoundPickerView> createState() => _SoundPickerViewState();
}

class _SoundPickerViewState extends State<_SoundPickerView>
    with SingleTickerProviderStateMixin {
  /// Where the preview has got. The platform does not report where playback
  /// is, so the playhead, the row's ring and its bars run off the sound's
  /// length, and the cubit clears the preview when the platform says it ended.
  late final AnimationController _progress = AnimationController(vsync: this);
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _progress.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Starts the playhead for the sound now previewing, or rests it.
  void _followPreview(SoundPickerState state) {
    final id = state.previewingSoundId;
    if (id == null) {
      _progress.reset();
      return;
    }
    final playing = state.allSounds.where((s) => s.id == id);
    final length = playing.isEmpty ? Duration.zero : playing.first.duration;
    _progress.duration = length > Duration.zero
        ? length
        : const Duration(seconds: 1);
    unawaited(_progress.forward(from: 0));
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// The wave and the play circle, over the sheet.
  Widget _hero(
    BuildContext context, {
    required SoundPickerState state,
    required PassTone tone,
    required bool circleInHero,
    required Widget circle,
  }) {
    final playing = state.previewingSoundId;
    final shown = playing ?? state.ringingSoundId;
    List<double>? peaks;
    for (final sound in state.allSounds) {
      if (sound.id == shown) peaks = sound.peaks;
    }
    final isShort = AppSize.of(context).isShort;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kPassSidePadding,
        20,
        kPassSidePadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (circleInHero)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: circle,
              ),
            ),
          SoundHero(
            peaks: peaks,
            isPlaying: playing != null,
            progress: _progress,
            tone: tone,
            height: soundHeroHeightFor(isShort: isShort),
          ),
        ],
      ),
    );
  }

  /// Whether the value's first line would run under the play circle that
  /// sits beside the header. A long name does, and then the circle sits over
  /// the wave instead.
  bool _clashesWithCircle(
    BuildContext context,
    String value,
    double columnWidth,
    Color color,
  ) {
    if (value.isEmpty) return false;
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: passValueStyle(color, kPassPageValueSize),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, columnWidth - 2 * kPassSidePadding));
    final lines = painter.computeLineMetrics();
    final firstLine = lines.isEmpty ? 0.0 : lines.first.width;
    painter.dispose();
    const room = SoundPlayCircle.size + 12;
    return firstLine > columnWidth - 2 * kPassSidePadding - room;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SoundPickerCubit, SoundPickerState>(
      listenWhen: (was, now) =>
          (now.errorCode != null && was.errorCode == null) ||
          was.previewingSoundId != now.previewingSoundId,
      listener: (context, state) {
        _followPreview(state);
        if (state.errorCode == null) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(_SoundPickerView.errorMessage(state.errorCode!)),
            ),
          );
        context.read<SoundPickerCubit>().clearError();
      },
      builder: (context, state) {
        final colors = context.appColors;
        final cubit = context.read<SoundPickerCubit>();
        final tone = passToneFor(PassId.sound, colors);
        final scope = PassFrameScope.maybeOf(context);
        final ringing = _SoundPickerView.ringingSound(state);
        // Until the list is read, the header shows what the card it grew
        // from said, so the name does not blink out and back.
        final value = ringing?.name ?? scope?.origin?.value ?? '';
        final isPlaying = state.previewingSoundId != null;
        final stateKey = soundHeaderStateKey(isPlaying: isPlaying);
        final label = state.isPerTopic
            ? LocaleKeys.personalize_passes_sound_topic_label.tr(
                namedArgs: {'topic': state.topicName!},
              )
            : LocaleKeys.personalize_sound_title.tr();

        final media = MediaQuery.of(context);
        final columnWidth = math.min(media.size.width, AppSize.contentMaxWidth);
        final circleInHero = _clashesWithCircle(
          context,
          value,
          columnWidth,
          tone.onGround,
        );

        void togglePlay() {
          if (isPlaying) {
            unawaited(cubit.stopPreview());
          } else if (ringing != null) {
            unawaited(cubit.togglePreview(ringing));
          }
        }

        final circle = SoundPlayCircle(
          isPlaying: isPlaying,
          playLabel: LocaleKeys.personalize_passes_sound_play.tr(),
          stopLabel: LocaleKeys.personalize_passes_sound_stop.tr(),
          onPressed: togglePlay,
        );

        final page = AppPassPage(
          tone: tone,
          label: label,
          value: value,
          state: stateKey?.tr(),
          controller: _scroll,
          onBack: () => _leave(context),
          slivers: [
            SliverToBoxAdapter(
              child: _hero(
                context,
                state: state,
                tone: tone,
                circleInHero: circleInHero,
                circle: circle,
              ),
            ),
            SliverToBoxAdapter(
              child: SoundSheet(
                state: state,
                progress: _progress,
                heldBack: _SoundPickerView._heldBack,
                onPickFile: _SoundPickerView._pickAndCrop,
                onRecord: _SoundPickerView._recordAndCrop,
              ),
            ),
          ],
        );

        // A Scaffold gives the error snack bar somewhere to show. The page
        // paints its own ground, so it shows nothing of its own.
        return Scaffold(
          backgroundColor: tone.ground,
          body: Stack(
            fit: StackFit.expand,
            children: [
              page,
              if (!circleInHero)
                _HeaderCircle(
                  scroll: _scroll,
                  columnWidth: columnWidth,
                  circle: circle,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Holds the play circle at the right of the header block, level with the
/// label, and lets it scroll away with the header. It is not in the pinned
/// row: it belongs to the page, not to the way out.
class _HeaderCircle extends StatelessWidget {
  const _HeaderCircle({
    required this.scroll,
    required this.columnWidth,
    required this.circle,
  });

  final ScrollController scroll;
  final double columnWidth;
  final Widget circle;

  /// How far the page scrolls before the circle is gone, so it never shows
  /// over the pinned strip.
  static const double _fadeOver = 18;

  /// The circle's top sits this far under the label's top.
  static const double _belowLabel = 4;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final frame = PassFrameScope.maybeOf(context)?.frame;
    final gutter = (media.size.width - columnWidth) / 2;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final visible = (1 - offset / _fadeOver).clamp(0.0, 1.0);
        final body = frame?.bodyOpacity ?? 1;
        final shift = frame?.headerOffset ?? Offset.zero;
        return Positioned(
          top:
              media.padding.top +
              kPassHeaderTop +
              _belowLabel -
              offset +
              shift.dy,
          right: gutter + kPassSidePadding,
          child: IgnorePointer(
            ignoring: visible < 1 || body < 1,
            child: Opacity(opacity: visible * body, child: child),
          ),
        );
      },
      child: circle,
    );
  }
}
