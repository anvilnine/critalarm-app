import 'package:critalarm/features/feedback/domain/device_report.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/presentation/open_feedback_form.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

/// Uses the existing form when configured, otherwise the existing report email.
class LanguageFeedback {
  LanguageFeedback({
    required this.readReport,
    this.formUrl = FeedbackLinks.feedbackFormUrl,
    this.openForm = openFeedbackForm,
    this.launch = launchUrl,
  });

  final Future<DeviceReport> Function({required String locale}) readReport;
  final String formUrl;
  final Future<Uri?> Function({
    required String base,
    required String source,
    required String locale,
    required LaunchMode mode,
  }) openForm;
  final Future<bool> Function(Uri uri, {required LaunchMode mode}) launch;

  Future<Uri?> open(String locale, String screen) async {
    if (formUrl.isNotEmpty) {
      return openForm(
        base: formUrl,
        source: screen,
        locale: locale,
        mode: LaunchMode.inAppBrowserView,
      );
    }
    final report = await readReport(locale: locale);
    final uri = FeedbackLinks.reportMail(
      report,
      email: FeedbackLinks.supportEmail,
      subject: '${LocaleKeys.settings_help_report_subject.tr()} '
          '[$locale: $screen]',
    );
    try {
      if (await launch(uri, mode: LaunchMode.externalApplication)) return null;
    } on Exception {
      // Return the prepared mail URL for the caller's existing copy fallback.
    }
    return uri;
  }
}
