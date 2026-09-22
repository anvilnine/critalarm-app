import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/push_bindings.dart';
import 'package:critalarm/app/quick_action_bindings.dart';
import 'package:critalarm/app/reminder_bindings.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/design_system/theme.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/presentation/open_feedback_form.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
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
  );

  /// Reminder taps. They route through the same router as everything else,
  /// by [_openPath].
  late final ReminderBindings _reminders = ReminderBindings(
    scheduler: getIt<ReminderScheduler>(),
    prompts: getIt<HomePromptRepository>(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _push.start();
    _reminders.start();
    _quickActions.start();
    // Sign-in, sign-out, a linked provider and an account delete all bump
    // this. Re-plan from what is left right away.
    appAccountIdentityChanges.addListener(_replan);
    // Plan once the first frame is up, so launch never waits on it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _replan());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_push.dispose());
    unawaited(_reminders.dispose());
    unawaited(_quickActions.dispose());
    appAccountIdentityChanges.removeListener(_replan);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_push.onResumed());
    unawaited(_reminders.onResumed());
    _replan();
  }

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
          builder: (context, child) => TourHost(
            router: _router,
            child: AppAmbientShell(
              router: _router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
