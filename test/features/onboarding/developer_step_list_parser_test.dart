import 'package:critalarm/features/onboarding/domain/flow/developer_step_list_parser.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final requires = OnboardingStepRegistry.requiresById;

  DeveloperStepListResult parse(String text) =>
      parseDeveloperStepList(text, requires: requires);

  group('splitDeveloperStepList', () {
    test('trims spaces and drops empty items', () {
      expect(
        splitDeveloperStepList(' welcome ,, connect ,  , permissions,'),
        ['welcome', 'connect', 'permissions'],
      );
    });

    test('an empty string has no items', () {
      expect(splitDeveloperStepList(''), isEmpty);
      expect(splitDeveloperStepList('  ,  , '), isEmpty);
    });
  });

  group('parseDeveloperStepList', () {
    test('accepts a list and gives the order the validator kept', () {
      final ok = parse('welcome, connect, permissions');
      expect(ok.isAccepted, isTrue);
      expect(ok.flow!.id, developerCustomFlowId);
      expect(ok.flow!.steps, ['welcome', 'connect', 'permissions']);
      expect(ok.unknown, isEmpty);
      expect(ok.duplicates, isEmpty);
    });

    test('reports an unknown id and still accepts the rest', () {
      final result = parse('welcome, made_up, connect, nope, made_up');

      expect(result.unknown, ['made_up', 'nope']);
      expect(result.flow!.steps, ['welcome', 'connect']);
    });

    test('reports a duplicate id and keeps the first position', () {
      final result = parse('welcome, connect, permissions, connect, welcome');

      expect(result.duplicates, ['connect', 'welcome']);
      expect(result.flow!.steps, ['welcome', 'connect', 'permissions']);
    });

    test('an empty string is rejected as empty', () {
      final result = parse('');

      expect(result.flow, isNull);
      expect(result.problem, DeveloperStepListProblem.empty);
    });

    test('a list of only unknown ids is rejected as empty', () {
      final result = parse('one, two');

      expect(result.unknown, ['one', 'two']);
      expect(result.problem, DeveloperStepListProblem.empty);
    });

    test('connect before welcome is rejected and names the first step', () {
      final result = parse('connect, welcome');

      expect(result.flow, isNull);
      expect(result.problem, DeveloperStepListProblem.welcomeNotFirst);
      expect(result.problemStep, 'connect');
    });

    test('a step before the one it requires names both', () {
      final result = parse('welcome, first_topic, connect');

      expect(result.flow, isNull);
      expect(result.problem, DeveloperStepListProblem.orderBroken);
      expect(result.problemStep, 'first_topic');
      expect(result.missingStep, 'connect');
    });

    test('a step whose required step is missing names the missing one', () {
      final result = parse('welcome, connect, real_ring');

      expect(result.problem, DeveloperStepListProblem.orderBroken);
      expect(result.problemStep, 'real_ring');
      expect(result.missingStep, 'first_topic');
    });

    test('an unknown id ahead of welcome does not hide welcome', () {
      expect(parse('made_up, welcome').flow!.steps, ['welcome']);
    });
  });
}
