import 'package:flutter/material.dart';

/// The font size at which the longest word of a title fits on one line.
///
/// [fontSize] is the size the title wants, [longestWordWidth] how wide its
/// longest word is at that size, [maxWidth] the room it has. The answer is
/// never larger than [fontSize] and never smaller than [minFontSize].
double fittedFontSize({
  required double fontSize,
  required double longestWordWidth,
  required double maxWidth,
  double minFontSize = 20,
}) {
  if (longestWordWidth <= maxWidth || longestWordWidth <= 0) return fontSize;
  final fitted = fontSize * maxWidth / longestWordWidth;
  return fitted.clamp(minFontSize, fontSize);
}

/// A display title that never breaks in the middle of a word.
///
/// A big title on a narrow phone can be wider than the screen as one word,
/// and plain text then breaks it wherever the line ends. This scales the
/// type down until the longest word fits. Between words it wraps like any
/// text, which is what a large text size should do.
class AppFittedTitle extends StatelessWidget {
  const AppFittedTitle(
    this.text, {
    required this.style,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final String text;

  /// The style at full size. Its `fontSize` must be set.
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final fontSize = style.fontSize!;

    return LayoutBuilder(
      builder: (context, constraints) {
        var longest = 0.0;
        for (final word in text.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > longest) longest = painter.width;
          painter.dispose();
        }
        final fitted = fittedFontSize(
          fontSize: fontSize,
          // A hair of slack, so rounding never tips a word over the edge.
          longestWordWidth: longest + 1,
          maxWidth: constraints.maxWidth,
        );
        final spacing = style.letterSpacing;
        return Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(
            fontSize: fitted,
            // Tracking is set in pixels, so it shrinks with the type.
            letterSpacing: spacing == null ? null : spacing * fitted / fontSize,
          ),
        );
      },
    );
  }
}
