import 'dart:async';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// The room a pill's tap box adds above and below it: the 30 pill and 8 above
/// and below is 46. The same at every text size, so a row that gives up 8
/// above and below keeps every pixel where it was.
const double tokenActionsTapRoom = 8;

/// Copy and Share, side by side.
///
/// The card tells the user this token is shown once and to save it now, and
/// the value is truncated to fit the row, so Copy is the only way to actually
/// obey that instruction. Share stays for sending it somewhere else.
///
/// Each pill is 30 high and sits in a tap box as tall as the key-value row it
/// goes in (46: the pill and the row's 8 above and below). The row is told
/// with `trailingFillsRow` so it spends none of its own padding there.
class TokenActions extends StatelessWidget {
  const TokenActions({
    required this.value,
    required this.onCopied,
    this.tapRoom = tokenActionsTapRoom,
    super.key,
  });

  final String value;
  final void Function(String message) onCopied;

  /// The room each pill's tap box adds above and below it. The caller spends
  /// that much of its own room there, so a caller with 9 above and below the
  /// pill asks for 9, which makes the box 48.
  final double tapRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CopyButton(value: value, onCopied: onCopied, tapRoom: tapRoom),
        const SizedBox(width: 6),
        _ShareButton(value: value, tapRoom: tapRoom),
      ],
    );
  }
}

/// Puts the whole token on the clipboard, not the truncated form on screen.
class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.value,
    required this.onCopied,
    required this.tapRoom,
  });

  final String value;
  final void Function(String message) onCopied;
  final double tapRoom;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          AppHaptics.selection();
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          onCopied(LocaleKeys.create_topic_copied_toast.tr());
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tapRoom),
          child: Container(
            constraints: const BoxConstraints(minHeight: 30),
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
        ),
      ),
    );
  }
}

/// Small pill button that opens the system share sheet with an endpoint or
/// token value, matching index.html .kv .copy.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.value, required this.tapRoom});

  final String value;
  final double tapRoom;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          unawaited(SharePlus.instance.share(ShareParams(text: value)));
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tapRoom),
          child: Container(
            constraints: const BoxConstraints(minHeight: 30),
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
        ),
      ),
    );
  }
}
