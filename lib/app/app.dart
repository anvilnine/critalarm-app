import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
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

class _CritAlarmAppState extends State<CritAlarmApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>(
      create: (_) {
        final cubit = getIt<ThemeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
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
