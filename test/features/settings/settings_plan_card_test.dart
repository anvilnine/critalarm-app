import 'package:critalarm/features/settings/presentation/settings_plan_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planUsageFraction', () {
    test('is the share of the allowance used', () {
      expect(planUsageFraction(used: 1, limit: 2), 0.5);
      expect(planUsageFraction(used: 0, limit: 2), 0);
    });

    test('stops at full when the allowance is passed', () {
      expect(planUsageFraction(used: 3, limit: 2), 1);
    });

    test('is null where there is no allowance to show', () {
      expect(planUsageFraction(used: 2, limit: null), isNull);
      expect(planUsageFraction(used: 2, limit: 0), isNull);
    });
  });
}
