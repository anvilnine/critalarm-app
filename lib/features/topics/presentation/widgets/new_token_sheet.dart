import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/new_token_rules.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the New token sheet for the topic [cubit] works on.
///
/// Step one names the token and step two shows it once. Nothing is made when
/// the sheet opens and nothing is made when it closes: the token is made by
/// the Make token button, once per tap.
///
/// The value lives in [cubit]'s state and is read from there. However the
/// sheet closes (I saved it, a swipe down, a tap outside, the back button),
/// the value is dropped from the state afterwards.
///
/// [initialName] fills the name field. [readServerUrl] stands in for reading
/// the saved connection, for a screen that already holds the address.
Future<void> showNewTokenSheet(
  BuildContext context, {
  required TopicTokensCubit cubit,
  String? initialName,
  Future<String?> Function()? readServerUrl,
}) async {
  final session = _SheetSession();
  await showAppSheet<void>(
    context: context,
    content: (sheetContext) => _NewTokenSheet(
      cubit: cubit,
      session: session,
      initialName: initialName,
      readServerUrl: readServerUrl ?? _readSavedServerUrl,
      onClose: () {
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
  if (!session.hasMadeRequest || cubit.isClosed) return;
  cubit.dismissNewToken();
}

Future<String?> _readSavedServerUrl() async {
  final result = await getIt<GetConnectionUsecase>()(const NoParams());
  return result.getOrNull()?.serverUrl;
}

/// What the open sheet tells the function that opened it.
class _SheetSession {
  /// Make token was tapped at least once, so a value may be in the state
  /// that this sheet put there.
  bool hasMadeRequest = false;
}

class _NewTokenSheet extends StatefulWidget {
  const _NewTokenSheet({
    required this.cubit,
    required this.session,
    required this.initialName,
    required this.readServerUrl,
    required this.onClose,
  });

  final TopicTokensCubit cubit;
  final _SheetSession session;
  final String? initialName;
  final Future<String?> Function() readServerUrl;
  final VoidCallback onClose;

  @override
  State<_NewTokenSheet> createState() => _NewTokenSheetState();
}

class _NewTokenSheetState extends State<_NewTokenSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );
  final MakeTokenGuard _guard = MakeTokenGuard();

  /// The rise and fade-in of the sheet's content, played once.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  );
  bool _hasStartedEnter = false;

  NewTokenStep _step = NewTokenStep.name;

  /// The last Make token was refused, and the name has not changed since.
  bool _isRefused = false;

  String? _serverUrl;
  bool _isValueCopied = false;
  bool _isCurlCopied = false;
  Timer? _valueTimer;
  Timer? _curlTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onNameChanged);
    unawaited(_loadServerUrl());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedEnter) return;
    _hasStartedEnter = true;
    if (context.reduceMotion) {
      _enter.value = 1;
    } else {
      unawaited(_enter.forward());
    }
  }

  @override
  void dispose() {
    _valueTimer?.cancel();
    _curlTimer?.cancel();
    _controller
      ..removeListener(_onNameChanged)
      ..dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _loadServerUrl() async {
    final url = await widget.readServerUrl();
    if (!mounted || url == null) return;
    setState(() => _serverUrl = url);
  }

  void _onNameChanged() {
    if (!mounted) return;
    setState(() => _isRefused = false);
  }

  void _pickName(String name) {
    AppHaptics.selection();
    _controller.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
  }

  Future<void> _make() async {
    if (_step != NewTokenStep.name || !_guard.tryBegin()) return;
    widget.session.hasMadeRequest = true;
    AppHaptics.capture();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isRefused = false);

    await widget.cubit.createToken(
      name: resolveNewTokenName(_controller.text),
    );
    if (!mounted) return;

    if (widget.cubit.state.newToken != null) {
      AppHaptics.success();
      setState(() => _step = NewTokenStep.shown);
    } else {
      AppHaptics.failed();
      _guard.release();
      setState(() => _isRefused = true);
    }
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onClose();
  }

  void _saved() {
    AppHaptics.selection();
    widget.cubit.dismissNewToken();
    _close();
  }

  void _noteValueCopied() {
    AppHaptics.selection();
    _valueTimer?.cancel();
    setState(() => _isValueCopied = true);
    _valueTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isValueCopied = false);
    });
  }

  Future<void> _copyCurl() async {
    final url = _serverUrl;
    final token = widget.cubit.state.newToken;
    if (url == null || token == null) return;
    final line = CurlLine.build(
      serverUrl: url,
      topic: widget.cubit.topicName,
      token: token,
      message: LocaleKeys.local_reminders_curl_sample_message.tr(),
      priority: CurlLine.urgent,
    );
    AppHaptics.selection();
    await Clipboard.setData(ClipboardData(text: line));
    if (!mounted) return;
    _curlTimer?.cancel();
    setState(() => _isCurlCopied = true);
    _curlTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCurlCopied = false);
    });
  }

  /// The tallest the scrolling content may be. The sheet around it adds its
  /// padding, the grab bar and the bottom inset, and a strip of the screen
  /// stays above it, so a tall sheet scrolls and never overflows.
  double _sheetMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    const sheetChrome = 10 + 5 + 14 + 18;
    const stripAbove = 24;
    final room =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom -
        sheetChrome -
        stripAbove;
    return room.clamp(160.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopicTokensCubit, TopicTokensState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final value = state.newToken;
        final isShown = _step == NewTokenStep.shown;

        // The value was dropped from outside while it was on screen.
        if (isShown && value == null && !_isClosing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _close();
          });
        }

        final isMaking = state.isWorking || (_guard.isBusy && !isShown);
        // A token being made must not lose its value to a swipe: the value
        // exists only in the answer to that request.
        final canPop = !(isMaking && !isShown);

        final Widget step = isShown && value != null
            ? KeyedSubtree(
                key: const ValueKey('new_token_shown'),
                child: _ShownStep(
                  name: state.newTokenName ?? '',
                  value: value,
                  serverUrl: _serverUrl,
                  topic: widget.cubit.topicName,
                  isValueCopied: _isValueCopied,
                  isCurlCopied: _isCurlCopied,
                  onValueCopied: _noteValueCopied,
                  onCopyCurl: () => unawaited(_copyCurl()),
                  onSaved: _saved,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('new_token_name'),
                child: _NameStep(
                  controller: _controller,
                  takenNames: [for (final t in state.tokens) t.name],
                  isMaking: isMaking,
                  refusedLine: _isRefused
                      ? (state.errorMessage ??
                            LocaleKeys.new_token_make_failed.tr())
                      : null,
                  onPick: _pickName,
                  onMake: () => unawaited(_make()),
                ),
              );

        return PopScope(
          canPop: canPop,
          child: AnimatedBuilder(
            animation: _enter,
            builder: (context, child) {
              final t = _enter.value;
              final rise = AppCurves.easeSpring.transform(t);
              final fade = AppCurves.easeOut.transform(t).clamp(0.0, 1.0);
              return Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, 60 * (1 - rise)),
                  child: child,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _sheetMaxHeight(context),
              ),
              child: SingleChildScrollView(
                child: _Resize(
                  duration: AppDurations.enter,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: context.motion(AppDurations.enter),
                    switchInCurve: AppCurves.easeOut,
                    switchOutCurve: AppCurves.easeOut,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: step,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets a change of height ease in. Under reduced motion it is the child
/// alone, with nothing to animate.
class _Resize extends StatelessWidget {
  const _Resize({
    required this.duration,
    required this.alignment,
    required this.child,
  });

  final Duration duration;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppCurves.easeOut,
      alignment: alignment,
      child: child,
    );
  }
}

/// The title grows with the system text up to 1.5 times: a name that fills
/// the 40 characters would otherwise take the whole screen at the largest
/// size.
TextScaler _titleScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);

TextStyle _titleStyle(AppColors colors) => TextStyle(
  fontFamily: AppTypography.fontDisplay,
  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
  fontSize: 24,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.02 * 24,
  height: 1.15,
  color: colors.ink,
);

/// Step one: a name, the quick names and Make token.
class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.takenNames,
    required this.isMaking,
    required this.refusedLine,
    required this.onPick,
    required this.onMake,
  });

  final TextEditingController controller;
  final List<String> takenNames;
  final bool isMaking;
  final String? refusedLine;
  final ValueChanged<String> onPick;
  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typed = controller.text.trim();
    final resolved = resolveNewTokenName(controller.text);
    final isTaken = resolved != null && takenNames.contains(resolved);
    final line = LocaleKeys.new_token_name_line.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            LocaleKeys.new_token_title.tr(),
            style: _titleStyle(colors),
            textScaler: _titleScaler(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(line, style: AppTypography.small(colors.ink3)),
        const SizedBox(height: 14),
        Semantics(
          label: line,
          textField: true,
          child: ExcludeSemantics(
            child: TextField(
              controller: controller,
              enabled: !isMaking,
              maxLength: kNewTokenNameMax,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onMake(),
              cursorColor: colors.cobalt,
              style: AppTypography.monoBold(colors.ink, fontSize: 17),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: _fieldBorder(colors.cobalt),
                enabledBorder: _fieldBorder(colors.cobalt),
                focusedBorder: _fieldBorder(colors.cobalt),
                disabledBorder: _fieldBorder(colors.hairline),
              ),
            ),
          ),
        ),
        if (isTaken) ...[
          const SizedBox(height: 8),
          Text(
            LocaleKeys.topic_tokens_name_taken_warning.tr(
              namedArgs: {'name': typed},
            ),
            style: AppTypography.small(colors.ink3, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in kNewTokenQuickNames)
              _QuickName(
                // l10n-ok: tool names
                label: name,
                isSelected: typed == name,
                onTap: isMaking ? null : () => onPick(name),
              ),
          ],
        ),
        if (refusedLine != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              refusedLine!,
              style: AppTypography.small(
                colors.critText,
                fontSize: 13,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: LocaleKeys.new_token_make_button.tr(),
          isFullWidth: true,
          isLoading: isMaking,
          onPressed: isMaking ? null : onMake,
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: Radii.mdAll,
    borderSide: BorderSide(color: color, width: 2),
  );
}

