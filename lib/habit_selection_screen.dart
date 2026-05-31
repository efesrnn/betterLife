import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'goal_selection_screen.dart';

class HabitSelectionScreen extends StatefulWidget {
  const HabitSelectionScreen({super.key});

  @override
  State<HabitSelectionScreen> createState() => _HabitSelectionScreenState();
}

class _HabitSelectionScreenState extends State<HabitSelectionScreen> {
  // Önceden tanımlı alışkanlıklar (tek seçim)
  final List<Map<String, String>> _habits = const [
    {'name': 'Cigarettes', 'icon': '🚬'},
    {'name': 'Vapes', 'icon': '💨'},
    {'name': 'Alcohol', 'icon': '🍾'},
    {'name': 'Junk Food', 'icon': '🍔'},
    {'name': 'Screen Time', 'icon': '📱'},
  ];

  int _selectedIndex = -1; // -1 = hiçbiri
  bool _isOtherSelected = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _isAnyHabitSelected => _selectedIndex != -1 || _isOtherSelected;

  void _selectHabit(int index) {
    setState(() {
      _selectedIndex = index;
      _isOtherSelected = false;
      _otherController.clear();
    });
  }

  void _goToNextPage() {
    final String selectedHabitName = _isOtherSelected
        ? _otherController.text.trim()
        : _habits[_selectedIndex]['name']!;

    if (selectedHabitName.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GoalSelectionScreen(selectedHabit: selectedHabitName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "Better Life" logosu
              Image.asset(
                'assets/app-logo/better_life_logo.png',
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),

              Text(
                AppStrings.chooseHabit,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: context.appText,
                ),
              ),
              const SizedBox(height: 32),

              ...List.generate(_habits.length, (i) => _buildHabitRow(i)),
              _buildOtherRow(),

              const SizedBox(height: 40),

              IconButton(
                iconSize: 60,
                icon: const Icon(Icons.arrow_circle_right_rounded),
                color: _isAnyHabitSelected
                    ? context.appAccent
                    : context.appBorder,
                onPressed: _isAnyHabitSelected ? _goToNextPage : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitRow(int index) {
    final habit = _habits[index];
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: GestureDetector(
        onTap: () => _selectHabit(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? context.appAccent : context.appBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? context.appAccent : context.appSub,
                size: 24,
              ),
              const SizedBox(width: 14),
              Text(
                habit['name']!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appText,
                ),
              ),
              const SizedBox(width: 10),
              Text(habit['icon']!, style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isOtherSelected ? context.appAccent : context.appBorder,
            width: _isOtherSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isOtherSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: _isOtherSelected ? context.appAccent : context.appSub,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _otherController,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appText,
                ),
                cursorColor: context.appAccent,
                onChanged: (text) {
                  setState(() {
                    if (text.trim().isNotEmpty) {
                      _isOtherSelected = true;
                      _selectedIndex = -1;
                    } else {
                      _isOtherSelected = false;
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: AppStrings.otherHabitHint,
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.appSub,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
