import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/material.dart';

/// The top bar's title on a screen whose header carries its own label.
///
/// It is clear while the header sits under the bar, and comes in once the
/// header has scrolled up under the bar. It follows the scroll position of
/// [controller], so reduced motion has nothing to turn off.
class AppScrollBarTitle extends StatelessWidget {
  const AppScrollBarTitle({
    required this.controller,
    required this.title,
    super.key,
  });

  final ScrollController controller;
  final String title;

  /// The scroll distance at which the title starts to come in, and the
  /// distance it takes to be whole. The header label is under the bar a
  /// little after the first.
  static const double from = 12;
  static const double span = 24;

  /// How much of the title shows with the list scrolled to [offset], 0 to 1.
  static double shownAt(double offset) =>
      ((offset - from) / span).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final shown = shownAt(offset);
        return ExcludeSemantics(
          excluding: shown < 1,
          child: Semantics(
            header: true,
            child: Opacity(
              opacity: shown,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headline(
                  colors.onCanvas,
                  fontSize: 18,
                ).copyWith(letterSpacing: -0.02 * 18),
              ),
            ),
          ),
        );
      },
    );
  }
}
