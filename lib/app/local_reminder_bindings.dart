import 'dart:async';

import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_tap_route.dart';
import 'package:flutter/foundation.dart';

/// What a running app does with a reminder tap. Sits beside the root widget,
/// like `AppPushBindings`, so it tests without pumping one.
///
/// A tap that launched the app is taken on start; a tap that woke it is
/// taken on resume; a tap while it runs arrives on the stream. The
/// scheduler drops the second copy of the same tap.
class LocalReminderBindings {
  LocalReminderBindings({
    required LocalReminderScheduler scheduler,
    required InAppNoticeRepository notices,
    required AlarmFocus focus,
    required void Function(String path) navigate,
    required Future<void> Function(Uri url) openUrl,
    required Future<void> Function() openStoreReview,
    required Future<void> Function(String source) openFeedbackForm,
    LocalReminderAnalytics? analytics,
    this.readIsPaid,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _scheduler = scheduler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _notices = notices,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _focus = focus,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _navigate = navigate,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _openUrl = openUrl,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _openStoreReview = openStoreReview,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _openFeedbackForm = openFeedbackForm,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _analytics = analytics;

  final LocalReminderScheduler _scheduler;
  final InAppNoticeRepository _notices;

  /// Whether this account is on Pro. A Pro reminder tapped after buying goes
  /// home instead of to the paywall. Null counts as free; a failed read
  /// counts as paid.
  final Future<bool> Function()? readIsPaid;
  final AlarmFocus _focus;
  final void Function(String path) _navigate;
  final Future<void> Function(Uri url) _openUrl;
  final Future<void> Function() _openStoreReview;
  final Future<void> Function(String source) _openFeedbackForm;
  final LocalReminderAnalytics? _analytics;

  StreamSubscription<LocalReminderTap>? _taps;

  void start() {
    _taps = _scheduler.taps.listen((tap) => unawaited(handle(tap)));
    unawaited(onResumed());
  }

  Future<void> onResumed() async {
    final tap = await _scheduler.takePendingTap();
    if (tap != null) await handle(tap);
  }

  Future<void> handle(LocalReminderTap tap) async {
    // Never waits on analytics: the tap routes first.
    unawaited(
      _analytics?.tapped(kind: tap.kind.wireName, action: tap.actionId),
    );
    if (LocalReminderTapRoute.countsAsProAsk(tap)) {
      await _notices.markProAsked();
    }
    // A browser, store or form that fails to open is logged, never thrown.
    try {
      final isPaid = await _readIsPaidSafely();
      switch (LocalReminderTapRoute.resolve(tap, isPaid: isPaid)) {
        case OpenRouteAction(:final path):
          _navigate(path);
        case OpenUrlAction(:final url):
          // While an alarm is under way, a reminder may not pull the user
          // out to a browser or a store page.
          if (_focus.on) {
            debugPrint('nav_dropped_alarm_focus location=$url');
            return;
          }
          await _openUrl(url);
        case OpenStoreReviewAction():
          await _openStoreReview();
        case OpenFeedbackFormAction(:final source):
          await _openFeedbackForm(source);
        case null:
          break;
      }
    } on Object catch (error) {
      debugPrint(
        'CritAlarmReminders: opening ${tap.kind.wireName} failed: '
        '${error.runtimeType}',
      );
    }
  }

  Future<void> dispose() async => _taps?.cancel();

  Future<bool> _readIsPaidSafely() async {
    final read = readIsPaid;
    if (read == null) return false;
    try {
      return await read();
    } on Object catch (_) {
      return true;
    }
  }
}
