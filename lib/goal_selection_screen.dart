import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'username_selection_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  final String selectedHabit;
  const GoalSelectionScreen({super.key, required this.selectedHabit});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  int _selectedIndex = -1;
  String? _selectedPercentage;
  final List<String> _percentages = const ['10%', '20%', '30%', '50%', '75%'];

  bool get _isReadyToProceed {
    if (_selectedIndex == -1) return false;
    if (_selectedIndex == 2 && _selectedPercentage == null) return false;
    return true;
  }

  void _goToNextPage() {
    String selectedGoalName = '';
    if (_selectedIndex == 0) selectedGoalName = AppStrings.goalQuitOnce;
    if (_selectedIndex == 1) selectedGoalName = AppStrings.goalQuitStepByStep;
    if (_selectedIndex == 2) {
      selectedGoalName = '${AppStrings.goalReduceBy}$_selectedPercentage';
    }
    if (_selectedIndex == 3) selectedGoalName = AppStrings.goalReduceStepByStep;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UsernameSelectionScreen(
          selectedHabit: widget.selectedHabit,
          selectedGoal: selectedGoalName,
        ),
      ),
    );
  }

  void _handleSelection(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 2) _selectedPercentage = null;
    });
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppStrings.whatsYourGoal,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: context.appText,
                ),
              ),
              const SizedBox(height: 40),

              _buildOptionRow(0, AppStrings.goalQuitOnce),
              _buildOptionRow(1, AppStrings.goalQuitStepByStep),
              _buildPercentageRow(2),
              _buildOptionRow(3, AppStrings.goalReduceStepByStep),

              const SizedBox(height: 48),

              IconButton(
                iconSize: 60,
                icon: const Icon(Icons.arrow_circle_right_rounded),
                color:
                    _isReadyToProceed ? context.appAccent : context.appBorder,
                onPressed: _isReadyToProceed ? _goToNextPage : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(int index, String text) {
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: GestureDetector(
        onTap: () => _handleSelection(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? context.appAccent : context.appBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? context.appAccent : context.appSub,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.appText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageRow(int index) {
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            GestureDetector(
              onTap: () => _handleSelection(index),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected ? context.appAccent : context.appSub,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              AppStrings.goalReduceBy,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.appText,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.appBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPercentage,
                  dropdownColor: context.appCard,
                  hint: Text(
                    AppStrings.percentageHint,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.appSub,
                    ),
                  ),
                  icon: Icon(Icons.arrow_drop_down,
                      color: context.appAccent, size: 28),
                  items: _percentages.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.appText,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPercentage = newValue;
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
