import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/design_system/theme.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/theme_mode_mapper.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  StreamSubscription<String>? _deepLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A notification tapped while the app is already running does not go
    // through the initial route, so the platform hands the route over here.
    if (getIt.isRegistered<PushHost>()) {
      _deepLinks = getIt<PushHost>().deepLinks.listen(_router.go);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_deepLinks?.cancel());
    super.dispose();
  }

  /// Coming back to the app reloads the shared lists, once, for every screen.
  /// A page can land while the phone is in a pocket, and the whole point of
  /// this app is showing it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(getIt<IncidentsCubit>().refresh());
    unawaited(getIt<TopicsCubit>().refresh());
  }

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
        ),
      ),
    );
  }
}
