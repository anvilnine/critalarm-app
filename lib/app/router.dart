import 'package:critalarm/design/gallery/gallery_screen.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:critalarm/features/paywall/presentation/paywall_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_screen.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:critalarm/features/topics/presentation/home_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/topics_list_screen.dart';
import 'package:go_router/go_router.dart';

/// Route names, so nothing navigates by a raw string.
abstract final class AppRoute {
  static const home = 'home';
  static const gallery = 'gallery';
  static const onboarding = 'onboarding';
  static const onboardingPermissions = 'onboardingPermissions';
  static const topics = 'topics';
  static const topicDetail = 'topicDetail';
  static const createTopic = 'createTopic';
  static const settings = 'settings';
  static const paywall = 'paywall';
  static const alarm = 'alarm';
  static const incidentDetail = 'incidentDetail';
  static const lockScreen = 'lockScreen';
}

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/',
    ),
    GoRoute(
      path: '/topics',
      name: AppRoute.topics,
      builder: (context, state) => const TopicsListScreen(),
    ),
    GoRoute(
      path: '/topics/new',
      name: AppRoute.createTopic,
      builder: (context, state) => const CreateTopicScreen(),
    ),
    GoRoute(
      path: '/topics/:name',
      name: AppRoute.topicDetail,
      builder: (context, state) {
        final name = state.pathParameters['name'] ?? '';
        return TopicDetailScreen(topicName: name);
      },
    ),
    GoRoute(
      path: '/settings',
      name: AppRoute.settings,
      builder: (context, state) => const SettingsScreen(),
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
      builder: (context, state) => const OnboardingWelcomeScreen(),
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
