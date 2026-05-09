import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsernameSelectionScreen extends StatefulWidget {
  const UsernameSelectionScreen({super.key});

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

  // Ok tuşuna basıldığında çalışacak fonksiyon
  Future<void> _saveUsernameAndProceed() async {
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1. Kullanıcı adını Supabase'de Auth Metadata içine kaydediyoruz
      await supabase.auth.updateUser(
        UserAttributes(
          data: {'username': username},
        ),
      );

      // 2. İşlem başarılıysa uygulamanın "Ana Ekranına" (Home) geçiş yap
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DummyHomeScreen()),
              (route) => false, // Geri tuşuyla buralara tekrar dönülmesini engeller
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred.'), backgroundColor: Colors.red),
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
        iconTheme: const IconThemeData(color: Colors.black), // Geri tuşu
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Başlık
              const Text(
                'WHAT SHOULD WE\nCALL YOU?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 50),

              // 2. Kullanıcı Adı Giriş Kutusu (Tasarıma uygun kalın çerçeveli)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center, // Yazıyı ortalıyoruz
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  onChanged: (text) {
                    setState(() {
                      // En az 3 harf girilmeden ok tuşu aktifleşmesin
                      _isReadyToProceed = text.trim().length >= 3;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter username...',
                    hintStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Küçük bir bilgi notu
              const Text(
                "You need at least 3 characters.",
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 60),

              // 3. İleri Ok Butonu VEYA Yükleniyor İkonu
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : IconButton(
                iconSize: 60,
                icon: const Icon(Icons.arrow_circle_right_outlined),
                // En az 3 harf varsa kırmızı, yoksa gri
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

// Yeni Geçici Ana Sayfa (Tüm kayıt işlemleri bittikten sonra gelinecek son nokta)
class DummyHomeScreen extends StatelessWidget {
  const DummyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Better Life Dashboard', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Geri tuşunu kaldırır
      ),
      body: const Center(
        child: Text(
          'Kurulum Tamamlandı!\nArtık uygulamanın ana sayfasındasın.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}