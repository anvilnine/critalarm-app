import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsMakerGuideStore implements MakerGuideStore {
  SharedPrefsMakerGuideStore(this._prefs);

  static const doneAtKey = 'reliability_maker_done_at_ms';
  static const osMajorKey = 'reliability_maker_done_os_major';

  final SharedPreferences _prefs;

  @override
  MakerGuideRecord read() {
    final doneMs = _prefs.getInt(doneAtKey);
    if (doneMs == null) return MakerGuideRecord.none;
    return MakerGuideRecord(
      doneAt: DateTime.fromMillisecondsSinceEpoch(doneMs, isUtc: true),
      osMajor: _prefs.getInt(osMajorKey),
    );
  }

  @override
  Future<void> write(MakerGuideRecord record) async {
    final doneAt = record.doneAt;
    if (doneAt == null) {
      await _prefs.remove(doneAtKey);
      await _prefs.remove(osMajorKey);
      return;
    }
    await _prefs.setInt(doneAtKey, doneAt.toUtc().millisecondsSinceEpoch);
    final major = record.osMajor;
    if (major == null) {
      await _prefs.remove(osMajorKey);
    } else {
      await _prefs.setInt(osMajorKey, major);
    }
  }
}
