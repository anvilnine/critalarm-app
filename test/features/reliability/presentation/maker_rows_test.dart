import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the maker row has a title', () {
    expect(
      reliabilityTitleKey(ReliabilityCheckIds.phoneMaker),
      LocaleKeys.maker_guide_row_title,
    );
  });

  test('each maker reason has its own line', () {
    ReliabilityCheck look(String reason) => ReliabilityCheck(
      id: ReliabilityCheckIds.phoneMaker,
      state: ReliabilityState.needsLook,
      reason: reason,
    );
    expect(
      reliabilityLineKey(look('maker_unchecked')),
      LocaleKeys.maker_guide_line_unchecked,
    );
    expect(
      reliabilityLineKey(look('maker_os_changed')),
      LocaleKeys.maker_guide_line_os_changed,
    );
  });

  test('the fix that opens the guide reads "See the steps"', () {
    expect(
      reliabilityFixLabelKey(
        const OpenRouteFix(makerGuideRouteName),
        testRouteName: 'testRing',
      ),
      LocaleKeys.maker_guide_fix_see_steps,
    );
  });

  test('other route fixes keep their labels', () {
    expect(
      reliabilityFixLabelKey(
        const OpenRouteFix('testRing'),
        testRouteName: 'testRing',
      ),
      LocaleKeys.reliability_fix_ring_test,
    );
    expect(
      reliabilityFixLabelKey(
        const OpenRouteFix('somewhere'),
        testRouteName: 'testRing',
      ),
      LocaleKeys.reliability_fix_open,
    );
  });
}
