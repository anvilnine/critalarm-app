import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// The English text a translation key resolves to, read from the file the
/// app ships.
String english(String key) {
  Object? node = jsonDecode(
    File('assets/translations/en.json').readAsStringSync(),
  );
  for (final part in key.split('.')) {
    node = (node! as Map<String, dynamic>)[part];
  }
  return node! as String;
}

const _absent = Object();

void main() {
  group('connectPrivacyLine', () {
    test('Cloud with relay_content none', () {
      final line = connectPrivacyLine(mode: 'hosted', relayContent: 'none');
      expect(line, ConnectPrivacyLine.cloudNone);
      expect(
        english(line!.translationKey),
        'Crit Alarm Cloud stores your messages. The push relay sees ids and '
        'the priority, never the text.',
      );
    });

    test('own server with relay_content none', () {
      final line = connectPrivacyLine(
        mode: 'selfhosted',
        relayContent: 'none',
      );
      expect(line, ConnectPrivacyLine.ownNone);
      expect(
        english(line!.translationKey),
        'Your server keeps your messages. Pushes pass through the Crit Alarm '
        'relay, which sees ids and the priority, never the text.',
      );
    });

    test('Cloud with relay_content full', () {
      final line = connectPrivacyLine(mode: 'hosted', relayContent: 'full');
      expect(line, ConnectPrivacyLine.cloudFull);
      expect(
        english(line!.translationKey),
        'Crit Alarm Cloud stores your messages. Pushes pass through the Crit '
        'Alarm relay and carry the message text.',
      );
    });

    test('own server with relay_content full', () {
      final line = connectPrivacyLine(
        mode: 'selfhosted',
        relayContent: 'full',
      );
      expect(line, ConnectPrivacyLine.ownFull);
      expect(
        english(line!.translationKey),
        'Your server keeps your messages. Pushes pass through the Crit Alarm '
        'relay and carry the message text.',
      );
    });

    test('an unknown relay_content value gives no line', () {
      expect(connectPrivacyLine(mode: 'hosted', relayContent: 'some'), isNull);
      expect(
        connectPrivacyLine(mode: 'selfhosted', relayContent: ''),
        isNull,
      );
      expect(connectPrivacyLine(mode: 'hosted', relayContent: 'NONE'), isNull);
    });

    test('a mode that is neither Cloud nor an own server gives no line', () {
      expect(connectPrivacyLine(mode: 'relay', relayContent: 'none'), isNull);
      expect(connectPrivacyLine(mode: 'other', relayContent: 'full'), isNull);
    });

    test('no relay_content in the answer gives no line', () {
      expect(connectPrivacyLine(mode: 'hosted', relayContent: null), isNull);
      expect(
        connectPrivacyLine(mode: 'selfhosted', relayContent: null),
        isNull,
      );
    });

    group('from the /v1/info answer as the server sent it', () {
      Map<String, dynamic> answer([Object? relayContent = _absent]) => {
        'version': '0.9.0',
        'base_url': 'https://api.critalarm.app',
        'relay_url': 'https://relay.critalarm.app',
        'mode': 'hosted',
        if (relayContent != _absent) 'relay_content': relayContent,
      };

      ConnectPrivacyLine? lineFor(ServerInfo info) => connectPrivacyLine(
        mode: info.mode,
        relayContent: info.statedRelayContent,
      );

      test(
        'field absent: no line, and the rest of the app still reads none',
        () {
          final info = ServerInfo.fromJson(answer());
          expect(info.statedRelayContent, isNull);
          expect(info.relayContent, 'none');
          expect(lineFor(info), isNull);
        },
      );

      test('none: the never-the-text line', () {
        final info = ServerInfo.fromJson(answer('none'));
        expect(info.statedRelayContent, 'none');
        expect(lineFor(info), ConnectPrivacyLine.cloudNone);
      });

      test('full: the carries-the-text line', () {
        final info = ServerInfo.fromJson(answer('full'));
        expect(info.relayContent, 'full');
        expect(lineFor(info), ConnectPrivacyLine.cloudFull);
      });

      test('unknown value: no line', () {
        final info = ServerInfo.fromJson(answer('summary'));
        expect(lineFor(info), isNull);
      });

      test('the stated value is not written back out', () {
        final json = ServerInfo.fromJson(answer('full')).toJson();
        expect(json.containsKey('relay_content_stated'), isFalse);
        expect(json['relay_content'], 'full');
      });
    });

    test('every key is the one the generated keys file holds', () {
      expect(
        ConnectPrivacyLine.cloudNone.translationKey,
        LocaleKeys.onboarding_connect_privacy_cloud_none,
      );
      expect(
        ConnectPrivacyLine.ownNone.translationKey,
        LocaleKeys.onboarding_connect_privacy_own_none,
      );
      expect(
        ConnectPrivacyLine.cloudFull.translationKey,
        LocaleKeys.onboarding_connect_privacy_cloud_full,
      );
      expect(
        ConnectPrivacyLine.ownFull.translationKey,
        LocaleKeys.onboarding_connect_privacy_own_full,
      );
    });
  });
}
