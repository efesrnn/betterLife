import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'friends_screen.dart';
import 'lungs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> _userData = {};
  String _email = '';

  int _dailyCount = 0;
  String _todayDateStr = '';
  String _todayDayName = '';
  int _selectedIndex = 0;

  double _packPrice = 115.0;
  int _packSize = 20;
  int _dailyBaseline = 20;
  double _totalSaved = 0.0;
  double _lungScore = 10.0;

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
    double absoluteTruthTotal = pastTotal + ((_dailyBaseline - _dailyCount) * pricePerCig);
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
        _email = user.email ?? '';
        _userData = user.userMetadata ?? {};
        _packPrice = prefs.getDouble('pack_price_${user.id}') ?? 115.0;
        _packSize = prefs.getInt('pack_size_${user.id}') ?? 20;
        _dailyBaseline = prefs.getInt('daily_baseline_${user.id}') ?? 20;
        _totalSaved = prefs.getDouble('total_saved_${user.id}') ?? 0.0;
        _lungScore = prefs.getDouble('lung_score_${user.id}') ?? 10.0;
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
          });
          await prefs.setDouble('pack_price_${user.id}', _packPrice);
          await prefs.setInt('pack_size_${user.id}', _packSize);
          await prefs.setInt('daily_baseline_${user.id}', _dailyBaseline);
          await prefs.setDouble('total_saved_${user.id}', _totalSaved);
          await prefs.setDouble('lung_score_${user.id}', _lungScore);
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

  void _showSettingsDialog({bool isReminder = false}) {
    TextEditingController priceCtrl = TextEditingController(text: _packPrice.toString());
    TextEditingController sizeCtrl = TextEditingController(text: _packSize.toString());
    TextEditingController baselineCtrl = TextEditingController(text: _dailyBaseline.toString());

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(0)),
            backgroundColor: Colors.white,
            title: Text(
              isReminder ? 'Price Check!' : 'Cigarette Info',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReminder)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 15.0),
                    child: Text('It has been 2 months! Have cigarette prices changed?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pack Price (TL)', border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sizeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cigarettes per Pack', border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: baselineCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'How many did you smoke daily?', border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
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
                child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 $friendName accepted your friend request!'), backgroundColor: Colors.green, duration: const Duration(seconds: 4)));
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
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0), side: const BorderSide(color: Colors.black, width: 3)),
                  backgroundColor: Colors.white,
                  title: const Text('Daily Check-In', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24), textAlign: TextAlign.center),
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
                    if (popUpCount == 0) TextButton(onPressed: () => Navigator.pop(context), child: const Text("No, I stayed strong!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))),
                    if (popUpCount > 0) ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.black, width: 2))),
                      onPressed: () { _updateDailyCount(_dailyCount + popUpCount); Navigator.pop(context); },
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final habit = _userData['habit'] ?? 'Habit';
    final isCigarette = habit.toString().toLowerCase().contains('cigarette');

    final List<Widget> _screens = [
      _buildHomeTab(habit),
      LungsScreen(lungScore: _lungScore),
      const FriendsScreen()
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 30),
        title: const Text('Better Life', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
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
                  Text(_userData['username']?.toString().toUpperCase() ?? 'USER', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(_email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            if (isCigarette)
              ListTile(
                leading: const Icon(Icons.smoking_rooms, color: Colors.black, size: 30),
                title: const Text('Cigarette Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsDialog();
                },
              ),
            const Divider(color: Colors.black26, thickness: 1),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red, size: 30), title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)), onTap: _logout),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        iconSize: 32,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), activeIcon: Icon(Icons.fitness_center), label: 'Lungs'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Friends'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String habit) {
    String label = '$habit\ntoday.';
    if (habit.toLowerCase().contains('cigarette')) label = 'Cigarettes smoked\ntoday.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 3)),
            child: Column(
              children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 3))),
                const SizedBox(height: 20),
                Text(_todayDateStr, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(_todayDayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (habit.toLowerCase().contains('cigarette'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade100, border: Border.all(color: Colors.black, width: 3)),
              child: Column(
                children: [
                  const Text('TOTAL SAVED', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Text('₺${(_totalSaved < 0 ? 0.0 : _totalSaved).toStringAsFixed(2)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.green)),
                  const SizedBox(height: 10),
                  Text(
                    'Daily Saving Target: ₺${(_dailyBaseline * (_packPrice / _packSize)).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}