import 'package:critalarm/core/l10n/app_locales.dart';
import 'package:critalarm/core/l10n/native_locale_bridge.dart';
import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelNativeLocaleBridge.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a pick sends its tag', () async {
    await const MethodChannelNativeLocaleBridge().setAppLocale(
      const Locale('en', 'XA'),
    );

    expect(calls.single.method, 'setAppLocale');
    expect(calls.single.arguments, {'tag': 'en-XA'});
  });

  test('System default sends no tag', () async {
    const bridge = MethodChannelNativeLocaleBridge();
    await bridge.setAppLocale(const Locale('en', 'XA'));
    await bridge.setAppLocale(null);

    expect(calls.map((call) => call.arguments), [
      {'tag': 'en-XA'},
      {'tag': null},
    ]);
  });

  test('tags are the BCP 47 tags the native side looks up', () {
    expect(MethodChannelNativeLocaleBridge.tagFor(null), isNull);
    expect(MethodChannelNativeLocaleBridge.tagFor(const Locale('de')), 'de');
    expect(
      MethodChannelNativeLocaleBridge.tagFor(localeFromTag('pt-BR')),
      'pt-BR',
    );
    expect(
      MethodChannelNativeLocaleBridge.tagFor(localeFromTag('zh-Hans')),
      'zh-Hans',
    );
    for (final tag in [...shippedLocaleTags, pseudoLocaleTag]) {
      expect(MethodChannelNativeLocaleBridge.tagFor(localeFromTag(tag)), tag);
    }
  });

  test('a platform with no handler is not an error', () async {
    messenger.setMockMethodCallHandler(channel, null);

    await expectLater(
      const MethodChannelNativeLocaleBridge().setAppLocale(const Locale('de')),
      completes,
    );
  });

  test('a native failure does not reach the caller', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    await expectLater(
      const MethodChannelNativeLocaleBridge().setAppLocale(null),
      completes,
    );
  });

  test('the shipped list drives the Flutter locales', () {
    expect(shippedLocales, [
      for (final tag in shippedLocaleTags) localeFromTag(tag),
    ]);
    expect(localeFromTag('zh-Hans').scriptCode, 'Hans');
    expect(localeFromTag('pt-BR').countryCode, 'BR');
    expect(localeFromTag('en'), const Locale('en'));
  });
}
