import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guides.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_settings_opener.dart';
import 'package:critalarm/features/reliability/presentation/maker/maker_guide_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements MakerGuideStore {
  MakerGuideRecord record = MakerGuideRecord.none;

  @override
  MakerGuideRecord read() => record;

  @override
  Future<void> write(MakerGuideRecord next) async => record = next;
}

/// Answers a fixed index and remembers what it was asked.
class _Opener implements MakerSettingsOpener {
  _Opener(this.answer);

  int answer;
  List<MakerIntentCandidate>? asked;

  @override
  Future<int> open(List<MakerIntentCandidate> candidates) async {
    asked = candidates;
    return answer;
  }
}

void main() {
  late _MemoryStore store;
  late _Opener opener;
  late FixedOsVersionReader os;
  final now = DateTime.utc(2026, 10, 7, 9);

  MakerGuideCubit build({String maker = 'samsung'}) => MakerGuideCubit(
    makerReader: FixedDeviceMakerReader.named(maker),
    os: os,
    store: store,
    opener: opener,
    now: () => now,
  );

  setUp(() {
    store = _MemoryStore();
    opener = _Opener(0);
    os = const FixedOsVersionReader(15);
  });

  test('loads the guide for the phone and starts not done', () async {
    final cubit = build(maker: 'Redmi');
    await cubit.load();
    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.guide, makerGuideFor(MakerFamily.xiaomi));
    expect(cubit.state.isDone, isFalse);
    await cubit.close();
  });

  test('a phone with no guide loads with no guide', () async {
    final cubit = build(maker: 'google');
    await cubit.load();
    expect(cubit.state.isLoaded, isTrue);
    expect(cubit.state.guide, isNull);
    await cubit.close();
  });

  test(
    '"I did these" saves the time and OS version, and "Not yet" clears it',
    () async {
      final cubit = build();
      await cubit.load();
      await cubit.markDone();
      expect(cubit.state.isDone, isTrue);
      expect(store.record, MakerGuideRecord(doneAt: now, osMajor: 15));
      await cubit.markNotDone();
      expect(cubit.state.isDone, isFalse);
      expect(store.record, MakerGuideRecord.none);
      await cubit.close();
    },
  );

  test(
    'a word given on this version loads as done; on another it does not',
    () async {
      store.record = MakerGuideRecord(doneAt: now, osMajor: 15);
      final same = build();
      await same.load();
      expect(same.state.isDone, isTrue);
      await same.close();

      os = const FixedOsVersionReader(16);
      final later = build();
      await later.load();
      expect(later.state.isDone, isFalse);
      await later.close();
    },
  );

  group('open settings', () {
    test('asks for the maker pages and then the app page', () async {
      final cubit = build();
      await cubit.load();
      await cubit.openSettings();
      final asked = opener.asked!;
      expect(asked.last.kind, MakerIntentKind.appDetails);
      expect(
        asked.length,
        makerGuideFor(MakerFamily.samsung).intents.length + 1,
      );
      await cubit.close();
    });

    test('a maker page that opens is reported as the maker page', () async {
      opener.answer = 0;
      final cubit = build();
      await cubit.load();
      await cubit.openSettings();
      expect(cubit.state.outcome, MakerOpenOutcome.makerPage);
      await cubit.close();
    });

    test(
      'the app page opening is said so, because the maker page was missing',
      () async {
        final cubit = build();
        await cubit.load();
        opener.answer = makerGuideFor(MakerFamily.samsung).intents.length;
        await cubit.openSettings();
        expect(cubit.state.outcome, MakerOpenOutcome.appPage);
        await cubit.close();
      },
    );

    test('nothing opening is reported as failed', () async {
      opener.answer = -1;
      final cubit = build();
      await cubit.load();
      await cubit.openSettings();
      expect(cubit.state.outcome, MakerOpenOutcome.failed);
      await cubit.close();
    });

    test('with no guide there is nothing to open', () async {
      final cubit = build(maker: 'google');
      await cubit.load();
      await cubit.openSettings();
      expect(opener.asked, isNull);
      expect(cubit.state.outcome, MakerOpenOutcome.none);
      await cubit.close();
    });
  });
}
