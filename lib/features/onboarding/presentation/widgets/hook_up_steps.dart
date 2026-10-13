import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/setup_layout_rules.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/domain/tool_snippet.dart';
import 'package:critalarm/features/topics/domain/tool_steps.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_message_row.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What the hook-up step shows for a tool with documented steps: a mono
/// label, the tool's name, and a white sheet holding the numbered steps, the
/// block to copy from, a row of three chips and the curl line one tap away.
///
/// The steps are the tool's own: they come from [toolStepsFor], and the
/// fields or code between them from the tool's [snippet]. The token is drawn
/// masked everywhere it is only looked at. Copy token and the copy buttons
/// put the whole value on the clipboard.
class HookUpStepsLayout extends StatefulWidget {
  const HookUpStepsLayout({
    required this.template,
    required this.steps,
    required this.snippet,
    required this.serverUrl,
    required this.token,
    required this.curl,
    required this.notes,
    super.key,
  });

  final ToolTemplate template;
  final ToolSteps steps;
  final ToolSnippet snippet;
  final String serverUrl;
  final String token;

  /// The curl line with its own copy button. Shown when the curl chip is
  /// open.
  final Widget curl;

  /// What the sheet is followed by: the note about the token and, where the
  /// topic is not critical, what that means for ringing.
  final Widget notes;

  @override
  State<HookUpStepsLayout> createState() => _HookUpStepsLayoutState();
}

enum _Copied { url, token }

class _HookUpStepsLayoutState extends State<HookUpStepsLayout> {
  bool _isCurlOpen = false;
  _Copied? _copied;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  String get _address => CurlLine.baseUrl(widget.serverUrl);

  void _copy(_Copied which, String value) {
    unawaited(Clipboard.setData(ClipboardData(text: value)));
    _copiedTimer?.cancel();
    setState(() => _copied = which);
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final keys = widget.steps.keys;
    final blockAfter = widget.steps.blockAfter;
    final textScale = setupTextScaleOf(context);

    Widget stepRow(int index) => _StepRow(
      number: index + 1,
      text: keys[index].tr(),
      showsDivider: index > 0 && index != blockAfter,
    );

    final chips = [
      _chip(
        label: _copied == _Copied.url
            ? LocaleKeys.common_copied.tr()
            : LocaleKeys.onboarding_hook_up_steps_copy_url.tr(),
        variant: AppButtonVariant.ink,
        onPressed: () => _copy(_Copied.url, _address),
        animatesLabel: true,
      ),
      _chip(
        label: _copied == _Copied.token
            ? LocaleKeys.common_copied.tr()
            : LocaleKeys.onboarding_hook_up_steps_copy_token.tr(),
        variant: AppButtonVariant.ghost,
        onPressed: () => _copy(_Copied.token, widget.token),
        animatesLabel: true,
      ),
      Semantics(
        expanded: _isCurlOpen,
        child: _chip(
          label: LocaleKeys.onboarding_hook_up_steps_curl.tr(),
          // Ink while the line is open, so the open chip reads as picked.
          variant: _isCurlOpen ? AppButtonVariant.ink : AppButtonVariant.ghost,
          onPressed: () => setState(() => _isCurlOpen = !_isCurlOpen),
        ),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.onboarding_hook_up_steps_label.tr().toUpperCase(),
                style: AppTypography.monoBold(
                  colors.onCanvasMuted,
                  fontSize: 11,
                ).copyWith(letterSpacing: 0.9),
              ),
              const SizedBox(height: Spacing.s1),
              AppFittedTitle(
                widget.template.label ?? '',
                textAlign: TextAlign.start,
                minFontSize: setupTitleMinFontSize,
                style: AppTypography.headline(colors.onCanvas, fontSize: 38),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.s4),
        AppSheet(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s4,
            Spacing.s2,
            Spacing.s4,
            Spacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blockAfter; i++) stepRow(i),
              const SizedBox(height: Spacing.s2),
              _block(context),
              const SizedBox(height: Spacing.s3),
              _AddressBlock(address: _address, token: widget.token),
              const SizedBox(height: Spacing.s2),
              if (hookUpStacksChips(textScale))
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: chips,
                )
              else
                Row(
                  children: [
                    for (final (i, chip) in chips.indexed) ...[
                      if (i > 0) const SizedBox(width: Spacing.s2),
                      Expanded(child: chip),
                    ],
                  ],
                ),
              AnimatedSize(
                duration: context.motion(AppDurations.base),
                curve: AppCurves.easeOut,
                alignment: Alignment.topCenter,
                child: ClipRect(
                  child: _isCurlOpen
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: context.motion(AppDurations.base),
                          curve: AppCurves.easeOut,
                          builder: (context, opacity, child) =>
                              Opacity(opacity: opacity, child: child),
                          child: Padding(
                            padding: const EdgeInsets.only(top: Spacing.s2),
                            child: widget.curl,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),
              const SizedBox(height: Spacing.s1),
              for (var i = blockAfter; i < keys.length; i++) stepRow(i),
            ],
          ),
        ),
        const SizedBox(height: Spacing.s3),
        widget.notes,
      ],
    );
  }

  /// A chip of the row: a small pill, as wide as the room it is given.
  Widget _chip({
    required String label,
    required AppButtonVariant variant,
    required VoidCallback onPressed,
    bool animatesLabel = false,
  }) => Semantics(
    liveRegion: animatesLabel,
    child: AppButton(
      label: label,
      variant: variant,
      size: AppButtonSize.sm,
      isFullWidth: true,
      animatesLabel: animatesLabel,
      onPressed: onPressed,
    ),
  );

  /// The tool's own fields or code, between its steps.
  Widget _block(BuildContext context) {
    final colors = context.appColors;
    return switch (widget.snippet) {
      ToolSnippetCode(:final code) => AppCodeBlock(code: code, isWrapped: true),
      ToolSnippetFields(:final fields) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One list on the sheet, a hairline between rows.
          for (final (index, field) in fields.indexed) ...[
            if (index > 0) Divider(height: 1, color: colors.hairline),
            HookUpToolField(
              field: field,
              // Looked at, the token is masked. Copied, it is whole.
              shownValue: widget.token.isNotEmpty && field.value == widget.token
                  ? maskToken(widget.token)
                  : null,
            ),
          ],
        ],
      ),
    };
  }
}

