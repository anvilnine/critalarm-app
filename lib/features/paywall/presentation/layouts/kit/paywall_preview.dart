import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/alarm_screens_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/app_icons_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/challenge_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/sounds_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/weekly_check_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/widgets_preview.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
export 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart'
    show PaywallPreviewClass;

/// Draws one preview at [size], which is never past its class size. Under
/// `paywallPreviewSceneMinEdge` it draws its mark on the shared glyph tile.
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
  PaywallPreviewId.wakeUpChallenges: (_, size) => ChallengePreview(size: size),
  PaywallPreviewId.customSounds: (_, size) => SoundsPreview(size: size),
  PaywallPreviewId.customAlarmScreens: (_, size) =>
      AlarmScreensPreview(size: size),
};

/// The stand-in glyph for a preview nobody has built yet.
GlyphType paywallPreviewGlyph(PaywallPreviewId id) => switch (id) {
  PaywallPreviewId.topics => GlyphType.bell,
  PaywallPreviewId.pushes => GlyphType.up,
  PaywallPreviewId.history => GlyphType.clock,
  PaywallPreviewId.widgets => GlyphType.list,
  PaywallPreviewId.appIcons => GlyphType.pencil,
  PaywallPreviewId.weeklyCheck => GlyphType.check,
  PaywallPreviewId.wakeUpChallenges => GlyphType.lock,
  PaywallPreviewId.customSounds => GlyphType.record,
  PaywallPreviewId.customAlarmScreens => GlyphType.filter,
};

/// The picture of one benefit, at one of three designed sizes. It draws
/// the registered preview for [id], or the shared tile with the benefit's
/// glyph while none is registered. A layout uses this and never draws a
/// benefit picture of its own.
///
/// A preview does not stretch. Pick a [sizeClass] and the widget is that
/// size: 56, 120 or 200 points square. Give it a [size] as well and it
/// takes that room and centres the drawing in it, no bigger than its class.
/// A [size] too small for the class asked for gets the class that reads
/// there: under 88 points that is always the glyph tile.
class PaywallPreview extends StatelessWidget {
  const PaywallPreview(
    this.id, {
    this.sizeClass,
    this.size,
    this.playFrom,
    this.topicName,
    this.topicsOwn,
    this.leavingCritical,
    super.key,
  });

  final PaywallPreviewId id;

  /// The size the preview is drawn at. Null picks the biggest class that
  /// reads in [size], or `small` when there is no [size] either.
  final PaywallPreviewClass? sizeClass;

  /// The room the widget takes. Null is the class size.
  final Size? size;

  /// The second on the layout's clock at which this preview's own loop
  /// starts at zero, for a layout that shows one benefit per scene. Until
  /// then the preview holds the first frame of its loop. Null follows the
  /// clock as it is: a preview that shares a loop waits for its turn.
  final double? playFrom;

  /// A topic name for the topics preview to show in its first row. No
  /// other preview reads it.
  final String? topicName;

  /// The person's own count and the topic they were making, for the topics
  /// preview: a tag with their count, and their topic as the row that
  /// switches on. It wins over [topicName]. No other preview reads it.
  final TopicsPreviewOwn? topicsOwn;

  /// For the topics preview of a plan that is ending: how many topics are
  /// on. It draws that many on and a last row for a new topic, off, held
  /// still. It wins over [topicsOwn] and [topicName]. No other preview reads
  /// it.
  final int? leavingCritical;

  @override
  Widget build(BuildContext context) {
    final fit = paywallPreviewFit(sizeClass: sizeClass, box: size);
    final builder = paywallPreviewBuilders[id];
    final name = topicName;
    // The person's own alarms, when the route carries some. A gallery tile
    // or a picker has no route and draws the made-up rows.
    final own = id == PaywallPreviewId.history
        ? PaywallRouteInfo.maybeOf(context)?.historyOwn
        : null;
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: fit.box,
        child: Center(
          child: SizedBox.fromSize(
            size: fit.drawn,
            child: builder != null
                ? PaywallPreviewPlay(
                    playFrom: playFrom,
                    child:
                        id == PaywallPreviewId.topics && leavingCritical != null
                        ? TopicsPreview(
                            size: fit.drawn,
                            leavingCritical: leavingCritical,
                          )
                        : id == PaywallPreviewId.topics && topicsOwn != null
                        ? TopicsPreview(size: fit.drawn, own: topicsOwn)
                        : id == PaywallPreviewId.topics && name != null
                        ? TopicsPreview(size: fit.drawn, topicName: name)
                        : own != null
                        ? HistoryPreview(size: fit.drawn, own: own)
                        : builder(context, fit.drawn),
                  )
                : PreviewGlyphTile.glyph(
                    paywallPreviewGlyph(id),
                    size: fit.drawn,
                  ),
          ),
        ),
      ),
    );
  }
}
