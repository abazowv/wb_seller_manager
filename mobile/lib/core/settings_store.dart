import 'package:shared_preferences/shared_preferences.dart';

/// Локальные настройки в shared_preferences: токен и порог низкого остатка.
class SettingsStore {
  SettingsStore(this._prefs);

  static const _tokenKey = 'auth_token';
  static const _thresholdKey = 'low_stock_threshold';
  static const defaultThreshold = 5;

  final SharedPreferences _prefs;

  static Future<SettingsStore> create() async => SettingsStore(await SharedPreferences.getInstance());

  String? get token => _prefs.getString(_tokenKey);

  Future<void> saveToken(String token) => _prefs.setString(_tokenKey, token);

  Future<void> clearToken() => _prefs.remove(_tokenKey);

  int get lowStockThreshold => _prefs.getInt(_thresholdKey) ?? defaultThreshold;

  Future<void> saveLowStockThreshold(int value) => _prefs.setInt(_thresholdKey, value);
}
