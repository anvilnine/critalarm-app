import 'dart:math';

/// The kinds of question, in the order a seed picks from.
enum OpsMathKind {
  /// What is 0x1F in decimal. Operand 0x1A to 0xFF, with at least one
  /// letter digit, so it takes real conversion.
  hexToDecimal,

  /// What is 2^10. Operand 5 to 12.
  powerOfTwo,

  /// How many seconds in 7 minutes. Operand 3 to 90, never a multiple of 10.
  secondsInMinutes,

  /// How many seconds in 3 hours. Operand 2 to 12.
  secondsInHours,

  /// How many kilobytes in 5 megabytes, at 1024. Operand 3 to 64.
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
    OpsMathKind.hexToDecimal => _hexOperand(random),
    OpsMathKind.powerOfTwo => 5 + random.nextInt(8),
    OpsMathKind.secondsInMinutes => _minutesOperand(random),
    OpsMathKind.secondsInHours => 2 + random.nextInt(11),
    OpsMathKind.kilobytesInMegabytes => 3 + random.nextInt(62),
  };
  return OpsMathQuestion(kind: kind, operand: operand);
}

/// 0x1A to 0xFF where at least one digit is a letter.
int _hexOperand(Random random) {
  while (true) {
    final value = 0x1A + random.nextInt(0xFF - 0x1A + 1);
    if (value >> 4 >= 10 || value & 0xF >= 10) return value;
  }
}

/// 3 to 90, never a multiple of 10.
int _minutesOperand(Random random) {
  while (true) {
    final value = 3 + random.nextInt(88);
    if (value % 10 != 0) return value;
  }
}

/// What a typed answer is: right, still short of the answer's length, or
/// wrong.
enum OpsMathVerdict { right, waiting, wrong }

/// Judges [typed] against [answer]. Right as soon as it is the answer. Wrong
/// only once it is as long as the answer, or when [isFinal] (done pressed)
/// and something was typed. Until then it waits, so a correct start is never
/// cleared.
OpsMathVerdict opsMathJudge({
  required String typed,
  required int answer,
  bool isFinal = false,
}) {
  if (opsMathAnswerMatches(typed: typed, answer: answer)) {
    return OpsMathVerdict.right;
  }
  if (typed.isEmpty) return OpsMathVerdict.waiting;
  if (isFinal || typed.length >= '$answer'.length) {
    return OpsMathVerdict.wrong;
  }
  return OpsMathVerdict.waiting;
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
