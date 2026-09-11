import 'package:critalarm/core/models/server_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerInfo', () {
    test('defaults match specification', () {
      const info = ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://alerts.example.com',
        relayUrl: 'https://relay.critalarm.app',
      );

      expect(info.name, 'critalarm');
      expect(info.version, '0.1.0');
      expect(info.baseUrl, 'https://alerts.example.com');
      expect(info.relayUrl, 'https://relay.critalarm.app');
      expect(info.relayContent, 'none');
      expect(info.mode, ServerModes.selfhosted);
    });

    test('copyWith works correctly', () {
      const info = ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://alerts.example.com',
        relayUrl: 'https://relay.critalarm.app',
      );

      final updated = info.copyWith(
        version: '1.0.0',
        mode: ServerModes.hosted,
        relayContent: 'full',
      );

      expect(updated.version, '1.0.0');
      expect(updated.mode, 'hosted');
      expect(updated.relayContent, 'full');
      expect(updated.baseUrl, 'https://alerts.example.com');
    });

    test('serializes and deserializes JSON roundtrip', () {
      const info = ServerInfo(
        version: '0.2.0',
        baseUrl: 'https://custom.example.org',
        relayUrl: 'https://relay.custom.org',
        relayContent: 'full',
        mode: ServerModes.relay,
      );

      final json = info.toJson();
      expect(json['name'], 'critalarm');
      expect(json['version'], '0.2.0');
      expect(json['base_url'], 'https://custom.example.org');
      expect(json['relay_url'], 'https://relay.custom.org');
      expect(json['relay_content'], 'full');
      expect(json['mode'], 'relay');

      final deserialized = ServerInfo.fromJson(json);
      expect(deserialized.name, info.name);
      expect(deserialized.version, info.version);
      expect(deserialized.baseUrl, info.baseUrl);
      expect(deserialized.relayUrl, info.relayUrl);
      expect(deserialized.relayContent, info.relayContent);
      expect(deserialized.mode, info.mode);
    });
  });
}
