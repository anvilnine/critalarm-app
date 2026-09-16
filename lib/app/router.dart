import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/app_shell.dart';
import 'package:critalarm/design/gallery/gallery_screen.dart';
import 'package:critalarm/features/history/presentation/history_screen.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/paywall/presentation/paywall_screen.dart';
import 'package:critalarm/features/permissions/presentation/device_permissions_screen.dart';
import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/developer_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/privacy_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_screen.dart';
import 'package:critalarm/features/settings/presentation/sound_picker_screen.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:critalarm/features/topics/presentation/home_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route names, so nothing navigates by a raw string.
abstract final class AppRoute {
  static const home = 'home';
  static const gallery = 'gallery';
  static const onboarding = 'onboarding';
  static const onboardingConnect = 'onboardingConnect';
  static const onboardingPermissions = 'onboardingPermissions';
  static const onboardingDenied = 'onboardingDenied';
  static const topics = 'topics';
  static const history = 'history';
  static const topicDetail = 'topicDetail';
  static const createTopic = 'createTopic';
  static const settings = 'settings';
  static const settingsDisconnected = 'settingsDisconnected';
  static const devicePermissions = 'devicePermissions';
  static const soundPicker = 'soundPicker';
  static const alarmSettings = 'alarmSettings';
  static const serverSettings = 'serverSettings';
  static const privacySettings = 'privacySettings';
  static const about = 'about';
  static const developerSettings = 'developerSettings';
  static const paywall = 'paywall';
  static const alarm = 'alarm';
  static const incidentDetail = 'incidentDetail';
  static const lockScreen = 'lockScreen';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: _rootKey,
  observers: [appRouteObserver],
  initialLocation: initialLocation,
  routes: [
    // Creating a topic covers the display, so it is routed off the root
    // navigator and the tab bar goes with it.
    GoRoute(
      path: '/topics/new',
      parentNavigatorKey: _rootKey,
      name: AppRoute.createTopic,
      builder: (context, state) => const CreateTopicScreen(),
    ),
    // The three root destinations live inside the shell, so the floating tab
    // bar stays on screen and each tab keeps its own back stack. Anything that
    // must cover the whole display is routed outside it.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: AppRoute.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                // A topic covers the display the same way creating one does,
                // so it draws on the root navigator and the tab bar goes with
                // it. Keeping it nested leaves the Topics list underneath, so
                // back returns to the list instead of leaving the app, and
                // History can push the same path.
                GoRoute(
                  path: 'topics/:name',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.topicDetail,
                  builder: (context, state) {
                    final name = state.pathParameters['name'] ?? '';
                    return TopicDetailScreen(topicName: name);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              name: AppRoute.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: AppRoute.settings,
              builder: (context, state) {
                final isDisconnected =
                    state.uri.queryParameters['disconnected'] == 'true';
                return SettingsScreen(forceDisconnected: isDisconnected);
              },
              routes: [
                GoRoute(
                  path: 'disconnected',
                  name: AppRoute.settingsDisconnected,
                  builder: (context, state) => const SettingsScreen(
                    forceDisconnected: true,
                  ),
                ),
                // One screen, two jobs. No `topic` sets the default sound;
                // `?topic=<name>` sets that topic only. Neither ever reaches
                // the server.
                GoRoute(
                  path: 'sounds',
                  name: AppRoute.soundPicker,
                  builder: (context, state) {
                    final topic = state.uri.queryParameters['topic'];
                    return SoundPickerScreen(
                      topicName: topic != null && topic.isNotEmpty
                          ? topic
                          : null,
                    );
                  },
                ),
                GoRoute(
                  path: 'permissions',
                  name: AppRoute.devicePermissions,
                  builder: (context, state) => const DevicePermissionsScreen(),
                ),
                GoRoute(
                  path: 'alarms',
                  name: AppRoute.alarmSettings,
                  builder: (context, state) => const AlarmSettingsScreen(),
                ),
                GoRoute(
                  path: 'server',
                  name: AppRoute.serverSettings,
                  builder: (context, state) => const ServerSettingsScreen(),
                ),
                GoRoute(
                  path: 'privacy',
                  name: AppRoute.privacySettings,
                  builder: (context, state) => const PrivacySettingsScreen(),
                ),
                GoRoute(
                  path: 'about',
                  name: AppRoute.about,
                  builder: (context, state) => const AboutScreen(),
                ),
                // Only reachable in builds made with
                // --dart-define=SKIP_PAYWALL=true, where Settings shows the
                // row that leads here.
                GoRoute(
                  path: 'developer',
                  name: AppRoute.developerSettings,
                  builder: (context, state) => const DeveloperSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/topics',
      name: AppRoute.topics,
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/paywall',
      name: AppRoute.paywall,
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/gallery',
      name: AppRoute.gallery,
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: AppRoute.onboarding,
      builder: (context, state) {
        final isDenied = state.uri.queryParameters['denied'] == 'true';
        // `?demo=true` comes from the developer menu. It shows every step,
        // including the ones this phone has already granted, because the
        // point is looking at the screens rather than getting through them.
        final replay = state.uri.queryParameters['demo'] == 'true';
        return OnboardingPermissionsScreen(
          replayForDemo: replay,
          initialStep: isDenied
              ? NotificationPermissionStep.denied
              : NotificationPermissionStep.initial,
        );
      },
    ),
    GoRoute(
      path: '/onboarding/denied',
      name: AppRoute.onboardingDenied,
      builder: (context, state) => const OnboardingPermissionsScreen(
        initialStep: NotificationPermissionStep.denied,
      ),
    ),
    GoRoute(
      path: '/onboarding/connect',
      name: AppRoute.onboardingConnect,
      builder: (context, state) => const OnboardingConnectScreen(),
    ),
    GoRoute(
      path: '/onboarding/permissions',
      name: AppRoute.onboardingPermissions,
      builder: (context, state) => const OnboardingPermissionsScreen(),
    ),
    GoRoute(
      path: '/alarm',
      name: AppRoute.alarm,
      builder: (context, state) => const CriticalAlarmScreen(),
    ),
    GoRoute(
      path: '/incidents/:id',
      name: AppRoute.incidentDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'];
        return CriticalAlarmScreen(incidentId: id);
      },
    ),
    GoRoute(
      path: '/lockscreen',
      name: AppRoute.lockScreen,
      builder: (context, state) => const LockScreen(),
    ),
  ],
);
