import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_edit_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Tokens block on a topic: what it has, a button to make one more, and a
/// way to revoke any of them.
///
/// Only ids and dates are listed. A token value exists on screen exactly once,
/// right after it is made, because the server keeps a hash of it and has
/// nothing to hand back later.
class TopicTokensSection extends StatelessWidget {
  const TopicTokensSection({
    required this.topicName,
    this.startCurlFlow = false,
    this.hasDivider = true,
    this.cubit,
    super.key,
  });

  final String topicName;

  /// Opens the "Get curl line" sheet once, as soon as this builds.
  final bool startCurlFlow;

  /// A hairline above the header. A screen that sets the block apart some
  /// other way turns it off.
  final bool hasDivider;

  /// Optional cubit for testing.
  final TopicTokensCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _TopicTokensSectionContent(
          startCurlFlow: startCurlFlow,
          hasDivider: hasDivider,
        ),
      );
    }
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicTokensCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: _TopicTokensSectionContent(
        startCurlFlow: startCurlFlow,
        hasDivider: hasDivider,
      ),
    );
  }
}

class _TopicTokensSectionContent extends StatefulWidget {
  const _TopicTokensSectionContent({
    required this.startCurlFlow,
    required this.hasDivider,
  });

  final bool startCurlFlow;
  final bool hasDivider;

  @override
  State<_TopicTokensSectionContent> createState() =>
      _TopicTokensSectionContentState();
}

