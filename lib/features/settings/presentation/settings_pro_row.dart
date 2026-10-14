import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Pro under the plan card in the Settings plan section.
///
/// The same cream card as the plan, so it reads as part of the section:
/// - Owned: the word and a yellow check. Nothing to tap.
/// - Checking: the word and a quiet clock, while a purchase the store
///   confirmed waits for the server. Nothing to tap.
/// - Not owned, or not known: the word, one line and the pill.
///
/// The row draws and reports the tap. Which paywall opens belongs to the
/// caller. It does not depend on the server, so own-server phones get it too.
class SettingsProRow extends StatelessWidget {
  const SettingsProRow({
    required this.state,
    required this.onSee,
    super.key,
  });

  final HoldingState state;

  /// The pill was tapped. Only called where the pill is drawn.
  final VoidCallback onSee;

  @override
  Widget build(BuildContext context) {
    final title = LocaleKeys.settings_pro_title.tr();
    switch (state) {
      case HoldingState.held:
        return SettingsPlanCard(
          title: title,
          titleMark: _OwnedMark(
            label: LocaleKeys.settings_pro_owned_label.tr(),
          ),
        );
      case HoldingState.pending:
        return SettingsPlanCard(
          title: title,
          titleMark: _CheckingMark(
            label: LocaleKeys.settings_pro_checking_label.tr(),
          ),
        );
      case HoldingState.notHeld:
      case HoldingState.unknown:
        return SettingsPlanCard(
          title: title,
          usage: LocaleKeys.settings_pro_line.tr(),
          actionLabel: LocaleKeys.settings_pro_button.tr(),
          onAction: onSee,
        );
    }
  }
}

/// [size] grown with the text, as far as chrome text grows, so a mark does
/// not shrink next to a larger word.
double _markSize(BuildContext context, double size) => MediaQuery.textScalerOf(
  context,
).clamp(maxScaleFactor: kChromeMaxTextScale).scale(size);

/// The Crit yellow with a dark outline, as the badge has, and a check.
class _OwnedMark extends StatelessWidget {
  const _OwnedMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = _markSize(context, 20);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: colors.inkFixed, width: 1.5),
          ),
          child: AppGlyph(
            GlyphType.check,
            size: size * 0.55,
            strokeWidth: 3,
            color: colors.inkFixed,
          ),
        ),
      ),
    );
  }
}

class _CheckingMark extends StatelessWidget {
  const _CheckingMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: AppGlyph(
          GlyphType.clock,
          size: _markSize(context, 16),
          strokeWidth: 2.4,
          color: colors.ink3,
        ),
      ),
    );
  }
}
