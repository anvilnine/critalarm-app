import 'dart:io';

import 'package:critalarm/core/sound/share_copy_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Which shared paths the app may open and then delete. The same cases as
/// ShareCopyRuleTest on Android.
void main() {
  late Directory root;
  late String folder;
  late File prefs;

  setUp(() async {
    // Directory.systemTemp sits under /var on macOS, which is a link to
    // /private/var, the same way the app's container is on iOS.
    root = await Directory.systemTemp.createTemp('share_copy_');
    folder = p.join(root.path, 'cache', shareCopyFolderName);
    await Directory(folder).create(recursive: true);
    prefs = File(p.join(root.path, 'shared_prefs', 'critalarm.xml'));
    await prefs.create(recursive: true);
    await prefs.writeAsString('x');
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> copy(String name) async {
    final file = File(p.join(folder, name));
    await file.writeAsString('audio');
    return file;
  }

  test('a copy directly inside the share folder gets through', () async {
    final file = await copy('1234_memo.m4a');
    expect(await isShareCopyPath(file.path, folder: folder), isTrue);
  });

  test('a file outside the share folder is turned away', () async {
    expect(await isShareCopyPath(prefs.path, folder: folder), isFalse);
  });

  test('.. is turned away, wherever it leads', () async {
    await copy('a.m4a');
    expect(
      await isShareCopyPath(
        p.join(folder, '..', '..', 'shared_prefs', 'critalarm.xml'),
        folder: folder,
      ),
      isFalse,
    );
    // Even back into the share folder.
    expect(
      await isShareCopyPath(
        '$folder/../$shareCopyFolderName/a.m4a',
        folder: folder,
      ),
      isFalse,
    );
    expect(await isShareCopyPath('$folder/./a.m4a', folder: folder), isFalse);
  });

  test(
    'a link inside the share folder that points out is turned away',
    () async {
      final link = Link(p.join(folder, '1234_memo.m4a'));
      await link.create(prefs.path);
      expect(await isShareCopyPath(link.path, folder: folder), isFalse);
      expect(prefs.existsSync(), isTrue);
    },
  );

  test('a file in a folder below the share folder is turned away', () async {
    final nested = Directory(p.join(folder, 'deeper'));
    await nested.create();
    final file = File(p.join(nested.path, 'a.m4a'));
    await file.writeAsString('audio');
    expect(await isShareCopyPath(file.path, folder: folder), isFalse);
  });

  test('the share folder itself is turned away', () async {
    expect(await isShareCopyPath(folder, folder: folder), isFalse);
  });

  test('a relative path is turned away', () async {
    expect(
      await isShareCopyPath('$shareCopyFolderName/a.m4a', folder: folder),
      isFalse,
    );
  });

  test('the same folder under a linked name still matches', () async {
    final file = await copy('1234_memo.m4a');
    final resolved = await Directory(folder).resolveSymbolicLinks();
    expect(await isShareCopyPath(file.path, folder: resolved), isTrue);
    final viaResolved = p.join(resolved, '1234_memo.m4a');
    expect(await isShareCopyPath(viaResolved, folder: folder), isTrue);
  });

  test('a copy that was never written still gets through', () async {
    // Too large to copy, or the copy failed: the user is still told why.
    expect(
      await isShareCopyPath(p.join(folder, '1234_huge.wav'), folder: folder),
      isTrue,
    );
  });

  test('a missing file outside the share folder is turned away', () async {
    expect(
      await isShareCopyPath(
        p.join(root.path, 'files', 'gone.m4a'),
        folder: folder,
      ),
      isFalse,
    );
  });
}
