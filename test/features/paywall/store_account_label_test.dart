import 'package:critalarm/features/paywall/domain/entities/store_account_label.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

  group('storeAccountLabelFor', () {
    // The renewal sentence has to name the place the money comes from, and
    // the two stores call it different things.
    test('Apple platforms name the Apple Account', () {
      expect(
        storeAccountLabelFor(TargetPlatform.iOS),
        equals('Apple Account'),
      );
      expect(
        storeAccountLabelFor(TargetPlatform.macOS),
        equals('Apple Account'),
      );
    });

    test('everything else names the Google Play account', () {
      expect(
        storeAccountLabelFor(TargetPlatform.android),
        equals('Google Play account'),
      );
      expect(
        storeAccountLabelFor(TargetPlatform.windows),
        equals('Google Play account'),
      );
    });
  });
}
