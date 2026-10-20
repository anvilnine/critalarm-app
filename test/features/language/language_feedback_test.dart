import 'package:critalarm/app/l10n/language_feedback.dart';
import 'package:critalarm/features/feedback/domain/device_report.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

DeviceReport _report(String locale) => DeviceReport(
  appVersion: '1',
  buildNumber: '2',
  device: 'phone',
  os: 'test',
  server: 'none',
  plan: 'free',
  pro: 'no',
  locale: locale,
);

void main() {
  test(
    'configured form receives locale and source in the in-app browser',
    () async {
      final feedback = LanguageFeedback(
        formUrl: 'https://example.test/feedback',
        readReport: ({required locale}) async => throw StateError('not email'),
        openForm:
            ({
              required base,
              required source,
              required locale,
              required mode,
            }) async {
              expect(base, 'https://example.test/feedback');
              expect(locale, 'ja');
              expect(source, 'about');
              expect(mode, LaunchMode.inAppBrowserView);
              return null;
            },
      );
      expect(await feedback.open('ja', 'about'), isNull);
    },
  );

  test(
    'blank form uses existing email with language and screen prefilled',
    () async {
      Uri? opened;
      final feedback = LanguageFeedback(
        readReport: ({required locale}) async => _report(locale),
        launch: (uri, {required mode}) async {
          opened = uri;
          expect(mode, LaunchMode.externalApplication);
          return true;
        },
      );
      expect(await feedback.open('de', 'language'), isNull);
      expect(opened!.scheme, 'mailto');
      expect(opened!.path, FeedbackLinks.supportEmail);
      expect(opened!.queryParameters['subject'], contains('[de: language]'));
      expect(opened!.queryParameters['body'], contains('Language: de'));
    },
  );

  test(
    'email failure returns prepared URL instead of silently losing report',
    () async {
      final feedback = LanguageFeedback(
        readReport: ({required locale}) async => _report(locale),
        launch: (_, {required mode}) async => false,
      );
      expect((await feedback.open('en', 'language'))!.scheme, 'mailto');
    },
  );
}
