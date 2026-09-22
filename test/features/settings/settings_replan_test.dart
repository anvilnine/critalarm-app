import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disconnecting a server re-plans reminders right away', () async {
    var replans = 0;
    final cubit = SettingsCubit(onConnectionChanged: () async => replans++);
    await cubit.disconnectServer();
    expect(replans, 1);
    await cubit.close();
  });

  test('saving a server re-plans reminders right away', () async {
    var replans = 0;
    final cubit = SettingsCubit(onConnectionChanged: () async => replans++);
    await cubit.saveConnection(
      serverUrl: 'https://alerts.example.com',
      adminToken: 'ad_1',
    );
    expect(replans, 1);
    await cubit.close();
  });
}
