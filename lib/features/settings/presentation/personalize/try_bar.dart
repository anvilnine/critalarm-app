import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The one quiet bar under the preview.
///
/// While a locked option is being tried it shows the plan badge, that the
/// try is not saved, and one button that opens the paywall. While a
/// purchase is being confirmed it is one line. Otherwise it takes no room.
/// It names no price and lists no benefit: that is the paywall's job.
class PersonalizeTryBar extends StatelessWidget {
  const PersonalizeTryBar({
    required this.bar,
    required this.sourceFor,
    super.key,
  });

  final TryBar bar;

  /// Where the paywall is opened from for the section being tried.
  final LockSource? Function(TryBarSell bar) sourceFor;

  /// Under this width the bar has no room for its words.
  static const double _wordsMinWidth = 260;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bar = this.bar;
    final content = switch (bar) {
      TryBarHidden() => const SizedBox(width: double.infinity),
      TryBarSell() => _shell(
        colors,
        LayoutBuilder(
          // Beside the choices the bar is narrow: the badge and the button
          // stay, the words go.
          builder: (context, box) => Row(
            children: [
              ProBadge(label: planWordFor(bar.offer), isLocked: true),
              const SizedBox(width: Spacing.s2),
              Expanded(
                child: box.maxWidth < _wordsMinWidth
                    ? const SizedBox.shrink()
                    : Text(
                        LocaleKeys.personalize_try_not_saved.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.small(colors.ink2, fontSize: 13),
                      ),
              ),
              const SizedBox(width: Spacing.s2),
              AppButton(
                label: LocaleKeys.personalize_try_button.tr(),
                size: AppButtonSize.sm,
                onPressed: () {
                  final source = sourceFor(bar);
                  if (source == null) return;
                  unawaited(
                    openPaywallForFeature(context, bar.feature, source),
                  );
                },
              ),
            ],
          ),
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

  Widget _shell(AppColors colors, Widget child) => Padding(
    padding: const EdgeInsets.only(top: Spacing.s3),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.mdAll,
      ),
      child: child,
    ),
  );
}
