import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'friends_screen.dart'; // YENİ: Arkadaşlar sayfasını ekledik

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic> _userData = {};
  String _email = '';

  // Günlük sayaç değişkenleri
  int _dailyCount = 0;
  String _todayDateStr = '';
  // Tarih bağımsız; haftanın gün indeksi (1..7) — etiket weekdays.<n>'den çevrilir.
  int _todayWeekdayIndex = 1;

  // YENİ: Alt menüde hangi sekmede olduğumuzu tutan değişken (0: Ana Sayfa, 1: Arkadaşlar)
  int _selectedIndex = 0;

  // Bilinen alışkanlık slug'ları — i18n key'lerinde gömülü olanlar.
  // Bunlardan biri değilse "generic" anahtarına argüman olarak geçilir.
  static const _knownHabitSlugs = <String>{
    'cigarettes',
    'vapes',
    'alcohol',
    'junk_food',
    'screen_time',
  };

  @override
  void initState() {
    super.initState();
    _initDateStrings();
    _loadUserData();
    _loadDailyCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showCheckInDialog();
        }
      });
    });
  }

  void _initDateStrings() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);

    _todayDateStr = '$day / $month / $year';
    _todayWeekdayIndex = now.weekday; // 1..7 (Pazartesi..Pazar)
  }

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";

    final savedDateKey = prefs.getString('last_saved_date');

    if (savedDateKey == todayKey) {
      setState(() {
        _dailyCount = prefs.getInt('daily_count') ?? 0;
      });
    } else {
      setState(() {
        _dailyCount = 0;
      });
      await prefs.setString('last_saved_date', todayKey);
      await prefs.setInt('daily_count', 0);
    }
  }

  Future<void> _updateDailyCount(int newCount) async {
    if (newCount < 0) newCount = 0;
    setState(() {
      _dailyCount = newCount;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_count', _dailyCount);
  }

  void _loadUserData() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _email = user.email ?? '';
        _userData = user.userMetadata ?? {};
      });
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
      );
    }
  }

  // Habit metadata değeri ya bilinen bir slug ('cigarettes'), ya da
  // kullanıcının "Other..." kutusuna yazdığı serbest metindir.
  // Eski string ('Cigarettes', 'Junk Food', ...) için geriye dönük eşleme yaparız.
  String _habitSlugFromRaw(String raw) {
    final h = raw.toLowerCase().trim();
    if (h.isEmpty) return '';
    if (_knownHabitSlugs.contains(h)) return h;
    if (h.contains('cigarette')) return 'cigarettes';
    if (h.contains('vape')) return 'vapes';
    if (h.contains('alcohol')) return 'alcohol';
    if (h.contains('junk')) return 'junk_food';
    if (h.contains('screen')) return 'screen_time';
    return '';
  }

  String _getDynamicQuestion(String habitRaw) {
    final slug = _habitSlugFromRaw(habitRaw);
    if (slug.isNotEmpty) {
      return 'home.checkin.questions.$slug'.tr();
    }
    return 'home.checkin.questions.generic'.tr(namedArgs: {'habit': habitRaw});
  }

  String _getDailyLabel(String habitRaw) {
    final slug = _habitSlugFromRaw(habitRaw);
    if (slug.isNotEmpty) {
      return 'home.labels.$slug'.tr();
    }
    return 'home.labels.generic'.tr(namedArgs: {'habit': habitRaw});
  }

  void _showCheckInDialog() {
    final habit = (_userData['habit'] as String?) ?? '';
    final question = _getDynamicQuestion(habit);
    int popUpCount = 0;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                    side: const BorderSide(color: Colors.black, width: 3),
                  ),
                  backgroundColor: Colors.white,
                  title: Text(
                    'home.checkin.title'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(iconSize: 40, icon: const Icon(Icons.remove_circle_outline), onPressed: () { if (popUpCount > 0) setStateDialog(() => popUpCount--); }),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Text(popUpCount.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
                          IconButton(iconSize: 40, icon: const Icon(Icons.add_circle_outline), onPressed: () => setStateDialog(() => popUpCount++)),
                        ],
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    if (popUpCount == 0)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'home.checkin.stayed_strong'.tr(),
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    if (popUpCount > 0) ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.black, width: 2))),
                      onPressed: () { _updateDailyCount(_dailyCount + popUpCount); Navigator.pop(context); },
                      child: Text('home.checkin.save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  // YENİ: Kabul edilen arkadaşlıkları kontrol edip bildirim gösteren fonksiyon
  Future<void> _checkAcceptedFriendRequests() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Benim gönderdiğim ve durumu 'ACCEPTED' olanları bul
      final response = await supabase
          .from('friendships')
          .select()
          .eq('requester_id', myId)
          .eq('status', 'ACCEPTED');

      final prefs = await SharedPreferences.getInstance();
      // Daha önce bildirimini gösterdiğimiz arkadaşlıkların ID listesi
      List<String> notifiedIds = prefs.getStringList('notified_friendships') ?? [];

      for (var f in response) {
        final friendshipId = f['id'].toString();

        // Eğer bu arkadaşlık için daha önce bildirim GÖSTERMEDİYSEK:
        if (!notifiedIds.contains(friendshipId)) {
          // Arkadaşın ismini bulalım
          final profile = await supabase.from('profiles').select().eq('id', f['addressee_id']).maybeSingle();
          final friendName = profile != null ? profile['username'] : 'Someone';

          if (mounted) {
            // Ekranda yeşil bildirim göster
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('friends.request_accepted_notification'.tr(namedArgs: {'name': friendName})),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4), // Ekranda 4 saniye kalsın
              ),
            );
          }

          // Gördüklerimizin arasına ekleyelim ki bir dahaki girişte tekrar bildirim atmasın
          notifiedIds.add(friendshipId);
        }
      }

      // Listeyi telefona kaydet
      await prefs.setStringList('notified_friendships', notifiedIds);

    } catch (e) {
      debugPrint('Error checking friend requests: $e');
    }
  }

  // Alt menüden sekme seçildiğinde çalışacak fonksiyon
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habit = (_userData['habit'] as String?) ?? '';

    // Sekmelere göre gösterilecek ekranların listesi
    final List<Widget> screens = [
      _buildHomeTab(habit), // 0. İndeks: Ana Takvim Ekranı
      const FriendsScreen(), // 1. İndeks: Arkadaşlar Ekranı
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 30),
        title: Text('app.name'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_circle, size: 60, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    _userData['username']?.toString().toUpperCase() ?? 'common.user'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(_email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red, size: 30),
              title: Text('common.logout'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
              onTap: _logout,
            ),
          ],
        ),
      ),

      // Gövde kısmı seçilen sekmeye göre değişecek
      body: screens[_selectedIndex],

      // YENİ: Alt Menü (Bottom Navigation Bar)
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black, // Senin gönderdiğin görseldeki gibi siyah arka plan
        selectedItemColor: Colors.white, // Seçili ikon beyaz
        unselectedItemColor: Colors.grey.shade600, // Seçili olmayan ikon koyu gri
        showSelectedLabels: false, // Daha temiz bir görünüm için yazıları gizledik (sadece ikon)
        showUnselectedLabels: false,
        iconSize: 32, // İkonları biraz büyüttük
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: 'home.nav.home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: 'home.nav.friends'.tr(),
          ),
        ],
      ),
    );
  }

  // Önceki tasarladığımız Takvim ekranını temizlik açısından ayrı bir metoda aldım
  Widget _buildHomeTab(String habit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 3),
            ),
            child: Column(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 3)),
                ),
                const SizedBox(height: 20),
                Text(_todayDateStr, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(
                  'weekdays.$_todayWeekdayIndex'.tr(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_dailyCount.toString(), style: const TextStyle(fontSize: 100, height: 1, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        IconButton(iconSize: 45, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateDailyCount(_dailyCount + 1)),
                        const SizedBox(height: 10),
                        IconButton(iconSize: 45, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateDailyCount(_dailyCount - 1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_getDailyLabel(habit), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
