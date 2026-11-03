import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/core/config/app_environment.dart';
import 'package:naseebak_mobile/core/constants/api_endpoints.dart';

void main() {
  group('Phase 9 — Flutter Multi-Environment & Production API Security Tests', () {
    test('1. Default build-time configuration resolves secure HTTPS and WSS endpoints for com.naseebak.app', () {
      final config = ApiEndpoints.environmentConfig;

      expect(config.androidPackageName, equals('com.naseebak.app'));
      expect(ApiEndpoints.baseUrl.startsWith('https://'), isTrue);
      expect(ApiEndpoints.reverbWsUrl.startsWith('wss://'), isTrue);
      expect(config.isSecureForRelease, isTrue);
    });

    test('2. Staging and Production environments reject cleartext HTTP/WS and private/localhost IPs', () {
      const insecureHttpProd = AppEnvironmentConfig(
        environment: NaseebakEnvironment.production,
        apiBaseUrl: 'http://api.example.com/api/v1',
        reverbWsUrl: 'wss://api.example.com/app/key',
        googleServerClientId: 'web-client.apps.googleusercontent.com',
      );
      expect(insecureHttpProd.isSecureForRelease, isFalse);
      expect(insecureHttpProd.validateSecurityRequirements(), contains('HTTPS'));

      const insecureWsStaging = AppEnvironmentConfig(
        environment: NaseebakEnvironment.staging,
        apiBaseUrl: 'https://staging-api.example.com/api/v1',
        reverbWsUrl: 'ws://staging-api.example.com/app/key',
        googleServerClientId: 'web-client.apps.googleusercontent.com',
      );
      expect(insecureWsStaging.isSecureForRelease, isFalse);
      expect(insecureWsStaging.validateSecurityRequirements(), contains('WSS'));

      const localhostProd = AppEnvironmentConfig(
        environment: NaseebakEnvironment.production,
        apiBaseUrl: 'https://127.0.0.1/api/v1',
        reverbWsUrl: 'wss://api.example.com/app/key',
        googleServerClientId: 'web-client.apps.googleusercontent.com',
      );
      expect(localhostProd.isSecureForRelease, isFalse);
      expect(localhostProd.validateSecurityRequirements(), contains('Localhost or private IP'));

      const privateIpStaging = AppEnvironmentConfig(
        environment: NaseebakEnvironment.staging,
        apiBaseUrl: 'https://192.168.1.50/api/v1',
        reverbWsUrl: 'wss://staging-api.example.com/app/key',
        googleServerClientId: 'web-client.apps.googleusercontent.com',
      );
      expect(privateIpStaging.isSecureForRelease, isFalse);

      const wrongPackageProd = AppEnvironmentConfig(
        environment: NaseebakEnvironment.production,
        apiBaseUrl: 'https://api.example.com/api/v1',
        reverbWsUrl: 'wss://api.example.com/app/key',
        googleServerClientId: 'web-client.apps.googleusercontent.com',
        androidPackageName: 'com.wrong.package',
      );
      expect(wrongPackageProd.isSecureForRelease, isFalse);
      expect(wrongPackageProd.validateSecurityRequirements(), contains('com.naseebak.app'));
    });

    test('3. Valid Staging and Production HTTPS/WSS configurations pass all security gates', () {
      const validStaging = AppEnvironmentConfig(
        environment: NaseebakEnvironment.staging,
        apiBaseUrl: 'https://staging.example.com/api/v1',
        reverbWsUrl: 'wss://staging.example.com/app/reverb-staging-key?protocol=7',
        googleServerClientId: 'staging-client.apps.googleusercontent.com',
        androidPackageName: 'com.naseebak.app',
      );
      expect(validStaging.isSecureForRelease, isTrue);
      expect(validStaging.validateSecurityRequirements(), isNull);

      const validProduction = AppEnvironmentConfig(
        environment: NaseebakEnvironment.production,
        apiBaseUrl: 'https://app.example.com/api/v1',
        reverbWsUrl: 'wss://ws.example.com/app/reverb-prod-key?protocol=7',
        googleServerClientId: 'prod-client.apps.googleusercontent.com',
        androidPackageName: 'com.naseebak.app',
      );
      expect(validProduction.isSecureForRelease, isTrue);
      expect(validProduction.validateSecurityRequirements(), isNull);
    });
  });
}
