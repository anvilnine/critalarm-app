import 'package:critalarm/app/router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaneHandOffRoute', () {
    final handOff = PaneHandOffRoute<void>(child: const SizedBox.shrink());
    final page = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    test('the page under it never runs its exit transition for it', () {
      // A route below asks the route above with canTransitionFrom before
      // it moves on that route's clock.
      expect(handOff.canTransitionFrom(page), isFalse);
      expect(page.canTransitionTo(handOff), isTrue);
    });

    test('it moves nothing above it either', () {
      expect(handOff.canTransitionTo(page), isFalse);
    });

    test('it is see-through, with no transition and no barrier', () {
      expect(handOff.opaque, isFalse);
      expect(handOff.transitionDuration, Duration.zero);
      expect(handOff.reverseTransitionDuration, Duration.zero);
      expect(handOff.barrierColor, isNull);
    });
  });
}
