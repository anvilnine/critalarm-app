import 'dart:async';
import 'dart:io';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.critalarm.app'));
  });

  Future<Failure> fail(Object error) async {
    final client = _MockApiClient();
    when(() => client.getServerInfo(any())).thenThrow(error);
    final result = await InMemoryServerRepository(client).getServerInfo();
    return result.exceptionOrNull()!;
  }

  test(
    'no connection keeps its own line and none of the exception text',
    () async {
      final failure = await fail(
        const SocketException("Failed host lookup: 'secret.example'"),
      );
      expect(failure.message, isNot(contains('secret')));
      expect(
        failureMessage(failure),
        LocaleKeys.onboarding_connect_network_unreachable.tr(),
      );
    },
  );

  test('a timeout keeps its own line', () async {
    final failure = await fail(TimeoutException('adm_secret'));
    expect(failure.message, isNot(contains('adm_secret')));
    expect(
      failureMessage(failure),
      LocaleKeys.onboarding_connect_connect_timeout.tr(),
    );
  });

  test('another exception is a fault on the phone', () async {
    final failure = await fail(const FormatException('adm_secret'));
    expect(failure.message, isNot(contains('adm_secret')));
    expect(failureMessage(failure), LocaleKeys.api_errors_unknown_phone.tr());
  });
}
