import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'habit_selection_screen.dart';
import 'home_screen.dart';
// EmailVerificationScreen auth_screen.dart içinde tanımlı

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
      final user = session.user;
      final emailConfirmed = user.emailConfirmedAt != null;

      if (!emailConfirmed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: user.email ?? ''),
          ),
        );
        return;
      }

      final isSetupComplete = user.userMetadata?['is_setup_complete'] ?? false;
      if (isSetupComplete) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HabitSelectionScreen()));
      }
    } else {
      // Hiç giriş yapmamış -> Login Ekranına
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kontrol yapılırken ekranda görünecek siyah yükleniyor ikonu
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }
}