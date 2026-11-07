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
  final String googleAndroidClientId;
  final String androidPackageName;

  const AppEnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.reverbWsUrl,
    required this.googleServerClientId,
    this.googleAndroidClientId = '',
    this.androidPackageName = 'com.naseebak.app',
  });

  /// Resolves build-time `--dart-define` configuration without hardcoding
  /// localhost or private development IPs in staging/production builds.
  ///
  /// Debug builds safely use staging by default.
  /// Production builds strictly require explicit production configuration via `--dart-define`
  /// and fail immediately if required endpoints are missing or point to staging.
  factory AppEnvironmentConfig.fromBuildDefines() {
    const rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'staging');
    final env = NaseebakEnvironment.fromName(rawEnv);

    const definedApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const definedWsUrl = String.fromEnvironment('REVERB_WS_URL', defaultValue: '');
    const definedWsHost = String.fromEnvironment('REVERB_WS_HOST', defaultValue: '');
    const definedWsScheme = String.fromEnvironment('REVERB_WS_SCHEME', defaultValue: 'wss');
    const definedWsPort = String.fromEnvironment('REVERB_WS_PORT', defaultValue: '443');
    const definedReverbKey = String.fromEnvironment(
      'REVERB_APP_KEY',
      defaultValue: 'nsb_stg_key_sandbox',
    );
    const definedGoogleServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );
    const definedGoogleAndroidClientId = String.fromEnvironment(
      'GOOGLE_ANDROID_CLIENT_ID',
      defaultValue: '',
    );
    const definedPackage = String.fromEnvironment(
      'ANDROID_PACKAGE_NAME',
      defaultValue: 'com.naseebak.app',
    );

    // Production security assertion:
    // Production builds require explicit production configuration and CANNOT
    // silently fall back to staging or missing endpoints.
    if (env.isProduction) {
      if (definedApiUrl.isEmpty) {
        throw StateError(
          'Missing production API URL. Production builds require an explicit '
          'API_BASE_URL via --dart-define=API_BASE_URL=https://<prod-domain>/api/v1. '
          'Production builds cannot silently fall back to staging or default URLs.',
        );
      }
      if (definedApiUrl.contains('hazem.my') || definedApiUrl.contains('staging')) {
        throw StateError(
          'Production configuration error: API_BASE_URL ($definedApiUrl) points to staging. '
          'Production builds cannot use staging endpoints.',
        );
      }
      if (definedWsUrl.isEmpty && definedWsHost.isEmpty) {
        throw StateError(
          'Missing production WebSocket configuration. Production builds require an explicit '
          'REVERB_WS_URL or REVERB_WS_HOST via --dart-define. '
          'Production builds cannot silently fall back to staging.',
        );
      }
      if ((definedWsUrl.isNotEmpty && (definedWsUrl.contains('hazem.my') || definedWsUrl.contains('staging'))) ||
          (definedWsHost.isNotEmpty && (definedWsHost.contains('hazem.my') || definedWsHost.contains('staging')))) {
        throw StateError(
          'Production configuration error: WebSocket configuration points to staging. '
          'Production builds cannot use staging endpoints.',
        );
      }
    }

    final rawResolvedApiUrl = definedApiUrl.isNotEmpty
        ? definedApiUrl
        : switch (env) {
            NaseebakEnvironment.development => 'https://dev-api.example.com/api/v1',
            NaseebakEnvironment.staging => 'https://naseebak-api.hazem.my/api/v1',
            NaseebakEnvironment.production => throw StateError(
                'Missing production API URL. Production builds require explicit '
                'API_BASE_URL via --dart-define.',
              ),
          };
    final resolvedApiUrl = _normalizeApiBaseUrl(rawResolvedApiUrl);

    final resolvedWsUrl = definedWsUrl.isNotEmpty
        ? definedWsUrl
        : (definedWsHost.isNotEmpty
            ? '$definedWsScheme://$definedWsHost${definedWsPort != '443' && definedWsPort != '80' ? ':$definedWsPort' : ''}/app/$definedReverbKey?protocol=7&client=flutter&version=1.0'
            : switch (env) {
                NaseebakEnvironment.development =>
                  'wss://dev-api.example.com/app/$definedReverbKey?protocol=7&client=flutter&version=1.0',
                NaseebakEnvironment.staging =>
                  'wss://naseebak-ws.hazem.my/app/$definedReverbKey?protocol=7&client=flutter&version=1.0',
                NaseebakEnvironment.production => throw StateError(
                    'Missing production WebSocket configuration. Production builds require explicit '
                    'REVERB_WS_URL or REVERB_WS_HOST via --dart-define.',
                  ),
              });

    final resolvedServerClientId = definedGoogleServerClientId.isNotEmpty
        ? definedGoogleServerClientId
        : switch (env) {
            NaseebakEnvironment.development => '',
            NaseebakEnvironment.staging =>
              '520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo.apps.googleusercontent.com',
            NaseebakEnvironment.production =>
              '520721691788-4ngp8rrm7g4foja1f3ql24bv2apdgcoo.apps.googleusercontent.com',
          };

    final resolvedAndroidClientId = definedGoogleAndroidClientId.isNotEmpty
        ? definedGoogleAndroidClientId
        : switch (env) {
            NaseebakEnvironment.development => '',
            NaseebakEnvironment.staging =>
              '520721691788-0fki6oqjcsjtk6g9qbo2ean3fj3cpeq2.apps.googleusercontent.com',
            NaseebakEnvironment.production =>
              '520721691788-0fki6oqjcsjtk6g9qbo2ean3fj3cpeq2.apps.googleusercontent.com',
          };

    final config = AppEnvironmentConfig(
      environment: env,
      apiBaseUrl: resolvedApiUrl,
      reverbWsUrl: resolvedWsUrl,
      googleServerClientId: resolvedServerClientId,
      googleAndroidClientId: resolvedAndroidClientId,
      androidPackageName: definedPackage,
    );

    final validationError = config.validateSecurityRequirements();
    if (validationError != null) {
      throw StateError(
        'Environment configuration security validation failed: $validationError',
      );
    }

    return config;
  }

  static String _normalizeApiBaseUrl(String rawUrl) {
    var trimmed = rawUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.endsWith('/api/v1')) {
      if (trimmed.endsWith('/api')) {
        return '$trimmed/v1';
      }
      return '$trimmed/api/v1';
    }
    return trimmed;
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
      if (environment.isProduction &&
          (apiUri.host.contains('hazem.my') || wsUri.host.contains('hazem.my'))) {
        return 'Production builds cannot point to staging domains (hazem.my).';
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
