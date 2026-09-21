import 'package:critalarm/features/feedback/domain/device_report.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const report = DeviceReport(
    appVersion: '0.1.0',
    buildNumber: '5',
    device: 'iPhone15,2',
    os: 'iOS 26.0',
    server: 'hosted',
    plan: 'free',
    locale: 'en-PH',
  );

  group('DeviceReport.mailFooter', () {
    test('lists every field under a separator', () {
      expect(
        report.mailFooter,
        '--\n'
        'App: 0.1.0 (5)\n'
        'Phone: iPhone15,2 · iOS 26.0\n'
        'Server: hosted · Plan: free\n'
        'Language: en-PH',
      );
    });
  });

  group('FeedbackLinks.reportMail', () {
    final uri = FeedbackLinks.reportMail(
      report,
      email: 'support@critalarm.app',
      subject: 'Crit Alarm problem',
    );

    test('addresses the support inbox', () {
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@critalarm.app');
    });

    test('encodes spaces as %20, never +', () {
      final text = uri.toString();
      expect(text, contains('subject=Crit%20Alarm%20problem'));
      expect(text, isNot(contains('+')));
    });

    test('leaves room to type above the device info', () {
      final body = Uri.decodeComponent(
        uri.toString().split('body=').last,
      );
      expect(body, '\n\n\n${report.mailFooter}');
    });
  });

  group('FeedbackLinks.form', () {
    test('adds the hidden fields to the form link', () {
      final uri = FeedbackLinks.form(
        'https://forms.zonily.cloud/form/abc123',
        report,
        isRelease: true,
      )!;
      expect(uri.host, 'forms.zonily.cloud');
      expect(uri.path, '/form/abc123');
      expect(uri.queryParameters, {
        'app': 'critalarm',
        'env': 'prod',
        'source': 'settings',
        'version': '0.1.0+5',
        'locale': 'en-PH',
        'plan': 'free',
        'os': 'iOS 26.0',
        'device': 'iPhone15,2',
      });
    });

    test('marks debug builds as dev', () {
      final uri = FeedbackLinks.form(
        'https://forms.zonily.cloud/form/abc123',
        report,
        isRelease: false,
      )!;
      expect(uri.queryParameters['env'], 'dev');
    });

    test('has no link while the form address is blank', () {
      expect(FeedbackLinks.form('', report, isRelease: true), isNull);
    });
  });
}
