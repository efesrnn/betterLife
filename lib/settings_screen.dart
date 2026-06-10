import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'developer_settings_screen.dart';
import 'theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _email = '';
  String _currentUsername = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentInfo();
  }

  void _loadCurrentInfo() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? '';
        _currentUsername = user.userMetadata?['username'] ?? '';
        _usernameController.text = _currentUsername;
      });
    }
  }

  Future<void> _updateUsername() async {
    var newUsername = _usernameController.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (newUsername.length > 24) newUsername = newUsername.substring(0, 24);
    if (newUsername.length < 3) {
      _snack(AppStrings.usernameMin3, isError: true);
      return;
    }
    if (newUsername.toLowerCase() == _currentUsername.toLowerCase()) return;

    setState(() => _isLoading = true);
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', newUsername)
          .maybeSingle();
      if (existing != null) {
        _snack(AppStrings.usernameTaken, isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({'username': newUsername}).eq('id', user.id);
        await supabase.auth.updateUser(UserAttributes(data: {'username': newUsername}));
        setState(() => _currentUsername = newUsername);
        _snack(AppStrings.usernameUpdated);
      }
    } catch (e) {
      _snack(AppStrings.errorWith(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      _snack(AppStrings.passwordMin6, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      _passwordController.clear();
      _snack(AppStrings.passwordUpdated);
    } catch (e) {
      _snack(AppStrings.errorWith(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : context.appAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        title: Text(AppStrings.settings,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(AppStrings.appearance),
            const SizedBox(height: 12),
            _themeToggleTile(),
            const SizedBox(height: 32),

            _sectionLabel(AppStrings.languageLabel),
            const SizedBox(height: 12),
            _languageTile(),
            const SizedBox(height: 32),

            _sectionLabel(AppStrings.accountInfo),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(14),
                
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.appAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.email_outlined,
                        color: context.appAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.emailAddress,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.appSub)),
                        const SizedBox(height: 2),
                        Text(_email,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.appText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _sectionLabel(AppStrings.changeUsername),
            const SizedBox(height: 12),
            _field(_usernameController, AppStrings.newUsername,
                Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _actionButton(
                AppStrings.saveUsername, _isLoading ? null : _updateUsername),
            const SizedBox(height: 32),

            _sectionLabel(AppStrings.changePassword),
            const SizedBox(height: 12),
            _field(_passwordController, AppStrings.newPassword,
                Icons.lock_outline_rounded,
                obscure: true),
            const SizedBox(height: 12),
            _actionButton(AppStrings.saveNewPassword,
                _isLoading ? null : _updatePassword),
            const SizedBox(height: 32),

            _sectionLabel(AppStrings.developerSettings.toUpperCase()),
            const SizedBox(height: 12),
            _developerTile(),
          ],
        ),
      ),
    );
  }

  // Gelistirici araclarina (merge, katalog duzenleme) gecis satiri
  Widget _developerTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeveloperSettingsScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: context.appAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.code_rounded,
                  color: context.appAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.developerSettings,
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(AppStrings.developerSettingsDesc,
                      style: TextStyle(color: context.appSub, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appSub),
          ],
        ),
      ),
    );
  }

  Widget _themeToggleTile() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.notifier,
      builder: (ctx, mode, child) {
        final isDark = mode == ThemeMode.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: context.appAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: context.appAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.theme,
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(isDark ? AppStrings.darkMode : AppStrings.lightMode,
                        style: TextStyle(color: context.appSub, fontSize: 12)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDark,
                onChanged: (v) => ThemeService.instance.toggle(),
                activeThumbColor: context.appAccent,
                activeTrackColor: context.appAccent.withAlpha(80),
                inactiveThumbColor: context.appSub,
                inactiveTrackColor: context.appBorder,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _languageTile() {
    final isTr = context.locale.languageCode == 'tr';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.appAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.language_rounded,
                color: context.appAccent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(AppStrings.language,
                style: TextStyle(
                    color: context.appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          _langPill(AppStrings.turkish, isTr,
              () => context.setLocale(const Locale('tr'))),
          const SizedBox(width: 8),
          _langPill(AppStrings.english, !isTr,
              () => context.setLocale(const Locale('en'))),
        ],
      ),
    );
  }

  Widget _langPill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.appAccent : context.appBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? context.appAccent : context.appBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.appSub,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: context.appSub,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: context.appText, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.appSub, fontSize: 13),
        prefixIcon: Icon(icon, color: context.appSub, size: 18),
        filled: true,
        fillColor: context.appCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.appAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: context.appBorder,
          elevation: 0,
        ),
        onPressed: onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}