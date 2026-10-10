import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/app/sound_lock_sync.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_data_fixture.dart';

class _MockGetInfo extends Mock implements GetServerInfoUsecase {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockSearches extends Mock implements RecentSearchesRepository {}

class _MockChallenges extends Mock implements ChallengeChoices {}

class _MockLooks extends Mock implements AlarmStyleChoices {}

class _MockSoundLock extends Mock implements OwnSoundLockFlag {}

class _MockOwnLook extends Mock implements OwnLookStore {}

/// The list with every item watched, so the order of the drops and what
/// one failure does to the rest can be read off. The ack queue and the
/// cursors are the real classes over preferences that are watched: each
/// writes there and nowhere else.
final class _List {
  _List({this.failing = const {}}) {
    Future<bool> write(String what) async {
      if (failing.contains(what)) throw StateError(what);
      if (order.isEmpty || order.last != what) order.add(what);
      return true;
    }

    when(() => ackPrefs.getString(any())).thenReturn('[]');
    when(
      () => ackPrefs.setString(any(), any()),
    ).thenAnswer((_) => write('acks'));
    when(() => ackPrefs.remove(any())).thenAnswer((_) => write('acks'));
    when(cursorPrefs.getKeys).thenReturn({'msg_sync_last_id.prod'});
    when(() => cursorPrefs.remove(any())).thenAnswer((_) => write('cursors'));
    when(searches.clear).thenAnswer((_) async {
      await write('searches');
      return unit.toSuccess();
    });
    when(challenges.forgetAll).thenAnswer((_) => write('challenges'));
    when(looks.forgetAll).thenAnswer((_) => write('looks'));
    when(soundLock.clear).thenAnswer((_) => write('sound lock'));
    when(ownLook.forgetAll).thenAnswer((_) => write('own photo'));
  }

  /// The drops that throw.
  final Set<String> failing;

  final order = <String>[];
  final ackPrefs = _MockPrefs();
  final cursorPrefs = _MockPrefs();
  final searches = _MockSearches();
  final challenges = _MockChallenges();
  final looks = _MockLooks();
  final soundLock = _MockSoundLock();
  final ownLook = _MockOwnLook();
  final _api = MockApiClient(
    MockServer(
      serverInfo: const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://server.example',
        relayUrl: 'https://relay.example',
        mode: ServerModes.hosted,
      ),
    ),
  );

  late final AckQueue acks = AckQueue(ackPrefs, _api);
  late final MessageSyncService cursors = MessageSyncService(
    cursorPrefs,
    _api,
  );

  late final AccountData data = AccountData(
    acks: acks,
    messageCursors: cursors,
    recentSearches: searches,
    challenges: challenges,
    alarmStyles: looks,
    soundLock: soundLock,
    ownLook: ownLook,
    afterForget: () async => order.add('after'),
  );
}

class _UnclearableProofStore extends SharedPrefsProofLogStore {
  _UnclearableProofStore() : super(_MockPrefs());

  @override
  Future<void> clear() async => throw StateError('stuck');
}

class _MockEstablish extends Mock implements EstablishApiSessionUsecase {}

class _MockSave extends Mock implements SaveConnectionUsecase {}

const _info = ServerInfo(
  version: '0.1.0',
  baseUrl: 'https://new.example.com',
  relayUrl: 'https://relay.example.com',
);

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);

/// The real stores over one prefs, the two flag writers and the look gate
/// wired the way `di.dart` wires them, and an account id and a plan the
/// test sets by hand.
final class _Phone {
  late final SharedPreferences prefs;
  late final SharedPrefsChallengeChoices challenges;
  late final SharedPrefsAlarmStyleChoices looks;
  late final OwnSoundLockFlag soundLock;
  late final SoundLockSync soundSync;
  late final ChallengeFlagSync challengeSync;
  late final AlarmStyleGate lookGate;
  late final OwnLookOnDisk ownLook;
  late final AccountData accountData;

  /// The account the phone is on. Null for none.
  String? accountId;

  /// The plan, for all three features. Null when it cannot be read.
  FeatureDecision? plan;

  int publishes = 0;

  Future<FeatureDecision> _decide() async =>
      plan ?? (throw const HoldingUnreadable(Holding.pro));

