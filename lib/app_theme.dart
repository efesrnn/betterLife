import 'package:flutter/material.dart';

// Koyu tema paleti - antrasit gri zemin ve yesil vurgu
const _dBg     = Color(0xFF181818);
const _dCard   = Color(0xFF252525);
const _dBorder = Color(0xFF333333);
const _dAccent = Color(0xFF22C55E);
const _dSub    = Color(0xFF888888);
const _dText   = Color(0xFFFFFFFF);
const _dTextDim= Color(0xFF666666);

// Acik tema paleti - acik gri zemin, beyaz kartlar ve yesil vurgu
const _lBg     = Color(0xFFF0F0F0);
const _lCard   = Color(0xFFFFFFFF);
const _lBorder = Color(0xFFE0E0E0);
const _lAccent = Color(0xFF16A34A);
const _lSub    = Color(0xFF9E9E9E);
const _lText   = Color(0xFF1A1A1A);
const _lTextDim= Color(0xFF757575);

class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _dBg,
    colorScheme: const ColorScheme.dark(
      primary: _dAccent,
      surface: _dCard,
      outline: _dBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _dBg,
      foregroundColor: _dText,
      elevation: 0,
      iconTheme: IconThemeData(color: _dText),
      titleTextStyle: TextStyle(
          color: _dText, fontWeight: FontWeight.w700, fontSize: 18),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _dCard,
      selectedItemColor: _dAccent,
      unselectedItemColor: _dSub,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      type: BottomNavigationBarType.fixed,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: _dBg),
    dividerColor: _dBorder,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _dAccent : _dSub),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _dAccent.withAlpha(80) : _dBorder),
    ),
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lBg,
    colorScheme: const ColorScheme.light(
      primary: _lAccent,
      surface: _lCard,
      outline: _lBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lBg,
      foregroundColor: _lText,
      elevation: 0,
      iconTheme: IconThemeData(color: _lText),
      titleTextStyle: TextStyle(
          color: _lText, fontWeight: FontWeight.w700, fontSize: 18),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _lCard,
      selectedItemColor: _lAccent,
      unselectedItemColor: _lSub,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      type: BottomNavigationBarType.fixed,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: _lBg),
    dividerColor: _lBorder,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _lAccent : _lSub),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _lAccent.withAlpha(80) : _lBorder),
    ),
  );
}

extension AppColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBg      => isDarkMode ? _dBg      : _lBg;
  Color get appCard    => isDarkMode ? _dCard    : _lCard;
  Color get appBorder  => isDarkMode ? _dBorder  : _lBorder;
  Color get appAccent  => isDarkMode ? _dAccent  : _lAccent;
  Color get appSub     => isDarkMode ? _dSub     : _lSub;
  Color get appText    => isDarkMode ? _dText    : _lText;
  Color get appTextDim => isDarkMode ? _dTextDim : _lTextDim;
}