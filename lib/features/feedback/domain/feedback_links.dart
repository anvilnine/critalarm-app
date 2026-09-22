import 'package:critalarm/features/feedback/domain/device_report.dart';

/// Where the Help rows in Settings go.
///
/// The forms follow `docs/feedback-forms.md` at the Anvil Nine root: one
/// form per kind on `forms.zonily.cloud`, with the context passed as query
/// parameters the form stores in hidden fields.
abstract final class FeedbackLinks {
  /// Problem reports land here.
  static const String supportEmail = 'support@critalarm.app';

  /// The feedback form. Blank hides its row until the form exists.
  static const String feedbackFormUrl = '';

  /// The feature request form. Blank hides its row until the form exists.
  static const String featureFormUrl = '';

  /// The numeric App Store id, needed to open the listing on iOS. Blank hides
  /// the Rate row on iOS. Android finds the listing by package name.
  static const String appStoreId = '';

  /// `source` for a form opened from Settings > Help.
  static const String settingsSource = 'settings';

  /// `source` for the feedback reminder (idea 22).
  static const String reminderSource = 'reminder_feedback';

  /// A `mailto:` link with [subject] and room to type above the device
  /// info.
  ///
  /// Built by hand because `Uri(queryParameters:)` turns spaces into `+`,
  /// which mail apps show as a literal plus.
  static Uri reportMail(
    DeviceReport report, {
    required String email,
    required String subject,
  }) {
    final body = '\n\n\n${report.mailFooter}';
    return Uri.parse(
      'mailto:$email'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
  }

  /// [base] with the hidden field values added, or null while [base] is
  /// blank.
  static Uri? form(
    String base,
    DeviceReport report, {
    required bool isRelease,
    required String source,
  }) {
    if (base.isEmpty) return null;
    return Uri.parse(base).replace(
      queryParameters: {
        'app': 'critalarm',
        'env': isRelease ? 'prod' : 'dev',
        'source': source,
        'version': '${report.appVersion}+${report.buildNumber}',
        'locale': report.locale,
        'plan': report.plan,
        'os': report.os,
        'device': report.device,
      },
    );
  }
}
