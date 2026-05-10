import 'package:flutter/material.dart';
import 'username_selection_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  final String selectedHabit; // YENİ: Önceki sayfadan gelen veri
  const GoalSelectionScreen({super.key, required this.selectedHabit});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  int _selectedIndex = -1;
  String? _selectedPercentage;
  final List<String> _percentages = ['10%', '20%', '30%', '50%', '75%'];

  bool get _isReadyToProceed {
    if (_selectedIndex == -1) return false;
    if (_selectedIndex == 2 && _selectedPercentage == null) return false;
    return true;
  }

  void _goToNextPage() {
    // Seçilen hedefi metin olarak alalım
    String selectedGoalName = '';
    if (_selectedIndex == 0) selectedGoalName = 'Fully quit in once.';
    if (_selectedIndex == 1) selectedGoalName = 'Fully quit by reducing step by step.';
    if (_selectedIndex == 2) selectedGoalName = 'Reduce by $_selectedPercentage';
    if (_selectedIndex == 3) selectedGoalName = 'Reduce step by step';

    Navigator.push(
      context,
      MaterialPageRoute(
        // İki veriyi de Username sayfasına yolluyoruz
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
      if (index != 2) {
        _selectedPercentage = null;
      }
    });
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "What's Your Goal?",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              _buildOptionRow(0, 'Fully quit in once.'),
              _buildOptionRow(1, 'Fully quit by reducing step\nby step.'),
              _buildPercentageRow(2),
              _buildOptionRow(3, 'Reduce step by step'),

              const SizedBox(height: 60),

              Center(
                child: IconButton(
                  iconSize: 60,
                  icon: const Icon(Icons.arrow_circle_right_outlined),
                  color: _isReadyToProceed ? Colors.red : Colors.grey.shade300,
                  onPressed: _isReadyToProceed ? _goToNextPage : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Standart seçenekleri oluşturan yardımcı widget
  Widget _buildOptionRow(int index, String text) {
    bool isSelected = _selectedIndex == index;
    // YENİ: Eğer listeden herhangi biri seçilmişse ve bu satır o seçilen satır değilse durumu "Diğeri Seçili" yapar
    bool isOtherSelected = _selectedIndex != -1 && !isSelected;
    // YENİ: Diğeri seçiliyse rengi gri yap, yoksa siyah bırak
    Color itemColor = isOtherSelected ? Colors.grey.shade400 : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: isSelected,
              activeColor: Colors.red,
              side: BorderSide(color: itemColor, width: 2), // Çerçeve rengi dinamik oldu
              onChanged: (bool? value) {
                if (value == true) {
                  _handleSelection(index);
                } else {
                  setState(() => _selectedIndex = -1);
                }
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: itemColor, // Yazı rengi dinamik oldu
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Yüzde (Dropdown) içeren 3. seçeneği oluşturan yardımcı widget
  Widget _buildPercentageRow(int index) {
    bool isSelected = _selectedIndex == index;
    bool isOtherSelected = _selectedIndex != -1 && !isSelected;
    Color itemColor = isOtherSelected ? Colors.grey.shade400 : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: isSelected,
              activeColor: Colors.red,
              side: BorderSide(color: itemColor, width: 2), // Çerçeve rengi dinamik
              onChanged: (bool? value) {
                if (value == true) {
                  _handleSelection(index);
                } else {
                  setState(() {
                    _selectedIndex = -1;
                    _selectedPercentage = null;
                  });
                }
              },
            ),
          ),
          Text(
            'Reduce by ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: itemColor, // Yazı rengi dinamik
            ),
          ),
          const SizedBox(width: 8),

          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: itemColor, width: 2), // Dropdown dış çerçevesi dinamik
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPercentage,
                hint: Text(
                  'Percentage',
                  style: TextStyle(fontWeight: FontWeight.bold, color: itemColor), // Hint rengi dinamik
                ),
                icon: Icon(Icons.arrow_drop_down, color: itemColor, size: 30), // Ok ikonu rengi dinamik
                items: _percentages.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}

// Geçici Sonraki Sayfa
class DummyFinalScreen extends StatelessWidget {
  const DummyFinalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Next Step', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Harika! İkinci sayfayı da geçtin.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}