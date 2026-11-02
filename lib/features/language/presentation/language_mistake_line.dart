import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The one quiet line under the Language screen and About: the translation is
/// AI work, and "Tell us" opens the report for the screen it sits on.
///
/// [screen] is the id the report carries, for example `language` or `about`.
class LanguageMistakeLine extends StatelessWidget {
  const LanguageMistakeLine({required this.screen, super.key});

  final String screen;

  /// The report could not be opened, so its address goes on the clipboard
  /// instead of the tap doing nothing (the same fallback Help uses).
  void _copy(ScaffoldMessengerState messenger, Uri uri) {
    final text = uri.toString();
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          LocaleKeys.settings_copied_toast.tr(namedArgs: {'url': text}),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = await getIt<LanguageCubit>().reportMistake(screen: screen);
    if (failed != null) _copy(messenger, failed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final line = AppTypography.small(colors.ink3, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              LocaleKeys.language_ai_line.tr(),
              textAlign: TextAlign.center,
              style: line,
            ),
            Semantics(
              button: true,
              link: true,
              label: LocaleKeys.language_report_link.tr(),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_report(context)),
                child: AppTapTarget(
                  child: Text(
                    LocaleKeys.language_report_link.tr(),
                    textAlign: TextAlign.center,
                    style: line.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.ink3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
