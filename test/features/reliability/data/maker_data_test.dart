import 'package:critalarm/features/reliability/data/platform_maker_settings_opener.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsMakerGuideStore', () {
    test('reads nothing before anything is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsMakerGuideStore(
        await SharedPreferences.getInstance(),
      );
      expect(store.read(), MakerGuideRecord.none);
    });

    test('keeps the time and the OS version it was given', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsMakerGuideStore(
        await SharedPreferences.getInstance(),
      );
      final record = MakerGuideRecord(
        doneAt: DateTime.utc(2026, 10, 7, 9),
        osMajor: 15,
      );
      await store.write(record);
      expect(store.read(), record);
    });

    test('keeps a time with no OS version', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsMakerGuideStore(
        await SharedPreferences.getInstance(),
      );
      final record = MakerGuideRecord(doneAt: DateTime.utc(2026, 10, 7, 9));
      await store.write(record);
      expect(store.read(), record);
    });

    test('clears both when the word is withdrawn', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsMakerGuideStore(prefs);
      await store.write(
        MakerGuideRecord(doneAt: DateTime.utc(2026, 10, 7, 9), osMajor: 15),
      );
      await store.write(MakerGuideRecord.none);
      expect(store.read(), MakerGuideRecord.none);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('PlatformMakerSettingsOpener', () {
    const channel = MethodChannel(PlatformMakerSettingsOpener.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    const tried = [
      MakerIntentCandidate.component(
        package: 'p',
        component: 'p.C',
        sources: ['s'],
      ),
      MakerIntentCandidate.appDetails(),
    ];

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'sends the candidates in order and returns the index that opened',
      () async {
        Object? sent;
        messenger.setMockMethodCallHandler(channel, (call) async {
          sent = call.arguments;
          return 1;
        });
        final opened = await PlatformMakerSettingsOpener().open(tried);
        expect(opened, 1);
        expect(sent, {
          'candidates': [
            {'kind': 'component', 'package': 'p', 'component': 'p.C'},
            {'kind': 'appDetails'},
          ],
        });
      },
    );

    test('a native answer of -1 is -1', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => -1);
      expect(await PlatformMakerSettingsOpener().open(tried), -1);
    });

    test('an answer outside the list is -1', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 7);
      expect(await PlatformMakerSettingsOpener().open(tried), -1);
    });

    test('no answer is -1', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await PlatformMakerSettingsOpener().open(tried), -1);
    });

    test('a native error is -1 and does not throw', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });
      expect(await PlatformMakerSettingsOpener().open(tried), -1);
    });

    test('a phone with no native side is -1 and does not throw', () async {
      expect(await PlatformMakerSettingsOpener().open(tried), -1);
    });
  });
}
