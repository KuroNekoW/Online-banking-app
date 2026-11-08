import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyBaseUrl = 'custom_base_url';
  static const String _keyRememberedIdentifier = 'remembered_identifier';
  static const String _keyHideBalance = 'hide_balance';
  static const String _keySecureAccessToken = 'access_token';
  static const String _keySecureRefreshToken = 'refresh_token';

  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateLegacyTokens();
  }

  static Future<void> _migrateLegacyTokens() async {
    final legacyAccessToken = _prefs?.getString(_keyAccessToken);
    final legacyRefreshToken = _prefs?.getString(_keyRefreshToken);
    if (legacyAccessToken != null) {
      await _secureStorage.write(key: _keySecureAccessToken, value: legacyAccessToken);
      await _prefs?.remove(_keyAccessToken);
    }
    if (legacyRefreshToken != null) {
      await _secureStorage.write(key: _keySecureRefreshToken, value: legacyRefreshToken);
      await _prefs?.remove(_keyRefreshToken);
    }
  }

  static Future<String?> getAccessToken() =>
      _secureStorage.read(key: _keySecureAccessToken);

  static Future<void> setAccessToken(String token) async {
    await _secureStorage.write(key: _keySecureAccessToken, value: token);
  }

  static Future<String?> getRefreshToken() =>
      _secureStorage.read(key: _keySecureRefreshToken);

  static Future<void> setRefreshToken(String token) async {
    await _secureStorage.write(key: _keySecureRefreshToken, value: token);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _keySecureAccessToken);
    await _secureStorage.delete(key: _keySecureRefreshToken);
    await _prefs?.remove(_keyAccessToken);
    await _prefs?.remove(_keyRefreshToken);
  }

  static String? getCustomBaseUrl() {
    return _prefs?.getString(_keyBaseUrl);
  }

  static Future<void> setCustomBaseUrl(String url) async {
    await _prefs?.setString(_keyBaseUrl, url);
  }

  static Future<void> clearCustomBaseUrl() async {
    await _prefs?.remove(_keyBaseUrl);
  }

  static String? getRememberedIdentifier() {
    return _prefs?.getString(_keyRememberedIdentifier);
  }

  static Future<void> setRememberedIdentifier(String identifier) async {
    await _prefs?.setString(_keyRememberedIdentifier, identifier);
  }

  static bool isBalanceHidden() {
    return _prefs?.getBool(_keyHideBalance) ?? false;
  }

  static Future<void> setBalanceHidden(bool hidden) async {
    await _prefs?.setBool(_keyHideBalance, hidden);
  }
}
