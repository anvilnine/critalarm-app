import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guides.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_intent_order.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_settings_opener.dart';
import 'package:critalarm/features/reliability/domain/sources/phone_maker_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the last tap on "Open settings" did.
enum MakerOpenOutcome {
  /// Not tapped yet.
  none,

  /// A page of the maker's own opened.
  makerPage,

  /// The maker's page was not reachable, so the app's page in the system
  /// settings opened instead.
  appPage,

  /// Nothing opened.
  failed,
}

@immutable
final class MakerGuideState {
  const MakerGuideState({
    this.guide,
    this.isLoaded = false,
    this.isDone = false,
    this.outcome = MakerOpenOutcome.none,
  });

  /// Null until loaded, and for a phone no guide covers.
  final MakerGuide? guide;
  final bool isLoaded;

  /// The user said they did the steps, on this OS version. The app cannot
  /// read the settings, so this is only their word.
  final bool isDone;
  final MakerOpenOutcome outcome;

  MakerGuideState copyWith({
    MakerGuide? guide,
    bool? isLoaded,
    bool? isDone,
    MakerOpenOutcome? outcome,
  }) => MakerGuideState(
    guide: guide ?? this.guide,
    isLoaded: isLoaded ?? this.isLoaded,
    isDone: isDone ?? this.isDone,
    outcome: outcome ?? this.outcome,
  );

  @override
  bool operator ==(Object other) =>
      other is MakerGuideState &&
      other.guide == guide &&
      other.isLoaded == isLoaded &&
      other.isDone == isDone &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(guide, isLoaded, isDone, outcome);
}

/// The guide page for this phone's maker: which steps, opening its settings,
/// and the user's word that they did them.
class MakerGuideCubit extends Cubit<MakerGuideState> {
  MakerGuideCubit({
    required this._makerReader,
    required this._os,
    required this._store,
    required this._opener,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const MakerGuideState());

  final DeviceMakerReader _makerReader;
  final OsVersionReader _os;
  final MakerGuideStore _store;
  final MakerSettingsOpener _opener;
  final DateTime Function() _now;

  Future<void> load() async {
    final family = makerFamilyFor(await _makerReader.read());
    final guide = family == null ? null : makerGuideFor(family);
    final isDone = await _isDone();
    if (isClosed) return;
    emit(MakerGuideState(guide: guide, isLoaded: true, isDone: isDone));
  }

  /// The same rule the Reliability row uses, so the two cannot disagree.
  Future<bool> _isDone() async {
    final check = PhoneMakerSource.phoneMakerCheckFor(
      record: _store.read(),
      osMajor: await _os.major(),
      guideRouteName: makerGuideRouteName,
    );
    return check.state == ReliabilityState.fine;
  }

  Future<void> openSettings() async {
    final guide = state.guide;
    if (guide == null) return;
    final tried = makerIntentOrder(guide);
    final opened = await _opener.open(tried);
    if (isClosed) return;
    emit(
      state.copyWith(
        outcome: opened < 0
            ? MakerOpenOutcome.failed
            : openedFallbackPage(tried, opened)
            ? MakerOpenOutcome.appPage
            : MakerOpenOutcome.makerPage,
      ),
    );
  }

  Future<void> markDone() async {
    await _store.write(
      MakerGuideRecord(doneAt: _now(), osMajor: await _os.major()),
    );
    if (isClosed) return;
    emit(state.copyWith(isDone: true));
  }

  Future<void> markNotDone() async {
    await _store.write(MakerGuideRecord.none);
    if (isClosed) return;
    emit(state.copyWith(isDone: false));
  }
}
