/// Конфигурация Strapi API
class StrapiConfig {
  /// URL базового API Strapi
  /// Для локальной разработки: http://localhost:1337
  /// Для Android эмулятора: http://10.0.2.2:1337
  /// Для iOS симулятора: http://localhost:1337
  static const String baseUrl = 'http://192.168.0.104:1337';
  
  /// URL для API endpoints
  static const String apiUrl = '$baseUrl/api';
  
  /// URL для загруженных файлов (медиа)
  static const String mediaUrl = baseUrl;
  
  /// Endpoints
  static const String authRegister = '$apiUrl/auth/local/register';
  static const String authLogin = '$apiUrl/auth/local';
  static const String usersMe = '$apiUrl/users/me';  // GET + PUT
  static const String users = '$apiUrl/users';
  static const String beats = '$apiUrl/beats';
  static const String genres = '$apiUrl/genres';
  static const String tags = '$apiUrl/tags';
  static const String beatFiles = '$apiUrl/beat-files';
  static const String purchases = '$apiUrl/purchases';
  static const String wallets = '$apiUrl/wallets';
  static const String walletEntries = '$apiUrl/wallet-entries';
  static const String chats = '$apiUrl/chats';
  static const String messages = '$apiUrl/messages';
  
  /// WebSocket URL (порт 1338 рядом со Strapi на 1337)
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}:1338';
  }
  
  /// Получить полный URL для медиа файла
  static String? getMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$mediaUrl$path';
  }
}
