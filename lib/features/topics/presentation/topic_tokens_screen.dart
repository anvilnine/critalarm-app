import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/new_token_sheet.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_edit_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Every token on one topic: a plain list and one New token button.
///
/// A row opens the sheet that renames or revokes it. The button opens the
/// New token sheet, which makes nothing until its own button is tapped.
/// Only names and dates are listed. A token value exists on screen once, in
/// that sheet, right after it is made.
class TopicTokensScreen extends StatelessWidget {
  const TopicTokensScreen({
    required this.topicName,
    this.startCurlFlow = false,
    this.cubit,
    this.readServerUrl,
    super.key,
  });

  final String topicName;

  /// Opens the New token sheet once, with the name filled in, as soon as the
  /// page builds. The silent topic reminder's "Get curl line" arrives here.
  final bool startCurlFlow;

  /// Optional cubit for testing and captures. It is not closed here.
  final TopicTokensCubit? cubit;

  /// Stands in for reading the saved connection when the sheet shows its
  /// curl line. Null reads the saved one.
  final Future<String?> Function()? readServerUrl;

  @override
  Widget build(BuildContext context) {
    final view = _TopicTokensView(
      topicName: topicName,
      startCurlFlow: startCurlFlow,
      readServerUrl: readServerUrl,
    );
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: view);
    }
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicTokensCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: view,
    );
  }
}

class _TopicTokensView extends StatefulWidget {
  const _TopicTokensView({
    required this.topicName,
    required this.startCurlFlow,
    required this.readServerUrl,
  });

  final String topicName;
  final bool startCurlFlow;
  final Future<String?> Function()? readServerUrl;

  @override
  State<_TopicTokensView> createState() => _TopicTokensViewState();
}

class _TopicTokensViewState extends State<_TopicTokensView> {
  @override
  void initState() {
    super.initState();
    if (widget.startCurlFlow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openNewToken(initialName: _scriptName()));
      });
    }
  }

  String _scriptName() => LocaleKeys.local_reminders_curl_default_name.tr();

  Future<void> _openNewToken({String? initialName}) {
    return showNewTokenSheet(
      context,
      cubit: context.read<TopicTokensCubit>(),
      initialName: initialName,
      readServerUrl: widget.readServerUrl,
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/topics/${Uri.encodeComponent(widget.topicName)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<TopicTokensCubit, TopicTokensState>(
      builder: (context, state) {
        final cubit = context.read<TopicTokensCubit>();
        final isLoading =
            state.status == TopicTokensStatus.loading && state.tokens.isEmpty;
        final hasFailed =
            state.status == TopicTokensStatus.failure && state.tokens.isEmpty;
        // A refused rename, revoke or make. A failed load has its own line
        // inside the sheet.
        final refused = hasFailed ? null : state.errorMessage;

        return AppScreenScaffold(
          hasTabBar: false,
          topBar: AppTopBar(
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.topic_tokens_page_back_aria.tr(
                namedArgs: {'topic': widget.topicName},
              ),
              onPressed: _back,
            ),
            // In the title slot, which is the one slot that is given a
            // width, so the chip shrinks with an ellipsis for a long name.
            titleWidget: SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: AppTopicChip(text: widget.topicName)),
                ],
              ),
            ),
          ),
          bottomBar: AppButton(
            label: LocaleKeys.topic_tokens_new_button.tr(),
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: state.isWorking
                ? null
                : () => unawaited(_openNewToken()),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, Spacing.s3, 20, 14),
                child: Semantics(
                  header: true,
                  child: Text(
                    LocaleKeys.topic_tokens_header.tr(),
                    style: AppTypography.headline(
                      colors.onCanvas,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheet(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: AnimatedSize(
                        duration: context.motion(AppDurations.base),
                        curve: AppCurves.easeOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: context.motion(AppDurations.base),
                          switchInCurve: AppCurves.easeOut,
                          switchOutCurve: AppCurves.easeOut,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  ...previousChildren,
                                  ?currentChild,
                                ],
                              ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: isLoading
                              ? const KeyedSubtree(
                                  key: ValueKey('tokens_page_skeleton'),
                                  child: _Skeleton(),
                                )
                              : hasFailed
                              ? KeyedSubtree(
                                  key: const ValueKey('tokens_page_failure'),
                                  child: _LoadFailed(
                                    message:
                                        state.errorMessage ??
                                        LocaleKeys.topic_tokens_load_failed
                                            .tr(),
                                    onRetry: () =>
                                        unawaited(cubit.load(cubit.topicName)),
                                  ),
                                )
                              : KeyedSubtree(
                                  key: ValueKey(
                                    'tokens_page_list_${state.tokens.length}',
                                  ),
                                  child: _Rows(
                                    state: state,
                                    onOpen: (token) => unawaited(
                                      openTokenEditSheet(context, cubit, token),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (refused != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: TokenNote(refused, color: colors.onCanvas),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The token rows, one under the other with a hairline between.
class _Rows extends StatelessWidget {
  const _Rows({required this.state, required this.onOpen});

  final TopicTokensState state;
  final ValueChanged<TopicTokenInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = state.tokens;
    // Nothing to list should not happen (a topic keeps one token) but the
    // sheet still draws, at a size that reads as a card.
    if (tokens.isEmpty) return const SizedBox(height: 24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tokens.length; i++) ...[
          if (i > 0)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: colors.hairline,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: TokenListRow(
              token: tokens[i],
              nameMaxLines: 5,
              onTap: state.isWorking ? null : () => onOpen(tokens[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const AppSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTokenRowSkeleton(),
          SizedBox(height: 8),
          AppTokenRowSkeleton(),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(liveRegion: true, child: TokenNote(message)),
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.topic_detail_retry_button.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
