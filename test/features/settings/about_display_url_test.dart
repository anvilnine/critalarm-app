import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aboutDisplayUrl', () {
    test('drops https', () {
      expect(
        aboutDisplayUrl('https://github.com/anvilnine/critalarm-app'),
        'github.com/anvilnine/critalarm-app',
      );
    });

    test('drops http', () {
      expect(aboutDisplayUrl('http://example.com/a'), 'example.com/a');
    });

    test('leaves a scheme-less value alone', () {
      expect(aboutDisplayUrl('critalarm.app/docs/'), 'critalarm.app/docs/');
    });
  });
}
