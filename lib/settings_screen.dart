import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
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
    final newUsername = _usernameController.text.trim();
    if (newUsername.length < 3) {
      _snack('Username must be at least 3 characters.', isError: true);
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
        _snack('This username is already taken!', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({'username': newUsername}).eq('id', user.id);
        await supabase.auth.updateUser(UserAttributes(data: {'username': newUsername}));
        setState(() => _currentUsername = newUsername);
        _snack('Username updated!');
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      _snack('Password must be at least 6 characters.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      _passwordController.clear();
      _snack('Password updated!');
    } catch (e) {
      _snack('Error: $e', isError: true);
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
        title: Text('Settings',
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
            _sectionLabel('APPEARANCE'),
            const SizedBox(height: 12),
            _themeToggleTile(),
            const SizedBox(height: 32),

            _sectionLabel('ACCOUNT INFO'),
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
                        Text('Email Address',
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

            _sectionLabel('CHANGE USERNAME'),
            const SizedBox(height: 12),
            _field(_usernameController, 'New Username', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _actionButton('Save Username', _isLoading ? null : _updateUsername),
            const SizedBox(height: 32),

            _sectionLabel('CHANGE PASSWORD'),
            const SizedBox(height: 12),
            _field(_passwordController, 'New Password', Icons.lock_outline_rounded, obscure: true),
            const SizedBox(height: 12),
            _actionButton('Save New Password', _isLoading ? null : _updatePassword),
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
                    Text('Theme',
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(isDark ? 'Dark mode' : 'Light mode',
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