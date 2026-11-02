import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:critalarm/core/platform/device_text.dart';
import 'package:critalarm/core/platform/device_word.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String tag) =>
    jsonDecode(File('assets/translations/$tag.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _at(Map<String, dynamic> map, String dotted) {
  Object? node = map;
  for (final part in dotted.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node;
}

/// Every leaf key path in [map]. A plural group counts as one leaf.
Iterable<String> _keys(Map<String, dynamic> map, [String prefix = '']) sync* {
  const forms = {'zero', 'one', 'two', 'few', 'many', 'other'};
  for (final e in map.entries) {
    final path = prefix.isEmpty ? e.key : '$prefix.${e.key}';
    final value = e.value;
    if (value is Map<String, dynamic> && !value.keys.every(forms.contains)) {
      yield* _keys(value, path);
    } else {
      yield path;
    }
  }
}

final _placeholder = RegExp(r'\{[A-Za-z_]*\}');

List<String> _placeholders(Object? value) {
  final text = value is Map ? value.values.join('\n') : '$value';
  return _placeholder.allMatches(text).map((m) => m.group(0)!).toList()..sort();
}

void main() {
  final english = _load('en');

  group('deviceVariantKeys against assets/translations', () {
    test('every variant it names exists in every shipped language', () {
      final missing = <String>[];
      for (final tag in shippedLocaleTags) {
        final translations = _load(tag);
        for (final entry in deviceVariantKeys.entries) {
          if (_at(translations, entry.key) == null) {
            missing.add('$tag: ${entry.key}');
          }
          for (final word in DeviceWord.values) {
            final variant = entry.value.forWord(word);
            if (variant != null && _at(translations, variant) == null) {
              missing.add('$tag: $variant');
            }
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('every _ipad, _tablet or _computer key in en.json is in it', () {
      final listed = {
        for (final keys in deviceVariantKeys.values)
          for (final word in DeviceWord.values) ?keys.forWord(word),
      };
      final suffix = RegExp(r'_(ipad|tablet|computer)$');
      final unlisted = _keys(
        english,
      ).where((k) => suffix.hasMatch(k) && !listed.contains(k)).toList();
      expect(unlisted, isEmpty);
    });

    test('each variant is the phone key plus the word', () {
      for (final entry in deviceVariantKeys.entries) {
        for (final word in DeviceWord.values) {
          final variant = entry.value.forWord(word);
          if (variant == null) continue;
          expect(variant, '${entry.key}_${word.name}');
        }
      }
    });

    test('a variant has the shape and placeholders of its phone text, '
        'and an iPad one says iPad', () {
      final problems = <String>[];
      for (final tag in shippedLocaleTags) {
        final translations = _load(tag);
        for (final entry in deviceVariantKeys.entries) {
          final phone = _at(translations, entry.key);
          for (final word in DeviceWord.values) {
            final key = entry.value.forWord(word);
            if (key == null) continue;
            final variant = _at(translations, key);
            if (variant == null) continue;
            if ((phone is Map) != (variant is Map)) {
              problems.add('$tag $key: plural shape differs');
            }
            if (phone is Map &&
                variant is Map &&
                (phone.keys.toList()..sort()).join() !=
                    (variant.keys.toList()..sort()).join()) {
              problems.add('$tag $key: plural forms differ');
            }
            if (_placeholders(phone).join() != _placeholders(variant).join()) {
              problems.add('$tag $key: placeholders differ');
            }
            // A phone sentence that names no device (German says "In 5
            // Sekunden klingeln" for "Ring my phone in 5 seconds") has nothing
            // to change, so its variants repeat it. Any other variant names
            // the iPad.
            final repeatsPhone = jsonEncode(phone) == jsonEncode(variant);
            final namesPhone = RegExp(
              'phone',
              caseSensitive: false,
            ).hasMatch(jsonEncode(_at(english, entry.key)));
            if (word == DeviceWord.ipad &&
                namesPhone &&
                !repeatsPhone &&
                !jsonEncode(variant).contains('iPad')) {
              problems.add('$tag $key: does not say iPad');
            }
          }
        }
      }
      expect(problems, isEmpty);
    });

    test('no English iPad variant promises a full-screen alarm', () {
      final promise = RegExp(
        'as an alarm|like an alarm|full.screen|takes over|rings until|'
        'Do Not Disturb',
        caseSensitive: false,
      );
      final wrong = <String>[];
      for (final keys in deviceVariantKeys.values) {
        final key = keys.ipad;
        if (key == null) continue;
        if (promise.hasMatch(jsonEncode(_at(english, key)))) wrong.add(key);
      }
      expect(wrong, isEmpty);
    });

    test('the iOS alarm promises have an iPad variant', () {
      for (final key in const [
        'priorities.alarm_ios',
        'onboarding_welcome.caption_rings_silent',
        'feature_guides.topic_critical_body',
        'onboarding_permissions.ios.alarms.subtitle',
        'topic_detail.critical_toggle_subtitle',
        'create_topic.critical_toggle_subtitle',
      ]) {
        expect(deviceVariantKeys[key]?.ipad, isNotNull, reason: key);
      }
    });

    test('no English computer variant says the computer rings', () {
      final rings = RegExp(r'\bring', caseSensitive: false);
      final wrong = <String>[];
      for (final keys in deviceVariantKeys.values) {
        final key = keys.computer;
        if (key == null) continue;
        if (rings.hasMatch(jsonEncode(_at(english, key)))) wrong.add(key);
      }
      expect(wrong, isEmpty);
    });

    test('no language ships an English variant', () {
      final english = _load('en');
      final untranslated = <String>[];
      for (final tag in shippedLocaleTags.where((t) => t != 'en')) {
        final translations = _load(tag);
        for (final keys in deviceVariantKeys.values) {
          for (final word in DeviceWord.values) {
            final key = keys.forWord(word);
            if (key == null) continue;
            if (jsonEncode(_at(translations, key)) ==
                jsonEncode(_at(english, key))) {
              untranslated.add('$tag: $key');
            }
          }
        }
      }
      expect(untranslated, isEmpty);
    });
  });

  group('withDeviceWord', () {
    test('a phone keeps the phone text, the same map', () {
      expect(withDeviceWord(english, DeviceWord.phone), same(english));
    });

    test('an iPad, a tablet and a computer get their own sentence', () {
      String stop(DeviceWord word) =>
          _at(withDeviceWord(english, word), 'wake.stop_phone')! as String;

      expect(stop(DeviceWord.phone), 'This phone');
      expect(stop(DeviceWord.ipad), 'This iPad');
      expect(stop(DeviceWord.tablet), 'This tablet');
      // The Mac and the web app cannot ring, so the wake path keeps the
      // phone there.
      expect(stop(DeviceWord.computer), 'This phone');
    });

    test('a computer is named where the sentence is true on it', () {
      final computer = withDeviceWord(english, DeviceWord.computer);
      expect(
        _at(computer, 'settings.storage_row_subtitle'),
        'How long old alarms stay on this computer',
      );
    });

    test('a plural string swaps all its forms', () {
      final ipad = withDeviceWord(english, DeviceWord.ipad);
      expect(_at(ipad, 'wake.chip_pass'), {
        'one': '{} iPad check passes',
        'other': '{} iPad checks pass',
      });
    });

    test('a string with no variant for the word keeps the phone text', () {
      // The ringer line is iOS only, so it has an iPad variant and nothing
      // for a tablet.
      final tablet = withDeviceWord(english, DeviceWord.tablet);
      expect(
        _at(tablet, 'alarm_loudness.line'),
        _at(english, 'alarm_loudness.line'),
      );
    });

    test('strings about phones in general are left alone', () {
      final ipad = withDeviceWord(english, DeviceWord.ipad);
      expect(
        _at(ipad, 'account.delete_what_goes_devices'),
        'Every phone signed in to this account',
      );
    });

    test('the map it was given is not changed', () {
      final before = jsonEncode(english);
      withDeviceWord(english, DeviceWord.computer);
      expect(jsonEncode(english), before);
    });

    test('German and Japanese name the iPad in their own words', () {
      for (final tag in ['de', 'ja']) {
        final ipad = withDeviceWord(_load(tag), DeviceWord.ipad);
        final line = _at(ipad, 'wake.stop_phone')! as String;
        expect(line, contains('iPad'), reason: tag);
      }
    });
  });

  test('DeviceWordAssetLoader applies the word to what it loads', () async {
    const loader = DeviceWordAssetLoader(
      DeviceWord.tablet,
      inner: _MapLoader({
        'wake': {
          'stop_phone': 'This phone',
          'stop_phone_tablet': 'This tablet',
        },
      }),
    );
    final loaded = await loader.load('assets/translations', const Locale('en'));
    expect(_at(loaded!, 'wake.stop_phone'), 'This tablet');
  });
}

class _MapLoader extends AssetLoader {
  const _MapLoader(this.map);

  final Map<String, dynamic> map;

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => map;
}
