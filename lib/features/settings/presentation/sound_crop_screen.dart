import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/domain/crop_window.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Trims a picked file down to one clip and saves it as a user sound.
///
/// Pops with a `Future<void>` that completes once any save the user started
/// has finished, so the sound list can wait for a save that outlives the
/// screen. [file] is null when the route was opened without one (a refresh on
/// the web, a stray link), and the screen leaves at once.
class SoundCropScreen extends StatelessWidget {
  const SoundCropScreen({required this.file, super.key});

  final PickedSoundFile? file;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    if (file == null) return const _LeaveAtOnce();
    return BlocProvider(
      create: (_) {
        final cubit = getIt<SoundCropCubit>();
        unawaited(cubit.load(file));
        return cubit;
      },
      child: const _SoundCropView(),
    );
  }
}

/// Leaves a cropper that has nothing to crop.
class _LeaveAtOnce extends StatelessWidget {
  const _LeaveAtOnce();

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/sounds');
      }
    });
    return const SizedBox.shrink();
  }
}

/// `0:42.0`. Minutes, seconds, tenths.
String formatClipTime(Duration d) {
  final tenths = (d.inMilliseconds / 100).round();
  final minutes = tenths ~/ 600;
  final seconds = (tenths % 600) ~/ 10;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${tenths % 10}';
}