  Future<void> start(
    Map<String, Object> initial, {
    required String? accountId,
    FeatureDecision? plan,
  }) async {
    this.accountId = accountId;
    this.plan = plan;
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(
      MockServer(
        serverInfo: const ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://server.example',
          relayUrl: 'https://relay.example',
          mode: ServerModes.hosted,
        ),
      ),
    );
    challenges = SharedPrefsChallengeChoices(prefs);
    looks = SharedPrefsAlarmStyleChoices(prefs);
    soundLock = OwnSoundLockFlag(prefs);
    soundSync = SoundLockSync(
      isLocked: () async => !(await _decide()).isUsable,
      changes: const Stream<Object?>.empty(),
      keepOnlyOurs: () => soundLock.keepOnlyFor(accountTagFor(this.accountId)),
      readWritten: () => soundLock.written,
      write: soundLock.write,
      publish: () async {
        publishes++;
        return true;
      },
    );
    challengeSync = ChallengeFlagSync(
      decide: _decide,
      changes: const [],
      keepOnlyOurs: () =>
          challenges.keepFlagsOnlyFor(accountTagFor(this.accountId)),
      readChoices: () => challenges.choices.keys.toSet(),
      readWritten: () => challenges.flaggedTopics,
      write: challenges.writeFlag,
      publish: () async {
        publishes++;
        return true;
      },
    );
    lookGate = AlarmStyleGate(
      choices: looks,
      decide: () => this.plan ?? const FeatureDecision.unread(Holding.pro),
      decideOnceReady: _decide,
      readAccountId: () async => this.accountId,
      planRead: Future<void>.value(),
    );
    ownLook = await OwnLookOnDisk.seed(prefs);
    accountData = AccountData(
      ownLook: ownLook.store,
      acks: AckQueue(prefs, api),
      messageCursors: MessageSyncService(prefs, api),
      recentSearches: SharedPrefsRecentSearchesRepository(prefs),
      challenges: challenges,
      alarmStyles: looks,
      soundLock: soundLock,
      afterForget: () async {
        await soundSync.checkAfterWipe();
        await challengeSync.checkAfterWipe();
        await lookGate.check();
      },
    );
    addTearDown(() async {
      await soundSync.dispose();
      await challengeSync.dispose();
      await lookGate.dispose();
      await challenges.dispose();
      await looks.dispose();
    });
  }

  /// What the app does at launch and when the account changes.
  Future<void> checkAll() async {
    await soundSync.check();
    await challengeSync.check();
    await lookGate.check();
  }

  List<String> get owedKeys => [
    for (final key in prefs.getKeys())
      if (key.startsWith('topic_challenge_owed.')) key,
  ]..sort();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://x.example.com'));
    registerFallbackValue(_info);
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  group('the wipe of what belongs to an account', () {
    test('drops everything on the list and keeps own sounds', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_1');
      expectAccountDataKept(phone.prefs);
      await phone.ownLook.expectKept();

      await phone.accountData.forget();

      expectAccountDataGone(phone.prefs);
      expectOwnSoundsKept(phone.prefs);
      // The own photo, its record and its accent: a person's picture does
      // not stay on a phone that left their account.
      await phone.ownLook.expectGone();
      expect(phone.challenges.choices, isEmpty);
      expect(phone.challenges.defaultForNewTopics, isNull);
      expect(phone.challenges.flaggedTopics, isEmpty);
      expect(phone.looks.assignments.defaultStyleId, isNull);
      expect(phone.looks.assignments.perTopic, isEmpty);
      expect(phone.looks.openNote, isNull);
      expect(phone.soundLock.written, isNull);
    });

    test('with the plan unreadable, the cleared flags still reach the '
        'copy native reads on iOS', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_1');

      await phone.accountData.forget();

      // One publish from each flag writer, with nothing written back.
      expect(phone.publishes, 2);
      expect(phone.soundSync.isPublishOwed, isFalse);
      expect(phone.challengeSync.isPublishOwed, isFalse);
      expectAccountDataGone(phone.prefs);
    });

    test('the sound lock is written again on the sure answer after it, '
        'for the account the phone is on then', () async {
      final phone = _Phone();
      await phone.start(
        accountDataFor('acc_1'),
        accountId: 'acc_1',
        plan: _open,
      );
      await phone.checkAll();
      expect(phone.prefs.getBool('alarm_sound_own_locked'), isFalse);

      // The phone leaves acc_1 and lands on a new account with no plan.
      phone
        ..accountId = 'acc_2'
        ..plan = _locked;
      await phone.accountData.forget();

      expect(phone.prefs.getBool('alarm_sound_own_locked'), isTrue);
      expect(
        phone.prefs.getString('alarm_sound_own_locked_for'),
        accountTagFor('acc_2'),
      );
      expect(phone.soundLock.written, isTrue);
      expectOwnSoundsKept(phone.prefs);
    });

    test('the challenge flags are written again once a topic has a '
        'challenge again and the plan is open', () async {
      final phone = _Phone();
      await phone.start(
        accountDataFor('acc_1'),
        accountId: 'acc_1',
        plan: _open,
      );
      phone.accountId = 'acc_2';
      await phone.accountData.forget();
      // Every choice went, so no topic owes anything.
      expect(phone.owedKeys, isEmpty);

      await phone.challenges.setChoice('prod', ChallengeKind.typeTopicName);
      await phone.challengeSync.check();

      expect(phone.owedKeys, ['topic_challenge_owed.prod']);
      expect(
        phone.prefs.getString('topic_challenge_owed_for'),
        accountTagFor('acc_2'),
      );
      expect(phone.challenges.isFlagged('prod'), isTrue);
    });

    test('a connect to a different server drops the list and keeps own '
        'sounds, and a connect to the same server drops nothing', () async {
      final getInfo = _MockGetInfo();
      final establish = _MockEstablish();
      final save = _MockSave();
      when(() => getInfo(any())).thenAnswer((_) async => _info.toSuccess());
      when(() => establish(any(), any())).thenAnswer(
        (invocation) async => ApiSession(
          baseUri: Uri.parse(_info.baseUrl),
          relayUri: Uri.parse(_info.relayUrl),
          mode: ServerMode.selfhosted,
          managementCredential: invocation.positionalArguments[1] as String,
        ),
      );
      when(() => save(any())).thenAnswer((_) async => unit.toSuccess());
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_1');
      ConnectToServerUsecase connectFrom(String saved) =>
          ConnectToServerUsecase(
            getInfo,
            establish,
            save,
            readSavedServerUrl: () async => saved,
            forgetServerData: phone.accountData.forget,
          );

      final same = await connectFrom(_info.baseUrl)(
        serverUrl: _info.baseUrl,
        adminToken: 'tk_one',
      );
      expect(same, isA<Connected>());
      expectAccountDataKept(phone.prefs);
      await phone.ownLook.expectKept();

      final other = await connectFrom('https://old.example.com')(
        serverUrl: _info.baseUrl,
        adminToken: 'tk_one',
      );
      expect(other, isA<Connected>());
      expectAccountDataGone(phone.prefs);
      expectOwnSoundsKept(phone.prefs);
      await phone.ownLook.expectGone();
    });
  });

  group('the order of the wipe, and what one failure does:', () {
    const everything = [
      'own photo',
      'acks',
      'cursors',
      'searches',
      'challenges',
      'looks',
      'sound lock',
      'after',
    ];

    test('the own photo goes first, then the list in its order', () async {
      final list = _List();
      await list.data.forget();
      expect(list.order, everything);
    });

    test('acknowledgements that cannot be cleared still stop the caller, '
        'and everything else is dropped first, the photo before all', () async {
      final list = _List(failing: {'acks'});
      await expectLater(
        list.data.forget,
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'acks')),
      );
      expect(list.order, [...everything]..remove('acks'));
      expect(list.order.first, 'own photo');
    });

    test('each of the three loud drops still stops the caller, and the '
        'first failure is the one thrown', () async {
      for (final failing in ['cursors', 'searches']) {
        final list = _List(failing: {failing});
        await expectLater(
          list.data.forget,
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', failing),
          ),
        );
        expect(list.order, [...everything]..remove(failing));
      }
      final list = _List(failing: {'acks', 'searches'});
      await expectLater(
        list.data.forget,
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'acks')),
      );
      expect(list.order, [
        'own photo',
        'cursors',
        'challenges',
        'looks',
        'sound lock',
        'after',
      ]);
    });

    test('a quiet drop that fails stops nothing and nobody', () async {
      for (final failing in [
        'own photo',
        'challenges',
        'looks',
        'sound lock',
      ]) {
        final list = _List(failing: {failing});
        await list.data.forget();
        expect(list.order, [...everything]..remove(failing), reason: failing);
      }
    });

    test('the proof log goes with the rest, and a drop that fails stops '
        'nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final proof = ProofLog(SharedPrefsProofLogStore(prefs));
      await proof.markRang(DateTime(2026, 10, 7, 9));
      expect(prefs.containsKey('proof_log'), isTrue);

      final list = _List();
      final data = AccountData(
        acks: list.acks,
        messageCursors: list.cursors,
        recentSearches: list.searches,
        challenges: list.challenges,
        alarmStyles: list.looks,
        soundLock: list.soundLock,
        ownLook: list.ownLook,
        proofLog: proof,
      );
      await data.forget();
      expect(prefs.containsKey('proof_log'), isFalse);
      expect(proof.newestRangAt(), isNull);

      // A log that cannot be cleared does not stop the caller.
      final stuck = _List();
      final blocked = AccountData(
        acks: stuck.acks,
        messageCursors: stuck.cursors,
        recentSearches: stuck.searches,
        challenges: stuck.challenges,
        alarmStyles: stuck.looks,
        soundLock: stuck.soundLock,
        ownLook: stuck.ownLook,
        proofLog: ProofLog(_UnclearableProofStore()),
      );
      await blocked.forget();
      expect(stuck.order, contains('sound lock'));
    });

    test('with the real photo store: a sign-out whose ack queue fails '
        'still takes the photo off the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onDisk = await OwnLookOnDisk.seed(prefs);
      final list = _List(failing: {'acks'});
      final data = AccountData(
        acks: list.acks,
        messageCursors: list.cursors,
        recentSearches: list.searches,
        challenges: list.challenges,
        alarmStyles: list.looks,
        soundLock: list.soundLock,
        ownLook: onDisk.store,
      );
      await onDisk.expectKept();
      // The account repository swallows this, as it always has.
      try {
        await data.forget();
      } on Object catch (_) {}
      await onDisk.expectGone();
    });
  });

  group('a note written under one account', () {
    for (final (name, accountId) in [
      ('another account', 'acc_2'),
      ('no account', null),
    ]) {
      test('is not trusted under $name', () async {
        final phone = _Phone();
        await phone.start(accountDataFor('acc_1'), accountId: accountId);
        await phone.checkAll();

        expect(phone.soundLock.written, isNull);
        expect(phone.challenges.flaggedTopics, isEmpty);
        expect(phone.challenges.isFlagged('prod'), isFalse);
        // The look is saved, and the plan cannot be read: without a note
        // for this account the standard look draws.
        expect(phone.lookGate.styleFor('prod'), AlarmStyleId.standard);
      });
    }

    test('is trusted under that account', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_1');
      await phone.checkAll();

      expect(phone.soundLock.written, isFalse);
      expect(phone.challenges.flaggedTopics, {'prod', 'nas'});
      expect(phone.lookGate.styleFor('prod'), AlarmStyleId.minimal);
      // Nothing was taken away, so there is nothing to copy.
      expect(phone.publishes, 0);
      expectAccountDataKept(phone.prefs);
    });

    test('is not trusted before the account was read at all', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_1');

      expect(phone.soundLock.written, isNull);
      expect(phone.challenges.flaggedTopics, isEmpty);
      expect(phone.challenges.isFlagged('prod'), isFalse);
      expect(phone.lookGate.styleFor('prod'), AlarmStyleId.standard);
    });

    test('stays where native reads it while the phone has no account, '
        'and nothing is written for nobody', () async {
      final phone = _Phone();
      await phone.start(
        accountDataFor('acc_1'),
        accountId: null,
        plan: _locked,
      );
      await phone.checkAll();

      // A sure "locked" with nobody to write it for changes nothing.
      expect(phone.prefs.getBool('alarm_sound_own_locked'), isFalse);
      expect(
        phone.prefs.getString('alarm_sound_own_locked_for'),
        accountTagFor('acc_1'),
      );
      expect(phone.owedKeys, hasLength(2));
    });
  });

  // Android restores every preference to a new phone. The case here is the
  // one where the phone then ends up on another account than the backup
  // was made on.
  group('a restored backup, every preference present, another account', () {
    test('the own sounds lock goes before the plan is known, and the '
        'next sure answer writes it for this account', () async {
      final phone = _Phone();
      await phone.start({
        ...accountDataFor('acc_1'),
        'alarm_sound_own_locked': true,
      }, accountId: 'acc_2');

      await phone.soundSync.check();

      expect(phone.prefs.containsKey('alarm_sound_own_locked'), isFalse);
      expect(phone.prefs.containsKey('alarm_sound_own_locked_for'), isFalse);
      // The copy the iOS extension reads is made again without it.
      expect(phone.publishes, 1);
      // The recordings and what rings where came with the backup and stay.
      expectOwnSoundsKept(phone.prefs);

      phone.plan = _locked;
      await phone.soundSync.check();
      expect(phone.prefs.getBool('alarm_sound_own_locked'), isTrue);
      expect(
        phone.prefs.getString('alarm_sound_own_locked_for'),
        accountTagFor('acc_2'),
      );
    });

    test('the challenge flags go before the plan is known, so native '
        'Done closes as it always did', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_2');

      await phone.challengeSync.check();

      expect(phone.owedKeys, isEmpty);
      expect(phone.prefs.containsKey('topic_challenge_owed_for'), isFalse);
      expect(phone.publishes, 1);

      // Without the plan no flag comes back.
      phone.plan = _locked;
      await phone.challengeSync.check();
      expect(phone.owedKeys, isEmpty);
    });

    test('the look note does not count, and a sure "locked" takes it '
        'away', () async {
      final phone = _Phone();
      await phone.start(accountDataFor('acc_1'), accountId: 'acc_2');

      await phone.lookGate.check();
      expect(phone.lookGate.styleFor('prod'), AlarmStyleId.standard);
      expect(phone.lookGate.styleFor(null), AlarmStyleId.standard);

      phone.plan = _locked;
      await phone.lookGate.check();
      expect(
        phone.prefs.containsKey('alarm_style_open_when_last_sure'),
        isFalse,
      );
    });
  });
}
