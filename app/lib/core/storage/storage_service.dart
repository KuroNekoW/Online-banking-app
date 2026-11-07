import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyBaseUrl = 'custom_base_url';
  static const String _keyRememberedIdentifier = 'remembered_identifier';
  static const String _keyHideBalance = 'hide_balance';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? getAccessToken() {
    return _prefs?.getString(_keyAccessToken);
  }

  static Future<void> setAccessToken(String token) async {
    await _prefs?.setString(_keyAccessToken, token);
  }

  static String? getRefreshToken() {
    return _prefs?.getString(_keyRefreshToken);
  }

  static Future<void> setRefreshToken(String token) async {
    await _prefs?.setString(_keyRefreshToken, token);
  }

  static Future<void> clearTokens() async {
    await _prefs?.remove(_keyAccessToken);
    await _prefs?.remove(_keyRefreshToken);
  }

  static String? getCustomBaseUrl() {
    return _prefs?.getString(_keyBaseUrl);
  }

  static Future<void> setCustomBaseUrl(String url) async {
    await _prefs?.setString(_keyBaseUrl, url);
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
