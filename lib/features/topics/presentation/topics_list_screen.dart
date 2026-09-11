import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// TopicsListScreen showing all registered topics or an empty state.
class TopicsListScreen extends StatelessWidget {
  const TopicsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicsListCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: const _TopicsListScreenContent(),
    );
  }
}

class _TopicsListScreenContent extends StatelessWidget {
  const _TopicsListScreenContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: GhostField(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                leading: AppIconButton(
                  glyph: GlyphType.back,
                  ariaLabel: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                title: 'Topics',
                trailing: AppIconButton(
                  glyph: GlyphType.plus,
                  ariaLabel: 'New topic',
                  onPressed: () => context.push('/topics/new'),
                ),
              ),
              const SizedBox(height: Spacing.s4),
              Expanded(
                child: BlocBuilder<TopicsListCubit, TopicsListState>(
                  builder: (context, state) {
                    if (state.isEmpty) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppEmptyState(
                          onButtonPressed: () => context.push('/topics/new'),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: AppSheet(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final topic in state.topics) ...[
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
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
