import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';
import 'auth_screen.dart';
import 'friends_screen.dart';
import 'lungs_screen.dart';
import 'settings_screen.dart';

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
          .showSnackBar(const SnackBar(content: Text('Uploading photo...')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error uploading: $e'),
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
            isReminder ? 'Price Check!' : 'Cigarette Info',
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
                    'It has been 2 months! Have cigarette prices changed?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: ctx.appTextDim, fontWeight: FontWeight.w600),
                  ),
                ),
              _dialogField(ctx, priceCtrl, 'Pack Price (TL)',
                  Icons.monetization_on_outlined),
              const SizedBox(height: 12),
              _dialogField(ctx, sizeCtrl, 'Cigarettes per Pack',
                  Icons.smoking_rooms_outlined),
              const SizedBox(height: 12),
              _dialogField(ctx, baselineCtrl, 'Daily cigarettes smoked',
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
                child: const Text('Save Settings',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
              profile != null ? profile['username'] : 'Someone';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('$friendName accepted your friend request!'),
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
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false);
    }
  }

  void _showCheckInDialog() {
    final habit = _userData['habit'] ?? 'your habit';
    String question = 'Did you slip up with $habit since you were away?';
    if (habit.toString().toLowerCase().contains('cigarette')) {
      question = 'Did you smoke any cigarettes since you were away?';
    }
    int popUpCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return AlertDialog(
            backgroundColor: ctx.appCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: ctx.appBorder, width: 1.5),
            ),
            title: Text('Daily Check-In',
                style: TextStyle(
                    color: ctx.appText,
                    fontWeight: FontWeight.w900,
                    fontSize: 22),
                textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(question,
                    style: TextStyle(
                        color: ctx.appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _counterBtn(
                      ctx,
                      Icons.remove_rounded,
                      () {
                        if (popUpCount > 0) {
                          setStateDialog(() => popUpCount--);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        '$popUpCount',
                        style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: ctx.appAccent,
                            height: 1),
                      ),
                    ),
                    _counterBtn(
                      ctx,
                      Icons.add_rounded,
                      () => setStateDialog(() => popUpCount++),
                    ),
                  ],
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (popUpCount == 0)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('No, I stayed strong!',
                      style: TextStyle(
                          color: ctx.appAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              if (popUpCount > 0)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ctx.appAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _updateDailyCount(_dailyCount + popUpCount);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _counterBtn(
      BuildContext ctx, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ctx.appAccent.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ctx.appBorder),
        ),
        child: Icon(icon, color: ctx.appAccent, size: 26),
      ),
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final habit = _userData['habit'] ?? 'Habit';
    final isCigarette =
        habit.toString().toLowerCase().contains('cigarette');
    final currentStreak = _getStreak();

    final screens = [
      _buildHomeTab(habit),
      LungsScreen(lungScore: _lungScore),
      const FriendsScreen(),
    ];

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText, size: 28),
        title: Text('Better Life',
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        centerTitle: true,
      ),
      drawer: _buildDrawer(context, isCigarette, currentStreak),
      body: screens[_selectedIndex],
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Lungs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Friends'),
        ],
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
                  _userData['username']?.toString().toUpperCase() ?? 'USER',
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
                      '$streak DAYS STREAK',
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
          if (isCigarette)
            _drawerTile(
              context,
              icon: Icons.smoking_rooms_rounded,
              label: 'Cigarette Info',
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
          _drawerTile(
            context,
            icon: Icons.settings_rounded,
            label: 'Settings',
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
            label: 'Logout',
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

  Widget _buildHomeTab(String habit) {
    String label = '$habit\ntoday.';
    if (habit.toLowerCase().contains('cigarette')) {
      label = 'Cigarettes smoked\ntoday.';
    }
    final double saved = _totalSaved < 0 ? 0.0 : _totalSaved;
    final double dailyTarget = _dailyBaseline * (_packPrice / _packSize);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // --- Counter card ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Date header
                Row(
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
                        shape: BoxShape.circle,
                        color: context.appAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                // Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$_dailyCount',
                      style: TextStyle(
                        fontSize: 96,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: context.appAccent,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        _roundBtn(context, Icons.add_rounded,
                            () => _updateDailyCount(_dailyCount + 1)),
                        const SizedBox(height: 14),
                        _roundBtn(context, Icons.remove_rounded,
                            () => _updateDailyCount(_dailyCount - 1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.appSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (_dailyBaseline > 0) ...[
                  const SizedBox(height: 20),
                  _progressBar(context),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // --- Savings card ---
          if (habit.toLowerCase().contains('cigarette'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.appAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.savings_rounded,
                        color: context.appAccent, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL SAVED',
                            style: TextStyle(
                                color: context.appSub,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(
                          '₺${saved.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: context.appAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Daily target: ₺${dailyTarget.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: context.appTextDim,
                              fontSize: 12,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
              '$_dailyCount / $_dailyBaseline smoked',
              style: TextStyle(
                  color: context.appTextDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              remaining > 0 ? '$remaining remaining' : 'Exceeded!',
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