/// One numbered step: a disc with the number, then the words, which wrap.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.showsDivider,
  });

  final int number;
  final String text;
  final bool showsDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ink with a yellow number on light, the other way round on dark, so the
    // disc keeps its contrast on the sheet in both.
    final disc = isDark ? colors.yellow : colors.inkFixed;
    final numberColor = isDark ? colors.inkFixed : colors.yellow;
    return Semantics(
      label: '$number. $text',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showsDivider
              ? Border(top: BorderSide(color: colors.hairline))
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.s2),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: disc,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    textScaler: TextScaler.noScaling,
                    style: AppTypography.monoBold(
                      numberColor,
                      fontSize: 13,
                    ).copyWith(height: 1),
                  ),
                ),
                const SizedBox(width: Spacing.s3),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.small(
                      colors.ink,
                      fontSize: 15,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The server address and the token, masked, on the dark panel the curl line
/// uses. Nothing here is a control: the chips under it copy the values.
class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.address, required this.token});

  final String address;
  final String token;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = AppTypography.mono(colors.onPanel, fontSize: 12.5);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.s4,
        vertical: Spacing.s3,
      ),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A zero width space after the slashes, so a long address breaks
          // there before it breaks inside a word.
          Text(address.replaceFirst('://', '://\u200B'), style: style),
          if (token.isNotEmpty)
            Text(
              maskToken(token),
              style: style.copyWith(color: colors.yellow),
            ),
        ],
      ),
    );
  }
}

/// The card that waits for the first message on the steps layout: a dot that
/// blinks, the title, and one mono line that says what to do in the tool.
///
/// When the message lands the card turns into the same row the curl layout
/// shows (`FirstMessageRow`), so what follows a first message is the same on
/// both.
class HookUpWaitingCard extends StatelessWidget {
  const HookUpWaitingCard({
    required this.isReceived,
    required this.lineKey,
    this.isCompact = false,
    super.key,
  });

