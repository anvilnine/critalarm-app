import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:critalarm/features/onboarding/presentation/real_ring_screen.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

typedef OnboardingStepScreenBuilder =
    Widget Function(BuildContext context, GoRouterState state);

/// One setup step: its id, its screen, and the rules a flow is checked
/// against. A flow lists step ids; everything else about a step lives here.
@immutable
class OnboardingStepEntry {
  const OnboardingStepEntry({
    required this.id,
    required this.ambientStep,
    this.route,
    this.routeName,
    this.screen,
    this.requires = const {},
    this.handlesMissingServer = false,
    this.isAvailable = _onEveryPhone,
    this.isSatisfied = _onlyOnceCompleted,
  });

  /// The id a flow lists. Saved on the phone, so it never changes.
  final String id;

  /// The path inside the onboarding shell. Null while the step has no
  /// screen yet; such a step is never shown.
  final String? route;
  final String? routeName;

  /// The screen [route] builds.
  final OnboardingStepScreenBuilder? screen;

  /// Step ids that must come earlier in a flow that lists this one.
  final Set<String> requires;

  /// True for a step that requires `connect` and has its own screen state
  /// for a server that is not there. The shell leaves such a step alone
  /// where it would otherwise put the waiting face or the failure in its
  /// place.
  final bool handlesMissingServer;

  /// Whether the step exists on this phone.
  final bool Function(OnboardingPlatform on) isAvailable;

  /// Whether the step is already true for this user, so a resume skips it.
  /// Local reads only.
  final Future<bool> Function(OnboardingStepFacts facts) isSatisfied;

  /// What the canvas behind the screen shows when the route opens.
  final OnboardingAmbientStep ambientStep;

  static bool _onEveryPhone(OnboardingPlatform on) => true;

  /// For steps that are something the user watches or does once, with
  /// nothing to look up: they count only when completed.
  static Future<bool> _onlyOnceCompleted(OnboardingStepFacts facts) async =>
      false;
}

/// A developer forced [stepId] to count as not done. Always false in a store
/// build.
bool _isForcedUnsatisfied(String stepId) =>
    getIt.isRegistered<DeveloperOnboardingOverrides>() &&
    getIt<DeveloperOnboardingOverrides>().forcedUnsatisfied.contains(stepId);

bool _onMobileOnly(OnboardingPlatform on) => !on.isWeb;

/// The home screen widgets exist on iOS and Android only.
bool _whereWidgetsExist(OnboardingPlatform on) =>
    !on.isWeb &&
    (on.platform == TargetPlatform.iOS ||
        on.platform == TargetPlatform.android);

bool _notYet(OnboardingPlatform on) => false;

/// Every setup step, bound to this phone and this user.
///
/// To add a step: add an entry to [entries], then list its id in a flow.
/// The router builds one route per entry that has a screen.
class OnboardingStepRegistry implements OnboardingStepCatalog {
  OnboardingStepRegistry({required this.on, required this.facts});

  final OnboardingPlatform on;
  final OnboardingStepFacts facts;

