import 'package:critalarm/features/in_app_notices/presentation/notice_return_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readsNoticeOnReturn', () {
    test('reads when Home comes back from another tab', () {
      expect(readsNoticeOnReturn(wasElsewhere: true, isCovered: false), isTrue);
    });

    test('a pushed screen is read by didPopNext, so not twice', () {
      expect(readsNoticeOnReturn(wasElsewhere: true, isCovered: true), isFalse);
    });

    test('reads nothing when Home was never left', () {
      expect(
        readsNoticeOnReturn(wasElsewhere: false, isCovered: false),
        isFalse,
      );
      expect(
        readsNoticeOnReturn(wasElsewhere: false, isCovered: true),
        isFalse,
      );
    });
  });
}
