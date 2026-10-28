import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:critalarm/core/telemetry/cancel_reason_analytics.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_sink.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_answer_store.dart';
import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_question_rule.dart';
import 'package:flutter/foundation.dart';

/// Where this phone is right now, as far as a send cares. Null from
/// `readContext` means a send is pointless: not on Crit Alarm Cloud, or no
/// account.
@immutable
final class CancelSendContext {
  const CancelSendContext({
    required this.accountId,
    required this.appVersion,
    required this.platform,
  });

  final String accountId;
  final String appVersion;
  final String platform;
}

enum _Outcome { sent, retry, drop }

/// Sends the answer to "What made you cancel?" and keeps a failed send for the
/// next launch.
///
/// The chip answer goes out at once. The text is a second send. The request has
/// no key: the server keeps one answer per account in a rolling 30 days, files
/// the second send under it and stores the text if there was none. A send that
/// fails is written down and tried once on each of the next
/// [CancelQuestionRule.maxRetries] launches, then dropped. A 400, 403 or 501 is
/// dropped at once.
///
/// Nothing here posts a notification, starts a ring or waits on the alarm
/// path. The answer never waits on analytics and never reads the analytics
/// switch: the event is fired on the side and its failures are swallowed.
final class CancelAnswerSender implements CancelAnswerSink {
  CancelAnswerSender({
    required this._store,
    required this._api,
    required this._readContext,
    this._analytics,
  });

  final CancelAnswerStore _store;
  final CancelReasonApi _api;
  final Future<CancelSendContext?> Function() _readContext;
  final CancelReasonAnalytics? _analytics;

  bool _hasRetried = false;

  /// Bumped by [clear]. A send or a retry that was in flight when the list was
  /// cleared does not write its result back.
  int _generation = 0;

  /// Reads and writes of the waiting list take turns, so two sends that fail
  /// together do not overwrite each other. The network is never awaited inside
  /// a turn, so [clear] does not wait for a slow server.
  Future<void> _turn = Future<void>.value();

  @override
  Future<void> sendReason(CancelReason reason) async {
    unawaited(_logQuietly(reason));
    await _sendNew(reason: reason);
  }

  @override
  Future<void> sendText(CancelReason reason, String text) async {
    final clean = cleanCancelText(text);
    if (clean == null) return;
    await _sendNew(reason: reason, text: clean);
  }

  /// Once per app launch: tries every waiting send again. A second call in the
  /// same run does nothing. Never throws.
  Future<void> retryPending() async {
    if (_hasRetried) return;
    _hasRetried = true;
    try {
      final generation = _generation;
      final entries = await _queued(() async => _store.readPending());
      if (entries.isEmpty) return;
      final context = await _contextQuietly();
      final kept = <CancelAnswer>[];
      for (final entry in entries) {
        // Another account or another server: the answer is not ours to send.
        if (context == null || context.accountId != entry.accountId) continue;
        if (await _attempt(entry) != _Outcome.retry) continue;
        final spent = entry.withRetry();
        if (spent.retries < CancelQuestionRule.maxRetries) kept.add(spent);
      }
      await _queued(() async {
        if (generation != _generation) return;
        // Sends that failed while this pass ran were appended after the ones
        // read above. Keep them behind the survivors.
        final added = _store.readPending().skip(entries.length);
        await _store.writePending([...kept, ...added]);
      });
    } on Object catch (_) {
      // Best effort. The entries stay as they were and a later launch retries.
    }
  }

  /// Forgets every waiting send. For sign-out, account delete and a connect to
  /// another server.
  Future<void> clear() {
    _generation += 1;
    return _queued(() => _store.writePending(const []));
  }

  Future<void> _sendNew({
    required CancelReason reason,
    String? text,
  }) async {
    try {
      final context = await _contextQuietly();
      if (context == null) return;
      final generation = _generation;
      final entry = CancelAnswer(
        accountId: context.accountId,
        reason: reason,
        text: text,
        appVersion: context.appVersion,
        platform: context.platform,
      );
      if (await _attempt(entry) != _Outcome.retry) return;
      await _queued(() async {
        if (generation != _generation) return;
        await _store.writePending([..._store.readPending(), entry]);
      });
    } on Object catch (_) {
      // The sink never throws: a phone that cannot write its list loses this
      // one answer and nothing else.
    }
  }

  Future<_Outcome> _attempt(CancelAnswer entry) async {
    try {
      await _api.sendCancelReason(
        reason: entry.reason,
        text: entry.text,
        appVersion: entry.appVersion,
        platform: entry.platform,
      );
      return _Outcome.sent;
    } on ApiException catch (error) {
      // 400 says the answer is wrong, 403 says the account never held the
      // Cloud plan and 501 says this server takes none. A retry changes none
      // of them. Anything else (401, 404, 429, 5xx) may pass later.
      return const {400, 403, 501}.contains(error.statusCode)
          ? _Outcome.drop
          : _Outcome.retry;
    } on Object catch (_) {
      return _Outcome.retry;
    }
  }

  Future<CancelSendContext?> _contextQuietly() async {
    try {
      return await _readContext();
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _logQuietly(CancelReason reason) async {
    try {
      await _analytics?.reason(reason);
    } on Object catch (_) {
      // Analytics is best effort. The answer does not depend on it.
    }
  }

  Future<T> _queued<T>(Future<T> Function() action) {
    final result = _turn.then((_) => action());
    _turn = result.then((_) {}, onError: (_) {});
    return result;
  }
}
