import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_state.dart';
import 'package:critalarm/features/settings/presentation/sound_crop_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Records a clip from the microphone, then turns into the cropper for it.
///
/// Both live in this one route, so back from the cropper lands on the sound
/// list. The route pops with whatever the cropper pops with (a future for a
/// save that may still be running), or null when the user leaves before the
/// cropper opens.
class SoundRecorderScreen extends StatelessWidget {
  const SoundRecorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<RecorderCubit>();
        unawaited(cubit.checkRinging());
        return cubit;
      },
      child: const RecorderView(),
    );
  }
}

/// The recorder itself, for a [RecorderCubit] above it.
class RecorderView extends StatefulWidget {
  const RecorderView({super.key});

  /// How long the happy face shows before the cropper opens.
  static const successPause = Duration(milliseconds: 600);

  @override
  State<RecorderView> createState() => _RecorderViewState();
}

class _RecorderViewState extends State<RecorderView>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<void>? _route;
  Timer? _toCropper;

  /// Set once the cropper has taken the file. The body is the cropper from
  /// then on.
  PickedSoundFile? _cropping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _toCropper?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leaving the app ends the recording. Inactive alone does not: the
  /// permission prompt and the control centre both cause it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<RecorderCubit>().checkRinging());
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(context.read<RecorderCubit>().interrupt());
    }
  }

  /// Something opened on top, such as the alarm screen.
  @override
  void didPushNext() {
    unawaited(context.read<RecorderCubit>().interrupt());
  }

  /// Whatever was on top closed, perhaps an alarm that was acknowledged.
  @override
  void didPopNext() {
    unawaited(context.read<RecorderCubit>().checkRinging());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecorderCubit, RecorderState>(
      listenWhen: (was, now) => was.status != now.status,
      listener: (context, state) {
        switch (state.status) {
          case RecorderStatus.recording:
            AppHaptics.capture();
          case RecorderStatus.stopped:
            AppHaptics.success();
            // Swaps the body, never pops, so nothing else on the stack can
            // be closed by mistake.
            _toCropper?.cancel();
            _toCropper = Timer(RecorderView.successPause, () {
              if (!mounted) return;
              final file = context.read<RecorderCubit>().handOff();
              if (file != null) setState(() => _cropping = file);
            });
          case RecorderStatus.ready ||
              RecorderStatus.starting ||
              RecorderStatus.stopping ||
              RecorderStatus.denied ||
              RecorderStatus.interrupted:
            break;
        }
      },
      builder: (context, state) {
        final cropping = _cropping;
        return AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: cropping == null
              ? _RecorderBody(state: state)
              : SoundCropScreen(key: ValueKey(cropping.path), file: cropping),
        );
      },
    );
  }
}

class _RecorderBody extends StatelessWidget {
  const _RecorderBody({required this.state});

  final RecorderState state;

  /// `0:12`.
  static String formatTimer(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<RecorderCubit>();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final busy =
        state.status == RecorderStatus.starting ||
        state.status == RecorderStatus.stopping ||
        state.status == RecorderStatus.stopped;
    final message = switch (state.status) {
      RecorderStatus.denied => LocaleKeys.sound_recorder_microphone_denied.tr(),
      RecorderStatus.interrupted => LocaleKeys.sound_recorder_interrupted.tr(),
      _ => null,
    };

    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        leading: AppIconButton(
          glyph: GlyphType.close,
          ariaLabel: LocaleKeys.sound_crop_cancel.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LocaleKeys.sound_recorder_title.tr(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaceWidget(state: state.face, size: 140),
                const SizedBox(height: 16),
                Opacity(
                  opacity: state.showsTimer(reduceMotion: reduceMotion) ? 1 : 0,
                  child: Text(
                    formatTimer(state.elapsed),
                    style:
                        AppTypography.display(
                          state.isLastSeconds ? colors.crit : colors.onCanvas,
                          fontSize: 64,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LocaleKeys.sound_recorder_max_duration.tr(
                    namedArgs: {'seconds': '${state.maxDuration.inSeconds}'},
                  ),
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontFamilyFallback: AppTypography.fontMonoFallbacks,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.ink3,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onCanvas,
                    ),
                  ),
                ],
                if (state.status == RecorderStatus.denied) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: LocaleKeys.sound_recorder_open_settings.tr(),
                    variant: AppButtonVariant.ghost,
                    onPressed: () => unawaited(cubit.openSettings()),
                  ),
                ],
                const SizedBox(height: 22),
                _LivePanel(state: state),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: Radii.fullAll,
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 6,
                    color: colors.crit,
                    backgroundColor: colors.canvasGhost,
                  ),
                ),
                const SizedBox(height: 26),
                _RecordButton(
                  isRecording: state.isRecording,
                  looksDisabled: state.alarmRinging,
                  onPressed: busy
                      ? null
                      : () {
                          AppHaptics.selection();
                          unawaited(cubit.toggle());
                        },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The dark panel of live bars. New readings come in on the right.
class _LivePanel extends StatelessWidget {
  const _LivePanel({required this.state});

  final RecorderState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final levels = state.levels;
    final bars = [
      for (var i = levels.length; i < RecorderState.barCount; i++) 0.04,
      ...levels,
    ];
    final live =
        state.isRecording ||
        state.status == RecorderStatus.stopping ||
        state.status == RecorderStatus.stopped;
    return ExcludeSemantics(
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: _CenteredBarsPainter(
            bars: bars,
            color: live ? colors.crit : colors.onPanel.withValues(alpha: .25),
          ),
        ),
      ),
    );
  }
}

class _CenteredBarsPainter extends CustomPainter {
  const _CenteredBarsPainter({required this.bars, required this.color});

  final List<double> bars;
  final Color color;
  static const gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = bars.length;
    if (count == 0 || size.isEmpty) return;
    final width = math.max<double>(1, (size.width - gap * (count - 1)) / count);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final height = math.max<double>(
        2,
        bars[i].clamp(0.0, 1.0) * (size.height - 4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * (width + gap),
            (size.height - height) / 2,
            width,
            height,
          ),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CenteredBarsPainter old) =>
      old.color != color || !listEquals(old.bars, bars);
}

/// The big round button. A red dot to start, a red square to stop.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.onPressed,
    this.looksDisabled = false,
  });

  final bool isRecording;

  /// Greyed out while an alarm rings. Still tappable, so a tap can check
  /// again once the alarm is acknowledged.
  final bool looksDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: isRecording
          ? LocaleKeys.sound_recorder_stop.tr()
          : LocaleKeys.sound_recorder_start.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onPressed == null || looksDisabled ? .5 : 1,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(color: colors.ink, width: 4),
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: context.motion(const Duration(milliseconds: 160)),
              width: isRecording ? 30 : 60,
              height: isRecording ? 30 : 60,
              decoration: BoxDecoration(
                color: colors.crit,
                borderRadius: BorderRadius.circular(isRecording ? 8 : 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
