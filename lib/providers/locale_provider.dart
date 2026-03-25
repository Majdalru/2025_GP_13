import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  /// ⭐ مهم جدًا للصوت
  bool get isArabic => _locale?.languageCode == 'ar';
  bool get isEnglish => _locale?.languageCode == 'en';

  /// ⭐ يفيدنا كثير في المقارنات
  String get currentLanguageCode => _locale?.languageCode ?? 'en';

  LocaleProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code');

    if (languageCode != null) {
      _locale = Locale(languageCode);
    } else {
      /// ⭐ default language
      _locale = const Locale('en');
    }

    notifyListeners();
  }

  Future<void> setLocale(Locale loc) async {
    if (!['en', 'ar'].contains(loc.languageCode)) return;

    _locale = loc;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', loc.languageCode);
  }

  /// ⭐ أسهل للاستخدام
  Future<void> setArabic() async {
    await setLocale(const Locale('ar'));
  }

  Future<void> setEnglish() async {
    await setLocale(const Locale('en'));
  }

  /// ⭐ لو تبغون toggle
  Future<void> toggleLanguage() async {
    if (isArabic) {
      await setEnglish();
    } else {
      await setArabic();
    }
  }

  Future<void> clearLocale() async {
    _locale = const Locale('en');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
  }
}