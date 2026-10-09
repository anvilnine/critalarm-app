import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/ops_math_question.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One developer-flavoured sum, answered on a number pad.
///
/// The question comes from a fixed generator (`ops_math_question.dart`),
/// chosen once when the challenge opens. A wrong answer clears the field
/// and keeps the same question. It reads nothing from the alarm.
final class OpsMathChallenge implements Challenge {
  const OpsMathChallenge();

  @override
  ChallengeKind get kind => ChallengeKind.opsMath;

  @override
  String get nameKey => LocaleKeys.challenges_ops_math_name;

  @override
  String get promptKey => LocaleKeys.challenges_ops_math_prompt;

  /// A sum needs nothing from the alarm.
  @override
  bool canRunFor(ChallengeIncident incident) => true;

  @override
  Widget build(BuildContext context, ChallengeRun run) => _OpsMath(run: run);
}

/// The question as a sentence, from the strings.
String opsMathQuestionText(OpsMathQuestion question) {
  final args = {'value': question.operandText};
  return switch (question.kind) {
    OpsMathKind.hexToDecimal => LocaleKeys.challenges_ops_math_q_hex.tr(
      namedArgs: args,
    ),
    OpsMathKind.powerOfTwo => LocaleKeys.challenges_ops_math_q_power.tr(
      namedArgs: args,
    ),
    OpsMathKind.secondsInMinutes => LocaleKeys.challenges_ops_math_q_minutes.tr(
      namedArgs: args,
    ),
    OpsMathKind.secondsInHours => LocaleKeys.challenges_ops_math_q_hours.tr(
      namedArgs: args,
    ),
    OpsMathKind.kilobytesInMegabytes =>
      LocaleKeys.challenges_ops_math_q_megabytes.tr(namedArgs: args),
  };
}

class _OpsMath extends StatefulWidget {
  const _OpsMath({required this.run});

  final ChallengeRun run;

  @override
  State<_OpsMath> createState() => _OpsMathState();
}

class _OpsMathState extends State<_OpsMath> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final OpsMathQuestion _question;
  bool _didPass = false;
  bool _wasWrong = false;

  @override
  void initState() {
    super.initState();
    _question = widget.run.isPicture
        ? OpsMathQuestion.sample
        : opsMathQuestion(DateTime.now().microsecondsSinceEpoch);
    _focus.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// [isFinal] is true when the person pressed done: a wrong answer is
  /// then wrong whatever its length.
  void _check(String typed, {bool isFinal = false}) {
    if (_didPass) return;
    // A number pad has no done key on iOS, so an answer as long as the
    // right one is judged as soon as it is typed.
    switch (opsMathJudge(
      typed: typed,
      answer: _question.answer,
      isFinal: isFinal,
    )) {
      case OpsMathVerdict.right:
        _didPass = true;
        widget.run.onPassed();
      case OpsMathVerdict.wrong:
        _controller.clear();
        setState(() => _wasWrong = true);
      case OpsMathVerdict.waiting:
        if (_wasWrong && typed.isNotEmpty) setState(() => _wasWrong = false);
    }
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
    final isPicture = widget.run.isPicture;
    final text = opsMathQuestionText(_question);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.canvasGhostStrong,
            borderRadius: Radii.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s4,
              vertical: Spacing.s4,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.monoBold(colors.onCanvas, fontSize: 22),
            ),
          ),
        ),
        const SizedBox(height: Spacing.s3),
        Semantics(
          label: text,
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
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                scrollPadding: challengeFieldScrollPadding,
                style: AppTypography.monoBold(colors.ink, fontSize: 24),
                cursorColor: colors.cobalt,
                onChanged: _check,
                onSubmitted: (typed) => _check(typed, isFinal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        // The number pad has nothing but numbers, so no line says so. The
        // only line here is the one after a wrong answer.
        if (_wasWrong) ...[
          const SizedBox(height: Spacing.s2),
          Semantics(
            liveRegion: true,
            child: Text(
              LocaleKeys.challenges_ops_math_wrong.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.small(colors.onCanvas, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}
