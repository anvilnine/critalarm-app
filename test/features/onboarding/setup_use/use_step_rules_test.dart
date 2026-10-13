import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/use_step_rules.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements SetupUseStore {
  SetupUse? value;
  int saves = 0;
  bool fails = false;

  @override
  SetupUse? read() => value;

  @override
  Future<void> save(SetupUse use) async {
    if (fails) throw StateError('disk full');
    saves++;
    value = use;
  }

  @override
  Future<void> clear() async => value = null;
}

void main() {
  late _MemoryStore store;
  late SetupUseReplay replay;

  setUp(() {
    store = _MemoryStore();
    replay = SetupUseReplay();
  });

  group('recordSetupUse', () {
    test('a real run saves the answer and leaves the replay alone', () async {
      await recordSetupUse(
        SetupUse.homelab,
        isReplay: false,
        store: store,
        replay: replay,
      );

      expect(store.value, SetupUse.homelab);
      expect(replay.pick, isNull);
    });

    test('a replay saves nothing and keeps the pick in memory', () async {
      await recordSetupUse(
        SetupUse.jobs,
        isReplay: true,
        store: store,
        replay: replay,
      );

      expect(store.saves, 0);
      expect(store.value, isNull);
      expect(replay.pick, SetupUse.jobs);
    });

    test('a store that fails does not stop setup', () async {
      store.fails = true;

      await expectLater(
        recordSetupUse(
          SetupUse.home,
          isReplay: false,
          store: store,
          replay: replay,
        ),
        completes,
      );
    });

    test('a second answer replaces the first', () async {
      for (final use in [SetupUse.servers, SetupUse.other]) {
        await recordSetupUse(
          use,
          isReplay: false,
          store: store,
          replay: replay,
        );
      }

      expect(store.value, SetupUse.other);
    });
  });

  group('setupUseEventWord', () {
    test('is the wire id, or skipped for the skip control', () {
      for (final use in SetupUse.values) {
        expect(setupUseEventWord(use, skipped: false), use.wire);
        expect(setupUseEventWord(use, skipped: true), 'skipped');
      }
    });
  });

  group('setupUseStartsPicked', () {
    test('a first visit has no row picked, whatever is saved', () {
      store.value = SetupUse.servers;
      expect(
        setupUseStartsPicked(
          cameBack: false,
          isReplay: false,
          store: store,
          replay: replay,
        ),
        isNull,
      );
    });

    test('coming back shows the saved answer', () {
      store.value = SetupUse.home;
      expect(
        setupUseStartsPicked(
          cameBack: true,
          isReplay: false,
          store: store,
          replay: replay,
        ),
        SetupUse.home,
      );
    });

    test('coming back with nothing saved picks no row', () {
      expect(
        setupUseStartsPicked(
          cameBack: true,
          isReplay: false,
          store: store,
          replay: replay,
        ),
        isNull,
      );
    });

    test('coming back in a replay shows the replay pick', () {
      store.value = SetupUse.servers;
      replay.set(SetupUse.jobs);
      expect(
        setupUseStartsPicked(
          cameBack: true,
          isReplay: true,
          store: store,
          replay: replay,
        ),
        SetupUse.jobs,
      );
    });
  });

  group('the page gives room', () {
    test('the face is full size at the default text size', () {
      expect(useStepFaceSizeFor(textScale: 1, width: 390), 124);
      expect(useStepFaceSizeFor(textScale: 1.3, width: 390), 124);
      expect(
        useStepFaceSizeFor(textScale: 1.3000000000000003, width: 390),
        124,
      );
    });

    test('the face shrinks above 1.3', () {
      expect(useStepFaceSizeFor(textScale: 1.31, width: 390), 72);
      expect(useStepFaceSizeFor(textScale: 1.6, width: 390), 72);
    });

    test('the face goes at 2.0 and on a phone narrower than 340', () {
      expect(useStepFaceSizeFor(textScale: 2, width: 390), 0);
      expect(useStepFaceSizeFor(textScale: 3, width: 390), 0);
      expect(useStepFaceSizeFor(textScale: 1, width: 320), 0);
      expect(useStepFaceSizeFor(textScale: 1, width: 339.9), 0);
      expect(useStepFaceSizeFor(textScale: 1, width: 340), 124);
    });

    test('the title is smaller on a narrow phone', () {
      expect(useStepTitleSizeFor(width: 320), 36);
      expect(useStepTitleSizeFor(width: 390), 44);
    });
  });
}
