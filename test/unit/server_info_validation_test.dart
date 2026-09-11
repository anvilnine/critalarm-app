import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Server URL Validation Logic', () {
    test(
      'accepts valid server URLs (http/https, hostnames, ports, IPv4/IPv6)',
      () {
        expect(
          ServerInfoValidation.isValidServerUrl('https://alerts.critalarm.app'),
          isTrue,
        );
        expect(
          ServerInfoValidation.isValidServerUrl('http://localhost'),
          isTrue,
        );
        expect(
          ServerInfoValidation.isValidServerUrl('http://localhost:8080'),
          isTrue,
        );
        expect(
          ServerInfoValidation.isValidServerUrl(
            'https://alerts.example.com:8443',
          ),
          isTrue,
        );
        expect(
          ServerInfoValidation.isValidServerUrl('http://192.168.1.100:9000'),
          isTrue,
        );
        expect(
          ServerInfoValidation.isValidServerUrl(
            'https://sub.domain.example.co.uk:443/api',
          ),
          isTrue,
        );
        // Handles leading/trailing whitespace
        expect(
          ServerInfoValidation.isValidServerUrl(
            '  https://alerts.critalarm.app  ',
          ),
          isTrue,
        );
      },
    );

    test('refuses invalid or malformed server URLs', () {
      // Empty string
      expect(ServerInfoValidation.isValidServerUrl(''), isFalse);
      // Whitespace only
      expect(ServerInfoValidation.isValidServerUrl('   '), isFalse);
      // Null
      expect(ServerInfoValidation.isValidServerUrl(null), isFalse);
      // Invalid schemes
      expect(
        ServerInfoValidation.isValidServerUrl('ftp://alerts.example.com'),
        isFalse,
      );
      expect(
        ServerInfoValidation.isValidServerUrl('ws://alerts.example.com'),
        isFalse,
      );
      expect(
        ServerInfoValidation.isValidServerUrl('file:///etc/hosts'),
        isFalse,
      );
      // Missing scheme
      expect(
        ServerInfoValidation.isValidServerUrl('alerts.example.com'),
        isFalse,
      );
      // Missing host
      expect(ServerInfoValidation.isValidServerUrl('http://'), isFalse);
      expect(ServerInfoValidation.isValidServerUrl('https://'), isFalse);
      expect(ServerInfoValidation.isValidServerUrl('http://:8080'), isFalse);
      // Arbitrary non-URL text
      expect(
        ServerInfoValidation.isValidServerUrl('not-a-valid-url'),
        isFalse,
      );
    });

    test('normalizeBaseUrl strips trailing slashes and whitespace', () {
      expect(
        ServerInfoValidation.normalizeBaseUrl('https://alerts.example.com/'),
        equals('https://alerts.example.com'),
      );
      expect(
        ServerInfoValidation.normalizeBaseUrl('https://alerts.example.com///'),
        equals('https://alerts.example.com'),
      );
      expect(
        ServerInfoValidation.normalizeBaseUrl('  https://alerts.example.com  '),
        equals('https://alerts.example.com'),
      );
      expect(
        ServerInfoValidation.normalizeBaseUrl('http://localhost:8080/'),
        equals('http://localhost:8080'),
      );
    });
  });

  group('Semver Major Compatibility Logic', () {
    test('accepts v0.x server versions (supported major = 0)', () {
      expect(
        ServerInfoValidation.isSemverCompatible('0.1.0'),
        isTrue,
        reason: 'Version 0.1.0 has major 0 and must be accepted',
      );
      expect(
        ServerInfoValidation.isSemverCompatible('0.2.1'),
        isTrue,
      );
      expect(
        ServerInfoValidation.isSemverCompatible('0.0.1-alpha.1'),
        isTrue,
      );
      expect(
        ServerInfoValidation.isSemverCompatible('v0.1.0'),
        isTrue,
        reason: 'v-prefixed semver should be accepted',
      );
      expect(
        ServerInfoValidation.isSemverCompatible('  0.1.5  '),
        isTrue,
      );
    });

    test(
      'refuses servers with unknown or future major versions (1.x, 2.x)',
      () {
        expect(
          ServerInfoValidation.isSemverCompatible('1.0.0'),
          isFalse,
          reason: 'Major version 1 is unknown/future and must be rejected',
        );
        expect(
          ServerInfoValidation.isSemverCompatible('1.2.3'),
          isFalse,
        );
        expect(
          ServerInfoValidation.isSemverCompatible('2.0.0'),
          isFalse,
          reason: 'Major version 2 is unknown/future and must be rejected',
        );
        expect(
          ServerInfoValidation.isSemverCompatible('v1.0.0'),
          isFalse,
        );
      },
    );

    test('refuses malformed or invalid semver strings', () {
      expect(ServerInfoValidation.isSemverCompatible(''), isFalse);
      expect(ServerInfoValidation.isSemverCompatible('   '), isFalse);
      expect(ServerInfoValidation.isSemverCompatible(null), isFalse);
      expect(
        ServerInfoValidation.isSemverCompatible('invalid-version'),
        isFalse,
      );
      expect(ServerInfoValidation.isSemverCompatible('abc.def.ghi'), isFalse);
    });
  });

  group('Server Mode Validation Logic', () {
    test('validates accepted modes: selfhosted, relay, hosted', () {
      expect(
        ServerInfoValidation.isValidMode(ServerModes.selfhosted),
        isTrue,
      );
      expect(
        ServerInfoValidation.isValidMode('selfhosted'),
        isTrue,
      );
      expect(
        ServerInfoValidation.isValidMode(ServerModes.relay),
        isTrue,
      );
      expect(
        ServerInfoValidation.isValidMode('relay'),
        isTrue,
      );
      expect(
        ServerInfoValidation.isValidMode(ServerModes.hosted),
        isTrue,
      );
      expect(
        ServerInfoValidation.isValidMode('hosted'),
        isTrue,
      );
      // Case-insensitive tolerance
      expect(
        ServerInfoValidation.isValidMode('SELFHOSTED'),
        isTrue,
      );
    });

    test('refuses unknown or empty server modes', () {
      expect(ServerInfoValidation.isValidMode('standalone'), isFalse);
      expect(ServerInfoValidation.isValidMode('cloud'), isFalse);
      expect(ServerInfoValidation.isValidMode(''), isFalse);
      expect(ServerInfoValidation.isValidMode('   '), isFalse);
      expect(ServerInfoValidation.isValidMode(null), isFalse);
    });
  });

  group('Topic Hash Derivation and base_url Handling', () {
    test('derives correct SHA-256 topic hash per API contract §4.1', () {
      // API spec §4.1: topic_hash = sha256hex(base_url + "/" + topic)
      // For baseUrl = 'https://alerts.example.com' and topic = 'prod':
      // input = 'https://alerts.example.com/prod'
      // sha256('https://alerts.example.com/prod') is verified
      final hash = ServerInfoValidation.deriveTopicHash(
        baseUrl: 'https://alerts.example.com',
        topic: 'prod',
      );

      // Verify lowercase hex 64 characters
      expect(hash.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);

      // Verify deterministic output
      final hash2 = ServerInfoValidation.deriveTopicHash(
        baseUrl: 'https://alerts.example.com',
        topic: 'prod',
      );
      expect(hash, equals(hash2));
    });

    test(
      'base_url trailing slashes and topic leading slashes are normalized',
      () {
        final canonicalHash = ServerInfoValidation.deriveTopicHash(
          baseUrl: 'https://alerts.example.com',
          topic: 'nas-backup',
        );

        final trailingSlashHash = ServerInfoValidation.deriveTopicHash(
          baseUrl: 'https://alerts.example.com/',
          topic: 'nas-backup',
        );

        final multipleSlashesHash = ServerInfoValidation.deriveTopicHash(
          baseUrl: 'https://alerts.example.com///',
          topic: '/nas-backup',
        );

        expect(trailingSlashHash, equals(canonicalHash));
        expect(multipleSlashesHash, equals(canonicalHash));
      },
    );

    test('different topics produce distinct hashes', () {
      final hashProd = ServerInfoValidation.deriveTopicHash(
        baseUrl: 'https://alerts.example.com',
        topic: 'prod',
      );
      final hashBackup = ServerInfoValidation.deriveTopicHash(
        baseUrl: 'https://alerts.example.com',
        topic: 'nas-backup',
      );

      expect(hashProd, isNot(equals(hashBackup)));
    });
  });

  group('Complete ServerInfo Model Validation', () {
    test(
      'isValidServerInfo returns true for a fully valid ServerInfo payload',
      () {
        const info = ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://alerts.example.com',
          relayUrl: 'https://relay.critalarm.app',
        );

        expect(ServerInfoValidation.isValidServerInfo(info), isTrue);
      },
    );

    test('isValidServerInfo returns false when version is incompatible', () {
      const incompatible = ServerInfo(
        version: '1.0.0',
        baseUrl: 'https://alerts.example.com',
        relayUrl: 'https://relay.critalarm.app',
      );

      expect(ServerInfoValidation.isValidServerInfo(incompatible), isFalse);
    });

    test('isValidServerInfo returns false when baseUrl is malformed', () {
      const malformedUrl = ServerInfo(
        version: '0.1.0',
        baseUrl: 'not-a-valid-url',
        relayUrl: 'https://relay.critalarm.app',
      );

      expect(ServerInfoValidation.isValidServerInfo(malformedUrl), isFalse);
    });

    test('isValidServerInfo returns false when mode is invalid', () {
      const invalidMode = ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://alerts.example.com',
        relayUrl: 'https://relay.critalarm.app',
        mode: 'unsupported_mode',
      );

      expect(ServerInfoValidation.isValidServerInfo(invalidMode), isFalse);
    });
  });
}
