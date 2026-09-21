import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/app_shell.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/gallery/gallery_screen.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/delete_account_screen.dart';
import 'package:critalarm/features/history/presentation/history_screen.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/paywall/presentation/hosted_paywall_screen.dart';
import 'package:critalarm/features/paywall/presentation/paywall_screen.dart';
import 'package:critalarm/features/permissions/presentation/device_permissions_screen.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/developer_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/dialog_sheet_gallery_screen.dart';
import 'package:critalarm/features/settings/presentation/face_gallery_screen.dart';
import 'package:critalarm/features/settings/presentation/privacy_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/settings_screen.dart';
import 'package:critalarm/features/settings/presentation/sound_crop_screen.dart';
import 'package:critalarm/features/settings/presentation/sound_picker_screen.dart';
import 'package:critalarm/features/settings/presentation/sound_recorder_screen.dart';
import 'package:critalarm/features/topics/presentation/create_topic_screen.dart';
import 'package:critalarm/features/topics/presentation/home_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_detail_screen.dart';
import 'package:critalarm/features/topics/presentation/topic_messages_screen.dart';
import 'package:flutter/foundation.dart';
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
  static const topicMessages = 'topicMessages';
  static const createTopic = 'createTopic';
  static const settings = 'settings';
  static const settingsDisconnected = 'settingsDisconnected';
  static const devicePermissions = 'devicePermissions';
  static const soundPicker = 'soundPicker';
  static const soundCrop = 'soundCrop';
  static const soundRecord = 'soundRecord';
  static const alarmSettings = 'alarmSettings';
  static const serverSettings = 'serverSettings';
  static const account = 'account';
  static const deleteAccount = 'deleteAccount';
  static const privacySettings = 'privacySettings';
  static const about = 'about';
  static const developerSettings = 'developerSettings';
  static const dialogSheetGallery = 'dialogSheetGallery';
  static const faceGallery = 'faceGallery';
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
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const CreateTopicScreen(),
      ),
    ),
    // One screen, two jobs. No `topic` sets the default sound;
    // `?topic=<name>` sets that topic only. Neither ever reaches the server.
    // It covers the display and both Settings and a topic open it, so it sits
    // on the root navigator. Nested under `/settings` it dragged the shell to
    // the Settings tab, which swallowed the next Settings tap and left the
    // page alive in the inactive branch with its preview still playing.
    GoRoute(
      path: '/sounds',
      parentNavigatorKey: _rootKey,
      name: AppRoute.soundPicker,
      pageBuilder: (context, state) {
        final topic = state.uri.queryParameters['topic'];
        return AmbientPage(
          key: state.pageKey,
          child: SoundPickerScreen(
            topicName: topic != null && topic.isNotEmpty ? topic : null,
          ),
        );
      },
    ),
    // The cropper for a file the user just picked. The file travels as
    // `extra`, so a refresh on the web or a stray link arrives with none,
    // and the screen goes straight back. It also leaves when the platform
    // cannot import sounds.
    GoRoute(
      path: '/sounds/crop',
      parentNavigatorKey: _rootKey,
      name: AppRoute.soundCrop,
      pageBuilder: (context, state) {
        final file = state.extra;
        return AmbientPage(
          key: state.pageKey,
          // Opaque, because a shared file opens it straight over the tab
          // shell, which does not fade out under an ambient page the way the
          // sound list does. The ambient backdrop sits outside the navigator,
          // so it still shows.
          opaque: true,
          child: SoundCropScreen(file: file is PickedSoundFile ? file : null),
        );
      },
    ),
    // The recorder. Pops with the recorded file, which the sound list then
    // opens in the cropper, so back from the cropper lands on the list.
    // Leaves at once where the platform cannot import sounds.
    GoRoute(
      path: '/sounds/record',
      parentNavigatorKey: _rootKey,
      name: AppRoute.soundRecord,
      redirect: (context, state) async =>
          (await getIt<SoundHost>().capabilities()).canImportSounds
          ? null
          : '/sounds',
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        opaque: true,
        child: const SoundRecorderScreen(),
      ),
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
              pageBuilder: (context, state) => AmbientPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'topics/:name',
                  name: AppRoute.topicDetail,
                  pageBuilder: (context, state) {
                    final name = state.pathParameters['name'] ?? '';
                    return AmbientPage(
                      key: state.pageKey,
                      child: TopicDetailScreen(topicName: name),
                    );
                  },
                  routes: [
                    // The topic screen shows only the newest message so its
                    // acknowledge button stays on screen. The rest are here.
                    GoRoute(
                      path: 'messages',
                      name: AppRoute.topicMessages,
                      pageBuilder: (context, state) {
                        final name = state.pathParameters['name'] ?? '';
                        return AmbientPage(
                          key: state.pageKey,
                          child: TopicMessagesScreen(topicName: name),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'sounds',
                      name: 'homeTopicSounds',
                      pageBuilder: (context, state) {
                        final name = state.pathParameters['name'] ?? '';
                        return AmbientPage(
                          key: state.pageKey,
                          child: SoundPickerScreen(topicName: name),
                        );
                      },
                    ),
                  ],
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
              pageBuilder: (context, state) => AmbientPage(
                key: state.pageKey,
                child: const HistoryScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'topics/:name',
                  name: 'historyTopicDetail',
                  pageBuilder: (context, state) {
                    final name = state.pathParameters['name'] ?? '';
                    return AmbientPage(
                      key: state.pageKey,
                      child: TopicDetailScreen(topicName: name),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'messages',
                      name: 'historyTopicMessages',
                      pageBuilder: (context, state) {
                        final name = state.pathParameters['name'] ?? '';
                        return AmbientPage(
                          key: state.pageKey,
                          child: TopicMessagesScreen(topicName: name),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'sounds',
                      name: 'historyTopicSounds',
                      pageBuilder: (context, state) {
                        final name = state.pathParameters['name'] ?? '';
                        return AmbientPage(
                          key: state.pageKey,
                          child: SoundPickerScreen(topicName: name),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: AppRoute.settings,
              pageBuilder: (context, state) {
                final isDisconnected =
                    state.uri.queryParameters['disconnected'] == 'true';
                return AmbientPage(
                  key: state.pageKey,
                  child: SettingsScreen(forceDisconnected: isDisconnected),
                );
              },
              routes: [
                GoRoute(
                  path: 'disconnected',
                  name: AppRoute.settingsDisconnected,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const SettingsScreen(
                      forceDisconnected: true,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'permissions',
                  name: AppRoute.devicePermissions,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const DevicePermissionsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'alarms',
                  name: AppRoute.alarmSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const AlarmSettingsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'sounds',
                      name: 'alarmSounds',
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        child: const SoundPickerScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'server',
                  name: AppRoute.serverSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const ServerSettingsScreen(),
                  ),
                ),
                // Absent on a self-hosted server: Settings hides the row that
                // leads here, because that server has no accounts.
                GoRoute(
                  path: 'account',
                  name: AppRoute.account,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const AccountScreen(),
                  ),
                  routes: [
                    // Its own route rather than a dialog: there is too much
                    // to read before erasing an account.
                    GoRoute(
                      path: 'delete',
                      name: AppRoute.deleteAccount,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        child: const DeleteAccountScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'privacy',
                  name: AppRoute.privacySettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const PrivacySettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'about',
                  name: AppRoute.about,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const AboutScreen(),
                  ),
                ),
                // Only reachable in builds made with
                // --dart-define=SKIP_PAYWALL=true, where Settings shows the
                // row that leads here.
                GoRoute(
                  path: 'developer',
                  name: AppRoute.developerSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    child: const DeveloperSettingsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'dialog-sheet',
                      name: AppRoute.dialogSheetGallery,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        child: const DialogSheetGalleryScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'faces',
                      name: AppRoute.faceGallery,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        child: const FaceGalleryScreen(),
                      ),
                    ),
                  ],
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
      // RevenueCat draws the paywall. The Flutter one in PaywallScreen is only
      // for a --dart-define=SKIP_PAYWALL=true build, where the RevenueCat SDK
      // is never configured and so has nothing to show.
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: buildSkipsPaywall
            ? const PaywallScreen()
            : const HostedPaywallScreen(),
      ),
    ),
    // Debug builds only. Nothing in the shipping UI links here, and a store
    // reviewer who finds a reachable screen the app never mentions calls it a
    // hidden feature.
    if (kDebugMode)
      GoRoute(
        path: '/gallery',
        name: AppRoute.gallery,
        pageBuilder: (context, state) => AmbientPage(
          key: state.pageKey,
          child: const GalleryScreen(),
        ),
      ),
    ShellRoute(
      builder: (context, state, child) => OnboardingShell(
        state: state,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/onboarding',
          name: AppRoute.onboarding,
          pageBuilder: (context, state) {
            final isDenied = state.uri.queryParameters['denied'] == 'true';
            final replay = state.uri.queryParameters['demo'] == 'true';
            return AmbientPage(
              key: state.pageKey,
              child: OnboardingPermissionsScreen(
                replayForDemo: replay,
                initialStep: isDenied
                    ? NotificationPermissionStep.denied
                    : NotificationPermissionStep.initial,
              ),
            );
          },
        ),
        GoRoute(
          path: '/onboarding/denied',
          name: AppRoute.onboardingDenied,
          pageBuilder: (context, state) => AmbientPage(
            key: state.pageKey,
            child: const OnboardingPermissionsScreen(
              initialStep: NotificationPermissionStep.denied,
            ),
          ),
        ),
        GoRoute(
          path: '/onboarding/connect',
          name: AppRoute.onboardingConnect,
          pageBuilder: (context, state) => AmbientPage(
            key: state.pageKey,
            child: const OnboardingConnectScreen(),
          ),
        ),
        GoRoute(
          path: '/onboarding/permissions',
          name: AppRoute.onboardingPermissions,
          pageBuilder: (context, state) => AmbientPage(
            key: state.pageKey,
            child: const OnboardingPermissionsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/alarm',
      name: AppRoute.alarm,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const CriticalAlarmScreen(),
      ),
    ),
    GoRoute(
      path: '/incidents/:id',
      name: AppRoute.incidentDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return AmbientPage(
          key: state.pageKey,
          child: CriticalAlarmScreen(incidentId: id),
        );
      },
    ),
    GoRoute(
      path: '/lockscreen',
      name: AppRoute.lockScreen,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const LockScreen(),
      ),
    ),
  ],
);
