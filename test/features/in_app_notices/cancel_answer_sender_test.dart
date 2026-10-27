import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/telemetry/cancel_reason_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sender.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Store implements CancelAnswerStore {
  String? askedFor;
  List<CancelAnswer> pending = [];

  @override
  String? readAskedFor() => askedFor;

  @override
  Future<void> writeAskedFor(String key) async => askedFor = key;

  @override
  List<CancelAnswer> readPending() => List.of(pending);

  @override
  Future<void> writePending(List<CancelAnswer> entries) async =>
      pending = List.of(entries);
}

final class _Call {
  _Call(this.reason, this.text);
  final CancelReason reason;
  final String? text;
}

final class _Api implements CancelReasonApi {
  final calls = <_Call>[];

  /// The failure each next call throws, oldest first. Empty means success.
  final script = <Object>[];

  /// When set, a call waits for it before it answers.
  Completer<void>? hold;

  @override
  Future<void> sendCancelReason({
    required CancelReason reason,
    required String appVersion,
    required String platform,
    String? text,
  }) async {
    calls.add(_Call(reason, text));
    final waiting = hold;
    if (waiting != null) await waiting.future;
    if (script.isEmpty) return;
    final next = script.removeAt(0);
    Error.throwWithStackTrace(next, StackTrace.current);
  }
}

final class _BrokenStore extends _Store {
  @override
  Future<void> writePending(List<CancelAnswer> entries) async =>
      throw StateError('disk full');
}

final class _Gate extends NoopTelemetryGate {
  final events = <(String, Map<String, Object?>?)>[];
  bool throws = false;

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    events.add((name, parameters));
    if (throws) throw StateError('gate down');
  }
}

const _context = CancelSendContext(
  accountId: 'acc_1',
  appVersion: '1.0.0+12',
  platform: 'ios',
);
const _unavailable = ApiException(statusCode: 503, message: 'unavailable');

