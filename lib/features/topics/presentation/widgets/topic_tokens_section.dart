import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
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
    this.cubit,
    super.key,
  });

  final String topicName;

  /// Opens the "Get curl line" sheet once, as soon as this builds.
  final bool startCurlFlow;

  /// Optional cubit for testing.
  final TopicTokensCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _TopicTokensSectionContent(startCurlFlow: startCurlFlow),
      );
    }
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicTokensCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: _TopicTokensSectionContent(startCurlFlow: startCurlFlow),
    );
  }
}

class _TopicTokensSectionContent extends StatefulWidget {
  const _TopicTokensSectionContent({required this.startCurlFlow});

  final bool startCurlFlow;

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
      title: LocaleKeys.reminders_curl_sheet_title.tr(
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
      message: LocaleKeys.reminders_curl_sample_message.tr(),
    );
    await Clipboard.setData(ClipboardData(text: line));
    // The raw token value and its own copy button would otherwise linger in
    // the "new token" banner below, right next to the line just copied.
    cubit.dismissNewToken();
    AppHaptics.selection();
    messenger.showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.reminders_curl_copied.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openToken(
    BuildContext context,
    TopicTokensCubit cubit,
    TopicTokenInfo token,
  ) async {
    await showAppSheet<void>(
      context: context,
      title: LocaleKeys.topic_tokens_edit_title.tr(),
      content: (sheetContext) => _TokenEditSheet(
        token: token,
        canRevoke: cubit.state.canRevoke,
        otherNames: [
          for (final other in cubit.state.tokens)
            if (other.tokenId != token.tokenId) other.name,
        ],
        onSave: (name) {
          Navigator.of(sheetContext).pop();
          unawaited(cubit.rename(token.tokenId, name));
        },
        onRevoke: () {
          Navigator.of(sheetContext).pop();
          unawaited(_confirmRevoke(context, cubit, token.tokenId));
        },
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    TopicTokensCubit cubit,
    String tokenId,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: LocaleKeys.topic_tokens_revoke_dialog_title.tr(),
      body: LocaleKeys.topic_tokens_revoke_dialog_content.tr(),
      actions: [
        AppDialogAction(
          label: LocaleKeys.common_cancel.tr(),
          value: false,
          variant: AppButtonVariant.ghost,
        ),
        AppDialogAction(
          label: LocaleKeys.topic_tokens_revoke_dialog_confirm.tr(),
          value: true,
          variant: AppButtonVariant.crit,
        ),
      ],
    );
    if (confirmed != true) return;
    AppHaptics.destructive();
    await cubit.revoke(tokenId);
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
            const AppSectionDivider(),
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
                            _Note(
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
                              _TokenRow(
                                token: token,
                                onTap: state.isWorking
                                    ? null
                                    : () => unawaited(
                                        _openToken(
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
                                            _Note(
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
                                            _Note(state.errorMessage!),
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

/// One token: its name, when it was made, and a way into its sheet.
///
/// The id is not on the row. It says nothing about what the token is for, and
/// it reads close enough to a `tk_` value that people try to send with it.
class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token, required this.onTap});

  final TopicTokenInfo token;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final made = token.createdAt;

    return Semantics(
      label: LocaleKeys.topic_tokens_edit_aria.tr(),
      button: true,
      child: AppListRow(
        name: token.name,
        meta: made == null
            ? LocaleKeys.topic_tokens_made_just_now.tr()
            : LocaleKeys.topic_tokens_made_on.tr(
                namedArgs: {
                  'date': DateFormat('MMM d, y').format(made.toLocal()),
                },
              ),
        faceState: null,
        onTap: onTap,
        trailing: AppGlyph(GlyphType.chevron, color: colors.ink3),
      ),
    );
  }
}

/// Rename or revoke one token.
///
/// The value is not in here and cannot be. The server keeps a hash of it, so
/// the only thing this sheet can change is the name.
class _TokenEditSheet extends StatefulWidget {
  const _TokenEditSheet({
    required this.token,
    required this.canRevoke,
    required this.otherNames,
    required this.onSave,
    required this.onRevoke,
  });

  final TopicTokenInfo token;

  /// False on a topic's last token. The server refuses to take it, so the
  /// sheet does not offer to.
  final bool canRevoke;

  /// What the other tokens on this topic are called. Names do not have to be
  /// unique, so a match is only worth a note.
  final List<String> otherNames;
  final ValueChanged<String> onSave;
  final VoidCallback onRevoke;

  @override
  State<_TokenEditSheet> createState() => _TokenEditSheetState();
}

class _TokenEditSheetState extends State<_TokenEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.token.name,
  );

  /// Another token on this topic already goes by the name being typed.
  bool _isNameTaken = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _controller.text.trim();
    final taken = name.isNotEmpty && widget.otherNames.contains(name);
    if (taken == _isNameTaken) return;
    setState(() => _isNameTaken = taken);
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    AppHaptics.capture();
    widget.onSave(name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          label: LocaleKeys.topic_tokens_edit_name_label.tr(),
          controller: _controller,
          placeholder: LocaleKeys.topic_tokens_edit_name_placeholder.tr(),
          maxLength: 40,
          isMono: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        // A heads-up, not a stop sign. The server allows two tokens with the
        // same name on one topic, so Save keeps working.
        if (_isNameTaken) ...[
          const SizedBox(height: 8),
          _Note(
            LocaleKeys.topic_tokens_name_taken_warning.tr(
              namedArgs: {'name': _controller.text.trim()},
            ),
          ),
        ],
        const SizedBox(height: 14),
        AppButton(
          label: LocaleKeys.topic_tokens_edit_save_button.tr(),
          isFullWidth: true,
          onPressed: _save,
        ),
        if (widget.canRevoke) ...[
          const SizedBox(height: 10),
          AppButton(
            label: LocaleKeys.topic_tokens_edit_revoke_button.tr(),
            variant: AppButtonVariant.crit,
            isFullWidth: true,
            onPressed: widget.onRevoke,
          ),
        ],
      ],
    );
  }
}

/// A line of small muted text. Used for the loading line, an error the list
/// survived, the name-already-used note, and the save-it-now warning.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.ink3,
      ),
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
    text: LocaleKeys.reminders_curl_default_name.tr(),
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
          label: LocaleKeys.reminders_curl_name_label.tr(),
          controller: _controller,
        ),
        const SizedBox(height: 16),
        AppButton(
          label: LocaleKeys.reminders_curl_make_button.tr(),
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
                        ? LocaleKeys.reminders_curl_default_name.tr()
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
