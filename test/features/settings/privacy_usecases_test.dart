import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPrivacyRepository extends Mock implements PrivacyRepository {}

void main() {
  late MockPrivacyRepository repository;

  setUp(() {
    repository = MockPrivacyRepository();
  });

  group('Privacy Usecases', () {
    test('GetPrivacySettingsUsecase delegates to repository', () async {
      const expected = PrivacySettings(
        analyticsEnabled: true,
      );
      when(
        () => repository.getPrivacySettings(),
      ).thenAnswer((_) async => expected.toSuccess());

      final usecase = GetPrivacySettingsUsecase(repository);
      final result = await usecase(const NoParams());

      expect(result.getOrNull(), equals(expected));
      verify(() => repository.getPrivacySettings()).called(1);
    });

    test('SetAnalyticsEnabledUsecase delegates to repository', () async {
      when(
        () => repository.setAnalyticsEnabled(enabled: any(named: 'enabled')),
      ).thenAnswer((_) async => unit.toSuccess());

      final usecase = SetAnalyticsEnabledUsecase(repository);
      final result = await usecase(true);

      expect(result.isSuccess(), isTrue);
      verify(() => repository.setAnalyticsEnabled(enabled: true)).called(1);
    });

    test('SetCrashReportingEnabledUsecase delegates to repository', () async {
      when(
        () => repository.setCrashReportingEnabled(
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => unit.toSuccess());

      final usecase = SetCrashReportingEnabledUsecase(repository);
      final result = await usecase(true);

      expect(result.isSuccess(), isTrue);
      verify(
        () => repository.setCrashReportingEnabled(enabled: true),
      ).called(1);
    });
  });
}
