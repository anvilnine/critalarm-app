import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/incoming_audio_bindings.dart';
import 'package:critalarm/app/push_bindings.dart';
import 'package:critalarm/app/quick_action_bindings.dart';
import 'package:critalarm/app/reminder_bindings.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/design_system/theme.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/presentation/open_feedback_form.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/entities/appearance_settings.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/theme_mode_mapper.dart';
import 'package:critalarm/features/tour/presentation/tour_host.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

class CritAlarmApp extends StatefulWidget {
  const CritAlarmApp({required this.initialLocation, super.key});

  final String initialLocation;

  @override
  State<CritAlarmApp> createState() => _CritAlarmAppState();
}

class _CritAlarmAppState extends State<CritAlarmApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );

  /// Taps, foreground pushes and the resume reload. A notification tapped
  /// while the app is already running does not go through the initial route,
  /// so the platform hands the route over here.
  late final AppPushBindings _push = AppPushBindings(
    getIt<PushHost>(),
    getIt<IncidentsCubit>(),
    getIt<TopicsCubit>(),
    _router.go,
    () => _router.routerDelegate.currentConfiguration.uri.path,
    (incidentId) => CriticalAlarmCubit.current?.select(incidentId),
    getIt<AlarmFocus>(),
  );

  /// Reminder taps. They route through the same router as everything else,
  /// by [_openPath].
  late final ReminderBindings _reminders = ReminderBindings(
    scheduler: getIt<ReminderScheduler>(),
    prompts: getIt<HomePromptRepository>(),
    readIsPaid: () => getIt<AccountRepository>().readIsPaid(),
    focus: getIt<AlarmFocus>(),
    navigate: _openPath,
    openUrl: (url) async {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    },
    openStoreReview: () => InAppReview.instance.openStoreListing(
      appStoreId: FeedbackLinks.appStoreId,
    ),
    openFeedbackForm: _openFeedbackForm,
    analytics: getIt<ReminderAnalytics>(),
  );

  late final QuickActionBindings _quickActions = QuickActionBindings(
    topics: getIt<TopicsCubit>(),
    navigate: _openPath,
    analytics: getIt<ReminderAnalytics>(),
  );

  /// The rule `openAppPath` follows, without a shell context: a path on
  /// another tab is a `go` so the tab bar moves with the user. Everything
  /// else is a push, so the confirm screen and the paywall close back to
  /// where the user was.
  void _openPath(String path) {
    final from = _router.routerDelegate.currentConfiguration.uri.toString();
    if (opensWithGo(path, from: from)) {
      _router.go(path);
    } else {
      unawaited(_router.push<void>(path));
    }
  }

  /// The same form the Help "Send feedback" row opens. The app is already
  /// open by the time this runs, then it hands off to the in-app browser.
  Future<void> _openFeedbackForm(String source) async {
    await openFeedbackForm(
      base: FeedbackLinks.feedbackFormUrl,
      source: source,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      mode: LaunchMode.inAppBrowserView,
    );
  }

  /// Shows snackbars from outside any screen, such as a shared file that
  /// could not be opened.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// "Share to Crit Alarm" from Voice Memos, Files and other apps. The file
  /// opens in the cropper, the same one "Pick a file" uses.
  late final AppIncomingAudioBindings _incomingAudio = AppIncomingAudioBindings(
    incoming: getIt<IncomingAudio>(),
    host: getIt<SoundHost>(),
    routeChanges: _router.routerDelegate,
    incidentChanges: getIt<IncidentsCubit>().stream,
    open: _openCropper,
    showMessage: (message) {
      // A failed audio share never talks over an alarm.
      if (getIt<AlarmFocus>().on) return;
      _messenger.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            // Above the floating tab bar, which would cover it otherwise.
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              AppFloatingTabBar.height + AppFloatingTabBar.edgeGap + 8,
            ),
          ),
        );
    },
  );

  /// A share that lands while a cropper is already open replaces it, so the
  /// user never has two croppers stacked. The one replaced deletes its own
  /// copy as it closes.
  void _openCropper(PickedSoundFile file) {
    final top = _router.routerDelegate.currentConfiguration.last.route;
    final onCropper = top.name == AppRoute.soundCrop;
    unawaited(
      onCropper
          ? _router.pushReplacementNamed(AppRoute.soundCrop, extra: file)
          : _router.pushNamed(AppRoute.soundCrop, extra: file),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _push.start();
    _reminders.start();
    // Sign-in, sign-out, a linked provider and an account delete all bump
    // this. Re-plan from what is left right away.
    appAccountIdentityChanges.addListener(_replan);
    appPlanChanges.addListener(_replan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Plan once the first frame is up, so launch never waits on it.
      _replan();
    });
    _incomingAudio.start();
    getIt<WidgetSync>().start();
    _autoDelete();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_push.dispose());
    unawaited(_reminders.dispose());
    unawaited(_quickActions.dispose());
    appAccountIdentityChanges.removeListener(_replan);
    appPlanChanges.removeListener(_replan);
    unawaited(_incomingAudio.dispose());
    unawaited(getIt<WidgetSync>().dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_push.onResumed());
    getIt<WidgetSync>().forget();
    unawaited(_reminders.onResumed());
    _replan();
    unawaited(_incomingAudio.onResumed());
    unawaited(_retryFailedLaunchCalls());
    _autoDelete();
  }

  /// Device registration, the Live Activity token upload and the incident
  /// reconcile each retry themselves on launch. If one still failed after
  /// every retry, this gives it one more try on the next resume instead of
  /// waiting for the next cold start.
  Future<void> _retryFailedLaunchCalls() async {
    if (!buildUsesMockApi) {
      unawaited(getIt<DeviceTokenRegistry>().retryIfPending());
      unawaited(getIt<LiveActivityTokenRegistry>().retryIfPending());
    }
    unawaited(getIt<IncidentAlarmController>().retryIfPending());
  }

  /// Drops alarms the user asked the phone to stop keeping. Does nothing
  /// until they set "Delete alarms after", which defaults to Never.
  void _autoDelete() => unawaited(getIt<AutoDeleteHistoryUsecase>()());

  /// Every open and resume re-plans: time zone, switches, topics and
  /// incidents may all have changed while the app was away.
  void _replan() => unawaited(getIt<ReminderPlanTrigger>().run());

  @override
  Widget build(BuildContext context) {
    // Incidents and topics are provided above the router, so every route sees
    // the same two cubits. `.value`, because they are singletons that outlive
    // this widget and must not be closed with it.
    return MultiBlocProvider(
      providers: [
        BlocProvider<IncidentsCubit>.value(value: getIt<IncidentsCubit>()),
        BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
        BlocProvider<ThemeCubit>(
          create: (_) {
            final cubit = getIt<ThemeCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider<AppearanceCubit>(
          create: (_) {
            final cubit = getIt<AppearanceCubit>();
            unawaited(cubit.load());
            return cubit;
          },
        ),
      ],
      child: BlocBuilder<ThemeCubit, AppThemeMode>(
        builder: (context, mode) => MaterialApp.router(
          onGenerateTitle: (context) => LocaleKeys.app_title.tr(),
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode.toThemeMode(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          routerConfig: _router,
          scaffoldMessengerKey: _messenger,
          builder: (context, child) => _AppearanceScope(
            child: _OnTranslationsLoaded(
              onLoaded: _quickActions.start,
              child: AppDeviceScope(
                isIphone:
                    getIt.isRegistered<DeviceForm>() &&
                    getIt<DeviceForm>().isIphone,
                child: TourHost(
                  router: _router,
                  child: AppAmbientShell(
                    router: _router,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calls [onLoaded] once, the first time it is built.
///
/// The quick action titles go through tr(). The translations load from disk
/// in the background, and a post-frame callback can fire before they finish,
/// which makes iOS store the raw keys. MaterialApp's builder sits inside its
/// Localizations widget, and that widget builds nothing until the
/// translations are loaded, so by the time this runs tr() works.
class _OnTranslationsLoaded extends StatefulWidget {
  const _OnTranslationsLoaded({required this.onLoaded, required this.child});

  final VoidCallback onLoaded;
  final Widget child;

  @override
  State<_OnTranslationsLoaded> createState() => _OnTranslationsLoadedState();
}

class _OnTranslationsLoadedState extends State<_OnTranslationsLoaded> {
  @override
  void initState() {
    super.initState();
    widget.onLoaded();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Applies the Appearance choices to everything below it.
///
/// Reduce motion goes into [MediaQueryData.disableAnimations], which every
/// `context.motion` and `context.reduceMotion` already reads, so it can only
/// add to the OS setting, never switch it off. Haptics are applied by
/// AppearanceCubit itself.
class _AppearanceScope extends StatelessWidget {
  const _AppearanceScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppearanceCubit, AppearanceSettings>(
      builder: (context, settings) {
        if (!settings.reduceMotion) return child;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        );
      },
    );
  }
}
