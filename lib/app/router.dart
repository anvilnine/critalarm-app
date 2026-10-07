import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/route_observer.dart';
import 'package:critalarm/app/shell/app_shell.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/gallery/gallery_screen.dart';
import 'package:critalarm/features/account/presentation/account_screen.dart';
import 'package:critalarm/features/account/presentation/delete_account_screen.dart';
import 'package:critalarm/features/history/presentation/history_screen.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/lock_screen.dart';
import 'package:critalarm/features/local_reminders/presentation/confirm_ring_screen.dart';
import 'package:critalarm/features/local_reminders/presentation/local_reminder_lab_screen.dart';
import 'package:critalarm/features/local_reminders/presentation/local_reminder_settings_screen.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/paywall/presentation/hosted_paywall_screen.dart';
import 'package:critalarm/features/paywall/presentation/paywall_screen.dart';
import 'package:critalarm/features/paywall/presentation/pro_welcome_screen.dart';
import 'package:critalarm/features/permissions/presentation/device_permissions_screen.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/presentation/maker/maker_guide_screen.dart';
import 'package:critalarm/features/reliability/presentation/reliability_screen.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/about_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_debug_screen.dart';
import 'package:critalarm/features/settings/presentation/alarm_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/app_icon_screen.dart';
import 'package:critalarm/features/settings/presentation/appearance_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/bar_backing_lab_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:critalarm/features/settings/presentation/developer_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/dialog_sheet_gallery_screen.dart';
import 'package:critalarm/features/settings/presentation/face_gallery_screen.dart';
import 'package:critalarm/features/settings/presentation/priorities_screen.dart';
import 'package:critalarm/features/settings/presentation/privacy_settings_screen.dart';
import 'package:critalarm/features/settings/presentation/ringing_faces_screen.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route names, so nothing navigates by a raw string.
abstract final class AppRoute {
  static const home = 'home';
  static const gallery = 'gallery';
  static const onboarding = 'onboarding';
  static const onboardingConnect = 'onboardingConnect';
  static const onboardingPermissions = 'onboardingPermissions';
  static const onboardingDenied = 'onboardingDenied';
  static const onboardingWelcome = 'onboardingWelcome';
  static const onboardingHowItRings = 'onboardingHowItRings';
  static const onboardingWidgets = 'onboardingWidgets';
  static const onboardingFirstTopic = 'onboardingFirstTopic';
  static const onboardingRealRing = 'onboardingRealRing';
  static const onboardingHookUp = 'onboardingHookUp';
  static const onboardingTest = 'onboardingTest';
  static const topics = 'topics';
  static const history = 'history';
  static const topicDetail = 'topicDetail';
  static const topicMessages = 'topicMessages';
  static const createTopic = 'createTopic';
  static const settings = 'settings';
  static const settingsDisconnected = 'settingsDisconnected';
  static const devicePermissions = 'devicePermissions';
  static const reliability = 'reliability';
  static const String makerGuide = makerGuideRouteName;
  static const soundPicker = 'soundPicker';
  static const soundCrop = 'soundCrop';
  static const soundRecord = 'soundRecord';
  static const alarmSettings = 'alarmSettings';
  static const priorities = 'priorities';
  static const serverSettings = 'serverSettings';
  static const account = 'account';
  static const deleteAccount = 'deleteAccount';
  static const privacySettings = 'privacySettings';
  static const appearanceSettings = 'appearanceSettings';
  static const appIcon = 'appIcon';
  static const localReminderSettings = 'localReminderSettings';
  static const about = 'about';
  static const developerSettings = 'developerSettings';
  static const alarmDebug = 'alarmDebug';
  static const barBackingLab = 'barBackingLab';
  static const dialogSheetGallery = 'dialogSheetGallery';
  static const faceGallery = 'faceGallery';
  static const ringingFaces = 'ringingFaces';
  static const localReminderLab = 'localReminderLab';
  static const paywall = 'paywall';
  static const proWelcome = 'proWelcome';
  static const alarm = 'alarm';
  static const incidentDetail = 'incidentDetail';
  static const lockScreen = 'lockScreen';
  static const testRing = 'testRing';
  static const askPermissions = 'askPermissions';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: _rootKey,
  observers: [appRouteObserver],
  initialLocation: initialLocation,
  // A critalarm:// data URI on a tap intent must never become a location the
  // router cannot match. Android stops Flutter passing it on (see
  // MainActivity.shouldHandleDeeplinking); this catches one that still does.
  redirect: (context, state) => PushDeepLink.fromAppUri(state.uri),
  routes: [
    // Creating a topic covers the display, so it is routed off the root
    // navigator and the tab bar goes with it.
    GoRoute(
      path: '/topics/new',
      parentNavigatorKey: _rootKey,
      name: AppRoute.createTopic,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        // Opaque, because it opens straight over the tab shell, which does
        // not fade out under an ambient page. Transparent, the Topics list
        // stayed on screen behind the form. The ambient backdrop sits outside
        // the navigator, so it still shows.
        opaque: true,
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
    // The recorder. Once a clip is recorded the same route shows the
    // cropper for it, so back from the cropper lands on the sound list.
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
    // The icon picker covers the display like creating a topic, so the tab
    // bar goes away. It sits on the root navigator at the top level, not under
    // `/settings/appearance`, for the reason given above `/sounds`. Only where
    // the platform can change its icon: the web cannot, so Appearance has no
    // row for it there and a typed URL lands back on Appearance.
    GoRoute(
      path: '/app-icon',
      parentNavigatorKey: _rootKey,
      name: AppRoute.appIcon,
      redirect: (context, state) async =>
          await getIt<AppIconHost>().canChangeAppIcon()
          ? null
          : '/settings/appearance',
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        // Over the shell, like /topics/new: opaque, or the Settings tab
        // shows through the transparent scaffold.
        opaque: true,
        child: const AppIconScreen(),
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
                    // `?curl=1` comes from the silent topic reminder's "Get
                    // curl line": the token sheet opens as the screen does.
                    final startCurlFlow =
                        state.uri.queryParameters['curl'] == '1';
                    return AmbientPage(
                      key: state.pageKey,
                      child: TopicDetailScreen(
                        topicName: name,
                        startCurlFlow: startCurlFlow,
                      ),
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
              // Every sub-page sits on the root navigator, above the floating
              // tab bar, so its + and search buttons are gone. Opaque, for the
              // reason given on `/app-icon`. Create-topic and search do not
              // belong on a page like Delete account.
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
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.devicePermissions,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const DevicePermissionsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'reliability',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.reliability,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const ReliabilityScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'maker',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.makerGuide,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const MakerGuideScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'alarms',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.alarmSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const AlarmSettingsScreen(),
                  ),
                ),
                // What priorities 1 to 5 do on this phone. A browser has no
                // push and no alarm, so a typed URL there lands on Settings.
                GoRoute(
                  path: 'priorities',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.priorities,
                  redirect: (context, state) =>
                      getIt<PlatformCapabilities>().canRunAlarm
                      ? null
                      : '/settings',
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const PrioritiesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'server',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.serverSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const ServerSettingsScreen(),
                  ),
                ),
                // Absent on a self-hosted server: Settings hides the row that
                // leads here, because that server has no accounts.
                GoRoute(
                  path: 'account',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.account,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const AccountScreen(),
                  ),
                  routes: [
                    // Its own route rather than a dialog: there is too much
                    // to read before erasing an account.
                    GoRoute(
                      path: 'delete',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.deleteAccount,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const DeleteAccountScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'appearance',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.appearanceSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const AppearanceSettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'privacy',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.privacySettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const PrivacySettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'local-reminders',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.localReminderSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const LocalReminderSettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'about',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.about,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const AboutScreen(),
                  ),
                ),
                // Only reachable in builds made with
                // --dart-define=SKIP_PAYWALL=true, where Settings shows the
                // row that leads here.
                GoRoute(
                  path: 'developer',
                  parentNavigatorKey: _rootKey,
                  name: AppRoute.developerSettings,
                  pageBuilder: (context, state) => AmbientPage(
                    key: state.pageKey,
                    opaque: true,
                    child: const DeveloperSettingsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'bar-backing',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.barBackingLab,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const BarBackingLabScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'dialog-sheet',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.dialogSheetGallery,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const DialogSheetGalleryScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'faces',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.faceGallery,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const FaceGalleryScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'ringing-faces',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.ringingFaces,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const RingingFacesScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'local-reminders',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.localReminderLab,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: const LocalReminderLabScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'alarm',
                      parentNavigatorKey: _rootKey,
                      name: AppRoute.alarmDebug,
                      pageBuilder: (context, state) => AmbientPage(
                        key: state.pageKey,
                        opaque: true,
                        child: BlocProvider(
                          create: (_) => getIt<AlarmDebugCubit>(),
                          child: const AlarmDebugScreen(),
                        ),
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
      path: paywallPath,
      name: AppRoute.paywall,
      // RevenueCat draws the paywall. The Flutter one in PaywallScreen is only
      // for a --dart-define=SKIP_PAYWALL=true build, where the RevenueCat SDK
      // is never configured and so has nothing to show.
      pageBuilder: (context, state) {
        // `?source=` names what opened it, for the paywall_viewed event.
        // A missing or unknown one reads as direct.
        final source = PaywallSource.parse(
          state.uri.queryParameters['source'],
        ).wire;
        return AmbientPage(
          key: state.pageKey,
          child: buildSkipsPaywall
              ? PaywallScreen(source: source)
              : HostedPaywallScreen(source: source),
        );
      },
    ),
    // Where a purchase lands. Replaces the paywall so Back never returns to
    // it.
    GoRoute(
      path: '/paywall/success',
      name: AppRoute.proWelcome,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const ProWelcomeScreen(),
      ),
    ),
    // Health's "Turn on" for a permission the user was never asked. The
    // onboarding prompt screen, on its own, outside the onboarding flow.
    GoRoute(
      path: '/permissions/ask',
      name: AppRoute.askPermissions,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const OnboardingPermissionsScreen(standalone: true),
      ),
    ),
    // Both "Ring me now" paths land here: the fire drill reminder and the
    // quick action. It covers the display, so it sits on the root navigator.
    GoRoute(
      path: '/ring',
      name: AppRoute.testRing,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        child: const ConfirmRingScreen(),
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
        // One route per setup step that has a screen. The registry holds
        // the path and the screen, so a new step is added there.
        for (final step in OnboardingStepRegistry.entries)
          if (step.route != null && step.screen != null)
            GoRoute(
              path: step.route!,
              name: step.routeName,
              // The gate holds a step that needs the server back while a
              // connect is still running behind the user.
              pageBuilder: (context, state) => AmbientPage(
                key: state.pageKey,
                child: OnboardingStepGate(
                  builder: (context) => step.screen!(context, state),
                ),
              ),
            ),
        // Two more doors into the permissions screen.
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
        opaque: true,
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
          opaque: true,
          child: CriticalAlarmScreen(
            incidentId: id,
            // A developer build can look at one screen with made-up values.
            previewsFirstToolAcked:
                buildHasOnboardingDeveloperTools &&
                state.uri.queryParameters[CriticalAlarmScreen.previewParam] ==
                    CriticalAlarmScreen.previewFirstToolAcked,
          ),
        );
      },
    ),
    GoRoute(
      path: '/lockscreen',
      name: AppRoute.lockScreen,
      pageBuilder: (context, state) => AmbientPage(
        key: state.pageKey,
        opaque: true,
        child: const LockScreen(),
      ),
    ),
  ],
);
