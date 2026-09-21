import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/incoming_audio_bindings.dart';
import 'package:critalarm/app/push_bindings.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/app_ambient_shell.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design_system/theme.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/settings/presentation/theme_mode_mapper.dart';
import 'package:critalarm/features/tour/presentation/tour_host.dart';
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

  /// Taps, foreground pushes and the resume reload. A notification tapped
  /// while the app is already running does not go through the initial route,
  /// so the platform hands the route over here.
  late final AppPushBindings _push = AppPushBindings(
    getIt<PushHost>(),
    getIt<IncidentsCubit>(),
    getIt<TopicsCubit>(),
    _router.go,
  );

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
    showMessage: (message) => _messenger.currentState
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
      ),
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
    _incomingAudio.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_push.dispose());
    unawaited(_incomingAudio.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_push.onResumed());
    unawaited(_incomingAudio.onResumed());
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
          scaffoldMessengerKey: _messenger,
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
