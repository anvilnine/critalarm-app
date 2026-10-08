import 'dart:math';

/// The kinds of question, in the order a seed picks from.
enum OpsMathKind {
  /// What is 0x1F in decimal. Operand 16 to 255.
  hexToDecimal,

  /// What is 2^10. Operand 1 to 12.
  powerOfTwo,

  /// How many seconds in 7 minutes. Operand 2 to 90.
  secondsInMinutes,

  /// How many seconds in 3 hours. Operand 1 to 12.
  secondsInHours,

  /// How many kilobytes in 5 megabytes, at 1024. Operand 2 to 64.
  kilobytesInMegabytes,
}

/// One developer-flavoured sum. [answer] is always a whole number above
/// zero.
final class OpsMathQuestion {
  const OpsMathQuestion({required this.kind, required this.operand});

  final OpsMathKind kind;

  /// The number in the question: the hex value, the exponent, the minutes,
  /// the hours or the megabytes.
  final int operand;

  /// The one right answer, as a whole number.
  int get answer => switch (kind) {
    OpsMathKind.hexToDecimal => operand,
    OpsMathKind.powerOfTwo => 1 << operand,
    OpsMathKind.secondsInMinutes => operand * 60,
    OpsMathKind.secondsInHours => operand * 3600,
    OpsMathKind.kilobytesInMegabytes => operand * 1024,
  };

  /// The operand as it is written in the question: hex for a hex question.
  String get operandText => kind == OpsMathKind.hexToDecimal
      ? '0x${operand.toRadixString(16).toUpperCase()}'
      : '$operand';

  /// The question shown on a Personalize picture, the same every time.
  static const OpsMathQuestion sample = OpsMathQuestion(
    kind: OpsMathKind.hexToDecimal,
    operand: 0x1F,
  );
}

/// The question for [seed]. The same seed always gives the same question,
/// so a rebuild of the screen never changes it.
OpsMathQuestion opsMathQuestion(int seed) {
  final random = Random(seed);
  final kind = OpsMathKind.values[random.nextInt(OpsMathKind.values.length)];
  final operand = switch (kind) {
    OpsMathKind.hexToDecimal => 16 + random.nextInt(240),
    OpsMathKind.powerOfTwo => 1 + random.nextInt(12),
    OpsMathKind.secondsInMinutes => 2 + random.nextInt(89),
    OpsMathKind.secondsInHours => 1 + random.nextInt(12),
    OpsMathKind.kilobytesInMegabytes => 2 + random.nextInt(63),
  };
  return OpsMathQuestion(kind: kind, operand: operand);
}

/// Whether [typed] is [answer].
///
/// Checked as a whole number: spaces around it and zeros before it do not
/// matter. Anything with a sign, a decimal point, a letter or nothing in it
/// is not an answer. A plain comparison of two numbers on screen: nothing
/// is read from a message and nothing is sent.
bool opsMathAnswerMatches({required String typed, required int answer}) {
  final text = typed.trim();
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) return false;
  return int.tryParse(text) == answer;
}
