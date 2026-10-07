import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/app_icons_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/weekly_check_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/widgets_preview.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';

/// Draws one preview inside a box of [size].
typedef PaywallPreviewBuilder =
    Widget Function(BuildContext context, Size size);

/// The previews that exist, by id. Empty until a preview is built: add an
/// entry here and every layout that shows that benefit draws it.
final Map<PaywallPreviewId, PaywallPreviewBuilder> paywallPreviewBuilders = {
  PaywallPreviewId.topics: (_, size) => TopicsPreview(size: size),
  PaywallPreviewId.pushes: (_, size) => PushesPreview(size: size),
  PaywallPreviewId.history: (_, size) => HistoryPreview(size: size),
  PaywallPreviewId.widgets: (_, size) => WidgetsPreview(size: size),
  PaywallPreviewId.appIcons: (_, size) => AppIconsPreview(size: size),
  PaywallPreviewId.weeklyCheck: (_, size) => WeeklyCheckPreview(size: size),
};

/// The stand-in glyph for a preview nobody has built yet.
GlyphType paywallPreviewGlyph(PaywallPreviewId id) => switch (id) {
  PaywallPreviewId.topics => GlyphType.bell,
  PaywallPreviewId.pushes => GlyphType.up,
  PaywallPreviewId.history => GlyphType.clock,
  PaywallPreviewId.widgets => GlyphType.list,
  PaywallPreviewId.appIcons => GlyphType.pencil,
  PaywallPreviewId.weeklyCheck => GlyphType.check,
  PaywallPreviewId.fireDrills => GlyphType.play,
  PaywallPreviewId.wakeUpChallenges => GlyphType.repeat,
  PaywallPreviewId.customAlarmScreens => GlyphType.filter,
  PaywallPreviewId.morningSummary => GlyphType.info,
};

/// The small picture of one benefit. It draws the registered preview for
/// [id], or a quiet tile with the benefit's glyph while none is registered.
/// A layout uses this and never draws a benefit picture of its own.
class PaywallPreview extends StatelessWidget {
  const PaywallPreview(
    this.id, {
    this.size = const Size.square(56),
    super.key,
  });

  final PaywallPreviewId id;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final builder = paywallPreviewBuilders[id];
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: builder != null
            ? builder(context, size)
            : _PlaceholderTile(id: id, size: size),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.id, required this.size});

  final PaywallPreviewId id;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final edge = size.shortestSide;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: BorderRadius.circular(math.min(Radii.md, edge * 0.3)),
      ),
      child: Center(
        child: AppGlyph(
          paywallPreviewGlyph(id),
          size: edge * 0.42,
          color: colors.ink,
        ),
      ),
    );
  }
}
