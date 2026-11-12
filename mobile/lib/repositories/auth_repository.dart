import '../core/api_client.dart';
import '../core/settings_store.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._settings);

  final ApiClient _api;
  final SettingsStore _settings;

  bool get hasToken => _settings.token != null;

  Stream<void> get onUnauthorized => _api.onUnauthorized;

  Future<User> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', data: {'email': email, 'password': password}) as Map<String, dynamic>;
    return _saveSession(data);
  }

  Future<User> register({required String name, required String email, required String password}) async {
    final data = await _api.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    ) as Map<String, dynamic>;
    return _saveSession(data);
  }

  /// Текущий пользователь по сохранённому токену.
  Future<User> me() async {
    final data = await _api.get('/auth/me') as Map<String, dynamic>;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => _settings.clearToken();

  Future<User> _saveSession(Map<String, dynamic> data) async {
    await _settings.saveToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}
