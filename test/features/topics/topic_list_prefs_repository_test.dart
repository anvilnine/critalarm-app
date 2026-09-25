import 'package:critalarm/features/topics/data/repositories/shared_prefs_topic_list_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsTopicListPrefsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = SharedPrefsTopicListPrefsRepository(
      await SharedPreferences.getInstance(),
    );
  });

  test('starts with nothing pinned, muted or read', () {
    expect(repo.pinned(), isEmpty);
    expect(repo.muted(), isEmpty);
    expect(repo.lastReadAt('prod'), isNull);
  });

  test('pin and unpin', () async {
    await repo.setPinned('prod', pinned: true);
    await repo.setPinned('ci', pinned: true);
    expect(repo.pinned(), {'prod', 'ci'});
    await repo.setPinned('prod', pinned: false);
    expect(repo.pinned(), {'ci'});
  });

  test('mute and unmute', () async {
    await repo.setMuted('prod', muted: true);
    expect(repo.muted(), {'prod'});
    await repo.setMuted('prod', muted: false);
    expect(repo.muted(), isEmpty);
  });

  test('read marks are per topic', () async {
    final at = DateTime.fromMillisecondsSinceEpoch(1757462400000);
    await repo.markRead('prod', at);
    expect(repo.lastReadAt('prod'), at);
    expect(repo.lastReadAt('ci'), isNull);
  });
}
