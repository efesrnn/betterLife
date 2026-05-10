import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'habit_selection_screen.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Bu değişken true ise Login, false ise Sign Up ekranı gösterilir
  bool _isLogin = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Supabase bağlantımızı alıyoruz
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Giriş Yapma / Kayıt Olma Fonksiyonu
  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Supabase Giriş İşlemi
        await supabase.auth.signInWithPassword(email: email, password: password);
      } else {
        // Supabase Kayıt İşlemi
        await supabase.auth.signUp(email: email, password: password);
      }

      if (mounted) {
        // İşlem başarılı olduktan sonra kullanıcının verilerini (metadata) çekiyoruz
        final user = supabase.auth.currentUser;
        final isSetupComplete = user?.userMetadata?['is_setup_complete'] ?? false;

        // Akıllı Yönlendirme (Auth Gate mantığı)
        if (isSetupComplete) {
          // Eğer önceden kurulumu tamamlamış (is_setup_complete: true) biriyse doğrudan Ana Sayfaya at
          Navigator.pushReplacement(
            context,
            // BURASI DEĞİŞTİ: DummyHomeScreen yerine HomeScreen yazıyoruz
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // Yeni kayıt olmuşsa veya kurulumu yarım bırakmışsa en baştan Alışkanlık seçimine at
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HabitSelectionScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      // Supabase'den gelen hatalar (örn: yanlış şifre)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      // Diğer hatalar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Oval "Better Life" Logosu
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 3),
                    borderRadius: const BorderRadius.all(Radius.elliptical(150, 70)),
                  ),
                  child: const Text(
                    'Better Life',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // 2. Başlık Metni
                Text(
                  _isLogin ? 'WELCOME BACK' : 'START YOUR JOURNEY',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),

                // 3. Email Kutusu
                _buildTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                  obscureText: false,
                ),
                const SizedBox(height: 20),

                // 4. Şifre Kutusu
                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 40),

                // 5. Giriş / Kayıt Butonu
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // Siyah buton
                      foregroundColor: Colors.white, // Beyaz yazı
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0), // Tasarımımıza uygun köşeli
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _isLogin ? 'LOGIN' : 'SIGN UP',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Sayfa Değiştirme Butonu (Login <-> Sign up)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin; // Modu değiştir
                    });
                  },
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign up here."
                        : "Already have an account? Login here.",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tasarımımıza uygun kalın çerçeveli TextField oluşturan yardımcı widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black87),
          hintText: hintText,
          hintStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}