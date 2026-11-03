enum NaseebakEnvironment {
  development,
  staging,
  production;

  static NaseebakEnvironment fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dev':
      case 'development':
      case 'local':
        return NaseebakEnvironment.development;
      case 'stage':
      case 'staging':
        return NaseebakEnvironment.staging;
      case 'prod':
      case 'production':
      default:
        return NaseebakEnvironment.production;
    }
  }

  bool get isProduction => this == NaseebakEnvironment.production;
  bool get isStaging => this == NaseebakEnvironment.staging;
  bool get isDevelopment => this == NaseebakEnvironment.development;
  bool get requiresStrictTls => isProduction || isStaging;
}

class AppEnvironmentConfig {
  final NaseebakEnvironment environment;
  final String apiBaseUrl;
  final String reverbWsUrl;
  final String googleServerClientId;
  final String androidPackageName;

  const AppEnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.reverbWsUrl,
    required this.googleServerClientId,
    this.androidPackageName = 'com.naseebak.app',
  });

  /// Resolves build-time `--dart-define` configuration without hardcoding
  /// localhost or private development IPs in staging/production builds.
  factory AppEnvironmentConfig.fromBuildDefines() {
    const rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'production');
    final env = NaseebakEnvironment.fromName(rawEnv);

    const definedApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const definedWsUrl = String.fromEnvironment('REVERB_WS_URL', defaultValue: '');
    const definedReverbKey = String.fromEnvironment(
      'REVERB_APP_KEY',
      defaultValue: 'naseebak-reverb-key',
    );
    const definedGoogleClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );
    const definedPackage = String.fromEnvironment(
      'ANDROID_PACKAGE_NAME',
      defaultValue: 'com.naseebak.app',
    );

    final resolvedApiUrl = definedApiUrl.isNotEmpty
        ? definedApiUrl
        : switch (env) {
            NaseebakEnvironment.development => 'https://dev-api.example.com/api/v1',
            NaseebakEnvironment.staging => 'https://staging-api.example.com/api/v1',
            NaseebakEnvironment.production => 'https://api.example.com/api/v1',
          };

    final resolvedWsUrl = definedWsUrl.isNotEmpty
        ? definedWsUrl
        : switch (env) {
            NaseebakEnvironment.development =>
              'wss://dev-api.example.com/app/$definedReverbKey?protocol=7&client=flutter&version=1.0',
            NaseebakEnvironment.staging =>
              'wss://staging-api.example.com/app/$definedReverbKey?protocol=7&client=flutter&version=1.0',
            NaseebakEnvironment.production =>
              'wss://api.example.com/app/$definedReverbKey?protocol=7&client=flutter&version=1.0',
          };

    return AppEnvironmentConfig(
      environment: env,
      apiBaseUrl: resolvedApiUrl,
      reverbWsUrl: resolvedWsUrl,
      googleServerClientId: definedGoogleClientId,
      androidPackageName: definedPackage,
    );
  }

  /// Validates that Staging and Production configurations strictly use HTTPS and WSS
  /// and never point to localhost, loopback, emulator, or RFC1918 private IPs.
  String? validateSecurityRequirements() {
    if (androidPackageName != 'com.naseebak.app') {
      return 'Android package identifier must be com.naseebak.app.';
    }

    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || apiUri.host.isEmpty) {
      return 'Invalid API_BASE_URL format.';
    }

    final wsUri = Uri.tryParse(reverbWsUrl);
    if (wsUri == null || wsUri.host.isEmpty) {
      return 'Invalid REVERB_WS_URL format.';
    }

    if (environment.requiresStrictTls) {
      if (apiUri.scheme.toLowerCase() != 'https') {
        return 'Staging and Production builds require HTTPS for API_BASE_URL.';
      }
      if (wsUri.scheme.toLowerCase() != 'wss') {
        return 'Staging and Production builds require WSS for REVERB_WS_URL.';
      }
      if (_isLocalOrPrivateHost(apiUri.host)) {
        return 'Localhost or private IP addresses are forbidden in Staging/Production API_BASE_URL (${apiUri.host}).';
      }
      if (_isLocalOrPrivateHost(wsUri.host)) {
        return 'Localhost or private IP addresses are forbidden in Staging/Production REVERB_WS_URL (${wsUri.host}).';
      }
    }

    return null;
  }

  bool get isSecureForRelease => validateSecurityRequirements() == null;

  static bool _isLocalOrPrivateHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized == '::1' ||
        normalized == '10.0.2.2' ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.localhost')) {
      return true;
    }

    if (RegExp(r'^10\.').hasMatch(normalized) ||
        RegExp(r'^192\.168\.').hasMatch(normalized) ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(normalized)) {
      return true;
    }

    return false;
  }
}
