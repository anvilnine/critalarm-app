import 'dart:async';

import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/topics/domain/topic_tokens_page_rules.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Opens the sheet that renames or revokes [token].
///
/// Save renames it. Revoke closes the sheet and asks first, in a dialog over
/// [context]. A topic's last token has no Revoke, because the server refuses
/// to take it.
Future<void> openTokenEditSheet(
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

/// One token: its name, when it was made, and a way into its sheet.
///
/// The id is not on the row. It says nothing about what the token is for, and
/// it reads close enough to a `tk_` value that people try to send with it.
class TokenListRow extends StatelessWidget {
  const TokenListRow({
    required this.token,
    required this.onTap,
    this.nameMaxLines = 1,
    super.key,
  });

  final TopicTokenInfo token;
  final VoidCallback? onTap;

  /// How many lines the name may take before it is cut. A page with room for
  /// long names raises it, so large text never hides the end of a name.
  final int nameMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: LocaleKeys.topic_tokens_edit_aria.tr(),
      button: true,
      child: AppListRow(
        name: token.name,
        meta: tokenMadeLine(
          createdAt: token.createdAt,
          now: DateTime.now(),
          madeJustNow: LocaleKeys.topic_tokens_made_just_now.tr(),
          madeOn: (when) =>
              LocaleKeys.topic_tokens_made_on.tr(namedArgs: {'date': when}),
          // Said inside a sentence, so it is in lower case.
          yesterday: LocaleKeys.topic_tokens_yesterday.tr(),
        ),
        faceState: null,
        onTap: onTap,
        nameMaxLines: nameMaxLines,
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
          TokenNote(
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
class TokenNote extends StatelessWidget {
  const TokenNote(this.text, {this.color, super.key});

  final String text;

  /// Overrides the muted ink, for a line that sits straight on a canvas.
  final Color? color;

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
        color: color ?? colors.ink3,
      ),
    );
  }
}
