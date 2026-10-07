import 'dart:convert';
import 'dart:io';

import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guides.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_intent_order.dart';
import 'package:flutter_test/flutter_test.dart';

/// A key like `maker_guide.samsung.step_1`, looked up in en.json.
bool hasString(Map<String, dynamic> json, String key) {
  Object? node = json;
  for (final part in key.split('.')) {
    if (node is! Map<String, dynamic> || !node.containsKey(part)) return false;
    node = node[part];
  }
  return node is String && node.isNotEmpty;
}

void main() {
  final en =
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;

  group('guide data', () {
    for (final family in MakerFamily.values) {
      final guide = makerGuideFor(family);

      group(family.name, () {
        test('is the guide for its own family', () {
          expect(guide.family, family);
        });

        test('has three to five steps', () {
          expect(guide.steps.length, inInclusiveRange(3, 5));
        });

        test('every step and the name have words in en.json', () {
          expect(hasString(en, guide.nameKey), isTrue, reason: guide.nameKey);
          for (final step in guide.steps) {
            expect(hasString(en, step.textKey), isTrue, reason: step.textKey);
          }
        });

        test(
          'every step names a version, a source and, if not confirmed, why',
          () {
            for (final step in guide.steps) {
              expect(step.writtenFor, isNotEmpty);
              expect(step.sources, isNotEmpty);
              if (!step.isConfirmed) expect(step.note, isNotEmpty);
            }
          },
        );

        test('every intent has a source, and an unconfirmed one says why', () {
          for (final intent in guide.intents) {
            expect(intent.sources, isNotEmpty);
            if (!intent.isConfirmed) expect(intent.note, isNotEmpty);
          }
        });

        test('links to the maker page on dontkillmyapp.com', () {
          expect(guide.moreUrl, startsWith('https://dontkillmyapp.com/'));
        });
      });
    }

    test('the words in en.json have no em dash or en dash', () {
      final text = jsonEncode(en['maker_guide']);
      expect(text.contains('\u2014'), isFalse);
      expect(text.contains('\u2013'), isFalse);
    });
  });

  group('makerIntentOrder', () {
    test('the maker pages come first, in the order the guide lists them', () {
      final guide = makerGuideFor(MakerFamily.oppo);
      final order = makerIntentOrder(guide);
      expect(order.take(guide.intents.length), guide.intents);
    });

    test(
      'the app page is always last, so a failure ends on a page that exists',
      () {
        for (final family in MakerFamily.values) {
          final order = makerIntentOrder(makerGuideFor(family));
          expect(
            order.last.kind,
            MakerIntentKind.appDetails,
            reason: family.name,
          );
          expect(
            order.where((i) => i.kind == MakerIntentKind.appDetails),
            hasLength(1),
            reason: family.name,
          );
        }
      },
    );

    test(
      'a guide with no pages of its own falls back to the app page only',
      () {
        const bare = MakerGuide(
          family: MakerFamily.samsung,
          nameKey: 'x',
          steps: [],
          intents: [],
          moreUrl: 'https://dontkillmyapp.com/samsung',
        );
        expect(makerIntentOrder(bare), [
          const MakerIntentCandidate.appDetails(),
        ]);
      },
    );

    test('an app page listed in the data is moved to the end, once', () {
      const guide = MakerGuide(
        family: MakerFamily.samsung,
        nameKey: 'x',
        steps: [],
        intents: [
          MakerIntentCandidate.appDetails(),
          MakerIntentCandidate.action(action: 'a.B', sources: ['s']),
        ],
        moreUrl: 'https://dontkillmyapp.com/samsung',
      );
      final order = makerIntentOrder(guide);
      expect(order.map((i) => i.kind), [
        MakerIntentKind.action,
        MakerIntentKind.appDetails,
      ]);
    });

    test('the app page is confirmed and no maker component is', () {
      expect(const MakerIntentCandidate.appDetails().isConfirmed, isTrue);
      for (final family in MakerFamily.values) {
        for (final intent in makerGuideFor(family).intents) {
          expect(intent.isConfirmed, isFalse, reason: '$family $intent');
        }
      }
    });

    test('candidates go to the native side as plain maps', () {
      const component = MakerIntentCandidate.component(
        package: 'p',
        component: 'p.C',
        sources: ['s'],
      );
      expect(component.toMap(), {
        'kind': 'component',
        'package': 'p',
        'component': 'p.C',
      });
      expect(const MakerIntentCandidate.appDetails().toMap(), {
        'kind': 'appDetails',
      });
      const action = MakerIntentCandidate.action(action: 'a.B', sources: ['s']);
      expect(action.toMap(), {'kind': 'action', 'action': 'a.B'});
    });
  });

  group('openedFallbackPage', () {
    final tried = makerIntentOrder(makerGuideFor(MakerFamily.huawei));

    test('is true only for the app page', () {
      expect(openedFallbackPage(tried, tried.length - 1), isTrue);
      expect(openedFallbackPage(tried, 0), isFalse);
    });

    test('is false for nothing opened and for an index out of range', () {
      expect(openedFallbackPage(tried, -1), isFalse);
      expect(openedFallbackPage(tried, tried.length), isFalse);
    });
  });
}
