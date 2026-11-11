import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/store/services/store_links.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/feedback/domain/feedback_links.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:critalarm/features/feedback/presentation/open_feedback_form.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The help rows on Settings, Help and feedback: the docs, two forms, a
/// problem report by email, and the store listing, in one white card.
///
/// A form row stays hidden while its address in [FeedbackLinks] is blank.
/// The Rate row never shows on web, and on iOS waits for the App Store id.
class HelpSection extends StatelessWidget {
  const HelpSection({super.key, this.title, this.leading = const []});

  /// The card's title, or none.
  final String? title;

  /// Rows drawn first in the same card, such as Feature Guides on Help and
  /// feedback.
  final List<Widget> leading;

  static bool _canRate(PlatformCapabilities on) =>
      !on.isWeb &&
      (on.platform == TargetPlatform.android ||
          FeedbackLinks.appStoreId.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final on = getIt<PlatformCapabilities>();
    return AppTitledCard(
      title: title,
      children: [
        ...leading,
        _row(
          LocaleKeys.settings_help_docs_row.tr(),
          () async => context.pushNamed(AppRoute.docs),
          detail: LocaleKeys.settings_help_docs_sub.tr(),
        ),
        if (FeedbackLinks.feedbackFormUrl.isNotEmpty)
          _row(
            LocaleKeys.settings_help_feedback_row.tr(),
            () => _openForm(context, FeedbackLinks.feedbackFormUrl),
          ),
        if (FeedbackLinks.featureFormUrl.isNotEmpty)
          _row(
            LocaleKeys.settings_help_feature_row.tr(),
            () => _openForm(context, FeedbackLinks.featureFormUrl),
          ),
        _row(
          LocaleKeys.settings_help_report_row.tr(),
          () => _openReportMail(context),
          detail: LocaleKeys.settings_help_report_sub.tr(),
        ),
        if (_canRate(on))
          _row(
            LocaleKeys.settings_help_rate_row.tr(),
            () => getIt<StoreLinks>().listing(),
            detail: on.platform == TargetPlatform.android
                ? LocaleKeys.settings_help_rate_sub_android.tr()
                : LocaleKeys.settings_help_rate_sub_ios.tr(),
          ),
      ],
    );
  }

  Widget _row(
    String title,
    Future<void> Function() onTap, {
    String? detail,
  }) {
    return AppCardRow(
      title: title,
      detail: detail,
      onTap: () => unawaited(onTap()),
    );
  }

  Future<void> _openForm(BuildContext context, String base) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedUri = await openFeedbackForm(
      base: base,
      source: FeedbackLinks.settingsSource,
      locale: context.locale.toLanguageTag(),
      mode: LaunchMode.inAppBrowserView,
    );
    if (failedUri != null) _copy(messenger, failedUri.toString());
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
