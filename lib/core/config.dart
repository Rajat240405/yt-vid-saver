class AppConfig {
  /// Base URL for the backend API.
  /// Override with:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
  ///
  /// Default points to Android emulator host loopback.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  /// Polling interval in milliseconds
  static const int pollIntervalMs = 1000;

  /// Default subject to send with download requests
  static const String defaultSubject = 'Study';
}