/// `29.5 s`.
String formatClipLength(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

class _SoundCropView extends StatelessWidget {
  const _SoundCropView();

  static void leave(BuildContext context) {
    // Navigator.pop, not maybePop: the PopScope below is what sends system
    // back gestures here in the first place.
    Navigator.of(context).pop(context.read<SoundCropCubit>().pendingSave);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave(context);
      },
      child: BlocConsumer<SoundCropCubit, SoundCropState>(
        listenWhen: (was, now) =>
            was.status != now.status ||
            (now.errorCode != null && was.errorCode == null),
        listener: (context, state) {
          switch (state.status) {
            case SoundCropStatus.saved:
              AppHaptics.success();
              leave(context);
            case SoundCropStatus.unavailable:
              leave(context);
            case SoundCropStatus.ready when state.errorCode != null:
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      LocaleKeys.sound_picker_error_copy_failed.tr(),
                    ),
                  ),
                );
              context.read<SoundCropCubit>().clearError();
            case SoundCropStatus.loading:
            case SoundCropStatus.ready:
            case SoundCropStatus.failed:
            case SoundCropStatus.saving:
              break;
          }
        },
        builder: (context, state) {
          final cubit = context.read<SoundCropCubit>();
          final window = state.window;
          final isBusy = state.status == SoundCropStatus.saving;
          final canSave = state.status == SoundCropStatus.ready;
          return AppScreenScaffold(
            hasTabBar: false,
            topBar: AppTopBar(
              leading: AppIconButton(
                glyph: GlyphType.close,
                ariaLabel: LocaleKeys.sound_crop_cancel.tr(),
                onPressed: () => leave(context),
              ),
              titleWidget: state.name.isEmpty
                  ? Text(
                      LocaleKeys.sound_crop_title.tr(),
                      style: _titleStyle(context.appColors),
                    )
                  : _NameTitle(
                      name: state.name,
                      enabled: !isBusy,
                      onRename: cubit.rename,
                    ),
            ),
            bottomBar: state.status == SoundCropStatus.failed
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: AppButton(
                      label: isBusy
                          ? LocaleKeys.sound_crop_saving.tr()
                          : LocaleKeys.sound_crop_save.tr(),
                      isFullWidth: true,
                      isLoading: isBusy,
                      onPressed: canSave
                          ? () {
                              AppHaptics.capture();
                              unawaited(cubit.save());
                            }
                          : null,
                    ),
                  ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: switch (state.status) {
                    SoundCropStatus.failed => _Failure(
                      code: state.errorCode,
                      onBack: () => leave(context),
                    ),
                    _ when window == null => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    _ => _Editor(state: state, window: window),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

TextStyle _titleStyle(AppColors colors) => TextStyle(
  fontFamily: AppTypography.fontDisplay,
  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
  fontWeight: FontWeight.w800,
  fontSize: 18,
  letterSpacing: -0.02 * 18,
  color: colors.onCanvas,
);

/// The sound's name as the title, with a pencil. Tap it to rename in place.
class _NameTitle extends StatefulWidget {
  const _NameTitle({
    required this.name,
    required this.enabled,
    required this.onRename,
  });

  final String name;
  final bool enabled;
  final ValueChanged<String> onRename;

  @override
  State<_NameTitle> createState() => _NameTitleState();
}

class _NameTitleState extends State<_NameTitle> {
  late final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    _controller
      ..text = widget.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.name.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    widget.onRename(_controller.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = _titleStyle(colors);
    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        style: style,
        cursorColor: colors.onCanvas,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration.collapsed(
          hintText: LocaleKeys.sound_crop_name_label.tr(),
        ).copyWith(counterText: ''),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _focus.unfocus(),
      );
    }
    return Semantics(
      button: true,
      label: LocaleKeys.sound_crop_name_label.tr(),
      value: widget.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _start,
        child: Row(
          children: [
            Flexible(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            const SizedBox(width: 8),
            AppGlyph(GlyphType.pencil, size: 18, color: colors.ink3),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.code, required this.onBack});

  final String? code;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            code == 'sourceTooLong'
                ? LocaleKeys.sound_picker_error_source_too_long.tr()
                : LocaleKeys.sound_crop_error_unreadable.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(colors.onCanvas),
          ),
          const SizedBox(height: Spacing.s4),
          AppButton(
            label: LocaleKeys.common_back.tr(),
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

/// The panel, the readout and the play button.
class _Editor extends StatefulWidget {
  const _Editor({required this.state, required this.window});

  final SoundCropState state;
  final CropWindow window;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> with SingleTickerProviderStateMixin {
  /// Bars in the whole-file strip and in the zoomed view.
  static const overviewBars = 200;
  static const detailBars = 72;

  /// Room shown each side of the selection, as a share of its length.
  static const roomShare = 0.15;

  late final AnimationController _playhead = AnimationController(
    vsync: this,
    duration: _length,
  );

  /// Held still while a finger is on the editor, in seconds.
  ({double from, double to})? _frozenView;

  List<double>? _overviewSource;
  List<double> _overview = const [];

  Duration get _length => widget.window.length > Duration.zero
      ? widget.window.length
      : const Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    if (widget.state.isPlaying) unawaited(_playhead.forward());
  }

  @override
  void didUpdateWidget(_Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playhead.duration = _length;
    final was = oldWidget.state.isPlaying;
    final now = widget.state.isPlaying;
    if (now && !was) unawaited(_playhead.forward(from: 0));
    if (!now && was) _playhead.reset();
  }

  @override
  void dispose() {
    _playhead.dispose();
    super.dispose();
  }

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;
  static Duration _duration(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

  ({double from, double to}) _liveView() {
    final w = widget.window;
    final start = _seconds(w.start);
    final end = _seconds(w.end);
    final room = (end - start) * roomShare;
    return (from: start - room, to: end + room);
  }

  List<double> _overviewPeaks(List<double> peaks) {
    if (!identical(peaks, _overviewSource)) {
      _overviewSource = peaks;
      _overview = slicePeaks(peaks, from: 0, to: 1, count: overviewBars);
    }
    return _overview;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<SoundCropCubit>();
    final state = widget.state;
    final w = widget.window;
    final file = _seconds(w.fileLength);
    final view = _frozenView ?? _liveView();
    final span = view.to - view.from;
    double inView(double seconds) => (seconds - view.from) / span;
    Duration atView(double fraction) => _duration(view.from + fraction * span);
    final startText = formatClipTime(w.start);
    final endText = formatClipTime(w.end);
    const step = SoundCropCubit.nudge;
    String windowValue(CropWindow w) => LocaleKeys.sound_crop_window_value.tr(
      namedArgs: {
        'start': formatClipTime(w.start),
        'end': formatClipTime(w.end),
      },
    );
    String startValue(CropWindow w) => LocaleKeys.sound_crop_handle_start_value
        .tr(namedArgs: {'time': formatClipTime(w.start)});
    String endValue(CropWindow w) => LocaleKeys.sound_crop_handle_end_value.tr(
      namedArgs: {'time': formatClipTime(w.end)},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _playhead,
          builder: (context, _) => AppCropPanel(
            overviewPeaks: _overviewPeaks(state.peaks),
            windowFrom: _seconds(w.start) / file,
            windowTo: _seconds(w.end) / file,
            onJump: (f) => cubit.centerOn(_duration(f * file)),
            detailPeaks: slicePeaks(
              state.peaks,
              from: view.from / file,
              to: view.to / file,
              count: detailBars,
            ),
            selectionFrom: inView(_seconds(w.start)),
            selectionTo: inView(_seconds(w.end)),
            contentFrom: inView(0).clamp(0.0, 1.0),
            contentTo: inView(file).clamp(0.0, 1.0),
            playhead: state.isPlaying ? _playhead.value : null,
            labels: CropEditorLabels(
              window: LocaleKeys.sound_crop_window_label.tr(),
              windowValue: windowValue(w),
              windowUp: windowValue(w.move(step)),
              windowDown: windowValue(w.move(-step)),
              start: LocaleKeys.sound_crop_handle_start.tr(),
              startValue: startValue(w),
              startUp: startValue(w.dragStart(w.start + step)),
              startDown: startValue(w.dragStart(w.start - step)),
              end: LocaleKeys.sound_crop_handle_end.tr(),
              endValue: endValue(w),
              endUp: endValue(w.dragEnd(w.end + step)),
              endDown: endValue(w.dragEnd(w.end - step)),
            ),
            nudges: CropEditorNudges(
              windowForward: () => cubit.moveBy(step),
              windowBack: () => cubit.moveBy(-step),
              startForward: () => cubit.dragStart(w.start + step),
              startBack: () => cubit.dragStart(w.start - step),
              endForward: () => cubit.dragEnd(w.end + step),
              endBack: () => cubit.dragEnd(w.end - step),
            ),
            onMoveWindow: (f) => cubit.moveBy(atView(f) - w.start),
            onMoveStart: (f) => cubit.dragStart(atView(f)),
            onMoveEnd: (f) => cubit.dragEnd(atView(f)),
            onDragStarted: () {
              AppHaptics.selection();
              setState(() => _frozenView = view);
            },
            onDragEnded: () => setState(() => _frozenView = null),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ExcludeSemantics(child: Text(startText, style: _mono(colors))),
              const Spacer(),
              Text(
                formatClipLength(w.length),
                style: AppTypography.display(colors.onCanvas, fontSize: 44)
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              if (w.isAtMax) ...[
                const SizedBox(width: 8),
                AppPlainChip(text: LocaleKeys.sound_crop_max.tr()),
              ],
              const Spacer(),
              ExcludeSemantics(child: Text(endText, style: _mono(colors))),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: AppTransportButton(
            isPlaying: state.isPlaying,
            playLabel: LocaleKeys.sound_crop_play.tr(),
            stopLabel: LocaleKeys.sound_crop_stop.tr(),
            onPressed: state.status == SoundCropStatus.ready
                ? () {
                    AppHaptics.selection();
                    unawaited(cubit.togglePlay());
                  }
                : null,
          ),
        ),
      ],
    );
  }

  TextStyle _mono(AppColors colors) => TextStyle(
    fontFamily: AppTypography.fontMono,
    fontFamilyFallback: AppTypography.fontMonoFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: colors.ink3,
  );
}
