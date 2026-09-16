import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_branches.dart';
import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shellBranchForPath', () {
    test('the three tab roots map to their own branch', () {
      expect(shellBranchForPath('/'), ShellBranch.topics);
      expect(shellBranchForPath('/history'), ShellBranch.history);
      expect(shellBranchForPath('/settings'), ShellBranch.settings);
    });

    test('a settings sub-screen belongs to the settings tab', () {
      for (final path in <String>[
        '/settings/permissions',
        '/settings/alarms',
        '/settings/server',
        '/settings/privacy',
        '/settings/about',
        '/settings/developer',
        '/settings/disconnected',
      ]) {
        expect(shellBranchForPath(path), ShellBranch.settings, reason: path);
      }
    });

    test('a route that covers the display belongs to no tab', () {
      for (final path in <String>[
        '/sounds',
        '/sounds?topic=ops',
        '/topics/new',
        '/topics/ops',
        '/topics/ops/messages',
        '/incidents/inc_1',
        '/paywall',
        '/alarm',
        '/lockscreen',
        '/onboarding/connect',
      ]) {
        expect(shellBranchForPath(path), isNull, reason: path);
      }
    });

    test('a query string does not change the answer', () {
      expect(
        shellBranchForPath('/settings?disconnected=true'),
        ShellBranch.settings,
      );
      expect(shellBranchForPath('/?x=1'), ShellBranch.topics);
    });

    test('a longer name that merely starts the same is not a match', () {
      expect(shellBranchForPath('/settingsomething'), isNull);
      expect(shellBranchForPath('/historybook'), isNull);
    });
  });

  group('ShellBranch', () {
    test('matches the branch order the router actually builds', () {
      final shell = buildRouter().configuration.routes
          .whereType<StatefulShellRoute>()
          .single;

      expect(shell.branches, hasLength(ShellBranch.locations.length));

      for (var i = 0; i < shell.branches.length; i++) {
        final first = shell.branches[i].routes.first as GoRoute;
        expect(
          first.path,
          ShellBranch.locations[i],
          reason: 'branch $i moved',
        );
        expect(shellBranchForPath(first.path), i, reason: 'branch $i moved');
      }
    });
  });

  group('the settings search index', () {
    test('never points a search result at the topics or history tab', () {
      for (final destination in SettingsSearchIndex.all) {
        final branch = shellBranchForPath(destination.routePath);
        expect(
          branch == null || branch == ShellBranch.settings,
          isTrue,
          reason:
              '${destination.id} points at branch $branch, so opening it from '
              'search would switch the user to a tab they did not ask for',
        );
      }
    });
  });
}
