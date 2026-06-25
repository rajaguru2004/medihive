class TokenManager {
  TokenManager._();

  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;

  static bool get isAuthenticated => _accessToken != null;

  static void setTokens({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  static void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}
