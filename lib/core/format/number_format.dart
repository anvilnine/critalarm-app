/// Formats a [double] for display: rounds to [maxDecimals] then trims trailing
/// zeros (and a dangling decimal point) so the value reads cleanly.
///
/// The rounding also scrubs binary floating-point noise — the classic
/// `1.2 - 0.0...` artefact that surfaces as "1.1999999999999993" on the Dart
/// VM. Examples: `88.0 → "88"`, `1.2 → "1.2"`, `1.1999999999999993 → "1.2"`.
///
/// Display-only. Never use this to round stored/parsed values — persistence
/// keeps full precision.
String formatNum(double v, {int maxDecimals = 1}) {
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  // Fold a rounded-to-negative-zero ("-0") back to "0".
  if (s == '-0') return '0';
  return s;
}
