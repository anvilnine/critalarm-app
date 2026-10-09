import 'dart:convert';

import 'package:critalarm/app/moved_phone_reset.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone that answers with one verdict until it is settled, the way the
/// iPhone marker does.
final class _Host implements BackupHost {
  _Host(this.verdict, {this.log});

  InstallMarkerVerdict verdict;
  final List<String>? log;
  int settled = 0;
  bool throwsOnRead = false;

  @override
  Future<InstallMarkerVerdict> installMarker() async {
    if (throwsOnRead) throw StateError('no answer');
    return verdict;
  }

  @override
  Future<void> settleInstallMarker() async {
    settled++;
    log?.add('settle');
    verdict = InstallMarkerVerdict.same;
  }

  @override
  Future<void> excludeFromBackup(String path) async {}
}

const _cloud = 'https://api.critalarm.app';
const _relay = 'https://relay.critalarm.app';
const _oldToken = 'dv_from-the-old-phone';
const _oldDevice = 'dev_old-phone';

/// What a restore leaves in the preferences of a phone that was on Cloud:
/// the old phone's device id and device token, in every place that keeps
/// one, and the push token the old phone last sent.
Map<String, Object> _restoredCloudPrefs() => {
  'device_id': _oldDevice,
  'device_token': _oldToken,
  'account_id': 'acct_1',
  'account_tier': 'free',
  'api_session': '$_cloud|$_relay|hosted|$_oldToken',
  'server_url': _cloud,
  'admin_token': _oldToken,
  DeviceTokenRegistry.lastTokenKey: 'apns-of-the-old-phone',
  DeviceTokenRegistry.lastVersionKey: '1.0.0',
  DeviceTokenRegistry.lastKindKey: 'apns',
  // Taste. None of it names a phone.
  'theme_mode': 'dark',
  'quiet_hours_enabled': true,
  'alarm_sound_default': 'classic_siren',
};

/// The same phone on a server of the person's own: the token in the
/// session is one the person typed.
Map<String, Object> _restoredOwnServerPrefs() => {
  ..._restoredCloudPrefs(),
  'api_session': 'https://alarm.example|$_relay|selfhosted|tk_typed-by-hand',
  'server_url': 'https://alarm.example',
  'admin_token': 'tk_typed-by-hand',
};

final class _Harness {
  _Harness._(this.prefs, this.host);

  static Future<_Harness> make(
    Map<String, Object> restored, {
    InstallMarkerVerdict verdict = InstallMarkerVerdict.moved,
  }) async {
    SharedPreferences.setMockInitialValues(restored);
    final prefs = await SharedPreferences.getInstance();
    final log = <String>[];
    return _Harness._(prefs, _Host(verdict, log: log))..log = log;
  }

  final SharedPreferences prefs;
  final _Host host;
  late final List<String> log;
  final reconnects = <String>[];
  bool forgetFails = false;
  int forgets = 0;

  late final devices = DeviceIdentityStore(prefs);
  late final sessions = SharedPrefsApiSessionStore(prefs);
  late final connections = SharedPrefsConnectionRepository(prefs);

  late final reset = MovedPhoneReset(
    host: host,
    forgetAccountData: () async {
      forgets++;
      log.add('forget');
      if (forgetFails) throw StateError('a drop failed');
    },
    sessions: sessions,
    connections: connections,
    devices: devices,
    forgetSentPushToken: () async {
      log.add('push token');
      await prefs.remove(DeviceTokenRegistry.lastTokenKey);
      await prefs.remove(DeviceTokenRegistry.lastVersionKey);
      await prefs.remove(DeviceTokenRegistry.lastKindKey);
    },
    reconnect: (serverUrl) async {
      log.add('reconnect');
      reconnects.add(serverUrl);
    },
  );

