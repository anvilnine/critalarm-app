import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reads the device report, builds a feedback-family form URL and opens it.
/// The Help section's rows and a reminder tap both end up here, so the
/// request shape and the open step exist once.
///
/// Returns null when [base] is blank or the open worked. Otherwise it
/// returns the built URL so the caller can fall back, the way the Help
/// section copies it to the clipboard.
Future<Uri?> openFeedbackForm({
  required String base,
  required String source,
  required String locale,
  required LaunchMode mode,
}) async {
  final report = await getIt<DeviceReportRepository>().read(locale: locale);
  final uri = FeedbackLinks.form(
    base,
    report,
    isRelease: kReleaseMode,
    source: source,
  );
  if (uri == null) return null;
  try {
    if (await launchUrl(uri, mode: mode)) return null;
  } on Exception {
    // Falls through so the caller can fall back.
  }
  return uri;
}
