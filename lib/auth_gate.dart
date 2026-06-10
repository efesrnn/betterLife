import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'auth_screen.dart';
import 'habit_selection_screen.dart';
import 'home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Supabase oturumunu kontrol et
    final session = Supabase.instance.client.auth.currentSession;

    // Yüklenme efekti görünsün diye çok kısa bir gecikme
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (session != null) {
      // E-posta doğrulaması kaldırıldı: oturum varsa doğrudan devam.
      final isSetupComplete =
          session.user.userMetadata?['is_setup_complete'] ?? false;
      if (isSetupComplete) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HabitSelectionScreen()));
      }
    } else {
      // Hiç giriş yapmamış -> Login Ekranına
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Oturum kontrol edilirken gösterilen, temaya uyumlu yükleme ekranı
    return Scaffold(
      backgroundColor: context.appBg,
      body: Center(
        child: CircularProgressIndicator(color: context.appAccent),
      ),
    );
  }
}