  final bool isReceived;

  /// The `en.json` key of the mono line.
  final String lineKey;

  /// Passed on to the received row.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(AppDurations.base),
      switchInCurve: AppCurves.easeOut,
      child: isReceived
          ? FirstMessageRow(
              key: const ValueKey('received'),
              isReceived: true,
              isCompact: isCompact,
            )
          : _Waiting(key: const ValueKey('waiting'), line: lineKey.tr()),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.line, super.key});

  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = LocaleKeys.onboarding_hook_up_waiting_title.tr();
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title $line',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s5 - 4,
            vertical: Spacing.s4,
          ),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: Radii.lgAll,
          ),
          child: Row(
            children: [
              const _BlinkDot(),
              const SizedBox(width: Spacing.s3 + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.small(
                        colors.onPanel,
                        fontSize: 16,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: AppTypography.mono(
                        colors.onPanelMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A yellow dot that fades in and out while the app waits. With animations
/// switched off it is drawn lit and nothing runs.
class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.ring,
    value: 1,
  );
  late final Animation<double> _opacity = Tween<double>(begin: 0.35, end: 1)
      .animate(
        CurvedAnimation(parent: _controller, curve: AppCurves.easeOut),
      );
  bool? _isReduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isReduced = context.reduceMotion;
    if (isReduced == _isReduced) return;
    _isReduced = isReduced;
    if (isReduced) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: context.appColors.yellow,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// One field of the tool's form: its name and the whole value, on one line
/// where both fit and stacked where they do not. The value wraps, so a token
/// is never cut short at any text size.
///
/// A value the user pastes has a copy button. A value they only read and
/// pick in the tool's own list has none.
class HookUpToolField extends StatefulWidget {
  const HookUpToolField({required this.field, this.shownValue, super.key});

  final ToolSnippetField field;

  /// What to draw in place of the value, when the value should not be on
  /// screen whole. The copy button still copies the value.
  final String? shownValue;

  @override
  State<HookUpToolField> createState() => _HookUpToolFieldState();
}

class _HookUpToolFieldState extends State<HookUpToolField> {
  bool _isCopied = false;

  void _copy() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.field.value)));
    setState(() => _isCopied = true);
    unawaited(
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final field = widget.field;
    final shown = widget.shownValue ?? field.value;
    final labelStyle = AppTypography.small(colors.ink3, fontSize: 13);
    final valueStyle = AppTypography.monoBold(colors.ink, fontSize: 13);

    final words = LayoutBuilder(
      builder: (context, constraints) {
        double width(String text, TextStyle style) => (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout()).width;
        final fitsOneLine =
            width(field.label, labelStyle) +
                Spacing.s3 +
                width(shown, valueStyle) <=
            constraints.maxWidth;
        if (fitsOneLine) {
          return Row(
            children: [
              Text(field.label, style: labelStyle),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Text(
                  shown,
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(field.label, style: labelStyle),
            const SizedBox(height: 2),
            Text(shown, style: valueStyle),
          ],
        );
      },
    );

    return ConstrainedBox(
      // Every row is as tall as a row with a button, so the list is even.
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        // The small button is a 36 pill in a 48 tap box, which takes the 6
        // above and below that the words keep for themselves.
        padding: EdgeInsets.fromLTRB(
          4,
          field.isCopyable ? 0 : 6,
          0,
          field.isCopyable ? 0 : 6,
        ),
        child: Row(
          children: [
            Expanded(
              child: field.isCopyable
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: words,
                    )
                  : words,
            ),
            if (field.isCopyable) ...[
              const SizedBox(width: Spacing.s2),
              // "Copy" turns into "Copied" in place: say it when it does.
              Semantics(
                liveRegion: true,
                child: AppButton(
                  label: _isCopied
                      ? LocaleKeys.common_copied.tr()
                      : LocaleKeys.common_copy.tr(),
                  variant: AppButtonVariant.paper,
                  size: AppButtonSize.sm,
                  onPressed: _copy,
                ),
              ),
            ] else
              // Lines the value up with the values that have a button.
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
