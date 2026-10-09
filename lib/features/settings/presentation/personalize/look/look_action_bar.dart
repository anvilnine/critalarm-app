import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/try_bar.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The hint line and the one control under the deck.
///
/// The control follows the look in the middle: a status when it is the look
/// that rings, a button to use it, the try bar when it is locked, or "Add your
/// photo" on an empty Yours. The tap on the button and on the try bar is the
/// person's act of using the look, and [onKeep] decides what that does.
///
/// The colours follow [page] through [fade], so the bar fades with the ground.
class LookActionBar extends StatelessWidget {
  const LookActionBar({
    required this.action,
    required this.hint,
    required this.confirming,
    required this.fade,
    required this.page,
    required this.onKeep,
    super.key,
  });

  final LookAction action;

  /// The hint line, already translated.
  final String hint;

  /// The holding being confirmed, or null.
  final Holding? confirming;

  final LookFade fade;
  final ValueListenable<double> page;

  /// The tap that uses or keeps the centred look.
  final VoidCallback onKeep;

  /// The height of the pill.
  static const double pillHeight = 58;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.s4,
      Spacing.s2,
      Spacing.s4,
      Spacing.s3,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hint(text: hint, fade: fade, page: page),
        const SizedBox(height: Spacing.s2),
        if (confirming != null && action.control != LookControl.inUse) ...[
          PersonalizeTryBar(bar: TryBarConfirming(confirming!), onKeep: onKeep),
          const SizedBox(height: Spacing.s2),
        ],
        _held(_control()),
      ],
    ),
  );

  /// Holds the control in a box as tall as the tallest one can be, so the deck
  /// above does not change size when a swipe changes the control.
  Widget _held(Widget control) => Stack(
    alignment: Alignment.center,
    children: [
      // The tallest control, drawn invisibly. It takes no touch and no
      // screen reader stop.
      Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: PersonalizeTryBar(
          bar: const TryBarSell(AppFeature.alarmScreenStyles, Holding.pro),
          onKeep: onKeep,
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: pillHeight),
        child: control,
      ),
    ],
  );

  Widget _control() {
    if (action.showsTryBar) {
      return PersonalizeTryBar(
        bar: TryBarSell(AppFeature.alarmScreenStyles, action.badge!),
        onKeep: onKeep,
      );
    }
    return switch (action.control) {
      LookControl.inUse => _Pill(
        key: const ValueKey('look-in-use'),
        label: LocaleKeys.personalize_passes_look_in_use.tr(),
        glyph: GlyphType.check,
        isFilled: false,
        fade: fade,
        page: page,
      ),
      LookControl.use => _Pill(
        key: const ValueKey('look-use'),
        label: LocaleKeys.personalize_passes_look_use.tr(),
        isFilled: true,
        fade: fade,
        page: page,
        onTap: onKeep,
      ),
      LookControl.addPhoto => _Pill(
        key: const ValueKey('look-add-photo'),
        label: LocaleKeys.alarm_styles_own_add_label.tr(),
        glyph: GlyphType.plus,
        isFilled: true,
        badge: action.badge,
        fade: fade,
        page: page,
        onTap: onKeep,
      ),
    };
  }
}

/// The hint line: mono, 12 points, in the page's text colour, announced once
/// when it changes.
class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.fade, required this.page});

  final String text;
  final LookFade fade;
  final ValueListenable<double> page;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: ValueListenableBuilder<double>(
      valueListenable: page,
      builder: (context, page, _) => Text(
        text,
        textAlign: TextAlign.center,
        // A label, so it stops growing at the chrome's text size and leaves
        // the room under the deck to the action.
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: kChromeMaxTextScale),
        style: AppTypography.mono(fade.textAt(page), fontSize: 12),
      ),
    ),
  );
}

/// A wide pill in the page's colours: filled in the text colour with the
/// ground on it, or outlined in the text colour. Filled it is a button.
/// Outlined it is a status.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isFilled,
    required this.fade,
    required this.page,
    this.glyph,
    this.badge,
    this.onTap,
    super.key,
  });

  final String label;
  final GlyphType? glyph;
  final bool isFilled;
  final Holding? badge;
  final LookFade fade;
  final ValueListenable<double> page;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = ValueListenableBuilder<double>(
      valueListenable: page,
      builder: (context, page, _) {
        final text = fade.textAt(page);
        final ground = fade.groundAt(page);
        final ink = isFilled ? ground : text;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: LookActionBar.pillHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.s5,
            vertical: Spacing.s2,
          ),
          decoration: BoxDecoration(
            color: isFilled ? text : null,
            borderRadius: BorderRadius.circular(LookActionBar.pillHeight / 2),
            border: isFilled ? null : Border.all(color: text, width: 2),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.s2,
            runSpacing: Spacing.s1,
            children: [
              if (glyph != null) AppGlyph(glyph!, size: 20, color: ink),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.body(ink).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (badge != null)
                ProBadge(label: planWordFor(badge!), isLocked: true),
            ],
          ),
        );
      },
    );
    final onTap = this.onTap;
    if (onTap == null) {
      return Semantics(container: true, label: label, child: body);
    }
    return Semantics(
      button: true,
      label: badge == null
          ? label
          : LocaleKeys.feature_lock_sheet_option.tr(
              namedArgs: {'name': label, 'plan': planWordFor(badge!)},
            ),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
  }
}
