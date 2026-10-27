// Used by tool/capture_responsive_matrix.dart. Not part of the app.
//
// The geometry WP6 (onboarding and New topic on tablets, foldables and
// desktop windows) promises, read off the render tree at rest:
//
// - New topic (07 and wp6_07_*): the close control is a bare cross with no
//   circle; on a medium or expanded window with no fold, Next sits within 48
//   of the card's bottom edge and is 480 wide or less.
// - Permission denial (13): the headline and the body line are on screen in
//   full, under the top bar and above the first button, with no overlap.
//
// Each line comes with true when its check failed.
//
// Developer tool.

import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/dismiss_cross.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fold_clearance.dart';

String _r(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

List<Rect> _painted(Finder finder) => [
  for (final e in finder.evaluate())
    if (e.renderObject case final RenderBox box) ?paintedRect(box),
];

/// The checks for [screenId] on a window of [window] with [fold].
List<(String, bool)> wp6Measure(
  WidgetTester tester,
  String screenId, {
  required Size window,
  required AppSize size,
  required AppFold fold,
}) {
  final lines = <(String, bool)>[];
  if (screenId == '07_create_topic' || screenId.startsWith('wp6_07')) {
    final circles = find.byWidgetPredicate(
      (w) => w is AppIconButton && w.glyph == GlyphType.close,
    );
    final crosses = _painted(find.byType(AppDismissCross));
    final isSetup = screenId == 'wp6_07_first_topic';
    final closeOk =
        circles.evaluate().isEmpty && (isSetup || crosses.isNotEmpty);
    lines.add((
      '${closeOk ? 'PASS' : 'FAIL'} close is a bare x: '
          '${crosses.length} cross, ${circles.evaluate().length} circle',
      !closeOk,
    ));
    final cards = _painted(find.byType(AppSheet));
    final buttons = _painted(
      find.byWidgetPredicate(
        (w) =>
            w is AppButton &&
            (w.label == LocaleKeys.create_topic_next_button.tr() ||
                w.label == LocaleKeys.create_topic_create_button.tr()),
      ),
    );
    if (cards.isEmpty || buttons.isEmpty) {
      lines.add(('card or Next not found', true));
      return lines;
    }
    final card = cards.first;
    final next = buttons.first;
    final gap = next.top - card.bottom;
    lines.add((
      'card ${_r(card)}, Next ${_r(next)}, gap ${gap.toStringAsFixed(1)}, '
          'Next width ${next.width.toStringAsFixed(1)}',
      false,
    ));
    if (!size.isCompact && !size.isShort && fold.isNone) {
      final ok = gap >= 0 && gap <= 48 && next.width <= 480.5;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} Next within 48 of the card '
            '(${gap.toStringAsFixed(1)}) and 480 wide or less '
            '(${next.width.toStringAsFixed(1)})',
        !ok,
      ));
    }
    if (!fold.isNone) {
      final ok =
          !boxCrossesFold(card, fold.band) && !boxCrossesFold(next, fold.band);
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} card and Next clear of the fold band '
            '${_r(fold.band)}',
        !ok,
      ));
    }
  }
  if (screenId == '13_permission_denial') {
    final title = _painted(
      find.text(LocaleKeys.onboarding_permissions_denied_title.tr()),
    );
    final body = _painted(
      find.text(LocaleKeys.onboarding_permissions_denied_description.tr()),
    );
    final buttons = _painted(find.byType(AppButton))
      ..sort((a, b) => a.top.compareTo(b.top));
    // The web build has no permissions step: the route opens the welcome
    // pages there instead.
    if (title.isEmpty && defaultTargetPlatform == TargetPlatform.macOS) {
      lines.add(('no denial on the web build, the route opens welcome', false));
      return lines;
    }
    if (title.isEmpty || body.isEmpty || buttons.isEmpty) {
      lines.add((
        'FAIL denial words or buttons not painted: title ${title.length}, '
            'body ${body.length}, buttons ${buttons.length}',
        true,
      ));
      return lines;
    }
    const top = AppScreenScaffold.topBarHeight;
    final first = buttons.first;
    final t = title.first;
    final b = body.first;
    final words = t.expandToInclude(b);
    final ok =
        words.top >= top - 0.5 &&
        words.left >= -0.5 &&
        words.right <= window.width + 0.5 &&
        (words.bottom <= first.top + 0.5 || words.top >= buttons.last.bottom);
    lines.add((
      '${ok ? 'PASS' : 'FAIL'} headline ${_r(t)} and body ${_r(b)} in full, '
          'under the top bar ($top) and clear of the buttons '
          '(first ${_r(first)})',
      !ok,
    ));
  }
  return lines;
}
