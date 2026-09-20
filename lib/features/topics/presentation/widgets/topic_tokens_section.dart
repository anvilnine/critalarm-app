import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/token_actions.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Tokens block on a topic: what it has, a button to make one more, and a
/// way to revoke any of them.
///
/// Only ids and dates are listed. A token value exists on screen exactly once,
/// right after it is made, because the server keeps a hash of it and has
/// nothing to hand back later.
class TopicTokensSection extends StatelessWidget {
  const TopicTokensSection({required this.topicName, super.key});

  final String topicName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<TopicTokensCubit>();
        unawaited(cubit.load(topicName));
        return cubit;
      },
      child: const _TopicTokensSectionContent(),
    );
  }
}

class _TopicTokensSectionContent extends StatelessWidget {
  const _TopicTokensSectionContent();

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
            if (state.status == TopicTokensStatus.loading &&
                state.tokens.isEmpty)
              _Note(LocaleKeys.topic_tokens_loading.tr())
            else if (state.status == TopicTokensStatus.failure &&
                state.tokens.isEmpty) ...[
              _Note(
                state.errorMessage ?? LocaleKeys.topic_tokens_load_failed.tr(),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: LocaleKeys.topic_detail_retry_button.tr(),
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                isFullWidth: true,
                onPressed: () => unawaited(cubit.load(cubit.topicName)),
              ),
            ] else ...[
              for (final token in state.tokens) ...[
                _TokenRow(
                  token: token,
                  onTap: state.isWorking
                      ? null
                      : () => unawaited(_openToken(context, cubit, token)),
                ),
                const SizedBox(height: 8),
              ],
              // The one moment the value exists on screen. Nothing can ask the
              // server for it again.
              if (made != null) ...[
                Text(
                  LocaleKeys.topic_tokens_new_label.tr(),
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.ink3,
                  ),
                ),
                if (state.newTokenName case final newName?
                    when newName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    newName,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontFamilyFallback: AppTypography.fontBodyFallbacks,
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
                    onCopied: (_) => AppHaptics.selection(),
                  ),
                ),
                const SizedBox(height: 6),
                _Note(LocaleKeys.create_topic_token_warning.tr()),
                const SizedBox(height: 8),
                AppButton(
                  label: LocaleKeys.topic_tokens_saved_button.tr(),
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  isFullWidth: true,
                  onPressed: cubit.dismissNewToken,
                ),
                const SizedBox(height: 8),
              ],
              if (state.errorMessage != null && state.tokens.isNotEmpty) ...[
                _Note(state.errorMessage!),
                const SizedBox(height: 8),
              ],
              AppButton(
                label: LocaleKeys.topic_tokens_new_button.tr(),
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                isFullWidth: true,
                isLoading: state.isWorking,
                onPressed: () => unawaited(cubit.createToken()),
              ),
            ],
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
