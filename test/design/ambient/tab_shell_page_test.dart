import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/design/ambient/tab_shell_page.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cover implements AmbientTabCover {
  const _Cover({required this.leavesTabBehind});

  @override
  final bool leavesTabBehind;
}

void main() {
  group('coverLeavesTabBehind', () {
    test('is true for a cover that asks for it', () {
      expect(coverLeavesTabBehind(const _Cover(leavesTabBehind: true)), isTrue);
    });

    test('is false for a cover that does not', () {
      expect(
        coverLeavesTabBehind(const _Cover(leavesTabBehind: false)),
        isFalse,
      );
    });

    test('is false for anything else, and for nothing', () {
      expect(coverLeavesTabBehind(Object()), isFalse);
      expect(coverLeavesTabBehind(null), isFalse);
    });
  });
}