  static final List<OnboardingStepEntry> entries = List.unmodifiable([
    OnboardingStepEntry(
      id: OnboardingStepId.welcome,
      route: '/onboarding/welcome',
      routeName: 'onboardingWelcome',
      ambientStep: OnboardingAmbientStep.welcome,
      screen: (context, state) => OnboardingWelcomeScreen(
        variant: state.uri.queryParameters.containsKey('v')
            ? WelcomeVariant.fromQuery(state.uri.queryParameters['v'])
            : null,
        isPreview: state.uri.queryParameters['preview'] == 'true',
      ),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.howItRings,
      route: '/onboarding/how-it-rings',
      routeName: 'onboardingHowItRings',
      ambientStep: OnboardingAmbientStep.howItRings,
      screen: (context, state) => const OnboardingHowItRingsScreen(),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.connect,
      route: '/onboarding/connect',
      routeName: 'onboardingConnect',
      ambientStep: OnboardingAmbientStep.connect,
      isSatisfied: (facts) => facts.hasConnection(),
      screen: (context, state) => const OnboardingConnectScreen(),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.permissions,
      route: '/onboarding',
      routeName: 'onboarding',
      ambientStep: OnboardingAmbientStep.notifications,
      isAvailable: _onMobileOnly,
      isSatisfied: (facts) => facts.hasEveryPermission(),
      screen: (context, state) => OnboardingPermissionsScreen(
        replayForDemo:
            isOnboardingReplayUri(state.uri) ||
            _isForcedUnsatisfied(OnboardingStepId.permissions),
        initialStep: state.uri.queryParameters['denied'] == 'true'
            ? NotificationPermissionStep.denied
            : NotificationPermissionStep.initial,
      ),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.firstTopic,
      route: '/onboarding/first-topic',
      routeName: 'onboardingFirstTopic',
      ambientStep: OnboardingAmbientStep.firstTopic,
      requires: const {OnboardingStepId.connect},
      isSatisfied: (facts) => facts.hasOwnedTopic(),
      // The Builder gives the callback a context inside the page, which is
      // where the route's state can be read from.
      screen: (context, state) => Builder(
        builder: (context) => CreateTopicScreen(
          isReplay: isOnboardingReplay(context),
          onDone: () =>
              finishOnboardingStep(context, OnboardingStepId.firstTopic),
        ),
      ),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.realRing,
      route: '/onboarding/real-ring',
      routeName: 'onboardingRealRing',
      ambientStep: OnboardingAmbientStep.connected,
      requires: const {OnboardingStepId.connect, OnboardingStepId.firstTopic},
      // It says for itself when no server is connected, and offers the test
      // of this phone only, so the shell does not stand in for it.
      handlesMissingServer: true,
      screen: (context, state) => const RealRingScreen(),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.legacyTest,
      route: '/onboarding/test',
      routeName: 'onboardingTest',
      ambientStep: OnboardingAmbientStep.connected,
      requires: const {OnboardingStepId.connect},
      screen: (context, state) =>
          const OnboardingConnectScreen(part: OnboardingConnectPart.test),
    ),
    OnboardingStepEntry(
      id: OnboardingStepId.widgets,
      route: '/onboarding/widgets',
      routeName: 'onboardingWidgets',
      ambientStep: OnboardingAmbientStep.widgets,
      isAvailable: _whereWidgetsExist,
      screen: (context, state) => const OnboardingWidgetsScreen(),
    ),
    // Known to the validator, so a flow may list it, but it has no screen
    // yet and is skipped.
    const OnboardingStepEntry(
      id: OnboardingStepId.hookUp,
      ambientStep: OnboardingAmbientStep.connected,
      requires: {OnboardingStepId.firstTopic},
      isAvailable: _notYet,
    ),
  ]);

  /// Every known step id, mapped to the ids that must come before it. What
  /// the flow validator checks a list against.
  static final Map<String, Set<String>> requiresById = Map.unmodifiable({
    for (final entry in entries) entry.id: entry.requires,
  });

  static OnboardingStepEntry? entryFor(String stepId) {
    for (final entry in entries) {
      if (entry.id == stepId) return entry;
    }
    return null;
  }

  /// The entry whose route is [path], or the closest one above it. Null
  /// when [path] is outside onboarding.
  static OnboardingStepEntry? entryForPath(String path) {
    OnboardingStepEntry? best;
    for (final entry in entries) {
      final route = entry.route;
      if (route == null) continue;
      if (path != route && !path.startsWith('$route/')) continue;
      if (best == null || route.length > best.route!.length) best = entry;
    }
    return best;
  }

  /// The canvas step of the entry [entryForPath] finds for [path].
  static OnboardingAmbientStep? ambientStepForPath(String path) =>
      entryForPath(path)?.ambientStep;

  @override
  Map<String, Set<String>> get requires => requiresById;

  @override
  bool isAvailable(String stepId) {
    final entry = entryFor(stepId);
    return entry != null && entry.route != null && entry.isAvailable(on);
  }

  @override
  Future<bool> isSatisfied(String stepId) async =>
      await entryFor(stepId)?.isSatisfied(facts) ?? false;

  @override
  String? routeOf(String stepId) => entryFor(stepId)?.route;
}
