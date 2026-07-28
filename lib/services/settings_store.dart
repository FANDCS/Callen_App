import 'package:shared_preferences/shared_preferences.dart';

/// Απλή, τοπική αποθήκευση ρυθμίσεων (θέμα εμφάνισης + χειροκίνητη
/// ρύθμιση server συγχρονισμού). Δεν κάνει καθόλου δίκτυο ακόμα — απλά
/// κρατάει ό,τι βάλει ο χρήστης, ώστε να είναι έτοιμο όταν φτιαχτεί το
/// πραγματικό sync engine (OneDrive Graph API / Redis).
class SettingsStore {
  static const _keyThemeMode = 'theme_mode';
  static const _keyLanguage = 'language'; // 'system' | 'el' | 'en'
  static const _keyContactSources = 'contact_sources'; // JSON-ish, comma-joined
  static const _keySyncServerUrl = 'sync_server_url';
  static const _keySyncApiKey = 'sync_api_key';
  static const _keySyncEnabled = 'sync_enabled';

  final SharedPreferences _prefs;
  SettingsStore._(this._prefs);

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_keyThemeMode, value);

  String get language => _prefs.getString(_keyLanguage) ?? 'system';
  Future<void> setLanguage(String value) =>
      _prefs.setString(_keyLanguage, value);

  /// Άδεια λίστα σημαίνει "όλες οι πηγές" (καμία επιλογή = default).
  List<String> get contactSources =>
      _prefs.getStringList(_keyContactSources) ?? [];
  Future<void> setContactSources(List<String> value) =>
      _prefs.setStringList(_keyContactSources, value);

  String get syncServerUrl => _prefs.getString(_keySyncServerUrl) ?? '';
  Future<void> setSyncServerUrl(String value) =>
      _prefs.setString(_keySyncServerUrl, value);

  String get syncApiKey => _prefs.getString(_keySyncApiKey) ?? '';
  Future<void> setSyncApiKey(String value) =>
      _prefs.setString(_keySyncApiKey, value);

  bool get syncEnabled => _prefs.getBool(_keySyncEnabled) ?? false;
  Future<void> setSyncEnabled(bool value) =>
      _prefs.setBool(_keySyncEnabled, value);
}
