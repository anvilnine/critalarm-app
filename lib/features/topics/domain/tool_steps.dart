import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

/// The setup steps of a tool whose own page in the docs lists them.
///
/// Only Uptime Kuma, Healthchecks and Home Assistant have such a page. Every
/// other tool is set up from the curl line or a pasted snippet alone.
@immutable
class ToolSteps {
  const ToolSteps({required this.keys, required this.blockAfter});

  /// The `en.json` key of each step, in order.
  final List<String> keys;

  /// How many steps come before the block the user copies from (the
  /// tool's fields or code). The steps after it come last.
  final int blockAfter;
}

/// The steps for [template], or null when it has none.
///
/// The last step says what happens when the user presses Test or runs the
/// automation, and that follows the topic's Critical switch. [isCritical]
/// true keeps the sentence "This phone rings." A topic that is not critical
/// does not ring: its first message arrives as a notification, so the
/// sentence is "It lands on this phone." When the switch is not known yet
/// ([isCritical] null) the step makes no promise of a ring, so it takes the
/// second sentence too.
ToolSteps? toolStepsFor(
  ToolTemplate? template, {
  required bool? isCritical,
}) {
  final isRinging = isCritical ?? false;
  return switch (template) {
    ToolTemplate.uptimeKuma => const ToolSteps(
      keys: [
        LocaleKeys.onboarding_hook_up_steps_uptime_kuma_1,
        // The sentence that names the notification type the fields belong to.
        LocaleKeys.onboarding_hook_up_tool_uptime_kuma,
        // Uptime Kuma's Test button posts at the Priority field, which is 3
        // so that a recovery does not ring. A DOWN event uses the other
        // field. So Test lands as a notification whatever the switch says.
        LocaleKeys.onboarding_hook_up_steps_step_test_lands,
      ],
      blockAfter: 2,
    ),
    ToolTemplate.healthchecks => ToolSteps(
      keys: [
        LocaleKeys.onboarding_hook_up_steps_healthchecks_1,
        LocaleKeys.onboarding_hook_up_tool_healthchecks,
        if (isRinging)
          LocaleKeys.onboarding_hook_up_steps_step_test
        else
          LocaleKeys.onboarding_hook_up_steps_step_test_lands,
      ],
      blockAfter: 2,
    ),
    ToolTemplate.homeAssistant => ToolSteps(
      keys: [
        LocaleKeys.onboarding_hook_up_steps_home_assistant_1,
        LocaleKeys.onboarding_hook_up_steps_home_assistant_2,
        if (isRinging)
          LocaleKeys.onboarding_hook_up_steps_home_assistant_3
        else
          LocaleKeys.onboarding_hook_up_steps_home_assistant_3_lands,
      ],
      blockAfter: 1,
    ),
    _ => null,
  };
}

/// The token as it is drawn on screen: `tk_`, the first four and the last
/// four characters after it, with `...` between, as in `tk_da39...a1c9`.
///
/// For display only. A token too short to hide a middle, or one that does not
/// start with `tk_`, masks to `tk_...`. An empty token masks to an empty
/// string.
String maskToken(String token) {
  if (token.isEmpty) return '';
  const prefix = 'tk_';
  if (!token.startsWith(prefix)) return '$prefix...';
  final rest = token.substring(prefix.length);
  if (rest.length < _shortestMaskable) return '$prefix...';
  return '$prefix${rest.substring(0, 4)}...'
      '${rest.substring(rest.length - 4)}';
}

/// Fewer characters after the prefix than this leave no middle to hide.
const int _shortestMaskable = 12;
