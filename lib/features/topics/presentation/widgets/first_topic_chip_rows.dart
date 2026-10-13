import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// "or", and under it one line of other names for the first topic. A tap puts
/// the name in the field.
class FirstTopicNameChips extends StatelessWidget {
  const FirstTopicNameChips({
    required this.names,
    required this.onTap,
    super.key,
  });

  final List<String> names;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onTap = this.onTap;

    return _ChipSection(
      label: LocaleKeys.first_topic_answer_or.tr(),
      chips: [
        for (final name in names)
          _SetupChip(
            text: name,
            style: AppTypography.mono(
              colors.ink,
              fontSize: 13,
            ).copyWith(height: 1),
            onTap: onTap == null ? null : () => onTap(name),
          ),
      ],
    );
  }
}

/// "What sends it", and under it one line of tools for the first topic, in
/// the order given. The picked one has the filled look.
class FirstTopicToolChips extends StatelessWidget {
  const FirstTopicToolChips({
    required this.tools,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final List<ToolTemplate> tools;
  final ToolTemplate? selected;
  final ValueChanged<ToolTemplate>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onTap = this.onTap;

    return _ChipSection(
      label: LocaleKeys.first_topic_answer_what_sends_it.tr(),
      chips: [
        for (final tool in tools)
          // No chip for "something else": picking none already means it.
          if (tool.label case final label?)
            _SetupChip(
              // Tool names are product names and stay as they are.
              text: label,
              style: AppTypography.small(
                colors.ink,
              ).copyWith(fontWeight: FontWeight.w600, height: 1),
              isSelected: tool == selected,
              onTap: onTap == null ? null : () => onTap(tool),
            ),
      ],
    );
  }
}

/// A small label over a line of chips.
class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.label, required this.chips});

  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.small(
            colors.ink3,
            fontSize: 12,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        // The chips sit in 48 high tap boxes, 6 above the pill: 4 more here
        // makes the pill 10 under the label.
        const SizedBox(height: 4),
        _ChipLine(chips: chips),
      ],
    );
  }
}

/// One line of chips, 8 apart, that scrolls sideways at any text size and
/// fades out at its end while there is more to scroll to.
///
/// The fade is read when the line is painted, after it has been laid out, so
/// the first frame already has it right. At the end of the line the last chip
/// is whole.
class _ChipLine extends StatefulWidget {
  const _ChipLine({required this.chips});

  final List<Widget> chips;

  @override
  State<_ChipLine> createState() => _ChipLineState();
}

class _ChipLineState extends State<_ChipLine> {
  /// How wide the fade at the end is.
  static const double _fadeWidth = 36;

  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The mask for a line [bounds] wide: solid, then easing out over the last
  /// [_fadeWidth] while there is more beyond the end.
  Shader _mask(Rect bounds, ui.TextDirection direction) {
    var moreAfter = _fadeWidth;
    if (_controller.hasClients && _controller.position.hasContentDimensions) {
      moreAfter = _controller.position.extentAfter;
    }
    final strength = (moreAfter / _fadeWidth).clamp(0.0, 1.0);
    final from = (1 - _fadeWidth / bounds.width).clamp(0.0, 1.0);
    return LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [
        Colors.black,
        Colors.black,
        Colors.black.withValues(alpha: 1 - strength),
      ],
      stops: [0, from, 1],
    ).createShader(bounds, textDirection: direction);
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final line = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < widget.chips.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.s2),
            widget.chips[i],
          ],
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: line,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => _mask(bounds, direction),
        child: child,
      ),
    );
  }
}

/// A pill that is 36 high or more, in a 48 high tap box that takes the tap.
///
/// Colours are the ones [AppTopicChip] has: cobalt tint, and the filled
/// highlight when picked.
class _SetupChip extends StatelessWidget {
  const _SetupChip({
    required this.text,
    required this.style,
    required this.onTap,
    this.isSelected = false,
  });

  final String text;
  final TextStyle style;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final chip = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? colors.highlight : colors.cobaltTint,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: style.copyWith(
          color: isSelected ? colors.onHighlight : colors.ink,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AppTapTarget(child: chip),
        ),
      ),
    );
  }
}
