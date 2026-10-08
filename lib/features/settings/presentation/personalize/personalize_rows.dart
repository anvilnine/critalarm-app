import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/widgets_preview.dart';
import 'package:critalarm/features/paywall/presentation/widgets/access_lock.dart';
import 'package:critalarm/features/settings/presentation/app_icon_screen.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/widgets/home_widgets_sheet.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Widgets row of the Personalize page.
Widget buildPersonalizeWidgetsRow(BuildContext context) =>
    const PersonalizeWidgetsRow();

/// The App icon row of the Personalize page.
Widget buildPersonalizeAppIconRow(BuildContext context) =>
    const PersonalizeAppIconRow();

/// A plain row that leaves the page: a small picture, a title, and an
/// arrow. Locked, the lock badge takes the arrow's place.
class PersonalizeRow extends StatelessWidget {
  const PersonalizeRow({
    required this.picture,
    required this.title,
    required this.onTap,
    super.key,
  });

  /// The edge of the picture at the left.
  static const double pictureSize = 40;

  final Widget picture;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLocked = FeatureLockScope.maybeOf(context)?.isLocked ?? false;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            children: [
              SizedBox.square(dimension: pictureSize, child: picture),
              const SizedBox(width: Spacing.s3),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body(
                    colors.ink,
                    fontSize: 15,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: Spacing.s2),
              // The badge sits here when the row is locked.
              Visibility.maintain(
                visible: !isLocked,
                child: AppGlyph(
                  GlyphType.arrow,
                  color: colors.ink3,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How far in from the row's right edge its lock badge sits.
const double _rowBadgeInset = -14;

/// Opens the widgets how-to. Locked, it opens the paywall. Drawn only where
/// home screen widgets exist: iOS and Android.
class PersonalizeWidgetsRow extends StatelessWidget {
  const PersonalizeWidgetsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = getIt<PlatformCapabilities>().platform;
    if (homeWidgetsStepsFor(platform) == null) return const SizedBox.shrink();
    final title = LocaleKeys.personalize_widgets_row.tr();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s2),
      child: AccessLock(
        feature: AppFeature.widgets,
        source: LockSource.personalizeWidgets,
        name: title,
        badgeAlignment: AlignmentDirectional.centerEnd,
        badgeOverhang: _rowBadgeInset,
        child: PersonalizeRow(
          title: title,
          picture: const WidgetsPreview(
            size: Size.square(PersonalizeRow.pictureSize),
          ),
          onTap: () {
            final access = getIt<FeatureAccess>();
            unawaited(
              showHomeWidgetsSheet(
                context: context,
                platform: platform,
                plan: homeWidgetsPlanFor(
                  access.decide(AppFeature.widgets),
                  isOwnServer: access.isOwnServer,
                ),
                onSeeHosted: () {
                  if (!context.mounted) return;
                  unawaited(
                    openPaywallForFeature(
                      context,
                      AppFeature.widgets,
                      LockSource.personalizeWidgets,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Opens the icon picker, with the icon showing now. Locked, it opens the
/// paywall. Takes no space where the platform cannot change its icon.
///
/// It asks the phone which icon is showing and nothing about plans: the
/// lock is [AccessLock]'s to draw.
class PersonalizeAppIconRow extends StatefulWidget {
  const PersonalizeAppIconRow({super.key});

  @override
  State<PersonalizeAppIconRow> createState() => _PersonalizeAppIconRowState();
}

class _PersonalizeAppIconRowState extends State<PersonalizeAppIconRow> {
  AppIcon? _current;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    final current = await getIt<AppIconHost>().current();
    if (mounted) setState(() => _current = current);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final title = LocaleKeys.personalize_app_icon_row.tr();
    return AccessLock(
      feature: AppFeature.appIcons,
      source: LockSource.personalizeAppIcon,
      name: title,
      badgeAlignment: AlignmentDirectional.centerEnd,
      badgeOverhang: _rowBadgeInset,
      child: PersonalizeRow(
        title: title,
        picture: AppIconPreview(
          icon: current,
          size: PersonalizeRow.pictureSize,
        ),
        onTap: () async {
          await context.push('/app-icon');
          // The picker may have changed it.
          await _read();
        },
      ),
    );
  }
}
