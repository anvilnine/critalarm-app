import 'package:critalarm/design/components/feature_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a locked option reads as its name, locked, then the plan', () {
    expect(
      featureLockSpoken(name: 'Yours', lockedWord: 'locked', planWord: 'Pro'),
      'Yours, locked, Pro',
    );
    expect(
      featureLockSpoken(
        name: 'App icon',
        lockedWord: 'locked',
        planWord: 'Hosted',
      ),
      'App icon, locked, Hosted',
    );
  });

  test('with no plan word it stops at locked', () {
    expect(
      featureLockSpoken(name: 'Yours', lockedWord: 'locked', planWord: null),
      'Yours, locked',
    );
  });
}
