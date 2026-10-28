import 'package:critalarm/core/telemetry/telemetry_build_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store release build on a phone, with one flag changed at a time.
bool allowed({
  bool isRelease = true,
  bool usesMockApi = false,
  bool skipsPaywall = false,
  bool hasPaywallLab = false,
  bool usesQuietAlarm = false,
  bool blocksTelemetry = false,
  Uri? webPage,
}) => telemetryAllowedFor(
  isRelease: isRelease,
  usesMockApi: usesMockApi,
  skipsPaywall: skipsPaywall,
  hasPaywallLab: hasPaywallLab,
  usesQuietAlarm: usesQuietAlarm,
  blocksTelemetry: blocksTelemetry,
  webPage: webPage,
);

void main() {
  group('telemetryAllowedFor', () {
    test('a store release build on a phone may send', () {
      expect(allowed(), isTrue);
    });

    test('a debug or profile build never sends', () {
      expect(allowed(isRelease: false), isFalse);
      expect(
        allowed(isRelease: false, webPage: Uri.parse('https://critalarm.app/')),
        isFalse,
      );
    });

    test('each desk build flag stops it', () {
      expect(allowed(usesMockApi: true), isFalse);
      expect(allowed(skipsPaywall: true), isFalse);
      expect(allowed(hasPaywallLab: true), isFalse);
      expect(allowed(usesQuietAlarm: true), isFalse);
      expect(allowed(blocksTelemetry: true), isFalse);
    });

    test('the quiet build the Makefile makes never sends', () {
      expect(allowed(skipsPaywall: true, usesQuietAlarm: true), isFalse);
    });

    test('web sends only from the production host', () {
      expect(allowed(webPage: Uri.parse('https://critalarm.app/')), isTrue);
      expect(
        allowed(webPage: Uri.parse('https://dashboard.critalarm.app/topics')),
        isTrue,
      );
      expect(allowed(webPage: Uri.parse('http://localhost:8080/')), isFalse);
      expect(allowed(webPage: Uri.parse('http://127.0.0.1:5173/')), isFalse);
    });

    test('a production web page in a desk build still never sends', () {
      expect(
        allowed(
          skipsPaywall: true,
          webPage: Uri.parse('https://dashboard.critalarm.app/'),
        ),
        isFalse,
      );
    });
  });

  group('isProductionWebPage', () {
    test('https on critalarm.app or a subdomain', () {
      expect(isProductionWebPage(Uri.parse('https://critalarm.app')), isTrue);
      expect(
        isProductionWebPage(Uri.parse('https://app.critalarm.app/#/home')),
        isTrue,
      );
      expect(
        isProductionWebPage(Uri.parse('https://DASHBOARD.critalarm.app/')),
        isTrue,
      );
    });

    test('plain http is not production', () {
      expect(isProductionWebPage(Uri.parse('http://critalarm.app/')), isFalse);
    });

    test('a host that only looks like it is not production', () {
      expect(
        isProductionWebPage(Uri.parse('https://critalarm.app.example.com/')),
        isFalse,
      );
      expect(
        isProductionWebPage(Uri.parse('https://notcritalarm.app/')),
        isFalse,
      );
      expect(
        isProductionWebPage(Uri.parse('https://critalarm-app.pages.dev/')),
        isFalse,
      );
    });

    test('localhost and LAN pages are not production', () {
      expect(
        isProductionWebPage(Uri.parse('https://localhost:8443/')),
        isFalse,
      );
      expect(
        isProductionWebPage(Uri.parse('http://192.168.1.20:8080/')),
        isFalse,
      );
    });
  });
}