class _TopicTokensSectionContentState
    extends State<_TopicTokensSectionContent> {
  @override
  void initState() {
    super.initState();
    if (widget.startCurlFlow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openCurlSheet());
      });
    }
  }

  /// "Get curl line" from the silent topic reminder. The existing new-token
  /// flow, with the name filled in as "Script". Nothing is minted until the
  /// button in the sheet is tapped.
  Future<void> _openCurlSheet() async {
    final cubit = context.read<TopicTokensCubit>();
    final name = await showAppSheet<String>(
      context: context,
      title: LocaleKeys.local_reminders_curl_sheet_title.tr(
        namedArgs: {'topic': cubit.topicName},
      ),
      content: (sheetContext) => StreamBuilder<TopicTokensState>(
        stream: cubit.stream,
        initialData: cubit.state,
        builder: (context, snapshot) => _CurlTokenSheet(
          // The sheet's own button, not the tokens list's: this one guards
          // against a fast double tap minting two tokens.
          isWorking: snapshot.data?.isWorking ?? false,
          onMake: (value) => Navigator.of(sheetContext).pop(value),
          onCancel: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final token = await cubit.createNamedToken(name);
    if (token == null) return;
    final connection = (await getIt<GetConnectionUsecase>()(
      const NoParams(),
    )).getOrNull();
    if (connection == null || !mounted) return;

    final line = CurlLine.build(
      serverUrl: connection.serverUrl,
      topic: cubit.topicName,
      token: token,
      message: LocaleKeys.local_reminders_curl_sample_message.tr(),
    );
    await Clipboard.setData(ClipboardData(text: line));
    // The raw token value and its own copy button would otherwise linger in
    // the "new token" banner below, right next to the line just copied.
    cubit.dismissNewToken();
    AppHaptics.selection();
    messenger.showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.local_reminders_curl_copied.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<TopicTokensCubit, TopicTokensState>(
      builder: (context, state) {
        final cubit = context.read<TopicTokensCubit>();
        final made = state.newToken;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hasDivider) const AppSectionDivider(),
            AppSectionHeader(LocaleKeys.topic_tokens_header.tr()),
            AnimatedSize(
              duration: context.motion(AppDurations.base),
              curve: AppCurves.easeOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: context.motion(AppDurations.base),
                switchInCurve: AppCurves.easeOut,
                switchOutCurve: AppCurves.easeOut,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child:
                    state.status == TopicTokensStatus.loading &&
                        state.tokens.isEmpty
                    ? const KeyedSubtree(
                        key: ValueKey('tokens_skeleton'),
                        child: AppTokensSectionSkeleton(),
                      )
                    : state.status == TopicTokensStatus.failure &&
                          state.tokens.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('tokens_failure'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TokenNote(
                              state.errorMessage ??
                                  LocaleKeys.topic_tokens_load_failed.tr(),
                            ),
                            const SizedBox(height: 8),
                            AppButton(
                              label: LocaleKeys.topic_detail_retry_button.tr(),
                              variant: AppButtonVariant.ghost,
                              size: AppButtonSize.sm,
                              isFullWidth: true,
                              onPressed: () => unawaited(
                                cubit.load(cubit.topicName),
                              ),
                            ),
                          ],
                        ),
                      )
                    : KeyedSubtree(
                        key: ValueKey(
                          'tokens_loaded_${state.tokens.length}',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final token in state.tokens) ...[
                              TokenListRow(
                                token: token,
                                onTap: state.isWorking
                                    ? null
                                    : () => unawaited(
                                        openTokenEditSheet(
                                          context,
                                          cubit,
                                          token,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // The one moment the value exists on screen.
                            // Nothing can ask the server for it again.
                            AnimatedSize(
                              duration: context.motion(AppDurations.base),
                              curve: AppCurves.easeOut,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: context.motion(AppDurations.base),
                                switchInCurve: AppCurves.easeOut,
                                switchOutCurve: AppCurves.easeOut,
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: made != null
                                    ? KeyedSubtree(
                                        key: ValueKey('new_token_$made'),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              LocaleKeys.topic_tokens_new_label
                                                  .tr(),
                                              style: TextStyle(
                                                fontFamily:
                                                    AppTypography.fontBody,
                                                fontFamilyFallback:
                                                    AppTypography
                                                        .fontBodyFallbacks,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: colors.ink3,
                                              ),
                                            ),
                                            if (state.newTokenName
                                                case final newName?
                                                when newName.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                newName,
                                                style: TextStyle(
                                                  fontFamily:
                                                      AppTypography.fontBody,
                                                  fontFamilyFallback:
                                                      AppTypography
                                                          .fontBodyFallbacks,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.ink,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            AppKeyValueRow(
                                              value: made,
                                              trailing: TokenActions(
                                                value: made,
                                                onCopied: (_) =>
                                                    AppHaptics.selection(),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TokenNote(
                                              LocaleKeys
                                                  .create_topic_token_warning
                                                  .tr(),
                                            ),
                                            const SizedBox(height: 8),
                                            AppButton(
                                              label: LocaleKeys
                                                  .topic_tokens_saved_button
                                                  .tr(),
                                              variant: AppButtonVariant.ghost,
                                              size: AppButtonSize.sm,
                                              isFullWidth: true,
                                              onPressed: cubit.dismissNewToken,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('no_new_token'),
                                      ),
                              ),
                            ),
                            // Shown whatever the token count: a refused
                            // create (the usual silent-topic case, where the
                            // topic has no token yet) must not read as "no
                            // error" just because the list is still empty.
                            AnimatedSize(
                              duration: context.motion(AppDurations.base),
                              curve: AppCurves.easeOut,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: context.motion(AppDurations.base),
                                switchInCurve: AppCurves.easeOut,
                                switchOutCurve: AppCurves.easeOut,
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: state.errorMessage != null
                                    ? KeyedSubtree(
                                        key: ValueKey(
                                          'token_error_${state.errorMessage}',
                                        ),
                                        child: Column(
                                          children: [
                                            TokenNote(state.errorMessage!),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('no_token_error'),
                                      ),
                              ),
                            ),
                            AppButton(
                              label: LocaleKeys.topic_tokens_new_button.tr(),
                              size: AppButtonSize.sm,
                              isFullWidth: true,
                              isLoading: state.isWorking,
                              onPressed: () => unawaited(cubit.createToken()),
                            ),
                          ],
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

/// The name field and the two buttons of the "Get curl line" sheet.
class _CurlTokenSheet extends StatefulWidget {
  const _CurlTokenSheet({
    required this.isWorking,
    required this.onMake,
    required this.onCancel,
  });

  /// True while the previous tap's token is still being made. Keeps a fast
  /// double tap from minting two.
  final bool isWorking;
  final ValueChanged<String> onMake;
  final VoidCallback onCancel;

  @override
  State<_CurlTokenSheet> createState() => _CurlTokenSheetState();
}

class _CurlTokenSheetState extends State<_CurlTokenSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: LocaleKeys.local_reminders_curl_default_name.tr(),
  );

  /// Set by the first tap on either button. Both pop the sheet, so a second
  /// tap before it closes would pop the screen under it.
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: LocaleKeys.local_reminders_curl_name_label.tr(),
          controller: _controller,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.local_reminders_curl_make_button.tr(),
          isFullWidth: true,
          isLoading: widget.isWorking,
          onPressed: widget.isWorking
              ? null
              : () {
                  if (_submitted) return;
                  _submitted = true;
                  final name = _controller.text.trim();
                  widget.onMake(
                    name.isEmpty
                        ? LocaleKeys.local_reminders_curl_default_name.tr()
                        : name,
                  );
                },
        ),
        const SizedBox(height: 8),
        AppButton(
          label: LocaleKeys.common_cancel.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: () {
            if (_submitted) return;
            _submitted = true;
            widget.onCancel();
          },
        ),
      ],
    );
  }
}
