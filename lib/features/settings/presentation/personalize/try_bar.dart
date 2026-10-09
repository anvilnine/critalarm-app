import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The one quiet bar under the deck of looks.
///
/// While a locked option is being tried it shows the plan badge, that the
/// try is not saved, and one button that keeps the look. The button is the
/// person's act of using it, so what it does is [onKeep]'s to say: the page
/// asks the lock rule and opens the paywall only then. While a purchase is
/// being confirmed the bar is one line. Otherwise it takes no room. It names
/// no price and lists no benefit: that is the paywall's job.
class PersonalizeTryBar extends StatelessWidget {
  const PersonalizeTryBar({
    required this.bar,
    required this.onKeep,
    super.key,
  });

  final TryBar bar;

  /// The button on the bar: use the look that is being tried.
  final VoidCallback onKeep;

  /// Under this width the bar has no room for its words.
  static const double _wordsMinWidth = 260;

  /// Under this width, or at large text, the button goes under the words.
  static const double _rowMinWidth = 300;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bar = this.bar;
    final content = switch (bar) {
      TryBarHidden() => const SizedBox(width: double.infinity),
      TryBarSell() => _shell(
        colors,
        LayoutBuilder(
          builder: (context, box) {
            final badge = ProBadge(
              label: planWordFor(bar.offer),
              isLocked: true,
            );
            final words = Text(
              LocaleKeys.personalize_try_not_saved.tr(),
              style: AppTypography.small(colors.ink2, fontSize: 13),
            );
            final button = AppButton(
              label: LocaleKeys.personalize_try_button.tr(),
              size: AppButtonSize.sm,
              onPressed: onKeep,
            );
            final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (isLarge || box.maxWidth < _rowMinWidth) {
              // No room for the words and the button side by side: the
              // badge and the words on one line, the button under them.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Spacing.s2,
                    runSpacing: Spacing.s1,
                    children: [badge, words],
                  ),
                  const SizedBox(height: Spacing.s2),
                  button,
                ],
              );
            }
            return Row(
              children: [
                badge,
                const SizedBox(width: Spacing.s2),
                Expanded(
                  child: box.maxWidth < _wordsMinWidth
                      ? const SizedBox.shrink()
                      : words,
                ),
                const SizedBox(width: Spacing.s2),
                button,
              ],
            );
          },
        ),
      ),
      TryBarConfirming() => _shell(
        colors,
        Text(
          LocaleKeys.personalize_try_confirming.tr(),
          style: AppTypography.small(colors.ink2, fontSize: 13),
        ),
      ),
    };
    final spoken = Semantics(
      key: ValueKey(bar.runtimeType),
      container: true,
      liveRegion: bar is! TryBarHidden,
      child: content,
    );
    // Under reduce motion the bar cuts in. A zero-length AnimatedSize is
    // not a cut: it lays itself out twice.
    if (context.reduceMotion) return spoken;
    return AnimatedSize(
      duration: AppDurations.quick,
      curve: AppCurves.easeOut,
      alignment: Alignment.topCenter,
      child: spoken,
    );
  }

  Widget _shell(AppColors colors, Widget child) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    alignment: AlignmentDirectional.centerStart,
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: Radii.mdAll,
    ),
    child: child,
  );
}
