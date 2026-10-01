import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/in_app_notices/presentation/home_asks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `runHomeAsk` reads a dozen things out of `getIt`. Only [AlarmFocus] is
/// registered here, so the guard is the only way the call can come back
/// without throwing.
void main() {
  late StreamController<List<Incident>> list;

  setUp(() {
    list = StreamController<List<Incident>>.broadcast();
    getIt.registerSingleton<AlarmFocus>(AlarmFocus(incidents: list.stream));
  });

  tearDown(() async {
    await getIt.reset();
    await list.close();
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    return captured;
  }

  testWidgets('asks nothing while an alarm is under way', (tester) async {
    final context = await pumpContext(tester);
    list.add([
      Incident(id: 'inc_1', topic: 'ops', openedAt: DateTime.now()),
    ]);
    await tester.pump();

    await runHomeAsk(context);
  });

  testWidgets('goes on to the rules once nothing is open', (tester) async {
    final context = await pumpContext(tester);

    // Nothing else is registered, so getting past the guard throws. That is
    // the proof the test above was stopped by the guard and not by luck.
    await expectLater(runHomeAsk(context), throwsA(isA<Object>()));
  });
}
