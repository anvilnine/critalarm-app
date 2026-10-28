// Used by tool/capture_responsive_matrix.dart. Not part of the app.
//
// The geometry WP6 (onboarding and New topic on tablets, foldables and
// desktop windows) promises, read off the render tree at rest:
//
// - New topic (07 and wp6_07_*): the close control is a bare cross with no
//   circle; on a medium or expanded window with no fold, Next sits within 48
//   of the card's bottom edge and is 480 wide or less. On the Razr cover the
//   name label, Paste and the field are on screen in full and nothing covers
//   them; on a tabletop fold the ring card's title and its switch are.
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
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/screen_frame.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_topic_critical_card.dart';
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

/// True when [box] is on screen in full and no box in [over] overlaps it.
bool _clearAtRest(Rect box, Size window, Iterable<Rect> over) =>
    box.top >= -0.5 &&
    box.left >= -0.5 &&
    box.bottom <= window.height + 0.5 &&
    box.right <= window.width + 0.5 &&
    over.every((o) => !o.deflate(0.5).overlaps(box));

/// The checks for [screenId] on a window of [window] with [fold].
///
/// [sizeId] is the matrix size id. A `desktop-*` id is the web build, which
/// has no permissions step. Without it, a macOS target stands for the web.
List<(String, bool)> wp6Measure(
  WidgetTester tester,
  String screenId, {
  required Size window,
  required AppSize size,
  required AppFold fold,
  String? sizeId,
}) {
  final isWeb =
      sizeId?.startsWith('desktop-') ??
      defaultTargetPlatform == TargetPlatform.macOS;
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
    // On the cover and a tabletop fold Next scrolls after the card, so at
    // rest it may sit past the bottom edge and not be painted at all.
    final flows = actionsFlowFor(screenFrameFor(size, fold));
    if (cards.isEmpty || (buttons.isEmpty && !flows)) {
      lines.add(('card or Next not found', true));
      return lines;
    }
    final card = cards.first;
    if (buttons.isEmpty) {
      lines.add((
        'card ${_r(card)}, Next after the card, below the edge at rest',
        false,
      ));
      _restChecks(
        lines,
        size: size,
        fold: fold,
        window: window,
        next: null,
        isSetup: isSetup,
      );
      return lines;
    }
    final next = buttons.first;
    final gap = next.top - card.bottom;
    lines.add((
      'card ${_r(card)}, Next ${_r(next)}, gap ${gap.toStringAsFixed(1)}, '
          'Next width ${next.width.toStringAsFixed(1)}',
      false,
    ));
    if (flows) {
      final ok = next.top >= card.bottom - 0.5;
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} Next scrolls after the card '
            '(top ${next.top.toStringAsFixed(1)}, card bottom '
            '${card.bottom.toStringAsFixed(1)})',
        !ok,
      ));
    }
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
    _restChecks(
      lines,
      size: size,
      fold: fold,
      window: window,
      next: next,
      isSetup: isSetup,
    );
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
    if (title.isEmpty && isWeb) {
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

/// The at-rest checks of New topic on the cover and on a tabletop fold.
/// [next] is Next's box, or null when it is below the edge and not painted.
void _restChecks(
  List<(String, bool)> lines, {
  required AppSize size,
  required AppFold fold,
  required Size window,
  required Rect? next,
  required bool isSetup,
}) {
  // The Razr cover: what names the topic is readable and usable at rest,
  // with Next scrolling after the card instead of pinned over the field.
  if (size.isCover && fold.isNone) {
    final label = _painted(
      find.text(LocaleKeys.create_topic_name_label.tr()),
    );
    final paste = isSetup
        ? <Rect>[]
        : _painted(
            find.byWidgetPredicate(
              (w) =>
                  w is AppButton &&
                  w.label == LocaleKeys.create_topic_paste_button.tr(),
            ),
          );
    final field = _painted(find.byType(EditableText));
    if (label.isEmpty || field.isEmpty || (!isSetup && paste.isEmpty)) {
      lines.add((
        'FAIL cover: name label ${label.length}, Paste ${paste.length}, '
            'field ${field.length} painted',
        true,
      ));
    } else {
      final boxes = [label.first, ...paste.take(1), field.first];
      final ok = boxes.every((b) => _clearAtRest(b, window, [?next]));
      // The rule holds at the default text size, as the cover's other
      // rules do. Larger, the 388 tall screen scrolls to the field, and the
      // line is recorded as information.
      final scale = MediaQuery.textScalerOf(
        find.byType(EditableText).evaluate().first,
      ).scale(1);
      final applies = scale <= 1.01;
      lines.add((
        '${ok ? 'PASS' : (applies ? 'FAIL' : 'INFO')} cover: name label '
            '${_r(label.first)}, '
            'Paste ${paste.isEmpty ? 'none' : _r(paste.first)} and field '
            '${_r(field.first)} on screen at rest, clear of Next'
            '${applies ? '' : ' (text ${scale.toStringAsFixed(1)}, '
                      'checked at 1.0 only)'}',
        !ok && applies,
      ));
    }
  }
  // A tabletop fold: the ring card's title and its switch are on screen
  // in the bottom half, with Next after the card instead of over it.
  if (fold.isTabletop) {
    final switches = _painted(find.byType(AppSwitch));
    final titles = _painted(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is FirstTopicCriticalCard || w is AppToggleRow,
        ),
        matching: find.byType(Text),
      ),
    )..sort((a, b) => a.top.compareTo(b.top));
    if (switches.isEmpty || titles.isEmpty) {
      lines.add((
        'FAIL tabletop: ring card switch ${switches.length}, '
            'title ${titles.length} painted',
        true,
      ));
    } else {
      final title = titles.first;
      final toggle = switches.first;
      final ok =
          _clearAtRest(title, window, [?next]) &&
          _clearAtRest(toggle, window, [?next]);
      lines.add((
        '${ok ? 'PASS' : 'FAIL'} tabletop: ring card title ${_r(title)} '
            'and switch ${_r(toggle)} on screen at rest, clear of Next',
        !ok,
      ));
    }
  }
}
