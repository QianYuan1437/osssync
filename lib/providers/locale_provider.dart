import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  String _locale = 'zh';

  String get locale => _locale;
  bool get isZh => _locale == 'zh';

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString('locale') ?? 'zh';
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    notifyListeners();
  }

  String t(String zh, String en) => _locale == 'zh' ? zh : en;
}
