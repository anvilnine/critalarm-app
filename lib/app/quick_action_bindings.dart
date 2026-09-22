import 'dart:async';

import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/features/reminders/domain/quick_action_items.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Keeps the app icon's quick actions in step with the topic list and
/// routes a picked action through go_router.
class QuickActionBindings {
  QuickActionBindings({
    required TopicsCubit topics,
    required void Function(String path) navigate,
    QuickActions quickActions = const QuickActions(),
    bool isWeb = kIsWeb,
    ReminderAnalytics? analytics,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _topics = topics,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _navigate = navigate,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _quickActions = quickActions,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isWeb = isWeb,
       // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _analytics = analytics;

  final TopicsCubit _topics;
  final void Function(String path) _navigate;
  final QuickActions _quickActions;
  final bool _isWeb;
  final ReminderAnalytics? _analytics;

  StreamSubscription<TopicsState>? _subscription;
  bool? _hasCriticalTopic;

  void start() {
    if (_isWeb) return;
    unawaited(_initialize());
    _subscription = _topics.stream.listen((state) => unawaited(_update(state)));
    unawaited(_update(_topics.state));
  }

  Future<void> _initialize() async {
    try {
      await _quickActions.initialize(_onAction);
    } on Object catch (error) {
      _log('initialize', error);
    }
  }

  void _onAction(String type) {
    final action = QuickActionType.fromWire(type);
    if (action != null) {
      unawaited(_analytics?.quickActionUsed(type: action.wire));
      _navigate(action.path);
    }
  }

  Future<void> _update(TopicsState state) async {
    final hasCritical = state.topics.any((topic) => topic.critical);
    if (hasCritical == _hasCriticalTopic) return;
    try {
      await _quickActions.setShortcutItems([
        for (final action in QuickActionItems.visible(
          hasCriticalTopic: hasCritical,
        ))
          ShortcutItem(type: action.wire, localizedTitle: action.titleKey.tr()),
      ]);
      // Only once the platform took them, so a failure is tried again on
      // the next topics update.
      _hasCriticalTopic = hasCritical;
    } on Object catch (error) {
      _log('setShortcutItems', error);
    }
  }

  void _log(String what, Object error) => debugPrint(
    'QuickActionBindings: $what failed: ${error.runtimeType}',
  );

  Future<void> dispose() async => _subscription?.cancel();
}
