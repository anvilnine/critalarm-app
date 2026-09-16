import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copy and Share, side by side.
///
/// The card tells the user this token is shown once and to save it now, and
/// the value is truncated to fit the row, so Copy is the only way to actually
/// obey that instruction. Share stays for sending it somewhere else.
class TokenActions extends StatelessWidget {
  const TokenActions({
    required this.value,
    required this.onCopied,
    super.key,
  });

  final String value;
  final void Function(String message) onCopied;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CopyButton(value: value, onCopied: onCopied),
        const SizedBox(width: 6),
        _ShareButton(value: value),
      ],
    );
  }
}

/// Puts the whole token on the clipboard, not the truncated form on screen.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value, required this.onCopied});

  final String value;
  final void Function(String message) onCopied;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () async {
        AppHaptics.selection();
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        onCopied(LocaleKeys.create_topic_copied_toast.tr());
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.fullAll,
          border: Border.all(color: colors.hairline, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          LocaleKeys.create_topic_copy_button.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
      ),
    );
  }
}

/// Small pill button that opens the system share sheet with an endpoint or
/// token value, matching index.html .kv .copy.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        unawaited(SharePlus.instance.share(ShareParams(text: value)));
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.fullAll,
          border: Border.all(color: colors.hairline, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          LocaleKeys.create_topic_share_button.tr(),
          style: TextStyle(
            fontFamily: AppTypography.fontBody,
            fontFamilyFallback: AppTypography.fontBodyFallbacks,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
      ),
    );
  }
}
