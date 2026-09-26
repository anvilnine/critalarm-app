import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:critalarm/gen/assets.gen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where `?source=` says the paywall was opened from, for paywall_viewed.
const appIconPaywallSource = 'app_icon';

/// The four home screen icons. Pro picks any of them; everyone else sees the
/// three Pro icons with the Pro pill, and a tap on one opens the paywall.
///
/// Only reachable where the platform can change its icon: Appearance hides the
/// row that leads here, and the route sends anything else back.
class AppIconScreen extends StatelessWidget {
  const AppIconScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AppIconCubit>(),
      child: const _AppIconView(),
    );
  }
}

class _AppIconView extends StatelessWidget {
  const _AppIconView();

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/appearance');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppIconCubit, AppIconState>(
      builder: (context, state) {
        return AppScreenScaffold(
          topBar: AppTopBar(
            title: LocaleKeys.settings_app_icon_title.tr(),
            leading: AppIconButton(
              glyph: GlyphType.back,
              ariaLabel: LocaleKeys.common_back.tr(),
              onPressed: () => _leave(context),
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, Spacing.s2, 12, 16),
                child: AppSheet(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSectionHeader(
                        LocaleKeys.settings_app_icon_header.tr(),
                      ),
                      for (final icon in AppIcon.values) ...[
                        _IconRow(icon: icon, state: state),
                        const SizedBox(height: 8),
                      ],
                      if (state.failed) ...[
                        AppNote(
                          text: LocaleKeys.settings_app_icon_failed.tr(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AppNote(
                        text: LocaleKeys.settings_app_icon_pro_note.tr(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.state});

  final AppIcon icon;
  final AppIconState state;

  @override
  Widget build(BuildContext context) {
    final locked = state.isLocked(icon);
    return AppRadioRow(
      title: appIconName(icon),
      selected: state.status == AppIconStatus.ready && state.current == icon,
      leading: AppIconPreview(icon: icon, size: 44, dimmed: locked),
      badge: icon.isPro && !state.unlocked
          ? ProBadge(label: LocaleKeys.paywall_pro_badge.tr())
          : null,
      onTap: () async {
        AppHaptics.selection();
        final pick = await context.read<AppIconCubit>().pick(icon);
        if (pick == AppIconPick.locked && context.mounted) {
          unawaited(context.push('/paywall?source=$appIconPaywallSource'));
        }
      },
    );
  }
}

/// The name of [icon], already translated.
String appIconName(AppIcon icon) => switch (icon) {
  AppIcon.standard => LocaleKeys.settings_app_icon_default.tr(),
  AppIcon.crowned => LocaleKeys.settings_app_icon_crowned.tr(),
  AppIcon.shades => LocaleKeys.settings_app_icon_shades.tr(),
  AppIcon.shadesCrown => LocaleKeys.settings_app_icon_shades_crown.tr(),
};

/// [icon] drawn the way a home screen draws it, corners and all.
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({
    required this.icon,
    required this.size,
    this.dimmed = false,
    super.key,
  });

  final AppIcon icon;
  final double size;

  /// Faded, for a Pro icon this device cannot pick yet.
  final bool dimmed;

  AssetGenImage get _image => switch (icon) {
    AppIcon.standard => Assets.appIcons.appIcon,
    AppIcon.crowned => Assets.appIcons.appIconProCrowned,
    AppIcon.shades => Assets.appIcons.appIconProShades,
    AppIcon.shadesCrown => Assets.appIcons.appIconProShadesCrown,
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: ClipRRect(
        // The iOS icon corner: 230 on a 1024 square.
        borderRadius: BorderRadius.circular(size * 230 / 1024),
        child: _image.image(
          width: size,
          height: size,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
