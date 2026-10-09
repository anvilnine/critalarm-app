import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_model.dart';
import 'package:flutter/foundation.dart';

/// What the screen does when the card's button is pressed. A value: the cubit
/// navigates nowhere and writes nothing, the screen runs it.
@immutable
sealed class HomeCardEffect {
  const HomeCardEffect();
}

/// Push this location (a go_router path, query included).
final class OpenPath extends HomeCardEffect {
  const OpenPath(this.path);

  final String path;

  @override
  bool operator ==(Object other) => other is OpenPath && other.path == path;

  @override
  int get hashCode => Object.hash(OpenPath, path);

  @override
  String toString() => 'OpenPath($path)';
}

/// Push the route with this `AppRoute` name.
final class OpenRoute extends HomeCardEffect {
  const OpenRoute(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is OpenRoute && other.name == name;

  @override
  int get hashCode => Object.hash(OpenRoute, name);

  @override
  String toString() => 'OpenRoute($name)';
}

/// Hand [fix] to `ReliabilityFixRunner.run`, then ask for the checks again.
/// Only fixes that open nothing of the app's own come here.
final class RunReliabilityFix extends HomeCardEffect {
  const RunReliabilityFix(this.fix);

  final ReliabilityFix fix;

  @override
  bool operator ==(Object other) =>
      other is RunReliabilityFix && other.fix == fix;

  @override
  int get hashCode => Object.hash(RunReliabilityFix, fix);

  @override
  String toString() => 'RunReliabilityFix($fix)';
}

/// Ask the server for the lists again (`HomeCubit.refresh`).
final class RefreshHome extends HomeCardEffect {
  const RefreshHome();

  @override
  bool operator ==(Object other) => other is RefreshHome;

  @override
  int get hashCode => (RefreshHome).hashCode;

  @override
  String toString() => 'RefreshHome()';
}

/// There is nothing to do. The fact the action was about is gone.
final class NoEffect extends HomeCardEffect {
  const NoEffect();

  @override
  bool operator ==(Object other) => other is NoEffect;

  @override
  int get hashCode => (NoEffect).hashCode;

  @override
  String toString() => 'NoEffect()';
}

/// The effect of pressing [action].
///
/// - [missed]: the missed alarm entry the card is showing, which decides
///   where "see why" goes.
/// - [testRouteName]: the `AppRoute` name of the test alarm screen. That
///   screen asks the server to send the test, so the card never rings
///   anything itself.
/// - [askPermissionsRouteName]: the `AppRoute` name of the permission prompt
///   screen, for a permission that was never asked.
///
/// Nothing here changes a topic, so Critical delivery stays the user's own
/// switch.
HomeCardEffect homeCardEffectFor(
  HomeCardAction action, {
  required MissedFact? missed,
  required String testRouteName,
  required String askPermissionsRouteName,
}) => switch (action) {
  OpenAlarm(:final incidentId) || OpenIncident(:final incidentId) => OpenPath(
    AppLinkRoutes.incident(incidentId),
  ),
  SeeMissed() => _seeMissed(missed, testRouteName),
  ConnectServer() => const OpenPath(OnboardingEntryPoint.connectServer),
  RetryLoad() => const RefreshHome(),
  Fix(:final fix) => _fixEffect(fix, askPermissionsRouteName),
  ContinueSetup(:final route) => OpenPath(route),
  GetFirstLine(:final topic) => OpenPath(
    '${AppLinkRoutes.topic(topic)}?curl=1',
  ),
  SendTest() => OpenRoute(testRouteName),
};

HomeCardEffect _seeMissed(MissedFact? missed, String testRouteName) {
  if (missed == null) return const NoEffect();
  final notice = missed.notice;
  return switch (missedAlarmAction(notice.reason)) {
    MissedAlarmAction.ringTest => OpenRoute(testRouteName),
    // The newest missed alarm is first.
    MissedAlarmAction.seeAlarm => OpenPath(
      AppLinkRoutes.incident(notice.incidentIds.first),
    ),
  };
}

/// A fix that opens a screen of the app becomes a route. The others go to the
/// fix runner, as the Reliability screen does.
HomeCardEffect _fixEffect(ReliabilityFix fix, String askPermissionsRouteName) =>
    switch (fix) {
      OpenRouteFix(:final routeName) => OpenRoute(routeName),
      MissedAlarmFix(testRouteName: final name) => OpenRoute(name),
      AskPermissionFix() => OpenRoute(askPermissionsRouteName),
      OpenSystemSettingsFix() || RunFix() => RunReliabilityFix(fix),
    };
