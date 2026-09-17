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

  Future<void> _confirmRevoke(
    BuildContext context,
    TopicTokensCubit cubit,
    String tokenId,
  ) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text(
          LocaleKeys.topic_tokens_revoke_dialog_title.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontFamilyFallback: AppTypography.fontDisplayFallbacks,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        content: Text(
          LocaleKeys.topic_tokens_revoke_dialog_content.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 14,
            color: colors.ink2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              LocaleKeys.common_cancel.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                color: colors.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              LocaleKeys.topic_tokens_revoke_dialog_confirm.tr(),
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
                color: colors.crit,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
                  canRevoke: state.canRevoke && !state.isWorking,
                  onRevoke: () => unawaited(
                    _confirmRevoke(context, cubit, token.tokenId),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // The revoke control is gone on the last token, so say why
              // before someone hunts for it. Skipped while an error is up,
              // because a refused revoke already says this.
              if (state.tokens.length == 1 &&
                  state.isReady &&
                  state.errorMessage == null) ...[
                _Note(LocaleKeys.topic_tokens_last_token_note.tr()),
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

/// One token: its id, when it was made, and a way to revoke it.
class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.token,
    required this.canRevoke,
    required this.onRevoke,
  });

  final TopicTokenInfo token;
  final bool canRevoke;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final made = token.createdAt;

    return AppListRow(
      name: token.tokenId,
      meta: made == null
          ? LocaleKeys.topic_tokens_made_just_now.tr()
          : LocaleKeys.topic_tokens_made_on.tr(
              namedArgs: {
                'date': DateFormat('MMM d, y').format(made.toLocal()),
              },
            ),
      faceState: null,
      trailing: canRevoke
          ? Semantics(
              label: LocaleKeys.topic_tokens_revoke_aria.tr(),
              button: true,
              child: GestureDetector(
                onTap: onRevoke,
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: Radii.fullAll,
                    border: Border.all(color: colors.hairline, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: AppGlyph(GlyphType.close, color: colors.crit),
                ),
              ),
            )
          : null,
    );
  }
}

/// A line of small muted text. Used for the loading line, an error the list
/// survived, the last-token note, and the save-it-now warning.
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
