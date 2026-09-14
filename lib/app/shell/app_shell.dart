import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/scroll_fade.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Holds the three root destinations and floats the tab bar over whichever one
/// is showing. Each branch keeps its own history, so switching tabs and coming
/// back lands where the user left off.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<ShellCubit>();
        unawaited(cubit.refresh());
        return cubit;
      },
      child: _AppShellContent(navigationShell: navigationShell),
    );
  }
}

class _AppShellContent extends StatelessWidget {
  const _AppShellContent({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    unawaited(context.read<ShellCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return BlocBuilder<ShellCubit, int>(
      builder: (context, missingPermissions) {
        return Stack(
          children: [
            Positioned.fill(child: navigationShell),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AppScrollFade(
                  edge: ScrollFadeEdge.bottom,
                  height: bottomInset + 112,
                  color: colors.canvas,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 22,
              child: Center(
                // Four slots inside 390 px is tight. Scale the whole bar down
                // rather than let a label clip on a narrow display.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AppFloatingTabBar(
                      currentIndex: navigationShell.currentIndex,
                      items: [
                        AppTabItem(label: LocaleKeys.nav_topics.tr()),
                        AppTabItem(label: LocaleKeys.nav_history.tr()),
                        AppTabItem(
                          label: LocaleKeys.nav_settings.tr(),
                          showFlag: missingPermissions > 0,
                        ),
                      ],
                      onSelect: (index) => _goBranch(context, index),
                      composeLabel: LocaleKeys.nav_new_topic.tr(),
                      onCompose: () => context.pushNamed('createTopic'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