  /// Every value in the preferences, as one text, to look for a token in.
  String get everything =>
      [for (final key in prefs.getKeys()) '$key=${prefs.get(key)}'].join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an install that has not moved', () {
    for (final verdict in [
      InstallMarkerVerdict.same,
      InstallMarkerVerdict.first,
      InstallMarkerVerdict.unknown,
    ]) {
      test('${verdict.name}: nothing is dropped', () async {
        final h = await _Harness.make(_restoredCloudPrefs(), verdict: verdict);
        final before = h.everything;

        expect(await h.reset.run(), isFalse);

        expect(h.everything, before);
        expect(h.forgets, 0);
        expect(h.host.settled, 0);
        expect(h.reconnects, isEmpty);
      });
    }

    test('a phone that cannot answer drops nothing', () async {
      final h = await _Harness.make(_restoredCloudPrefs());
      h.host.throwsOnRead = true;
      final before = h.everything;

      expect(await h.reset.run(), isFalse);

      expect(h.everything, before);
      expect(h.forgets, 0);
    });
  });

  group('restored onto another phone, on Cloud', () {
    test('the old device token is nowhere on the phone', () async {
      final h = await _Harness.make(_restoredCloudPrefs());
      expect(h.everything, contains(_oldToken));

      expect(await h.reset.run(), isTrue);

      expect(h.everything, isNot(contains(_oldToken)));
      expect(h.everything, isNot(contains(_oldDevice)));
      expect(h.prefs.getString('account_id'), isNull);
      expect(await h.sessions.read(), isNull);
      expect((await h.connections.getConnection()).isError(), isTrue);
    });

    test('the phone has a device id of its own and no token yet', () async {
      final h = await _Harness.make(_restoredCloudPrefs());

      await h.reset.run();

      final identity = await h.devices.readOrCreate();
      expect(identity.deviceId, isNot(_oldDevice));
      expect(identity.deviceId, startsWith('dev_'));
      // No token means the next registration is a first one: a POST that
      // makes a new device, never a PATCH of the old phone's row.
      expect(identity.deviceToken, isNull);
    });

    test('account data goes through the one list, once', () async {
      final h = await _Harness.make(_restoredCloudPrefs());

      await h.reset.run();

      expect(h.forgets, 1);
    });

    test('the push token the old phone sent is forgotten', () async {
      final h = await _Harness.make(_restoredCloudPrefs());

      await h.reset.run();

      expect(h.prefs.getString(DeviceTokenRegistry.lastTokenKey), isNull);
      expect(h.prefs.getString(DeviceTokenRegistry.lastVersionKey), isNull);
      expect(h.prefs.getString(DeviceTokenRegistry.lastKindKey), isNull);
    });

    test('what the relay accepted for the old phone is forgotten', () async {
      final h = await _Harness.make(_restoredCloudPrefs());
      final confirmations = RelayConfirmationStore(h.prefs);
      await confirmations.record(
        DateTime(2026, 10),
        RelayAttemptOutcome.accepted,
        RelayConfirmationScope.of(
          deviceId: _oldDevice,
          relay: _relay,
          token: 'apns-of-the-old-phone',
        ),
      );
      final keys = h.prefs.getKeys().length;

      await h.reset.run();

      expect(h.prefs.getKeys().length, lessThan(keys));
      expect(h.everything, isNot(contains(_oldDevice)));
    });

    test('it connects again to the same server, as setup would', () async {
      final h = await _Harness.make(_restoredCloudPrefs());

      await h.reset.run();

      expect(h.reconnects, [_cloud]);
    });

    test(
      'the marker is settled after the drops and before the connect',
      () async {
        final h = await _Harness.make(_restoredCloudPrefs());

        await h.reset.run();

        expect(h.log, ['forget', 'push token', 'settle', 'reconnect']);
        expect(h.host.settled, 1);
      },
    );

    test('taste stays', () async {
      final h = await _Harness.make(_restoredCloudPrefs());

      await h.reset.run();

      expect(h.prefs.getString('theme_mode'), 'dark');
      expect(h.prefs.getBool('quiet_hours_enabled'), isTrue);
      expect(h.prefs.getString('alarm_sound_default'), 'classic_siren');
    });

    test('the next launch finds nothing to do', () async {
      final h = await _Harness.make(_restoredCloudPrefs());
      await h.reset.run();
      final identity = await h.devices.readOrCreate();

      expect(await h.reset.run(), isFalse);

      expect(h.forgets, 1);
      expect(h.reconnects, hasLength(1));
      expect((await h.devices.readOrCreate()).deviceId, identity.deviceId);
    });

    test(
      'with a connection and no session it still drops and connects',
      () async {
        final h = await _Harness.make({
          ..._restoredCloudPrefs()..remove('api_session'),
        });

        await h.reset.run();

        expect(h.everything, isNot(contains(_oldToken)));
        expect(h.reconnects, [_cloud]);
      },
    );

    test(
      'with a session and no connection it connects to the session',
      () async {
        final h = await _Harness.make({
          ..._restoredCloudPrefs()
            ..remove('server_url')
            ..remove('admin_token'),
        });

        await h.reset.run();

        expect(h.everything, isNot(contains(_oldToken)));
        expect(h.reconnects, [_cloud]);
      },
    );
  });

  group('restored onto another phone, never connected', () {
    test('the identity is dropped and nothing is connected', () async {
      final h = await _Harness.make({
        'device_id': _oldDevice,
        'theme_mode': 'dark',
      });

      expect(await h.reset.run(), isTrue);

      expect(h.everything, isNot(contains(_oldDevice)));
      expect(h.reconnects, isEmpty);
      expect(h.host.settled, 1);
    });
  });

  group('restored onto another phone, on a server of the person own', () {
    test('the connection the person typed in stays', () async {
      final h = await _Harness.make(_restoredOwnServerPrefs());

      expect(await h.reset.run(), isTrue);

      final session = await h.sessions.read();
      expect(session?.mode, ServerMode.selfhosted);
      expect(session?.managementCredential, 'tk_typed-by-hand');
      expect(
        (await h.connections.getConnection()).getOrNull(),
        const ServerConnection(
          serverUrl: 'https://alarm.example',
          adminToken: 'tk_typed-by-hand',
        ),
      );
      expect(h.reconnects, isEmpty);
    });

    test('the device id and token the relay knew still go', () async {
      final h = await _Harness.make(_restoredOwnServerPrefs());

      await h.reset.run();

      expect(h.everything, isNot(contains(_oldToken)));
      expect(h.everything, isNot(contains(_oldDevice)));
      expect(h.forgets, 1);
      expect(h.prefs.getString(DeviceTokenRegistry.lastTokenKey), isNull);
      expect(h.host.settled, 1);
    });
  });

  group('a drop that fails', () {
    test('the identity still goes, and the marker is not settled', () async {
      final h = await _Harness.make(_restoredCloudPrefs())
        ..forgetFails = true;

      expect(await h.reset.run(), isTrue);

      expect(h.everything, isNot(contains(_oldToken)));
      expect(h.host.settled, 0);
      // No connect on a launch that did not finish: the next one runs the
      // whole list again first.
      expect(h.reconnects, isEmpty);
    });

    test(
      'the next launch runs the whole list again and then settles',
      () async {
        final h = await _Harness.make(_restoredCloudPrefs())
          ..forgetFails = true;
        await h.reset.run();

        h.forgetFails = false;
        expect(await h.reset.run(), isTrue);

        expect(h.forgets, 2);
        expect(h.host.settled, 1);
        expect(await h.reset.run(), isFalse);
      },
    );

    test('a connect that cannot start does not undo the reset', () async {
      SharedPreferences.setMockInitialValues(_restoredCloudPrefs());
      final prefs = await SharedPreferences.getInstance();
      final host = _Host(InstallMarkerVerdict.moved);
      final reset = MovedPhoneReset(
        host: host,
        forgetAccountData: () async {},
        sessions: SharedPrefsApiSessionStore(prefs),
        connections: SharedPrefsConnectionRepository(prefs),
        devices: DeviceIdentityStore(prefs),
        forgetSentPushToken: () async {},
        reconnect: (_) async => throw StateError('no network stack'),
      );

      expect(await reset.run(), isTrue);

      expect(host.settled, 1);
      expect(prefs.getString('device_token'), isNull);
    });
  });

  group('on an iPhone, where the identity is in the Keychain', () {
    const channel = MethodChannel('app.critalarm/device_identity');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    /// The Keychain as the channel sees it: one value per service and
    /// sync flag.
    late Map<String, String> keychain;

    String slot(Map<Object?, Object?> args) =>
        '${args['service']}|${args['synchronizable']}';

    setUp(() {
      keychain = {
        // An encrypted computer backup or a phone to phone transfer
        // carries this item to the next phone.
        '${KeychainDeviceIdentityStore.deviceService}|false': jsonEncode({
          'device_id': _oldDevice,
          'device_token': _oldToken,
          'account_id': 'acct_1',
          'account_tier': 'free',
          'caps': <String, dynamic>{},
        }),
        // iCloud Keychain carries this one on purpose.
        '${KeychainDeviceIdentityStore.accountService}|true': jsonEncode({
          'account_id': 'acct_1',
          'account_join_token': 'aj_join',
        }),
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map<Object?, Object?>;
        switch (call.method) {
          case 'read':
            if (args['synchronizable'] == 'any') {
              return keychain['${args['service']}|true'] ??
                  keychain['${args['service']}|false'];
            }
            return keychain[slot(args)];
          case 'write':
            keychain[slot(args)] = args['value']! as String;
          case 'delete':
            keychain.remove(slot(args));
        }
        return null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<({MovedPhoneReset reset, KeychainDeviceIdentityStore devices})>
    make() async {
      SharedPreferences.setMockInitialValues({
        'api_session': '$_cloud|$_relay|hosted|$_oldToken',
        'server_url': _cloud,
        'admin_token': _oldToken,
      });
      final prefs = await SharedPreferences.getInstance();
      final devices = KeychainDeviceIdentityStore(prefs);
      return (
        devices: devices,
        reset: MovedPhoneReset(
          host: _Host(InstallMarkerVerdict.moved),
          forgetAccountData: () async {},
          sessions: SharedPrefsApiSessionStore(prefs),
          connections: SharedPrefsConnectionRepository(prefs),
          devices: devices,
          forgetSentPushToken: () async {},
          reconnect: (_) async {},
        ),
      );
    }

    test('before the reset the new phone would use the old identity', () async {
      final made = await make();

      final identity = await made.devices.readOrCreate();

      expect(identity.deviceId, _oldDevice);
      expect(identity.deviceToken, _oldToken);
    });

    test('the old device item is deleted', () async {
      final made = await make();

      await made.reset.run();

      expect(keychain.values.join('\n'), isNot(contains(_oldToken)));
      expect(keychain.values.join('\n'), isNot(contains(_oldDevice)));
    });

    test(
      'the synced account item stays, so the phone joins the account',
      () async {
        final made = await make();

        await made.reset.run();

        final identity = await made.devices.readOrCreate();
        expect(identity.deviceId, isNot(_oldDevice));
        expect(identity.deviceToken, isNull);
        expect(identity.accountId, 'acct_1');
        expect(identity.accountJoinToken, 'aj_join');
        expect(
          keychain['${KeychainDeviceIdentityStore.accountService}|true'],
          contains('aj_join'),
        );
      },
    );

    test('the registration at launch and the connect use one new id', () async {
      final made = await make();

      await made.reset.run();

      final first = await made.devices.readOrCreate();
      final second = await made.devices.readOrCreate();
      expect(second.deviceId, first.deviceId);
    });
  });
}
