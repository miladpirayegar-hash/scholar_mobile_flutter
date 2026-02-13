class ApiConfig {
  // Use --dart-define=API_BASE_URL=... in production builds.
  // Defaults keep Android emulator behavior, while web defaults to localhost.
  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _webDefaultBaseUrl = 'http://localhost:8080';
  static const String _androidDefaultBaseUrl = 'http://10.0.2.2:8080';

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    const isWeb = bool.fromEnvironment('dart.library.js_interop');
    return isWeb ? _webDefaultBaseUrl : _androidDefaultBaseUrl;
  }

  // Outline extraction endpoint path.
  static const String outlineExtractPath = '/api/outline/extract';

  // Optional API key for outline extraction.
  // Leave empty and supply via secure config later.
  static const String outlineApiKey = String.fromEnvironment(
    'OUTLINE_API_KEY',
    defaultValue: '',
  );
}
