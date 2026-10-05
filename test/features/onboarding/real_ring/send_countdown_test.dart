import 'dart:async';

import 'package:critalarm/features/onboarding/domain/real_ring/send_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// A periodic timer the test ticks by hand.
class _FakeTicker implements Timer {
  _FakeTicker(this.period, this._onTick);

  final Duration period;
  final void Function(Timer timer) _onTick;
  bool _active = true;
  int _ticks = 0;

  void fire() {
    if (!_active) return;
    _ticks++;
    _onTick(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;
}

void main() {
  late List<_FakeTicker> tickers;
  late List<int?> seen;
  late int sends;

  SendCountdown build({Duration delay = const Duration(seconds: 5)}) {
    return SendCountdown(
      delay: delay,
      onChanged: seen.add,
      onSend: () => sends++,
      ticker: (period, onTick) {
        final ticker = _FakeTicker(period, onTick);
        tickers.add(ticker);
        return ticker;
      },
    );
  }

  setUp(() {
    tickers = [];
    seen = [];
    sends = 0;
  });

  test('the shipped delay is five seconds', () {
    expect(realRingSendDelay, const Duration(seconds: 5));
  });

  test('a tap starts the count and sends nothing yet', () {
    final countdown = build();

    expect(countdown.start(), isTrue);

    expect(countdown.isRunning, isTrue);
    expect(countdown.secondsLeft, 5);
    expect(seen, [5]);
    expect(sends, 0);
    expect(tickers.single.period, const Duration(seconds: 1));
  });

  test('it counts down a second at a time and sends once at the end', () {
    final countdown = build()..start();

    for (var i = 0; i < 4; i++) {
      tickers.single.fire();
    }
    expect(seen, [5, 4, 3, 2, 1]);
    expect(sends, 0);

    tickers.single.fire();

    expect(seen, [5, 4, 3, 2, 1, null]);
    expect(sends, 1);
    expect(countdown.isRunning, isFalse);
    expect(tickers.single.isActive, isFalse);
  });

  test('a tick after the end sends nothing more', () {
    build().start();
    for (var i = 0; i < 5; i++) {
      tickers.single.fire();
    }

    tickers.single.fire();

    expect(sends, 1);
  });

  test('cancel goes back to idle and sends nothing', () {
    final countdown = build()..start();
    tickers.single.fire();

    countdown.cancel();

    expect(seen, [5, 4, null]);
    expect(sends, 0);
    expect(countdown.isRunning, isFalse);
    expect(tickers.single.isActive, isFalse);

    // The timer the cancel stopped cannot send later.
    tickers.single.fire();
    expect(sends, 0);
  });

  test('cancel with nothing running does nothing', () {
    build().cancel();

    expect(seen, isEmpty);
    expect(sends, 0);
  });

  test('the app leaving the front mid-count sends at once, and once', () {
    final countdown = build()..start();
    tickers.single.fire();

    countdown.leftFront();

    expect(sends, 1);
    expect(seen, [5, 4, null]);
    expect(countdown.isRunning, isFalse);

    // Neither the stopped timer nor a second lifecycle event sends again.
    tickers.single.fire();
    countdown.leftFront();
    expect(sends, 1);
  });

  test('the app leaving the front with nothing running sends nothing', () {
    build().leftFront();

    expect(sends, 0);
    expect(seen, isEmpty);
  });

  test('a second tap while it counts changes nothing', () {
    final countdown = build()..start();
    tickers.single.fire();

    expect(countdown.start(), isFalse);

    expect(tickers, hasLength(1));
    expect(countdown.secondsLeft, 4);
    expect(seen, [5, 4]);
    expect(sends, 0);
  });

  test('after a cancel a new tap starts a fresh count', () {
    final countdown = build()
      ..start()
      ..cancel();

    expect(countdown.start(), isTrue);

    expect(tickers, hasLength(2));
    expect(countdown.secondsLeft, 5);
    expect(sends, 0);
  });

  test('a delay of zero sends on the tap, with no count', () {
    final countdown = build(delay: Duration.zero);

    expect(countdown.start(), isTrue);

    expect(sends, 1);
    expect(seen, isEmpty);
    expect(tickers, isEmpty);
    expect(countdown.isRunning, isFalse);
  });

  test('once disposed nothing is sent or reported', () {
    final countdown = build()
      ..start()
      ..dispose();
    tickers.single.fire();
    countdown.leftFront();

    expect(sends, 0);
    expect(seen, [5]);
    expect(countdown.start(), isFalse);
  });
}
