import 'dart:async';

import 'package:critalarm/core/constants/legal_links.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which build this is, what licence it ships under, and where the code and
/// the docs live.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      topBar: AppTopBar(
        title: LocaleKeys.settings_about_header.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.common_back.tr(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
            child: AppSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppKeyValueRow(
                    label: LocaleKeys.settings_about_version_label.tr(),
                    value: 'v$appVersion',
                  ),
                  const SizedBox(height: 8),
                  AppKeyValueRow(
                    label: LocaleKeys.settings_about_license_label.tr(),
                    value: LocaleKeys.settings_about_license_value.tr(),
                    isMono: false,
                  ),
                  const SizedBox(height: 8),
                  _AboutLinkRow(
                    label: LocaleKeys.settings_about_docs_label.tr(),
                    url: 'https://critalarm.app/docs/',
                  ),
                  const SizedBox(height: 8),
                  _AboutLinkRow(
                    label: LocaleKeys.settings_about_github_label.tr(),
                    url: 'https://github.com/anvilnine/critalarm-app',
                  ),
                  const SizedBox(height: 8),
                  _AboutLinkRow(
                    label: LocaleKeys.settings_about_issues_label.tr(),
                    url: 'https://github.com/anvilnine/critalarm-app/issues',
                  ),
                  const SizedBox(height: 8),
                  _AboutLinkRow(
                    label: LocaleKeys.settings_about_privacy_label.tr(),
                    url: privacyUrl,
                  ),
                  const SizedBox(height: 8),
                  _AboutLinkRow(
                    label: LocaleKeys.settings_about_terms_label.tr(),
                    url: termsUrl,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutLinkRow extends StatelessWidget {
  const _AboutLinkRow({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  /// Open the link in a browser sheet: Safari on iOS, Chrome Custom Tabs on
  /// Android. If the platform will not open it, copy it instead so the row
  /// never does nothing.
  Future<void> _open(ScaffoldMessengerState messenger) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppBrowserView,
      );
    } on Exception {
      opened = false;
    }
    if (!opened) {
      _copy(messenger);
    }
  }

  void _copy(ScaffoldMessengerState messenger) {
    unawaited(Clipboard.setData(ClipboardData(text: url)));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          LocaleKeys.settings_copied_toast.tr(namedArgs: {'url': url}),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$label: $url',
      link: true,
      linkUrl: Uri.tryParse(url),
      // The row shows the same label and URL; read them once, not twice.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => unawaited(_open(ScaffoldMessenger.of(context))),
        onLongPress: () => _copy(ScaffoldMessenger.of(context)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.cream,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontFamilyFallback: AppTypography.fontBodyFallbacks,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      url,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontFamilyFallback: AppTypography.fontMonoFallbacks,
                        fontSize: 12,
                        color: colors.ink3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppGlyph(
                GlyphType.arrow,
                color: colors.ink3,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
