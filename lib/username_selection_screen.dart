import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart'; // Ana sayfa yönlendirmesi için

class UsernameSelectionScreen extends StatefulWidget {
  final String selectedHabit;
  final String selectedGoal;

  const UsernameSelectionScreen({
    super.key,
    required this.selectedHabit,
    required this.selectedGoal,
  });

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
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

  // Ok tuşuna basıldığında çalışacak Supabase Kayıt Fonksiyonu
  Future<void> _saveUsernameAndProceed() async {
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      // 1. Auth Metadata'ya kaydediyoruz (Kendi yerel işlemleri için)
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'habit': widget.selectedHabit,
            'goal': widget.selectedGoal,
            'is_setup_complete': true, // Kurulum bitti işareti
          },
        ),
      );

      // 2. Takım arkadaşının kurduğu public.profiles tablosuna kaydediyoruz!
      // (Böylece Discover sayfasında diğer insanlar bizi bulabilecek)
      await supabase.from('profiles').upsert({
        'id': user.id, // Kullanıcının benzersiz ID'si
        'username': username,
        'habit': widget.selectedHabit,
        'goal': widget.selectedGoal,
      });

      // 3. İşlem başarılıysa Ana Ekrana (Home) geçiş yap
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('username_setup.save_error'.tr()), backgroundColor: Colors.red),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'username_setup.title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  onChanged: (text) {
                    setState(() {
                      // Takım arkadaşının yazdığı kurala göre isim en az 3 harf olmalı
                      _isReadyToProceed = text.trim().length >= 3;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'username_setup.hint'.tr(),
                    hintStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'username_setup.min_chars'.tr(),
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : IconButton(
                iconSize: 60,
                icon: const Icon(Icons.arrow_circle_right_outlined),
                color: _isReadyToProceed ? Colors.red : Colors.grey.shade300,
                onPressed: _isReadyToProceed ? _saveUsernameAndProceed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