/// One quick name. The chosen one is filled with ink.
class _QuickName extends StatelessWidget {
  const _QuickName({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected ? colors.ink : colors.cream,
            borderRadius: Radii.fullAll,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTypography.small(
                isSelected ? colors.cream : colors.ink,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step two: the value once, the curl line and I saved it.
class _ShownStep extends StatelessWidget {
  const _ShownStep({
    required this.name,
    required this.value,
    required this.serverUrl,
    required this.topic,
    required this.isValueCopied,
    required this.isCurlCopied,
    required this.onValueCopied,
    required this.onCopyCurl,
    required this.onSaved,
  });

  final String name;
  final String value;
  final String? serverUrl;
  final String topic;
  final bool isValueCopied;
  final bool isCurlCopied;
  final VoidCallback onValueCopied;
  final VoidCallback onCopyCurl;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final url = serverUrl;
    // Copy and Share need a row of their own once the text is large.
    final isStacked = MediaQuery.textScalerOf(context).scale(14) > 20;

    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.monoBold(colors.ink),
    );
    final actions = TokenActions(
      value: value,
      onCopied: (_) => onValueCopied(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Yellow with an ink outline in both themes, as every face is.
            ExcludeSemantics(
              child: FaceWidget(
                state: FaceState.happy,
                size: 52,
                overrideFillColor: colors.yellow,
                overrideStrokeColor: colors.inkFixed,
                overrideInkColor: colors.inkFixed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      name,
                      style: _titleStyle(colors),
                      textScaler: _titleScaler(context),
                    ),
                  ),
                  Text(
                    LocaleKeys.new_token_shown_once.tr(),
                    style: AppTypography.small(colors.critText).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.cream,
            borderRadius: Radii.mdAll,
          ),
          child: isStacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    valueText,
                    const SizedBox(height: 8),
                    actions,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: valueText),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        ),
        _Resize(
          duration: AppDurations.quick,
          alignment: Alignment.topLeft,
          child: isValueCopied
              ? Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 0, 0),
                    child: Text(
                      LocaleKeys.new_token_copied.tr(),
                      style: AppTypography.small(
                        colors.ink,
                        fontSize: 13,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (url != null) ...[
          const SizedBox(height: 12),
          _Terminal(
            command: CurlLine.forTerminalShowing(
              serverUrl: url,
              topic: topic,
              token: value,
              message: LocaleKeys.local_reminders_curl_sample_message.tr(),
            ),
            highlight: maskedToken(value),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              label: isCurlCopied
                  ? LocaleKeys.new_token_copied.tr()
                  : LocaleKeys.new_token_copy_curl.tr(),
              isFilled: isCurlCopied,
              onTap: onCopyCurl,
            ),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: LocaleKeys.new_token_saved_button.tr(),
          isFullWidth: true,
          onPressed: onSaved,
        ),
      ],
    );
  }
}

/// A small outlined pill, filled with the panel colour once it has done its
/// job.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.isFilled,
    required this.onTap,
  });

  final String label;
  final bool isFilled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isFilled ? colors.ink : Colors.transparent,
            borderRadius: Radii.fullAll,
            border: Border.all(
              color: colors.ink,
              width: 2,
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTypography.small(
                isFilled ? colors.cream : colors.ink,
                fontSize: 13.5,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark box with the curl line and a blinking cursor.
class _Terminal extends StatelessWidget {
  const _Terminal({required this.command, required this.highlight});

  /// The command as shown, token partly hidden.
  final String command;

  /// The part of [command] drawn in yellow, the hidden token.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = AppTypography.mono(
      colors.onPanel,
      fontSize: 12,
    ).copyWith(height: 1.6, letterSpacing: 0);
    final at = command.indexOf(highlight);
    final before = at < 0 ? command : command.substring(0, at);
    final after = at < 0 ? '' : command.substring(at + highlight.length);

    return Semantics(
      label: LocaleKeys.new_token_curl_label.tr(),
      value: command,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: Radii.lgAll,
        ),
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(
                text: r'$ ',
                style: TextStyle(color: colors.yellow),
              ),
              TextSpan(text: before),
              if (at >= 0)
                TextSpan(
                  text: highlight,
                  style: TextStyle(color: colors.yellow),
                ),
              TextSpan(text: after),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _BlinkingCursor(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A yellow block that blinks once a second. Under reduced motion it stays
/// on and no clock runs.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      unawaited(_clock.repeat());
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => Container(
            width: 8,
            height: 15,
            // On for the first half of each second, off for the second half.
            color: _clock.value < 0.5 ? colors.yellow : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
