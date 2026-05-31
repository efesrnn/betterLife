import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'habit_selection_screen.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.enterEmailPassword),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(email: email, password: password);
        if (mounted) {
          final user = supabase.auth.currentUser;
          final isSetupComplete =
              user?.userMetadata?['is_setup_complete'] ?? false;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => isSetupComplete
                  ? const HomeScreen()
                  : const HabitSelectionScreen(),
            ),
          );
        }
      } else {
        // E-posta doğrulaması yok: kayıt sonrası doğrudan onboarding.
        await supabase.auth.signUp(email: email, password: password);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HabitSelectionScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        final message = e.message.toLowerCase().contains('rate limit')
            ? AppStrings.tooManyAttempts
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.unexpectedError),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appAccent, width: 2),
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(160, 70)),
                  ),
                  child: Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: context.appAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                Text(
                  _isLogin ? AppStrings.welcomeBack : AppStrings.startJourney,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: context.appText,
                  ),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                  controller: _emailController,
                  hintText: AppStrings.email,
                  icon: Icons.email_outlined,
                  obscureText: false,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _passwordController,
                  hintText: AppStrings.password,
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.appBorder,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            _isLogin ? AppStrings.login : AppStrings.signUp,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5),
                          ),
                  ),
                ),
                const SizedBox(height: 18),

                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? AppStrings.noAccount : AppStrings.haveAccount,
                    style: TextStyle(
                      color: context.appAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: context.appText),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: context.appSub, size: 20),
        hintText: hintText,
        hintStyle: TextStyle(color: context.appSub, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: context.appCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
