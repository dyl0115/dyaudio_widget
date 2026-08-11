import 'package:shared_preferences/shared_preferences.dart';

class ListnrCredentials {
  final String baseUrl;
  final String username;
  final String password;

  ListnrCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });
}

class ListnrPrefs {
  static const _kBaseUrl = 'listnr_base_url';
  static const _kUsername = 'listnr_username';
  static const _kPassword = 'listnr_password';

  static Future<void> save({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    await prefs.setString(_kBaseUrl, normalized);
    await prefs.setString(_kUsername, username);
    await prefs.setString(_kPassword, password);
  }

  static Future<ListnrCredentials?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_kBaseUrl);
    final username = prefs.getString(_kUsername);
    final password = prefs.getString(_kPassword);
    if (baseUrl == null || baseUrl.isEmpty || username == null || password == null) {
      return null;
    }
    return ListnrCredentials(baseUrl: baseUrl, username: username, password: password);
  }
}
