import 'dart:async';

import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_sheet_rules.dart';

/// How a connect sheet closed.
enum ConnectSheetEnd {
  /// The person connected.
  connected,

  /// The person left without connecting, after a failure or before trying.
  left,

  /// An alarm took the screen before the person tried to connect. The link
  /// goes back to wait.
  interrupted,

  /// An alarm took the screen while a connect was under way. The connect
  /// carries on, and the link is spent.
  interruptedWhileConnecting,
}

/// Shows [link] and completes when the sheet closes.
typedef ConnectSheetPresenter =
    Future<ConnectSheetEnd> Function(ConnectLink link);

/// Opens the connect sheet for the link in the holder when the app can show
/// one, and holds the link back until then.
///
/// - The link is taken from the holder when the sheet opens, so the holder is
///   empty for as long as the sheet is up and after it closes.
/// - A second link that arrives while the sheet is up waits in the holder
///   and gets its own sheet after this one closes. The sheet never changes
///   what it shows while the person is reading it, because a tap on
///   Connect must connect to what was on screen.
/// - Newest wins. A link that is waiting is replaced by a newer one, and a
///   link that goes back (below) never replaces a newer one. The older link
///   is dropped on purpose, because the person tapped the newer one last.
/// - A sheet that an alarm closed before the person tried to connect puts
///   its link back, unless a newer link has arrived.
/// - A sheet that failed to open puts its link back once. A second failure
///   drops it.
///
/// Memory only. Nothing here logs the link.
class ConnectLinkCoordinator {
  ConnectLinkCoordinator({
    required ConnectLinkHolder links,
    required Future<ConnectSheetSituation> Function() readSituation,
    required ConnectSheetPresenter showSheet,
    bool Function()? checkAgain,
  }) : _stillAllowed = checkAgain,
       _holder = links,
       _situation = readSituation,
       _present = showSheet;

  final ConnectLinkHolder _holder;
  final Future<ConnectSheetSituation> Function() _situation;
  final ConnectSheetPresenter _present;

  /// Asked once more, with no wait before the sheet opens, because the
  /// situation was read a moment earlier and an alarm can start in between.
  final bool Function()? _stillAllowed;

  /// The link that already failed to open once. It is not given a third try.
  ConnectLink? _failedOnce;

  StreamSubscription<ConnectLink>? _sub;
  bool _busy = false;
  bool _again = false;
  bool _disposed = false;

  /// True while a sheet is up.
  bool get isShowing => _showing;
  bool _showing = false;

  /// Starts listening, and asks once for a link that arrived before this.
  void start() {
    _sub ??= _holder.links.listen((_) => check());
    unawaited(check());
  }

  /// Asks again. Call it when anything the rule reads has changed: the
  /// screen, an alarm, a sheet, setup.
  Future<void> check() async {
    if (_disposed) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      while (!_disposed && _holder.pending != null) {
        _again = false;
        final situation = await _situation();
        if (_disposed || _holder.pending == null) return;
        if (!canShowConnectSheetNow(situation)) {
          if (_again) continue;
          return;
        }
        if (!(_stillAllowed?.call() ?? true)) return;
        final link = _holder.take();
        if (link == null) return;
        await _show(link);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _show(ConnectLink link) async {
    _showing = true;
    var end = ConnectSheetEnd.left;
    var failed = false;
    try {
      end = await _present(link);
    } on Object {
      // Nothing is reported, because what failed may hold the link.
      failed = true;
    } finally {
      _showing = false;
    }
    if (!failed) _failedOnce = null;
    // A newer link always wins: it is what the person tapped last. So a link
    // goes back only when nothing newer is waiting, and that is on purpose.
    if (_holder.pending != null) return;
    if (failed) {
      // One more try, so a sheet that could not open for a moment does not
      // cost the person their link. A second failure drops it.
      if (_failedOnce == link) {
        _failedOnce = null;
        return;
      }
      _failedOnce = link;
      _holder.offer(link);
    } else if (end == ConnectSheetEnd.interrupted) {
      _holder.offer(link);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
  }
}
