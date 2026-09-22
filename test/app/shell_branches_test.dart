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

    test('a topic screen belongs to the topics tab', () {
      for (final path in <String>[
        '/topics/ops',
        '/topics/ops?curl=1',
        '/topics/ops/messages',
        '/topics/ops/sounds',
      ]) {
        expect(shellBranchForPath(path), ShellBranch.topics, reason: path);
      }
    });

    test('a route that covers the display belongs to no tab', () {
      for (final path in <String>[
        '/sounds',
        '/sounds?topic=ops',
        '/topics/new',
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

    test('every screen inside a tab maps back to that tab', () {
      final shell = buildRouter().configuration.routes
          .whereType<StatefulShellRoute>()
          .single;

      void walk(List<RouteBase> routes, String parent, int branch) {
        for (final route in routes.whereType<GoRoute>()) {
          final joined = route.path.startsWith('/')
              ? route.path
              : '${parent == '/' ? '' : parent}/${route.path}';
          final path = joined.replaceAll(RegExp(':[A-Za-z]+'), 'x');
          expect(shellBranchForPath(path), branch, reason: path);
          walk(route.routes, joined, branch);
        }
      }

      for (var i = 0; i < shell.branches.length; i++) {
        walk(shell.branches[i].routes, '', i);
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

  group('opensWithGo', () {
    test('a path on another tab is a go', () {
      expect(opensWithGo('/settings/account', from: '/'), isTrue);
      expect(opensWithGo('/history', from: '/settings'), isTrue);
      expect(opensWithGo('/', from: '/ring'), isTrue);
      expect(opensWithGo('/topics/ops?curl=1', from: '/history'), isTrue);
      expect(opensWithGo('/topics/ops?curl=1', from: '/settings'), isTrue);
    });

    test('a path on the same tab is a push', () {
      expect(opensWithGo('/settings/account', from: '/settings'), isFalse);
      expect(opensWithGo('/history?x=1', from: '/history'), isFalse);
      expect(opensWithGo('/topics/ops?curl=1', from: '/'), isFalse);
    });

    test('a route that covers the display is a push', () {
      expect(opensWithGo('/ring', from: '/settings'), isFalse);
      expect(opensWithGo('/paywall?source=x', from: '/'), isFalse);
      expect(opensWithGo('/topics/new', from: '/settings'), isFalse);
    });
  });
}
