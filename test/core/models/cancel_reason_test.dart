import 'package:critalarm/core/models/cancel_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the wire names are the contract names, in the order of the chips', () {
    expect(CancelReason.values.map((reason) => reason.wire), [
      'price',
      'unused',
      'selfhost',
      'missing',
      'broken',
      'other',
    ]);
  });

  test('fromWire reads a wire name and gives null for anything else', () {
    expect(CancelReason.fromWire('selfhost'), CancelReason.selfhost);
    expect(CancelReason.fromWire('Price'), isNull);
    expect(CancelReason.fromWire(''), isNull);
    expect(CancelReason.fromWire(null), isNull);
  });

  group('cleanCancelText', () {
    test('gives null for nothing or only spaces', () {
      expect(cleanCancelText(''), isNull);
      expect(cleanCancelText('  \n\t '), isNull);
    });

    test('trims the ends and keeps the middle', () {
      expect(
        cleanCancelText('  moved to my\n own server  '),
        'moved to my\n own server',
      );
    });

    test('trims what JavaScript trim() trims, and nothing more', () {
      // Whitespace and line terminators on the ECMAScript list: tab, line
      // feed, vertical tab, form feed, carriage return, space, no-break
      // space, ogham space mark, en quad to hair space, line and paragraph
      // separators, narrow no-break space, medium mathematical space,
      // ideographic space and the byte order mark. Written as code units
      // because a formatter turns the escapes into the characters.
      final trimmed = String.fromCharCodes([
        0x0009,
        0x000A,
        0x000B,
        0x000C,
        0x000D,
        0x0020,
        0x00A0,
        0x1680,
        for (var unit = 0x2000; unit <= 0x200A; unit++) unit,
        0x2028,
        0x2029,
        0x202F,
        0x205F,
        0x3000,
        0xFEFF,
      ]);
      expect(cleanCancelText('${trimmed}hi$trimmed'), 'hi');
      expect(cleanCancelText('${trimmed}a b$trimmed'), 'a b');
      expect(cleanCancelText(trimmed), isNull);
      // Zero width space and Mongolian vowel separator are not on the list.
      final zeroWidth = String.fromCharCode(0x200B);
      expect(
        cleanCancelText('${zeroWidth}hi$zeroWidth'),
        '${zeroWidth}hi$zeroWidth',
      );
      final vowelSeparator = String.fromCharCode(0x180E);
      expect(cleanCancelText('${vowelSeparator}hi'), '${vowelSeparator}hi');
      // Next line (U+0085) is white space to Dart and not to JavaScript, so
      // it stays: the server would count it too.
      final nextLine = String.fromCharCode(0x0085);
      expect(
        cleanCancelText('${nextLine}hi$nextLine'),
        '${nextLine}hi$nextLine',
      );
      expect(cleanCancelText(nextLine), nextLine);
    });

    test('keeps 500 characters and cuts the 501st', () {
      expect(cleanCancelText('x' * 500), 'x' * 500);
      expect(cleanCancelText('x' * 501), 'x' * 500);
    });

    test('counts after trimming', () {
      expect(cleanCancelText('  ${'x' * 500}  '), 'x' * 500);
    });

    test('counts an emoji as one character and never splits it', () {
      expect(cleanCancelText('😀' * 500), '😀' * 500);
      final cut = cleanCancelText('😀' * 501)!;
      expect(cut.runes.length, 500);
      expect(cut, '😀' * 500);
    });
  });
}
