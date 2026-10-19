import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/language/presentation/language_mistake_line.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The app's language: System default first, then each shipped language in
/// its own name. A tap picks it at once, there is no Save.
///
/// [LanguageCubit] lives for the whole app, so the screen only observes it.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<LanguageCubit>();
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.language_title.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSheet(
                  child: BlocBuilder<LanguageCubit, LanguageState>(
                    bloc: cubit,
                    builder: (context, state) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, choice) in cubit.choices.indexed) ...[
                          if (i > 0) const SizedBox(height: 8),
                          AppRadioRow(
                            title: choice.nativeName,
                            selected: choice.tag == state.selectedTag,
                            onTap: () {
                              AppHaptics.selection();
                              unawaited(cubit.select(choice.tag));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const LanguageMistakeLine(screen: 'language'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
