/// The two steps of the sheet. Step one names the token, step two shows it
/// once.
enum NewTokenStep { name, shown }

/// The longest name the server keeps (api.md 3.1). Longer is cut.
const kNewTokenNameMax = 40;

/// Tool names offered as quick names. They are data, not words of the app.
const kNewTokenQuickNames = <String>[
  'curl',
  'Uptime Kuma',
  'Grafana',
  'GitHub Actions',
  'cron',
];

/// The name to send for what was typed: trimmed and cut to
/// [kNewTokenNameMax] characters. Null when nothing is left, so the request
/// carries no name and the server assigns `Token N`.
String? resolveNewTokenName(String typed) {
  final trimmed = typed.trim();
  if (trimmed.isEmpty) return null;
  final cut = String.fromCharCodes(trimmed.runes.take(kNewTokenNameMax));
  final result = cut.trimRight();
  return result.isEmpty ? null : result;
}

/// How many characters of a token show at the start of its masked form.
const _maskHead = 7;

/// How many characters of a token show at the end of its masked form.
const _maskTail = 4;

/// What stands between the two ends of a masked token.
const _maskGap = '...';

/// [token] with its middle hidden, such as `tk_da39...a1c9`. A token too
/// short to have a middle is returned whole.
String maskedToken(String token) {
  if (token.length <= _maskHead + _maskTail) return token;
  final head = token.substring(0, _maskHead);
  final tail = token.substring(token.length - _maskTail);
  return '$head$_maskGap$tail';
}

/// Lets one tap make one token.
///
/// [tryBegin] answers true once. Every later call answers false until
/// [release] runs, which the sheet does only when the server refused, so the
/// person can try again. A token that was made keeps the guard closed.
class MakeTokenGuard {
  bool _isBusy = false;

  bool get isBusy => _isBusy;

  /// True when this call may start the request.
  bool tryBegin() {
    if (_isBusy) return false;
    _isBusy = true;
    return true;
  }

  /// Opens the guard again after a request that made nothing.
  void release() => _isBusy = false;
}
