import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Developer options: what each product's paywall opens on this phone.
///
/// One control for Hosted and one for Pro. Each follows the remote value,
/// or outranks it with the shipped surface, the pick by entry point, or one
/// named layout. Only drawn in a build with Developer options, where DI
/// registers the switches.
class DeveloperPaywallRouteSection extends StatelessWidget {
  const DeveloperPaywallRouteSection({super.key});

  @override
  Widget build(BuildContext context) {
    final switches = getIt<DevPaywallLayoutSwitches>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PaywallRoutePicker(
          title: LocaleKeys.settings_developer_paywall_route_hosted_title.tr(),
          layoutSwitch: switches.hosted,
        ),
        const SizedBox(height: 14),
        _PaywallRoutePicker(
          title: LocaleKeys.settings_developer_paywall_route_pro_title.tr(),
          layoutSwitch: switches.pro,
        ),
      ],
    );
  }
}

class _PaywallRoutePicker extends StatefulWidget {
  const _PaywallRoutePicker({required this.title, required this.layoutSwitch});

  final String title;
  final DevPaywallLayoutSwitch layoutSwitch;

  @override
  State<_PaywallRoutePicker> createState() => _PaywallRoutePickerState();
}

class _PaywallRoutePickerState extends State<_PaywallRoutePicker> {
  /// The choices take 15 rows, so they stay folded until asked for.
  bool _isOpen = false;

  static final List<PaywallLayoutSetting?> _choices = [
    null,
    PaywallLayoutSetting.shipped,
    PaywallLayoutSetting.auto,
    for (final layout in PaywallLayoutId.values)
      PaywallLayoutSetting.pinned(layout),
  ];

  static String _label(PaywallLayoutSetting? setting) {
    if (setting == null) {
      return LocaleKeys.settings_developer_paywall_route_follow.tr();
    }
    if (setting.isShipped) {
      return LocaleKeys.settings_developer_paywall_route_shipped.tr();
    }
    if (setting.isAuto) {
      return LocaleKeys.settings_developer_paywall_route_auto.tr();
    }
    return setting.storedKey;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ValueListenableBuilder<PaywallLayoutSetting?>(
      valueListenable: widget.layoutSwitch,
      builder: (context, selected, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListRow(
            name: widget.title,
            meta: LocaleKeys.settings_developer_paywall_route_subtitle.tr(
              args: [_label(selected)],
            ),
            faceState: null,
            trailing: AppGlyph(GlyphType.arrow, color: colors.ink3, size: 16),
            onTap: () => setState(() => _isOpen = !_isOpen),
          ),
          if (_isOpen) ...[
            const SizedBox(height: 4),
            for (final choice in _choices) ...[
              AppListRow(
                name: _label(choice),
                meta: '',
                faceState: null,
                trailing: choice == selected
                    ? AppGlyph(
                        GlyphType.check,
                        color: colors.highlight,
                        size: 16,
                      )
                    : null,
                onTap: () {
                  unawaited(widget.layoutSwitch.setSetting(choice));
                  setState(() => _isOpen = false);
                },
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}
