import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter email and password.'),
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
          final emailConfirmed = user?.emailConfirmedAt != null;
          if (!emailConfirmed) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(email: email),
              ),
            );
            return;
          }
          final isSetupComplete = user?.userMetadata?['is_setup_complete'] ?? false;
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
        await supabase.auth.signUp(email: email, password: password);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        final message = e.message.toLowerCase().contains('rate limit')
            ? 'Too many attempts. Please wait a few minutes and try again.'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('An unexpected error occurred.'),
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
                    'Better Life',
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
                  _isLogin ? 'WELCOME BACK' : 'START YOUR JOURNEY',
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
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                  obscureText: false,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Password',
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
                            _isLogin ? 'LOGIN' : 'SIGN UP',
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
                    _isLogin
                        ? "Don't have an account? Sign up here."
                        : "Already have an account? Login here.",
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

// ─── Email Verification Screen ────────────────────────────────────────────────

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final supabase = Supabase.instance.client;
  Timer? _pollTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await supabase.auth.refreshSession();
        final user = supabase.auth.currentUser;
        if (user?.emailConfirmedAt != null && mounted) {
          _pollTimer?.cancel();
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
      } catch (_) {}
    });
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;
    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Verification email resent to ${widget.email}'),
          backgroundColor: supabase.auth.currentUser != null
              ? Colors.green
              : Colors.redAccent,
        ));
      }
      setState(() => _resendCooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to resend: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _goBack() async {
    _pollTimer?.cancel();
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.appAccent.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_rounded,
                      size: 40, color: context.appAccent),
                ),
                const SizedBox(height: 32),
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: context.appText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.appSub),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the link in the email to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.appSub),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: context.appAccent,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _resendCooldown > 0 ? null : _resendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.appBorder,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend Email',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _goBack,
                  icon: Icon(Icons.arrow_back_rounded,
                      size: 16, color: context.appSub),
                  label: Text(
                    'Wrong email? Go back',
                    style: TextStyle(
                        color: context.appSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}