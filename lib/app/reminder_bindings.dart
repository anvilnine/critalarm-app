import 'dart:async';

import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_tap_route.dart';
import 'package:flutter/foundation.dart';

/// What a running app does with a reminder tap. Sits beside the root widget,
/// like `AppPushBindings`, so it tests without pumping one.
///
/// A tap that launched the app is taken on start; a tap that woke it is
/// taken on resume; a tap while it runs arrives on the stream. The
/// scheduler drops the second copy of the same tap.
class ReminderBindings {
  ReminderBindings({
    required ReminderScheduler scheduler,
    required HomePromptRepository prompts,
    required void Function(String path) navigate,
    required Future<void> Function(Uri url) openUrl,
    required Future<void> Function() openStoreReview,
    required Future<void> Function(String source) openFeedbackForm,
    ReminderAnalytics? analytics,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _scheduler = scheduler,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _prompts = prompts,
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

  final ReminderScheduler _scheduler;
  final HomePromptRepository _prompts;
  final void Function(String path) _navigate;
  final Future<void> Function(Uri url) _openUrl;
  final Future<void> Function() _openStoreReview;
  final Future<void> Function(String source) _openFeedbackForm;
  final ReminderAnalytics? _analytics;

  StreamSubscription<ReminderTap>? _taps;

  void start() {
    _taps = _scheduler.taps.listen((tap) => unawaited(handle(tap)));
    unawaited(onResumed());
  }

  Future<void> onResumed() async {
    final tap = await _scheduler.takePendingTap();
    if (tap != null) await handle(tap);
  }

  Future<void> handle(ReminderTap tap) async {
    // Never waits on analytics: the tap routes first.
    unawaited(
      _analytics?.tapped(kind: tap.kind.wireName, action: tap.actionId),
    );
    if (ReminderTapRoute.countsAsProAsk(tap)) {
      await _prompts.markProPromptAsked();
    }
    // A browser, store or form that fails to open is logged, never thrown.
    try {
      switch (ReminderTapRoute.resolve(tap)) {
        case OpenRouteAction(:final path):
          _navigate(path);
        case OpenUrlAction(:final url):
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
}
