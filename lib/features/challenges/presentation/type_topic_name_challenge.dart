import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/type_topic_name_match.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Type the name of the topic that rang.
///
/// The name is on screen, right over the field. What is typed is compared
/// with it, capitals and outer spaces aside. No timer, and a wrong try
/// costs nothing: the field just waits.
final class TypeTopicNameChallenge implements Challenge {
  const TypeTopicNameChallenge();

  @override
  ChallengeKind get kind => ChallengeKind.typeTopicName;

  @override
  String get nameKey => LocaleKeys.challenges_type_topic_name_name;

  @override
  String get promptKey => LocaleKeys.challenges_type_topic_name_prompt;

  /// A topic always has a name. An empty one could never be matched, so
  /// it asks for nothing.
  @override
  bool canRunFor(ChallengeIncident incident) =>
      incident.topic.trim().isNotEmpty;

  @override
  Widget build(BuildContext context, ChallengeRun run) =>
      _TypeTopicName(run: run);
}

class _TypeTopicName extends StatefulWidget {
  const _TypeTopicName({required this.run});

  final ChallengeRun run;

  @override
  State<_TypeTopicName> createState() => _TypeTopicNameState();
}

class _TypeTopicNameState extends State<_TypeTopicName> {
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
    if (!topicNameMatches(typed: typed, topic: widget.run.incident.topic)) {
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
    final topic = widget.run.incident.topic;
    final isPicture = widget.run.isPicture;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The name to copy, right over the field so both sit above the
        // keyboard together.
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
              child: Text(
                topic,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.monoBold(colors.onCanvas, fontSize: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.s3),
        Semantics(
          sortKey: const OrdinalSortKey(2),
          // A screen reader lands here first, so the field says what to
          // type.
          label: LocaleKeys.challenges_type_topic_name_field_label.tr(
            namedArgs: {'topic': topic},
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(
                color: _focus.hasFocus ? colors.cobalt : colors.hairline,
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
                // The keyboard is up the moment the challenge is.
                autofocus: !isPicture,
                readOnly: isPicture,
                canRequestFocus: !isPicture,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                // Room for the way out, pinned under the field.
                scrollPadding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
                style: AppTypography.monoBold(colors.ink, fontSize: 24),
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
            LocaleKeys.challenges_type_topic_name_hint.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.small(colors.onCanvas, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
