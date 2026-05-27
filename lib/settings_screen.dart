import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bg = Color(0xFF0F172A);
const Color _card = Color(0xFF1E293B);
const Color _border = Color(0xFF334155);
const Color _accent = Color(0xFF818CF8);
const Color _sub = Color(0xFF94A3B8);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username must be at least 3 characters.'), backgroundColor: Colors.red));
      return;
    }
    if (newUsername.toLowerCase() == _currentUsername.toLowerCase()) return;

    setState(() => _isLoading = true);

    try {
      final existingUser = await supabase.from('profiles').select('id').eq('username', newUsername).maybeSingle();
      if (existingUser != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This username is already taken!'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({'username': newUsername}).eq('id', user.id);
        await supabase.auth.updateUser(UserAttributes(data: {'username': newUsername}));
        setState(() => _currentUsername = newUsername);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      _passwordController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('ACCOUNT INFO'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.email_outlined, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sub)),
                        const SizedBox(height: 2),
                        Text(_email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _sectionLabel('CHANGE USERNAME'),
            const SizedBox(height: 12),
            _darkField(
              controller: _usernameController,
              label: 'New Username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: 'Save Username',
              onPressed: _isLoading ? null : _updateUsername,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 32),
            _sectionLabel('CHANGE PASSWORD'),
            const SizedBox(height: 12),
            _darkField(
              controller: _passwordController,
              label: 'New Password',
              icon: Icons.lock_outline_rounded,
              obscure: true,
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: 'Save New Password',
              onPressed: _isLoading ? null : _updatePassword,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _sub,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _sub),
        prefixIcon: Icon(icon, color: _sub, size: 20),
        filled: true,
        fillColor: _card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }

  Widget _actionButton({required String label, required VoidCallback? onPressed, required bool isLoading}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: _border,
        ),
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}