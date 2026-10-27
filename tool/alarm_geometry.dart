// Used by tool/capture_responsive_matrix.dart. Not part of the app.
//
// Measures the ringing alarm from the render tree at rest: "I'm up", Silence,
// Read the full message, the message card, the face and the word. Prints the
// boxes and a PASS or FAIL for each rule the layout promises at that size
// (docs: the WP2 section of the tablet, foldable and desktop layouts spec).
//
// Developer tool.

import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/sheets.dart';
import 'package:critalarm/design/faces/ringing/shuffling_ringing_face.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:critalarm/features/incidents/presentation/widgets/ringing_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fold_clearance.dart';

String _r(Rect r) =>
    '[${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)}]';

Rect? _painted(Finder finder) {
  for (final element in finder.evaluate()) {
    final render = element.renderObject;
    if (render is! RenderBox) continue;
    final rect = paintedRect(render);
    if (rect != null) return rect;
  }
  return null;
}

Rect? _button(String label) => _painted(find.widgetWithText(AppButton, label));

/// Lines of `(text, failed)` for the ringing screen in a window of
/// [window], or an empty list when no ringing screen is on screen.
List<(String, bool)> measureRingingAlarm(
  WidgetTester tester, {
  required Size window,
  required AppSize size,
  required AppFold fold,
}) {
  if (find.byType(RingingScreen).evaluate().isEmpty) return const [];
  final lines = <(String, bool)>[];
  void check(String what, {required bool ok}) =>
      lines.add(('${ok ? 'PASS' : 'FAIL'} $what', !ok));

  final layout = ringingLayoutFor(size, fold.posture);
  final screen = Offset.zero & window;
  final up = _button(LocaleKeys.critical_alarm_acknowledge_button.tr());
  final silence = _button(
    LocaleKeys.critical_alarm_silence_ringing_button.tr(),
  );
  final read = _button(LocaleKeys.critical_alarm_read_message_button.tr());
  final card = _painted(
    find.descendant(
      of: find.byType(RingingScreen),
      matching: find.byType(AppSheet),
    ),
  );
  final face = _painted(find.byType(ShufflingRingingFace));
  final ringing = find.byType(RingingScreen).evaluate().first.widget;
  final word = _painted(
    find.descendant(
      of: find.byType(RingingScreen),
      matching: find.text((ringing as RingingScreen).state.word),
    ),
  );

  lines.add((
    'ringing layout ${layout.name}; '
        "I'm up ${up == null ? 'none' : _r(up)}, "
        'Silence ${silence == null ? 'none' : _r(silence)}, '
        'Read ${read == null ? 'none' : _r(read)}, '
        'card ${card == null ? 'none' : _r(card)} '
        '(${card?.width.toStringAsFixed(1)} wide), '
        'face ${face == null ? 'none' : _r(face)}, '
        'word ${word == null ? 'none' : _r(word)}',
    false,
  ));

  // Every size: "I'm up" whole and on the window at rest.
  check(
    "I'm up fully on screen at rest",
    ok:
        up != null &&
        screen.inflate(0.5).contains(up.topLeft) &&
        screen.inflate(0.5).contains(up.bottomRight),
  );

  if (layout == RingingLayout.cover &&
      up != null &&
      silence != null &&
      read != null &&
      card != null) {
    final buttons = [up, silence, read];
    check(
      'cover: no button overlaps the card or the face',
      ok:
          buttons.every((b) => !b.overlaps(card)) &&
          (face == null || buttons.every((b) => !b.overlaps(face))),
    );
    check(
      'cover: the word fits inside the window',
      ok: word != null && word.left >= -0.5 && word.right <= window.width + 0.5,
    );
    check(
      'cover: Silence and Read sit side by side',
      ok: (silence.top - read.top).abs() < 0.5 && read.left >= silence.right,
    );
  }

  if (layout == RingingLayout.expanded &&
      up != null &&
      silence != null &&
      read != null &&
      card != null) {
    check(
      'expanded: card ${card.width.toStringAsFixed(1)} >= 400 wide',
      ok: card.width >= 400,
    );
    final buttons = [up, silence, read];
    check(
      'expanded: the three buttons sit in the column under the card',
      ok: buttons.every(
        (b) =>
            b.top >= card.bottom - 0.5 &&
            b.left >= card.left - 0.5 &&
            b.right <= card.right + 0.5,
      ),
    );
    check(
      'expanded: card and buttons at most ${AppSize.actionMaxWidth} wide',
      ok:
          buttons.every((b) => b.width <= AppSize.actionMaxWidth + 0.5) &&
          card.width <= AppSize.actionMaxWidth + 0.5,
    );
  }
  return lines;
}
