import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'home_screen.dart';

class UsernameSelectionScreen extends StatefulWidget {
  final String selectedHabit;
  final String selectedGoal;

  const UsernameSelectionScreen({
    super.key,
    required this.selectedHabit,
    required this.selectedGoal,
  });

  @override
  State<UsernameSelectionScreen> createState() =>
      _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isReadyToProceed = false;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Onboarding'deki habit adını seed slug'ına eşler (bilinmiyorsa null).
  String? _slugForHabit(String name) {
    final n = name.toLowerCase();
    if (n.contains('cigaret') || n.contains('sigara') || n.contains('vape')) {
      return 'smoking_cessation';
    }
    if (n.contains('alcohol') || n.contains('alkol')) return 'alcohol_cessation';
    if (n.contains('junk') || n.contains('fast') || n.contains('food')) {
      return 'fast_food_cessation';
    }
    if (n.contains('screen') ||
        n.contains('ekran') ||
        n.contains('media') ||
        n.contains('medya')) {
      return 'social_media_reduction';
    }
    return null;
  }

  // Hedef metnini program tipine eşler.
  String _programForGoal(String goal) {
    final g = goal.toLowerCase();
    if (g.contains('kademeli') || g.contains('step') || g.contains('adım')) {
      return 'GRADUAL_DECREASE';
    }
    if (g.contains('azalt') || g.contains('reduce') || g.contains('%')) {
      return 'REDUCE';
    }
    return 'QUIT';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _saveUsernameAndProceed() async {
    // DB kuralı: username sadece [a-z0-9_], 3-24 karakter olmalı.
    // Büyük harf/boşluk/Türkçe karakterleri güvenli biçime çevir.
    var username = _usernameController.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (username.length > 24) username = username.substring(0, 24);

    if (username.length < 3) {
      _snack(AppStrings.usernameMinChars);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      // Kullanıcı adı benzersizlik kontrolü (başkası almış mı?)
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', user.id)
          .maybeSingle();
      if (existing != null) {
        _snack(AppStrings.usernameTaken);
        setState(() => _isLoading = false);
        return;
      }

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'habit': widget.selectedHabit,
            'goal': widget.selectedGoal,
            'is_setup_complete': true,
          },
        ),
      );

      // display_name de yazılıyor (spec gereği boş bırakılmamalı)
      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'display_name': username,
        'habit': widget.selectedHabit,
        'goal': widget.selectedGoal,
      });

      // Birincil habit'i user_habits'e ekle ki Home'da (çok-habit) görünsün.
      // Eşleşme yoksa / hata olursa sessizce atla (Habits sekmesinden eklenebilir).
      try {
        final slug = _slugForHabit(widget.selectedHabit);
        if (slug != null) {
          final h = await supabase
              .from('habits')
              .select('id, default_start_value')
              .eq('slug', slug)
              .maybeSingle();
          if (h != null) {
            await supabase.from('user_habits').insert({
              'user_id': user.id,
              'habit_id': h['id'],
              'program_type': _programForGoal(widget.selectedGoal),
              'start_value': (h['default_start_value'] as num?)?.toDouble(),
            });
          }
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppStrings.whatShouldWeCallYou,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: context.appText,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appBorder, width: 1.5),
                ),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  cursorColor: context.appAccent,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.appText,
                  ),
                  onChanged: (text) {
                    setState(() {
                      _isReadyToProceed = text.trim().length >= 3;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.enterUsername,
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.appSub,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.usernameMinChars,
                style: TextStyle(
                  color: context.appSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),
              _isLoading
                  ? CircularProgressIndicator(color: context.appAccent)
                  : IconButton(
                      iconSize: 60,
                      icon: const Icon(Icons.arrow_circle_right_rounded),
                      color: _isReadyToProceed
                          ? context.appAccent
                          : context.appBorder,
                      onPressed:
                          _isReadyToProceed ? _saveUsernameAndProceed : null,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
