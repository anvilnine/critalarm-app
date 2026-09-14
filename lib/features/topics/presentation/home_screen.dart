import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// HomeScreen matching docs/design-system/index.html mobile mockup.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<HomeCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatelessWidget {
  const _HomeScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return SeverityScope(
          severity: state.severity,
          child: AppScreenScaffold(
            onRefresh: () => context.read<HomeCubit>().refresh(),
            topBar: AppTopBar(
              title: LocaleKeys.topics_list_title.tr(),
              trailing: AppIconButton(
                glyph: GlyphType.search,
                ariaLabel: LocaleKeys.topics_list_search_aria_label.tr(),
                onPressed: () {},
              ),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: Spacing.s3),
                    AppStage(
                      faceState: state.faceState,
                      word: state.word,
                      sub: state.subText,
                    ),
                    const SizedBox(height: Spacing.s4),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: AppSheet(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.topicItems.isEmpty) ...[
                          AppEmptyState(
                            onButtonPressed: () => context.push('/topics/new'),
                          ),
                        ] else ...[
                          for (final topic in state.topicItems) ...[
                            AppListRow(
                              name: topic.name,
                              meta: topic.meta,
                              faceState: topic.faceState,
                              isCrit: topic.isCrit,
                              isQuiet: topic.isQuiet,
                              trailing: AppPriorityChip(
                                priority: topic.priority,
                              ),
                              onTap: () =>
                                  context.push('/topics/${topic.name}'),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
