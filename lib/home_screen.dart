import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_screen.dart';
import 'friends_screen.dart';
import 'lungs_screen.dart';
import 'settings_screen.dart';

const Color _bg = Color(0xFF0F172A);
const Color _card = Color(0xFF1E293B);
const Color _border = Color(0xFF334155);
const Color _accent = Color(0xFF818CF8);
const Color _green = Color(0xFF34D399);
const Color _sub = Color(0xFF94A3B8);

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
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    _todayDayName = days[now.weekday - 1];
  }

  int _getStreak() {
    if (_dailyCount > 0) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quit = DateTime(_quitDate.year, _quitDate.month, _quitDate.day);
    int streak = today.difference(quit).inDays;
    return streak < 0 ? 0 : streak;
  }

  Future<void> _checkTwoMonthUpdateReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('last_price_update');

    if (lastUpdateStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final difference = DateTime.now().difference(lastUpdate).inDays;
      if (difference >= 60) {
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
    final todayKey = "${now.year}-${now.month}-${now.day}";

    final userDateKey = 'last_saved_date_$userId';
    final userCountKey = 'daily_count_$userId';
    final savedDateKey = prefs.getString(userDateKey);

    if (savedDateKey == todayKey) {
      setState(() {
        _dailyCount = prefs.getInt(userCountKey) ?? 0;
      });
    } else {
      int yesterdaysCount = prefs.getInt(userCountKey) ?? 0;
      if (yesterdaysCount > 0) {
        _quitDate = DateTime(now.year, now.month, now.day);
        await prefs.setString('quit_date_$userId', _quitDate.toIso8601String());
        try {
          await supabase.from('profiles').update({'quit_date': _quitDate.toIso8601String()}).eq('id', userId);
        } catch (_) {}
      }

      double pastTotal = _totalSaved;
      await prefs.setDouble('past_total_saved_$userId', pastTotal);
      double baseLung = _lungScore;
      await prefs.setDouble('past_lung_score_$userId', baseLung);

      setState(() => _dailyCount = 0);

      double pricePerCig = _packPrice / _packSize;
      await _updateTotalSaved(pastTotal + (_dailyBaseline * pricePerCig));
      await _updateLungScore(baseLung + 1.11);

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
      await supabase.from('profiles').update({'total_saved': newTotal}).eq('id', user.id);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _updateLungScore(double newScore) async {
    if (newScore < 0) newScore = 0.0;
    if (newScore > 100) newScore = 100.0;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _lungScore = newScore);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lung_score_${user.id}', newScore);
    try {
      await supabase.from('profiles').update({'lung_score': newScore}).eq('id', user.id);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _updateDailyCount(int newCount) async {
    if (newCount < 0) newCount = 0;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final userId = user.id;
    final userCountKey = 'daily_count_$userId';

    setState(() => _dailyCount = newCount);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(userCountKey, _dailyCount);

    double pastTotal = prefs.getDouble('past_total_saved_$userId') ?? 0.0;
    double pricePerCig = _packPrice / _packSize;
    await _updateTotalSaved(pastTotal + ((_dailyBaseline - _dailyCount) * pricePerCig));

    double pastLung = prefs.getDouble('past_lung_score_$userId') ?? 10.0;
    await _updateLungScore((pastLung + 1.11) - (_dailyCount * 25.0));
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
        final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null) {
          setState(() {
            if (profile['pack_price'] != null) _packPrice = (profile['pack_price']).toDouble();
            if (profile['pack_size'] != null) _packSize = profile['pack_size'];
            if (profile['daily_baseline'] != null) _dailyBaseline = profile['daily_baseline'];
            if (profile['total_saved'] != null) _totalSaved = (profile['total_saved']).toDouble();
            if (profile['lung_score'] != null) _lungScore = (profile['lung_score']).toDouble();
            _avatarUrl = profile['avatar_url'];

            if (profile['quit_date'] != null) {
              _quitDate = DateTime.parse(profile['quit_date']);
            } else if (prefs.getString('quit_date_${user.id}') == null) {
              _quitDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            }
          });

          await prefs.setDouble('pack_price_${user.id}', _packPrice);
          await prefs.setInt('pack_size_${user.id}', _packSize);
          await prefs.setInt('daily_baseline_${user.id}', _dailyBaseline);
          await prefs.setDouble('total_saved_${user.id}', _totalSaved);
          await prefs.setDouble('lung_score_${user.id}', _lungScore);
          await prefs.setString('quit_date_${user.id}', _quitDate.toIso8601String());

          if (_avatarUrl != null) {
            await prefs.setString('avatar_url_${user.id}', _avatarUrl!);
          } else {
            await prefs.remove('avatar_url_${user.id}');
          }
        }
      } catch (e) {
        debugPrint("DB Error: $e");
      }

      if (!prefs.containsKey('past_total_saved_${user.id}')) {
        int currentDailyCount = prefs.getInt('daily_count_${user.id}') ?? 0;
        double pricePerCig = _packPrice / _packSize;
        double derivedPastTotal = _totalSaved - ((_dailyBaseline - currentDailyCount) * pricePerCig);
        await prefs.setDouble('past_total_saved_${user.id}', derivedPastTotal);
      }

      if (!prefs.containsKey('past_lung_score_${user.id}')) {
        int currentDailyCount = prefs.getInt('daily_count_${user.id}') ?? 0;
        double derivedPastLung = _lungScore - 1.11 + (currentDailyCount * 25.0);
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
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading photo...')));

      final bytes = await image.readAsBytes();
      final fileExtension = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      await supabase.from('profiles').update({'avatar_url': imageUrl}).eq('id', user.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_url_${user.id}', imageUrl);
      setState(() => _avatarUrl = imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showSettingsDialog({bool isReminder = false}) {
    TextEditingController priceCtrl = TextEditingController(text: _packPrice.toString());
    TextEditingController sizeCtrl = TextEditingController(text: _packSize.toString());
    TextEditingController baselineCtrl = TextEditingController(text: _dailyBaseline.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isReminder ? 'Price Check!' : 'Cigarette Info',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReminder)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'It has been 2 months! Have cigarette prices changed?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _sub, fontWeight: FontWeight.w500),
                  ),
                ),
              _dialogField(controller: priceCtrl, label: 'Pack Price (TL)'),
              const SizedBox(height: 12),
              _dialogField(controller: sizeCtrl, label: 'Cigarettes per Pack'),
              const SizedBox(height: 12),
              _dialogField(controller: baselineCtrl, label: 'Daily cigarettes smoked'),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final user = supabase.auth.currentUser;
                  if (user != null) {
                    String priceText = priceCtrl.text.replaceAll(',', '.');
                    double newPrice = double.tryParse(priceText) ?? 115.0;
                    int newSize = int.tryParse(sizeCtrl.text) ?? 20;
                    int newBaseline = int.tryParse(baselineCtrl.text) ?? 20;

                    final prefs = await SharedPreferences.getInstance();
                    double pastTotal = prefs.getDouble('past_total_saved_${user.id}') ?? 0.0;
                    double pricePerCig = newPrice / newSize;
                    double updatedTotalSaved = pastTotal + ((newBaseline - _dailyCount) * pricePerCig);

                    double pastLung = prefs.getDouble('past_lung_score_${user.id}') ?? 10.0;
                    double updatedLungScore = (pastLung + 1.11) - (_dailyCount * 25.0);

                    await prefs.setDouble('pack_price_${user.id}', newPrice);
                    await prefs.setInt('pack_size_${user.id}', newSize);
                    await prefs.setInt('daily_baseline_${user.id}', newBaseline);
                    await prefs.setString('last_price_update', DateTime.now().toIso8601String());

                    setState(() {
                      _packPrice = newPrice;
                      _packSize = newSize;
                      _dailyBaseline = newBaseline;
                    });

                    await _updateTotalSaved(updatedTotalSaved);
                    await _updateLungScore(updatedLungScore);
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _sub),
        filled: true,
        fillColor: _bg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }

  Future<void> _checkAcceptedFriendRequests() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final response = await supabase.from('friendships').select().eq('requester_id', myId).eq('status', 'ACCEPTED');
      final prefs = await SharedPreferences.getInstance();
      List<String> notifiedIds = prefs.getStringList('notified_friendships') ?? [];

      for (var f in response) {
        final friendshipId = f['id'].toString();
        if (!notifiedIds.contains(friendshipId)) {
          final profile = await supabase.from('profiles').select().eq('id', f['addressee_id']).maybeSingle();
          final friendName = profile != null ? profile['username'] : 'Someone';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('🎉 $friendName accepted your friend request!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ));
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
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
    }
  }

  void _showCheckInDialog() {
    final habit = _userData['habit'] ?? 'your habit';
    String question = 'Did you slip up with $habit since you were away?';
    if (habit.toLowerCase().contains('cigarette')) question = 'Did you smoke any cigarettes since you were away?';

    int popUpCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Daily Check-In',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    question,
                    style: const TextStyle(color: _sub, fontSize: 15, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _counterButton(Icons.remove_rounded, () {
                        if (popUpCount > 0) setStateDialog(() => popUpCount--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          '$popUpCount',
                          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      _counterButton(Icons.add_rounded, () => setStateDialog(() => popUpCount++)),
                    ],
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                if (popUpCount == 0)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("I stayed strong!", style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                if (popUpCount > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        _updateDailyCount(_dailyCount + popUpCount);
                        Navigator.pop(context);
                      },
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final habit = _userData['habit'] ?? 'Habit';
    final isCigarette = habit.toString().toLowerCase().contains('cigarette');
    int currentStreak = _getStreak();

    final List<Widget> screens = [
      _buildHomeTab(habit, currentStreak),
      LungsScreen(lungScore: _lungScore),
      const FriendsScreen(),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        title: const Text(
          'Better Life',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      drawer: _buildDrawer(isCigarette, currentStreak),
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _accent,
        unselectedItemColor: const Color(0xFF475569),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        iconSize: 28,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'Lungs'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Friends'),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isCigarette, int currentStreak) {
    return Drawer(
      backgroundColor: _card,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4338CA), Color(0xFF1E293B)],
              ),
            ),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _uploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white24,
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null ? const Icon(Icons.account_circle, size: 64, color: Colors.white) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: _card, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _userData['username']?.toString().toUpperCase() ?? 'USER',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (currentStreak > 0) ...[
                      const AnimatedFlame(),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      currentStreak > 0 ? '$currentStreak day streak' : '0 day streak',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCigarette)
            _drawerItem(
              icon: Icons.smoking_rooms_rounded,
              label: 'Cigarette Info',
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
          const Divider(color: _border, height: 1),
          _drawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadUserData());
            },
          ),
          _drawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: Colors.redAccent,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
      onTap: onTap,
      horizontalTitleGap: 8,
    );
  }

  Widget _buildHomeTab(String habit, int currentStreak) {
    String label = '$habit today';
    if (habit.toLowerCase().contains('cigarette')) label = 'cigarettes smoked today';

    final double progress = _dailyBaseline > 0 ? (_dailyCount / _dailyBaseline).clamp(0.0, 1.0) : 0.0;
    final Color progressColor = _dailyCount == 0
        ? _green
        : (_dailyCount >= _dailyBaseline ? Colors.redAccent : _accent);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main counter card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _todayDayName,
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _todayDateStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (currentStreak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AnimatedFlame(),
                            const SizedBox(width: 5),
                            Text(
                              '$currentStreak',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _counterButton(Icons.remove_rounded, () => _updateDailyCount(_dailyCount - 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$_dailyCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 92,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    _counterButton(Icons.add_rounded, () => _updateDailyCount(_dailyCount + 1)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(color: _sub, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('today: $_dailyCount', style: const TextStyle(color: _sub, fontSize: 12)),
                    Text('goal: 0  (was $_dailyBaseline)', style: const TextStyle(color: _sub, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (habit.toLowerCase().contains('cigarette'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF064E3B), _bg],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.25), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.savings_outlined, color: _green, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL SAVED',
                        style: TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₺${(_totalSaved < 0 ? 0.0 : _totalSaved).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'daily target: ₺${(_dailyBaseline * (_packPrice / _packSize)).toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF475569), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class AnimatedFlame extends StatefulWidget {
  const AnimatedFlame({super.key});

  @override
  State<AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<AnimatedFlame> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
    );
  }
}