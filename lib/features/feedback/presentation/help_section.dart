import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Help block in Settings: two forms, a problem report by email, and
/// the store listing.
///
/// A form row stays hidden while its address in [FeedbackLinks] is blank.
/// The Rate row never shows on web, and on iOS waits for the App Store id.
class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  bool get _canRate =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          FeedbackLinks.appStoreId.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (FeedbackLinks.feedbackFormUrl.isNotEmpty)
        _row(
          context,
          LocaleKeys.settings_help_feedback_row.tr(),
          () => _openForm(context, FeedbackLinks.feedbackFormUrl),
        ),
      if (FeedbackLinks.featureFormUrl.isNotEmpty)
        _row(
          context,
          LocaleKeys.settings_help_feature_row.tr(),
          () => _openForm(context, FeedbackLinks.featureFormUrl),
        ),
      _row(
        context,
        LocaleKeys.settings_help_report_row.tr(),
        () => _openReportMail(context),
      ),
      if (_canRate)
        _row(
          context,
          LocaleKeys.settings_help_rate_row.tr(),
          () => InAppReview.instance.openStoreListing(
            appStoreId: FeedbackLinks.appStoreId,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionHeader(LocaleKeys.settings_help_header.tr()),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String name,
    Future<void> Function() onTap,
  ) {
    return AppListRow(
      name: name,
      meta: '',
      faceState: null,
      trailing: AppGlyph(
        GlyphType.arrow,
        color: context.appColors.ink3,
        size: 16,
      ),
      onTap: () => unawaited(onTap()),
    );
  }

  Future<void> _openForm(BuildContext context, String base) async {
    final messenger = ScaffoldMessenger.of(context);
    final report = await getIt<DeviceReportRepository>().read(
      locale: context.locale.toLanguageTag(),
    );
    final uri = FeedbackLinks.form(base, report, isRelease: kReleaseMode);
    if (uri == null) return;
    if (!await _launch(uri, LaunchMode.inAppBrowserView)) {
      _copy(messenger, uri.toString());
    }
  }

  Future<void> _openReportMail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final subject = LocaleKeys.settings_help_report_subject.tr();
    final report = await getIt<DeviceReportRepository>().read(
      locale: context.locale.toLanguageTag(),
    );
    final uri = FeedbackLinks.reportMail(
      report,
      email: FeedbackLinks.supportEmail,
      subject: subject,
    );
    if (!await _launch(uri, LaunchMode.externalApplication)) {
      _copy(messenger, FeedbackLinks.supportEmail);
    }
  }

  Future<bool> _launch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } on Exception {
      return false;
    }
  }

  /// No mail app or browser to hand off to, so the address goes on the
  /// clipboard instead of the tap doing nothing.
  void _copy(ScaffoldMessengerState messenger, String text) {
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
}
