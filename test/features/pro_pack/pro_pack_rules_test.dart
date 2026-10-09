import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_grant.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_state.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_sheet_page.dart';
import 'package:critalarm/features/pro_pack/presentation/pro_pack_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

const _isHeldLine =
    'bool get isHeldWithoutSwitch => _relayHolds() || _otherGrant(_other);';

void main() {
  group('the packs list', () {
    test('holds the pack when it lists it', () {
      expect(listsProPack(const [AccountPack(id: 'pro')]), isTrue);
      expect(
        listsProPack(const [AccountPack(id: 'pro', expiresAt: 1759812345)]),
        isTrue,
      );
    });

    test('an empty list holds nothing', () {
      expect(listsProPack(const []), isFalse);
    });

    test('an id the app does not know is passed over', () {
      expect(listsProPack(const [AccountPack(id: 'team')]), isFalse);
      expect(listsProPack(const [AccountPack(id: 'PRO')]), isFalse);
      expect(
        listsProPack(const [AccountPack(id: 'team'), AccountPack(id: 'pro')]),
        isTrue,
      );
    });

    test('reading it off the wire drops what is not a pack', () {
      expect(accountPacksFromJson(null), isEmpty);
      expect(accountPacksFromJson('pro'), isEmpty);
      expect(
        accountPacksFromJson([
          {'id': 'pro', 'expires_at': null},
          {'expires_at': 5},
          {'id': ''},
          'pro',
          {'id': 'later', 'expires_at': 12},
        ]),
        const [AccountPack(id: 'pro'), AccountPack(id: 'later', expiresAt: 12)],
      );
    });
  });

  group('the refresh table (api.md 4.2)', () {
    test('confirmed, listed: the account holds it', () {
      expect(
        proPackRefreshOutcome(confirmed: true, listed: true),
        ProPackRefreshOutcome.held,
      );
    });

    test('confirmed, not listed: read, and held from no source', () {
      expect(
        proPackRefreshOutcome(confirmed: true, listed: false),
        ProPackRefreshOutcome.notHeld,
      );
    });

    test('not confirmed, listed: it already held it', () {
      expect(
        proPackRefreshOutcome(confirmed: false, listed: true),
        ProPackRefreshOutcome.held,
      );
    });

    test('not confirmed, not listed: nothing can be concluded', () {
      expect(
        proPackRefreshOutcome(confirmed: false, listed: false),
        ProPackRefreshOutcome.unknown,
      );
    });

    test('a refresh answer only counts a literal true as confirmed', () {
      PacksRefreshAnswer read(Object? confirmed) => PacksRefreshAnswer.fromJson(
        {'confirmed': confirmed, 'checked_at': null, 'packs': const <Object>[]},
      );
      expect(read(true).confirmed, isTrue);
      expect(read(false).confirmed, isFalse);
      expect(read(null).confirmed, isFalse);
      expect(read('true').confirmed, isFalse);
    });
  });

  group('the mapping function', () {
    test('grants nothing, whatever the tier', () {
      for (final tier in [null, 'free', 'relay', 'hosted', 'pro', 'anything']) {
        expect(
          proPackGrantedElsewhere(ProPackOtherSources(tier: tier)),
          isFalse,
          reason: 'tier $tier',
        );
      }
    });

    test('is the only code in the feature that is handed the tier', () {
      // Every other file in the feature has no word for a tier, a plan or a
      // store entitlement, so none of them can grant the pack from one.
      final banned = RegExp(
        r'\btier\b|AccountAccess|PlanChanges|SubscriptionTier|'
        r'entitlement|CustomerInfo|ProOverride\b|DevProSwitch',
      );
      // Where the tier is carried to the mapping function, and nowhere else.
      const carriers = {
        'lib/features/pro_pack/domain/pro_pack_grant.dart',
        'lib/features/pro_pack/domain/pro_pack_access.dart',
      };
      final offenders = <String>[];
      for (final file in Directory(
        'lib/features/pro_pack',
      ).listSync(recursive: true).whereType<File>()) {
        if (carriers.contains(file.path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (banned.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty);

      // In the access class the tier is taken in and put straight into
      // ProPackOtherSources. No other line of code there names it.
      final access = File(
        'lib/features/pro_pack/domain/pro_pack_access.dart',
      ).readAsLinesSync();
      final naming = [
        for (final line in access)
          if (!line.trimLeft().startsWith('//') &&
              RegExp(r'\btier\b').hasMatch(line))
            line.trim(),
      ];
      expect(naming, [
        'String? tier,',
        '_other = ProPackOtherSources(tier: tier);',
      ]);
      // And what it was put into is read by the grant function alone.
      expect(
        access
            .where((line) => RegExp(r'\b_other\b').hasMatch(line))
            .map((line) => line.trim()),
        const [
          'ProPackOtherSources _other = const ProPackOtherSources();',
          _isHeldLine,
          '_other = ProPackOtherSources(tier: tier);',
        ],
      );
    });
  });

  group('the sheet', () {
    test('every stage has a view, and waiting stages watch', () {
      for (final stage in ProPackSheetStage.values) {
        final view = proPackSheetView(stage);
        expect(
          view.isWaiting,
          view.face == FaceState.watching,
          reason: '$stage',
        );
      }
    });

    test('the stages after the store say the purchase is being confirmed', () {
      expect(
        proPackSheetView(ProPackSheetStage.checking).titleKey,
        LocaleKeys.pro_pack_sheet_checking,
      );
      expect(
        proPackSheetView(ProPackSheetStage.checkingPaused).titleKey,
        LocaleKeys.pro_pack_sheet_paused_title,
      );
    });

    test('a stage that still waits on the store never says it is done', () {
      final words =
          (jsonDecode(File('assets/translations/en.json').readAsStringSync())
                  as Map<String, dynamic>)['pro_pack']
              as Map<String, dynamic>;
      String text(String key) =>
          words[key.substring('pro_pack.'.length)] as String;

      for (final stage in [
        ProPackSheetStage.loading,
        ProPackSheetStage.atStore,
      ]) {
        final view = proPackSheetView(stage);
        expect(view.lineKey, isNull, reason: '$stage');
        expect(
          view.titleKey,
          isNot(
            anyOf(
              LocaleKeys.pro_pack_sheet_checking,
              LocaleKeys.pro_pack_sheet_paused_title,
            ),
          ),
          reason: '$stage',
        );
        expect(text(view.titleKey), contains('store'), reason: '$stage');
        expect(text(view.titleKey), isNot(contains('done')), reason: '$stage');
      }
      // Only the stage reached after the store finished carries that line.
      expect(
        [
          for (final stage in ProPackSheetStage.values)
            if (proPackSheetView(stage).lineKey ==
                LocaleKeys.pro_pack_sheet_paused_line)
              stage,
        ],
        [ProPackSheetStage.checkingPaused],
      );
      expect(
        proPackSheetView(ProPackSheetStage.checking).lineKey,
        isNull,
        reason: 'one face and one line while it asks on its own',
      );
    });

    test('the route to the sheet carries what opened it and nothing else', () {
      expect(
        proPackSheetLocation(ProPackSheetSource.homeWidgets),
        '/pro?source=${ProPackSheetSource.homeWidgets.wire}',
      );
    });

    test('stages a person rests on have different faces', () {
      final faces = [
        for (final stage in [
          ProPackSheetStage.notOnSale,
          ProPackSheetStage.offers,
          ProPackSheetStage.checkingPaused,
          ProPackSheetStage.held,
        ])
          proPackSheetView(stage).face,
      ];
      expect(faces.toSet().length, faces.length);
    });

    test('a source it does not know reads as direct', () {
      expect(
        ProPackSheetSource.parse('reliability'),
        ProPackSheetSource.reliability,
      );
      expect(ProPackSheetSource.parse(null), ProPackSheetSource.direct);
      expect(ProPackSheetSource.parse('paywall'), ProPackSheetSource.direct);
    });
  });
}
