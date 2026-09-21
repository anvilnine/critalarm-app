import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/prompts/domain/home_ask_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/widgets/consent_prompt_sheet.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';

bool _isAsking = false;

/// Runs whichever ask `HomeAskRules` says is due as home opens or comes
/// back to the front: the consent sheet, the store review popup, or nothing.
///
/// When one is due, waits a moment so home has settled, and gives up if
/// another screen has been pushed on top in the meantime.
Future<void> runHomeAsk(
  BuildContext context, {
  required bool isRinging,
}) async {
  if (_isAsking) return;
  _isAsking = true;
  try {
    final ask = await getIt<HomeAskRules>().next(isRinging: isRinging);
    if (ask == HomeAsk.none) return;

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    switch (ask) {
      case HomeAsk.consent:
        await showConsentPromptSheet(
          context: context,
          repository: getIt<HomePromptRepository>(),
          onShare: _share,
        );
      case HomeAsk.review:
        await _askForReview();
      case HomeAsk.none:
        break;
    }
  } finally {
    _isAsking = false;
  }
}

/// Saves the choice and switches collection on, the same two steps the
/// Privacy screen's switches take.
Future<void> _share({
  required bool crashReports,
  required bool analytics,
}) async {
  final gate = getIt<TelemetryGate>();
  final privacy = getIt<PrivacyRepository>();
  if (crashReports) {
    await gate.setCrashlyticsEnabled(true);
    await privacy.setCrashReportingEnabled(enabled: true);
  }
  if (analytics) {
    await gate.setAnalyticsEnabled(true);
    await privacy.setAnalyticsEnabled(enabled: true);
  }
}

/// The store decides whether its popup really shows, and never says. So the
/// ask counts the moment it is made.
Future<void> _askForReview() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) return;
  await getIt<HomePromptRepository>().markReviewAsked();
  await review.requestReview();
}
