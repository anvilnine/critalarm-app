import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sender.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSearches extends Mock implements RecentSearchesRepository {}

class _MockChallenges extends Mock implements ChallengeChoices {}

class _MockLooks extends Mock implements AlarmStyleChoices {}

class _MockSoundLock extends Mock implements OwnSoundLockFlag {}

class _MockOwnLook extends Mock implements OwnLookStore {}

class _Store implements CancelAnswerStore {
  _Store({this.broken = false});

  final bool broken;
  List<CancelAnswer> pending = [
    const CancelAnswer(
      accountId: 'acc_1',
      reason: CancelReason.price,
      appVersion: '1.0.0+12',
      platform: 'ios',
    ),
  ];

  @override
  String? readAskedFor() => null;

  @override
  Future<void> writeAskedFor(String key) async {}

  @override
  List<CancelAnswer> readPending() => List.of(pending);

  @override
  Future<void> writePending(List<CancelAnswer> entries) async {
    if (broken) throw StateError('stuck');
    pending = List.of(entries);
  }
}

void main() {
  late List<String> dropped;
  late _MockSearches searches;
  late _MockChallenges challenges;
  late _MockLooks looks;
  late _MockSoundLock soundLock;
  late _MockOwnLook ownLook;
  late AckQueue acks;
  late MessageSyncService cursors;

  AccountData accountData(_Store store) => AccountData(
    acks: acks,
    messageCursors: cursors,
    recentSearches: searches,
    challenges: challenges,
    alarmStyles: looks,
    soundLock: soundLock,
    ownLook: ownLook,
    cancelAnswers: CancelAnswerSender(
      store: store,
      api: const NoCancelReasonApi(),
      readContext: () async => null,
    ),
    afterForget: () async => dropped.add('after'),
  );

  setUp(() async {
    dropped = [];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(MockServer());
    acks = AckQueue(prefs, api);
    cursors = MessageSyncService(prefs, api);
    searches = _MockSearches();
    challenges = _MockChallenges();
    looks = _MockLooks();
    soundLock = _MockSoundLock();
    ownLook = _MockOwnLook();
    when(searches.clear).thenAnswer((_) async => unit.toSuccess());
    when(
      challenges.forgetAll,
    ).thenAnswer((_) async => dropped.add('challenges'));
    when(looks.forgetAll).thenAnswer((_) async => dropped.add('looks'));
    when(soundLock.clear).thenAnswer((_) async {
      dropped.add('sound lock');
      return true;
    });
    when(ownLook.forgetAll).thenAnswer((_) async {});
  });

  test('forget clears the cancel answers still waiting', () async {
    final store = _Store();
    await accountData(store).forget();
    expect(store.pending, isEmpty);
    expect(dropped, contains('after'));
  });

  test(
    'a cancel answer queue that cannot be cleared stops nothing else',
    () async {
      final store = _Store(broken: true);
      await accountData(store).forget();
      expect(
        dropped,
        containsAll(['challenges', 'looks', 'sound lock', 'after']),
      );
    },
  );
}
