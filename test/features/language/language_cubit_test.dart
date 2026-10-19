import 'package:critalarm/core/l10n/native_locale_bridge.dart';
import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:critalarm/features/language/domain/language_locale_host.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host implements LanguageLocaleHost {
  @override
  String? savedTag;
  String phone = 'en';
  @override
  String currentTag = 'en';
  final calls = <String>[];

  @override
  Future<void> apply(String? tag) async {
    calls.add('apply:$tag');
    savedTag = tag;
    currentTag = tag ?? phone;
  }
}

class _Bridge implements NativeLocaleBridge {
  final calls = <Locale?>[];
  @override
  Future<void> setAppLocale(Locale? locale) async => calls.add(locale);
}

void main() {
  late _Host host;
  late _Bridge bridge;
  late LanguageCubit cubit;
  late List<String> replanned;
  late List<String> reports;

  setUp(() {
    host = _Host();
    bridge = _Bridge();
    replanned = [];
    reports = [];
    cubit = LanguageCubit(
      host: host,
      bridge: bridge,
      replanReminders: () async => replanned.add(host.currentTag),
      openReport: (locale, screen) async {
        reports.add('$locale:$screen');
        return null;
      },
    );
  });
  tearDown(() => cubit.close());

  test('lists System default then exactly shipped tags in native names', () {
    expect(cubit.choices.first.tag, isNull);
    expect(
      cubit.choices.skip(1).map((choice) => choice.tag),
      shippedLocaleTags,
    );
    expect(cubit.choices[1].nativeName, 'English');
    expect(shippedLocaleTags.every(languageNativeNames.containsKey), isTrue);
    expect(languageNativeNames['de'], 'Deutsch');
    expect(languageNativeNames['ja'], '日本語');
    expect(cubit.choices.any((choice) => choice.tag == 'en-XA'), isFalse);
  });

  test('selection applies before native sync and reminder refresh', () async {
    final changed = cubit.stream.first;
    await cubit.select('en');
    expect((await changed).selectedTag, 'en');
    expect(host.savedTag, 'en');
    expect(bridge.calls, [const Locale('en')]);
    expect(replanned, ['en']);
    expect(cubit.state.selectedTag, 'en');
  });

  test(
    'reset removes the choice and follows subsequent phone changes',
    () async {
      await cubit.select('en');
      host.phone = 'de';
      await cubit.select(null);
      expect(host.savedTag, isNull);
      expect(cubit.state.selectedTag, isNull);
      expect(host.currentTag, 'de');
      expect(bridge.calls.last, isNull);
      host.phone = 'ja';
      await cubit.followSystemLocale();
      expect(cubit.state.effectiveTag, 'ja');
      expect(replanned.last, 'ja');
    },
  );

  test('phone changes never override an explicit choice', () async {
    await cubit.select('en');
    host.phone = 'ja';
    await cubit.followSystemLocale();
    expect(host.calls, ['apply:en']);
    expect(cubit.state.selectedTag, 'en');
  });

  test('launch sync sends saved choice, not resolved phone language', () async {
    host.savedTag = 'en';
    await cubit.synchronizeNative();
    expect(bridge.calls.single, const Locale('en'));
    host.savedTag = null;
    await cubit.synchronizeNative();
    expect(bridge.calls.last, isNull);
    expect(replanned, isEmpty);
  });

  test('unsupported and pseudo tags cannot be selected', () async {
    await expectLater(cubit.select('en-XA'), throwsArgumentError);
    await expectLater(cubit.select('not-shipped'), throwsArgumentError);
    expect(host.calls, isEmpty);
  });

  test('saved choice initializes state before the screen opens', () async {
    host.savedTag = 'en';
    final restored = LanguageCubit(
      host: host,
      bridge: bridge,
      replanReminders: () async {},
      openReport: (_, _) async => null,
    );
    expect(restored.state.selectedTag, 'en');
    await restored.synchronizeNative();
    expect(bridge.calls.single, const Locale('en'));
    await restored.close();
  });

  test('rapid picks are serialized and the last reset wins', () async {
    final first = cubit.select('en');
    final last = cubit.select(null);
    await Future.wait([first, last]);
    expect(host.calls, ['apply:en', 'apply:null']);
    expect(host.savedTag, isNull);
    expect(bridge.calls, [const Locale('en'), null]);
    expect(replanned, ['en', 'en']);
    expect(cubit.state.selectedTag, isNull);
  });

  test('report carries effective language and caller screen', () async {
    expect(cubit.canReport, isTrue);
    await cubit.reportMistake(screen: 'language');
    expect(reports, ['en:language']);
  });
}
