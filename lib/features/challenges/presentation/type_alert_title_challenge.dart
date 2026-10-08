import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/type_alert_title_match.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Type the first words of the alert title.
///
/// The title is on screen, right over the field, with the words to type in
/// bold. What is typed is compared with those words by a plain string
/// match (see `type_alert_title_match.dart`). Nothing is read, logged or
/// sent.
final class TypeAlertTitleChallenge implements Challenge {
  const TypeAlertTitleChallenge();

  @override
  ChallengeKind get kind => ChallengeKind.typeAlertTitle;

  @override
  String get nameKey => LocaleKeys.challenges_type_alert_title_name;

  @override
  String get promptKey => LocaleKeys.challenges_type_alert_title_prompt;

  /// Only when the screen shows a real title. A hidden title is a fallback
  /// line the screen made up, which the incident marks by passing no
  /// `alertTitle`, and asking for it would ask for words nobody wrote.
  @override
  bool canRunFor(ChallengeIncident incident) =>
      alertTitleWordsToType(incident.alertTitle).isNotEmpty;

  @override
  Widget build(BuildContext context, ChallengeRun run) =>
      _TypeAlertTitle(run: run);
}

/// The size the title is shown at: a step down at each of two lengths, so
/// a long one stays readable above the keyboard without being cut.
double alertTitleFontSize(String title) {
  final length = title.trim().length;
  if (length <= 30) return 22;
  if (length <= 80) return 18;
  return 16;
}

class _TypeAlertTitle extends StatefulWidget {
  const _TypeAlertTitle({required this.run});

  final ChallengeRun run;

  @override
  State<_TypeAlertTitle> createState() => _TypeAlertTitleState();
}

class _TypeAlertTitleState extends State<_TypeAlertTitle> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _didPass = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _check(String typed) {
    if (_didPass) return;
    if (!alertTitleMatches(
      typed: typed,
      title: widget.run.incident.alertTitle,
    )) {
      return;
    }
    _didPass = true;
    widget.run.onPassed();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_redraw)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = widget.run.incident.alertTitle ?? '';
    final isPicture = widget.run.isPicture;
    final size = alertTitleFontSize(title);
    final asked = alertTitleWordsToType(title).join(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          sortKey: const OrdinalSortKey(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.canvasGhostStrong,
              borderRadius: Radii.mdAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s4,
                vertical: Spacing.s3,
              ),
              // No line limit: the whole title is shown, and the words to
              // type are the bold ones.
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final part in alertTitleParts(title))
                      TextSpan(
                        text: part.text,
                        style: part.isAsked
                            ? AppTypography.monoBold(
                                colors.onCanvas,
                                fontSize: size,
                              )
                            : AppTypography.mono(
                                colors.onCanvas,
                                fontSize: size - 2,
                              ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.s3),
        Semantics(
          sortKey: const OrdinalSortKey(2),
          label: LocaleKeys.challenges_type_alert_title_field_label.tr(
            namedArgs: {'words': asked},
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(
                color: _focus.hasFocus ? colors.ink : colors.hairline,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.s4,
                vertical: Spacing.s3,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: !isPicture,
                readOnly: isPicture,
                canRequestFocus: !isPicture,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                scrollPadding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
                style: AppTypography.monoBold(colors.ink, fontSize: 22),
                cursorColor: colors.cobalt,
                onChanged: _check,
                onSubmitted: _check,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.s2),
        ExcludeSemantics(
          child: Text(
            LocaleKeys.challenges_type_alert_title_hint.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.onCanvas, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