void main() {
  late _Store store;
  late _Api api;
  late _Gate gate;
  CancelSendContext? context;

  CancelAnswerSender sender({bool withGate = true}) => CancelAnswerSender(
    store: store,
    api: api,
    readContext: () async => context,
    analytics: withGate ? CancelReasonAnalytics(gate) : null,
  );

  setUp(() {
    store = _Store();
    api = _Api();
    gate = _Gate();
    context = _context;
  });

  test(
    'the chip answer is sent at once, with no text, and nothing is kept',
    () async {
      final s = sender();
      await s.sendReason(CancelReason.selfhost);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.reason, CancelReason.selfhost);
      expect(api.calls.single.text, isNull);
      expect(store.pending, isEmpty);
    },
  );

  test('the text is a second send', () async {
    final s = sender();
    await s.sendReason(CancelReason.price);
    await s.sendText(CancelReason.price, '  too much for what I use  ');
    expect(api.calls, hasLength(2));
    expect(api.calls[1].text, 'too much for what I use');
  });

  test('text of only spaces sends nothing', () async {
    final s = sender();
    await s.sendText(CancelReason.price, '   ');
    expect(api.calls, isEmpty);
  });

  test('text over 500 characters is cut before it is sent', () async {
    final s = sender();
    await s.sendText(CancelReason.other, 'y' * 800);
    expect(api.calls.single.text, 'y' * 500);
  });

  test('a failed send is kept, and the next launch tries it again', () async {
    api.script.add(_unavailable);
    await sender().sendReason(CancelReason.broken);
    expect(store.pending, hasLength(1));
    expect(store.pending.single.retries, 0);
    expect(api.calls, hasLength(1));

    await sender().retryPending();
    expect(api.calls, hasLength(2));
    expect(store.pending, isEmpty);
  });

  test('a send that keeps failing is dropped after three more tries', () async {
    api.script.addAll([_unavailable, _unavailable, _unavailable, _unavailable]);
    await sender().sendReason(CancelReason.broken);
    expect(api.calls, hasLength(1));

    await sender().retryPending(); // launch 1
    expect(store.pending.single.retries, 1);
    await sender().retryPending(); // launch 2
    expect(store.pending.single.retries, 2);
    await sender().retryPending(); // launch 3
    expect(store.pending, isEmpty);
    expect(api.calls, hasLength(4));

    await sender().retryPending(); // nothing left to try
    expect(api.calls, hasLength(4));
  });

  test('one launch is one retry, however often it is asked', () async {
    api.script.addAll([_unavailable, _unavailable]);
    await sender().sendReason(CancelReason.broken);
    final launch = sender();
    await launch.retryPending();
    await launch.retryPending();
    expect(api.calls, hasLength(2));
    expect(store.pending.single.retries, 1);
  });

  test(
    'a 403 is dropped at once, with no retry: the account never held Cloud',
    () async {
      api.script.add(
        const ApiException(statusCode: 403, message: 'tier', tier: 'hosted'),
      );
      await sender().sendReason(CancelReason.broken);
      expect(store.pending, isEmpty);
      await sender().retryPending();
      expect(api.calls, hasLength(1));
    },
  );

  test('a 400 or a 501 is dropped at once, never retried', () async {
    api.script.add(
      const ApiException(statusCode: 400, message: 'invalid request'),
    );
    await sender().sendReason(CancelReason.broken);
    expect(store.pending, isEmpty);

    api.script.add(
      const ApiException(
        statusCode: 501,
        message: 'not supported in relay mode',
      ),
    );
    await sender().sendReason(CancelReason.broken);
    expect(store.pending, isEmpty);
  });

  test(
    'the chip send and the text send are two entries only when both fail',
    () async {
      api.script.addAll([_unavailable, _unavailable]);
      final s = sender();
      await s.sendReason(CancelReason.price);
      await s.sendText(CancelReason.price, 'words');
      expect(store.pending.map((e) => e.text), [null, 'words']);
    },
  );

  test(
    'a network error, a 401, a 404 and a 429 are kept for a retry',
    () async {
      for (final failure in <Object>[
        StateError('socket'),
        const ApiException(statusCode: 401, message: 'unauthorized'),
        const ApiException(statusCode: 404, message: 'not found'),
        const ApiException(statusCode: 429, message: 'rate limited'),
      ]) {
        store.pending = [];
        api.script.add(failure);
        await sender().sendReason(CancelReason.other);
        expect(store.pending, hasLength(1), reason: '$failure');
      }
    },
  );

  test(
    'an entry from another account is dropped on retry with no send',
    () async {
      api.script.add(_unavailable);
      await sender().sendReason(CancelReason.broken);
      context = const CancelSendContext(
        accountId: 'acc_other',
        appVersion: '1.0.0+12',
        platform: 'ios',
      );
      await sender().retryPending();
      expect(api.calls, hasLength(1));
      expect(store.pending, isEmpty);
    },
  );

  test('a store that cannot write does not make the send throw', () async {
    store = _BrokenStore();
    api.script.add(_unavailable);
    await sender().sendReason(CancelReason.broken);
    await sender().retryPending();
    expect(api.calls, hasLength(1));
  });

  test('a send still in flight when the list is cleared is not kept', () async {
    api.script.add(_unavailable);
    api.hold = Completer<void>();
    final s = sender();
    final sending = s.sendReason(CancelReason.broken);
    await pumpEventQueue();
    await s.clear();
    api.hold!.complete();
    await sending;
    expect(store.pending, isEmpty);
  });

  test(
    'a send that fails during the retry pass is kept behind the rest',
    () async {
      api.script.addAll([_unavailable, _unavailable]);
      await sender().sendReason(CancelReason.price);
      final launch = sender();
      api.hold = Completer<void>();
      final retrying = launch.retryPending();
      await pumpEventQueue();
      api.script.add(_unavailable);
      final sending = launch.sendText(CancelReason.price, 'late');
      await pumpEventQueue();
      api.hold!.complete();
      await Future.wait([retrying, sending]);
      expect(store.pending.map((e) => (e.text, e.retries)), [
        (null, 1),
        ('late', 0),
      ]);
    },
  );

  test('away from Crit Alarm Cloud nothing is sent or kept', () async {
    context = null;
    final s = sender();
    await s.sendReason(CancelReason.broken);
    expect(api.calls, isEmpty);
    expect(store.pending, isEmpty);
  });

  test(
    'away from Crit Alarm Cloud a kept answer is dropped on retry',
    () async {
      api.script.add(_unavailable);
      await sender().sendReason(CancelReason.broken);
      context = null;
      await sender().retryPending();
      expect(api.calls, hasLength(1));
      expect(store.pending, isEmpty);
    },
  );

  test('clear forgets everything waiting', () async {
    api.script.add(_unavailable);
    final s = sender();
    await s.sendReason(CancelReason.broken);
    await s.clear();
    expect(store.pending, isEmpty);
  });

  group('against the mock server', () {
    late MockServer server;

    CancelAnswerSender mockSender() => CancelAnswerSender(
      store: store,
      api: MockApiClient(server),
      readContext: () async => context,
    );

    setUp(() {
      server = MockServer()..accountTier = 'hosted';
      server.serverInfo = server.serverInfo.copyWith(mode: ServerModes.hosted);
    });

    test(
      'the chip answer arrives, then the text arrives, and the text is stored',
      () async {
        final s = mockSender();
        await s.sendReason(CancelReason.selfhost);
        await s.sendText(CancelReason.selfhost, 'moved to my own box');
        expect(server.cancelAnswers, hasLength(1));
        expect(server.cancelAnswers.single.text, 'moved to my own box');
      },
    );

    test(
      'a retried chip send after the text went through keeps the text',
      () async {
        server.failNextCancelAnswers = 1;
        await mockSender().sendReason(CancelReason.selfhost);
        expect(store.pending, hasLength(1));
        await mockSender().sendText(
          CancelReason.selfhost,
          'moved to my own box',
        );
        expect(server.cancelAnswers.single.text, 'moved to my own box');
        await mockSender().retryPending();
        expect(store.pending, isEmpty);
        expect(server.cancelAnswers, hasLength(1));
        expect(server.cancelAnswers.single.text, 'moved to my own box');
      },
    );

    test('a 403 from the server drops the answer with no retry', () async {
      server.accountTier = 'free';
      await mockSender().sendReason(CancelReason.price);
      expect(store.pending, isEmpty);
      expect(server.cancelAnswerAttempts, 1);
    });
  });

  group('analytics', () {
    test(
      'the chip logs cancel_reason with the wire name and nothing else',
      () async {
        final s = sender();
        await s.sendReason(CancelReason.selfhost);
        await pumpEventQueue();
        expect(gate.events, hasLength(1));
        expect(gate.events.single.$1, 'cancel_reason');
        expect(gate.events.single.$2, equals({'reason': 'selfhost'}));
      },
    );

    test('the text is never an event', () async {
      final s = sender();
      await s.sendText(CancelReason.selfhost, 'my own words');
      await pumpEventQueue();
      expect(gate.events, isEmpty);
    });

    test('a retry logs nothing', () async {
      api.script.add(_unavailable);
      await sender().sendReason(CancelReason.broken);
      gate.events.clear();
      await sender().retryPending();
      await pumpEventQueue();
      expect(gate.events, isEmpty);
    });

    test('the answer goes out with no analytics at all', () async {
      await sender(withGate: false).sendReason(CancelReason.price);
      expect(api.calls, hasLength(1));
    });

    test('a gate that throws does not stop or fail the answer', () async {
      gate.throws = true;
      await sender().sendReason(CancelReason.price);
      expect(api.calls, hasLength(1));
      expect(store.pending, isEmpty);
    });
  });
}
