import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'auth_screen.dart';
import 'friends_screen.dart';
import 'habits_screen.dart';
import 'home_habit_view.dart';
import 'settings_screen.dart';
import 'services/habit_repository.dart';
import 'services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> _userData = {};

  int _dailyCount = 0;
  String _todayDateStr = '';
  String _todayDayName = '';
  int _selectedIndex = 0;

  double _packPrice = 115.0;
  int _packSize = 20;
  int _dailyBaseline = 20;
  double _totalSaved = 0.0;
  double _lungScore = 10.0;
  String? _avatarUrl;

  DateTime _quitDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initDateStrings();
    _loadUserData();
    _checkAcceptedFriendRequests();
    _checkTwoMonthUpdateReminder();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showCheckInDialog();
      });
    });
  }

  void _initDateStrings() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().substring(2);
    _todayDateStr = '$day / $month / $year';
    const days = [
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
      'FRIDAY', 'SATURDAY', 'SUNDAY'
    ];
    _todayDayName = days[now.weekday - 1];
  }

  int _getStreak() {
    if (_dailyCount > 0) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quit = DateTime(_quitDate.year, _quitDate.month, _quitDate.day);
    final streak = today.difference(quit).inDays;
    return streak < 0 ? 0 : streak;
  }

  Future<void> _checkTwoMonthUpdateReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('last_price_update');
    if (lastUpdateStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      if (DateTime.now().difference(lastUpdate).inDays >= 60) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSettingsDialog(isReminder: true);
        });
      }
    } else {
      await prefs.setString('last_price_update', DateTime.now().toIso8601String());
    }
  }

  Future<void> _loadDailyCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final userDateKey = 'last_saved_date_$userId';
    final userCountKey = 'daily_count_$userId';
    final savedDateKey = prefs.getString(userDateKey);

    if (savedDateKey == todayKey) {
      setState(() => _dailyCount = prefs.getInt(userCountKey) ?? 0);
    } else {
      int yesterdaysCount = prefs.getInt(userCountKey) ?? 0;
      if (yesterdaysCount > 0) {
        _quitDate = DateTime(now.year, now.month, now.day);
        await prefs.setString('quit_date_$userId', _quitDate.toIso8601String());
        try {
          await supabase
              .from('profiles')
              .update({'quit_date': _quitDate.toIso8601String()}).eq('id', userId);
        } catch (_) {}
      }
      double pastTotal = _totalSaved;
      await prefs.setDouble('past_total_saved_$userId', pastTotal);
      double baseLung = _lungScore;
      await prefs.setDouble('past_lung_score_$userId', baseLung);
      setState(() => _dailyCount = 0);
      double pricePerCig = _packPrice / _packSize;
      double newLiveTotal = pastTotal + (_dailyBaseline * pricePerCig);
      await _updateTotalSaved(newLiveTotal);
      double newLiveLung = baseLung + 1.11;
      await _updateLungScore(newLiveLung);
      await prefs.setString(userDateKey, todayKey);
      await prefs.setInt(userCountKey, 0);
    }
  }

  Future<void> _updateTotalSaved(double newTotal) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _totalSaved = newTotal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_saved_${user.id}', newTotal);
    try {
      await supabase
          .from('profiles')
          .update({'total_saved': newTotal}).eq('id', user.id);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _updateLungScore(double newScore) async {
    newScore = newScore.clamp(0.0, 100.0);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _lungScore = newScore);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lung_score_${user.id}', newScore);
    try {
      await supabase
          .from('profiles')
          .update({'lung_score': newScore}).eq('id', user.id);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _updateDailyCount(int newCount) async {
    if (newCount < 0) newCount = 0;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;
    setState(() => _dailyCount = newCount);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_count_$userId', _dailyCount);
    double pastTotal = prefs.getDouble('past_total_saved_$userId') ?? 0.0;
    double pricePerCig = _packPrice / _packSize;
    double absoluteTruthTotal =
        pastTotal + ((_dailyBaseline - _dailyCount) * pricePerCig);
    await _updateTotalSaved(absoluteTruthTotal);
    double pastLung = prefs.getDouble('past_lung_score_$userId') ?? 10.0;
    double absoluteTruthLung = (pastLung + 1.11) - (_dailyCount * 25.0);
    await _updateLungScore(absoluteTruthLung);
  }

  void _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userData = user.userMetadata ?? {};
        _packPrice = prefs.getDouble('pack_price_${user.id}') ?? 115.0;
        _packSize = prefs.getInt('pack_size_${user.id}') ?? 20;
        _dailyBaseline = prefs.getInt('daily_baseline_${user.id}') ?? 20;
        _totalSaved = prefs.getDouble('total_saved_${user.id}') ?? 0.0;
        _lungScore = prefs.getDouble('lung_score_${user.id}') ?? 10.0;
        _avatarUrl = prefs.getString('avatar_url_${user.id}');
        String? quitStr = prefs.getString('quit_date_${user.id}');
        if (quitStr != null) _quitDate = DateTime.parse(quitStr);
      });
      try {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          setState(() {
            if (profile['pack_price'] != null)
              _packPrice = (profile['pack_price']).toDouble();
            if (profile['pack_size'] != null) _packSize = profile['pack_size'];
            if (profile['daily_baseline'] != null)
              _dailyBaseline = profile['daily_baseline'];
            if (profile['total_saved'] != null)
              _totalSaved = (profile['total_saved']).toDouble();
            if (profile['lung_score'] != null)
              _lungScore = (profile['lung_score']).toDouble();
            _avatarUrl = profile['avatar_url'];
            if (profile['quit_date'] != null) {
              _quitDate = DateTime.parse(profile['quit_date']);
            } else if (prefs.getString('quit_date_${user.id}') == null) {
              _quitDate = DateTime(
                  DateTime.now().year, DateTime.now().month, DateTime.now().day);
            }
          });
          await prefs.setDouble('pack_price_${user.id}', _packPrice);
          await prefs.setInt('pack_size_${user.id}', _packSize);
          await prefs.setInt('daily_baseline_${user.id}', _dailyBaseline);
          await prefs.setDouble('total_saved_${user.id}', _totalSaved);
          await prefs.setDouble('lung_score_${user.id}', _lungScore);
          await prefs.setString(
              'quit_date_${user.id}', _quitDate.toIso8601String());
          if (_avatarUrl != null) {
            await prefs.setString('avatar_url_${user.id}', _avatarUrl!);
          } else {
            await prefs.remove('avatar_url_${user.id}');
          }
        }
      } catch (e) {
        debugPrint('DB Error: $e');
      }
      if (!prefs.containsKey('past_total_saved_${user.id}')) {
        int currentDailyCount = prefs.getInt('daily_count_${user.id}') ?? 0;
        double pricePerCig = _packPrice / _packSize;
        double derivedPastTotal =
            _totalSaved - ((_dailyBaseline - currentDailyCount) * pricePerCig);
        await prefs.setDouble('past_total_saved_${user.id}', derivedPastTotal);
      }
      if (!prefs.containsKey('past_lung_score_${user.id}')) {
        int currentDailyCount = prefs.getInt('daily_count_${user.id}') ?? 0;
        double derivedPastLung =
            _lungScore - 1.11 + (currentDailyCount * 25.0);
        await prefs.setDouble('past_lung_score_${user.id}', derivedPastLung);
      }
      _loadDailyCount();
    }
  }

  Future<void> _uploadAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800, maxHeight: 800);
    if (image == null) return;
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.uploadingPhoto)));
      final bytes = await image.readAsBytes();
      final fileExtension = image.path.split('.').last;
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      await supabase.storage.from('avatars').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(upsert: true));
      final imageUrl =
          supabase.storage.from('avatars').getPublicUrl(fileName);
      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_url_${user.id}', imageUrl);
      setState(() => _avatarUrl = imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.photoUpdated),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.errorUploading(e)),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showSettingsDialog({bool isReminder = false}) {
    final priceCtrl =
        TextEditingController(text: _packPrice.toString());
    final sizeCtrl = TextEditingController(text: _packSize.toString());
    final baselineCtrl =
        TextEditingController(text: _dailyBaseline.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: ctx.appCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ctx.appBorder, width: 1.5),
          ),
          title: Text(
            isReminder ? AppStrings.priceCheck : AppStrings.cigaretteInfo,
            style: TextStyle(
                color: ctx.appText,
                fontWeight: FontWeight.w900,
                fontSize: 22),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReminder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    AppStrings.priceCheckBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: ctx.appTextDim, fontWeight: FontWeight.w600),
                  ),
                ),
              _dialogField(ctx, priceCtrl, AppStrings.packPrice,
                  Icons.monetization_on_outlined),
              const SizedBox(height: 12),
              _dialogField(ctx, sizeCtrl, AppStrings.cigsPerPack,
                  Icons.smoking_rooms_outlined),
              const SizedBox(height: 12),
              _dialogField(ctx, baselineCtrl, AppStrings.dailyCigs,
                  Icons.bar_chart_rounded),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctx.appAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final user = supabase.auth.currentUser;
                  if (user != null) {
                    String priceText =
                        priceCtrl.text.replaceAll(',', '.');
                    double newPrice = double.tryParse(priceText) ?? 115.0;
                    int newSize = int.tryParse(sizeCtrl.text) ?? 20;
                    int newBaseline =
                        int.tryParse(baselineCtrl.text) ?? 20;
                    final prefs = await SharedPreferences.getInstance();
                    double pastTotal =
                        prefs.getDouble('past_total_saved_${user.id}') ??
                            0.0;
                    double pricePerCig = newPrice / newSize;
                    double updatedTotalSaved =
                        pastTotal + ((newBaseline - _dailyCount) * pricePerCig);
                    double pastLung =
                        prefs.getDouble('past_lung_score_${user.id}') ?? 10.0;
                    double updatedLungScore =
                        (pastLung + 1.11) - (_dailyCount * 25.0);
                    await prefs.setDouble(
                        'pack_price_${user.id}', newPrice);
                    await prefs.setInt('pack_size_${user.id}', newSize);
                    await prefs.setInt(
                        'daily_baseline_${user.id}', newBaseline);
                    await prefs.setString(
                        'last_price_update',
                        DateTime.now().toIso8601String());
                    setState(() {
                      _packPrice = newPrice;
                      _packSize = newSize;
                      _dailyBaseline = newBaseline;
                    });
                    await _updateTotalSaved(updatedTotalSaved);
                    await _updateLungScore(updatedLungScore);
                  }
                  if (mounted) Navigator.pop(ctx);
                },
                child: Text(AppStrings.saveSettings,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogField(BuildContext ctx, TextEditingController controller,
      String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: ctx.appText, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ctx.appTextDim, fontSize: 13),
        prefixIcon: Icon(icon, color: ctx.appSub, size: 20),
        filled: true,
        fillColor: ctx.appBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ctx.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ctx.appAccent),
        ),
      ),
    );
  }

  Future<void> _checkAcceptedFriendRequests() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final response = await supabase
          .from('friendships')
          .select()
          .eq('requester_id', myId)
          .eq('status', 'ACCEPTED');
      final prefs = await SharedPreferences.getInstance();
      List<String> notifiedIds =
          prefs.getStringList('notified_friendships') ?? [];
      for (var f in response) {
        final friendshipId = f['id'].toString();
        if (!notifiedIds.contains(friendshipId)) {
          final profile = await supabase
              .from('profiles')
              .select()
              .eq('id', f['addressee_id'])
              .maybeSingle();
          final friendName =
              profile != null ? profile['username'] : AppStrings.someone;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(AppStrings.friendAcceptedRequest(friendName)),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4)));
          }
          notifiedIds.add(friendshipId);
        }
      }
      await prefs.setStringList('notified_friendships', notifiedIds);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _logout() async {
    // Cikis yapan cihaza bildirim gitmemesi icin token kaydini sil
    await NotificationService.instance.removeToken();
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false);
    }
  }

  // Habit-aware günlük check-in. QUIT (tamamen bırak) modunda sayaç yoktur,
  // sorulması anlamsız -> atlanır. Yalnızca bugün loglanmamış azalt/kademeli/koru
  // habit'leri varsa tek bir hatırlatma çıkar ve kullanıcıyı Home'a yönlendirir.
  Future<void> _showCheckInDialog() async {
    List<UserHabit> habits;
    try {
      habits = await HabitRepository().getActiveHabits();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final pending = habits
        .where((h) => h.programType != ProgramType.quit && !h.loggedToday)
        .toList();
    if (pending.isEmpty) return;
    final locale = context.locale.languageCode;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: ctx.appCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ctx.appBorder, width: 1.5),
          ),
          title: Text(AppStrings.dailyCheckIn,
              style: TextStyle(
                  color: ctx.appText,
                  fontWeight: FontWeight.w900,
                  fontSize: 20),
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.checkinReminderBody(pending.length),
                  style: TextStyle(color: ctx.appText, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ...pending.take(5).map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text(safeHabitIcon(h.habit?.icon),
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(h.habit?.title(locale) ?? '',
                            style: TextStyle(
                                color: ctx.appText,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  )),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text(AppStrings.cancel, style: TextStyle(color: ctx.appSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ctx.appAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) setState(() => _selectedIndex = 0);
              },
              child: Text(AppStrings.checkinGoLog,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final habit = _userData['habit'] ?? 'Habit';
    final isCigarette =
        habit.toString().toLowerCase().contains('cigarette');
    final currentStreak = _getStreak();

    // Sekmeler: Home, Habits (çoklu alışkanlık), Friends.
    // Akciğer sağlığı artık drawer'dan / habit detayından açılır.
    final screens = <Widget>[
      const HomeHabitsPager(),
      const HabitsScreen(),
      const FriendsScreen(),
    ];

    final navItems = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_rounded),
          label: AppStrings.home),
      BottomNavigationBarItem(
          icon: const Icon(Icons.eco_outlined),
          activeIcon: const Icon(Icons.eco_rounded),
          label: AppStrings.habitsTab),
      BottomNavigationBarItem(
          icon: const Icon(Icons.people_outline_rounded),
          activeIcon: const Icon(Icons.people_rounded),
          label: AppStrings.friends),
    ];

    // Güvenlik: seçili index sekme sayısını aşmasın.
    final safeIndex =
        _selectedIndex < screens.length ? _selectedIndex : 0;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText, size: 28),
        title: Text(AppStrings.appName,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        centerTitle: true,
      ),
      drawer: _buildDrawer(context, isCigarette, currentStreak),
      // IndexedStack sekmeler arasi gecislerde ekran state'ini korur,
      // boylece girilen degerler kaybolmaz.
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: context.appCard,
        selectedItemColor: context.appAccent,
        unselectedItemColor: context.appSub,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        iconSize: 26,
        currentIndex: safeIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }

  Widget _buildDrawer(
      BuildContext context, bool isCigarette, int streak) {
    return Drawer(
      backgroundColor: context.appBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: context.isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF16A34A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _uploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white.withAlpha(40),
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person_rounded,
                                size: 40, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _userData['username']?.toString().toUpperCase() ??
                      AppStrings.defaultUser,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      AppStrings.daysStreak(streak),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (streak >= 1) ...[
                      const SizedBox(width: 6),
                      const AnimatedFlame(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Sigara/akciğer bilgisi artık ilgili habit'in detay ekranından
          // açılır (çoklu-habit modeli). Drawer sade tutuldu.
          _drawerTile(
            context,
            icon: Icons.settings_rounded,
            label: AppStrings.settings,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadUserData());
            },
          ),
          Divider(color: context.appBorder, thickness: 1, height: 8),
          _drawerTile(
            context,
            icon: Icons.logout_rounded,
            label: AppStrings.logout,
            color: Colors.redAccent,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    final c = color ?? context.appText;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 22),
      ),
      title: Text(label,
          style: TextStyle(
              color: c, fontWeight: FontWeight.w700, fontSize: 16)),
      onTap: onTap,
    );
  }

  // Gün bazlı genel milestone'lar (her alışkanlık için ortak).
  List<List<dynamic>> _homeMilestones(bool tr) => [
    [1, tr ? '1 GÜN' : '1 DAY'],
    [7, tr ? '1 HAFTA' : '1 WEEK'],
    [30, tr ? '1 AY' : '1 MONTH'],
    [90, tr ? '3 AY' : '3 MONTHS'],
    [180, tr ? '6 AY' : '6 MONTHS'],
    [365, tr ? '1 YIL' : '1 YEAR'],
  ];

  Widget _buildHomeTab(String habit) {
    final isCigarette = habit.toLowerCase().contains('cigarette');
    final tr = context.locale.languageCode == 'tr';

    final now = DateTime.now();
    var diff = now.difference(_quitDate);
    if (diff.isNegative) diff = Duration.zero;
    final cleanDays = diff.inDays;
    final cleanStr = tr
        ? '${cleanDays}g ${diff.inHours % 24}s ${diff.inMinutes % 60}dk'
        : '${cleanDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m';

    // Sonraki milestone + ilerleme yüzdesi
    final ms = _homeMilestones(tr);
    int prev = 0;
    int nextDays = ms.last[0] as int;
    String nextLabel = ms.last[1] as String;
    for (final m in ms) {
      if (cleanDays < (m[0] as int)) {
        nextDays = m[0] as int;
        nextLabel = m[1] as String;
        break;
      }
      prev = m[0] as int;
    }
    final frac = nextDays > prev
        ? ((cleanDays - prev) / (nextDays - prev)).clamp(0.0, 1.0)
        : 1.0;

    final double saved = _totalSaved < 0 ? 0.0 : _totalSaved;
    final int cigsIfContinued = cleanDays * _dailyBaseline;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          _dateHeader(),
          const SizedBox(height: 12),
          _milestoneGauge(frac, cleanDays, nextLabel),
          const SizedBox(height: 20),
          if (isCigarette) ...[
            Row(children: [
              Expanded(
                  child: _statCard(
                      Icons.timer_outlined, AppStrings.cleanTime, cleanStr)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(Icons.savings_rounded, AppStrings.savedShort,
                      '₺${saved.toStringAsFixed(0)}',
                      valueColor: context.appAccent)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _statCard(Icons.favorite_rounded,
                      AppStrings.lungsShort, '%${_lungScore.toStringAsFixed(0)}',
                      valueColor: context.appAccent)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(Icons.smoking_rooms_rounded,
                      AppStrings.ifContinued,
                      '$cigsIfContinued ${tr ? "sigara" : "cigs"}')),
            ]),
            const SizedBox(height: 16),
            _compactCounter(habit, tr),
          ] else ...[
            Row(children: [
              Expanded(
                  child: _statCard(
                      Icons.timer_outlined, AppStrings.cleanTime, cleanStr)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(Icons.local_fire_department_rounded,
                      AppStrings.streakLabel, '$cleanDays ${tr ? "gün" : "days"}',
                      valueColor: context.appAccent)),
            ]),
            const SizedBox(height: 12),
            _statCard(Icons.volunteer_activism_rounded,
                AppStrings.lifeContribution, AppStrings.keepGoing),
          ],
        ],
      ),
    );
  }

  Widget _dateHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_todayDayName,
                style: TextStyle(
                    color: context.appSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2)),
            const SizedBox(height: 3),
            Text(_todayDateStr,
                style: TextStyle(
                    color: context.appText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ],
        ),
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: context.appAccent)),
      ],
    );
  }

  Widget _milestoneGauge(double frac, int cleanDays, String nextLabel) {
    return SizedBox(
      width: 230,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(210, 210),
            painter: _GaugePainter(
              fraction: frac,
              trackColor: context.appBorder,
              progressColor: context.appAccent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$cleanDays',
                  style: TextStyle(
                      fontSize: 54,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: context.appAccent)),
              const SizedBox(height: 2),
              Text(AppStrings.daysClean,
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${(frac * 100).round()}%',
                  style: TextStyle(
                      color: context.appTextDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Positioned(
            bottom: 6,
            child: Column(
              children: [
                Text(AppStrings.nextLabel,
                    style: TextStyle(
                        color: context.appSub,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                Text(nextLabel,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: context.appAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _compactCounter(String habit, bool tr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.dailyCigs.toUpperCase(),
                    style: TextStyle(
                        color: context.appSub,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('$_dailyCount',
                    style: TextStyle(
                        color: context.appAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1)),
              ],
            ),
          ),
          _roundBtn(context, Icons.remove_rounded,
              () => _updateDailyCount(_dailyCount - 1)),
          const SizedBox(width: 10),
          _roundBtn(context, Icons.add_rounded,
              () => _updateDailyCount(_dailyCount + 1)),
        ],
      ),
    );
  }

  Widget _roundBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? const Color(0xFF333333)
              : context.appBorder,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: context.appAccent, size: 26),
      ),
    );
  }

  Widget _progressBar(BuildContext context) {
    final progress = (_dailyCount / _dailyBaseline).clamp(0.0, 1.0);
    final remaining = _dailyBaseline - _dailyCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.smokedOfBaseline(_dailyCount, _dailyBaseline),
              style: TextStyle(
                  color: context.appTextDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              remaining > 0
                  ? AppStrings.remainingCount(remaining)
                  : AppStrings.exceeded,
              style: TextStyle(
                  color: remaining > 0 ? context.appAccent : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: context.appBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.redAccent : context.appAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedFlame extends StatefulWidget {
  const AnimatedFlame({super.key});

  @override
  State<AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<AnimatedFlame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.35).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Icon(Icons.local_fire_department_rounded,
          color: Colors.orangeAccent, size: 20),
    );
  }
}

// --- Dairesel "C" milestone göstergesi (altta açıklık) -----------------------
class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color progressColor;
  _GaugePainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = 3.1415926 * 0.75; // 135° (sol-alt)
    const sweep = 3.1415926 * 1.5; // 270° -> altta 90° boşluk ("C")
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final prog = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, track);
    canvas.drawArc(rect, start, sweep * fraction.clamp(0.0, 1.0), false, prog);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}
