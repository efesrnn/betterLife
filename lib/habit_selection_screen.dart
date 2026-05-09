import 'package:flutter/material.dart';
import 'goal_selection_screen.dart';

class HabitSelectionScreen extends StatefulWidget {
  const HabitSelectionScreen({super.key});

  @override
  State<HabitSelectionScreen> createState() => _HabitSelectionScreenState();
}

class _HabitSelectionScreenState extends State<HabitSelectionScreen> {
  // Alışkanlık listemiz
  final List<Map<String, dynamic>> _habits = [
    {'name': 'Cigarettes', 'icon': '🚬', 'selected': true},
    {'name': 'Vapes', 'icon': '💨', 'selected': false},
    {'name': 'Alcohol', 'icon': '🍾', 'selected': false},
    {'name': 'Junk Food', 'icon': '🍔', 'selected': false},
    {'name': 'Screen Time', 'icon': '📱💻', 'selected': false},
  ];

  bool _isOtherSelected = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  // YENİ: En az bir tane alışkanlık seçili mi diye kontrol eden fonksiyon
  bool get _isAnyHabitSelected {
    // Listede seçili olan var mı bakıyoruz
    bool isListSelected = _habits.any((habit) => habit['selected'] == true);
    // Ya listeden biri seçili olacak YA DA "Other" seçili olacak
    return isListSelected || _isOtherSelected;
  }

  // YENİ: Sonraki sayfaya geçiş fonksiyonu
  void _goToNextPage() {
    Navigator.push(
      context,
      // BURASI DEĞİŞTİ: Artık yeni tasarladığımız sayfaya gidiyor
      MaterialPageRoute(builder: (context) => const GoalSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. En üstteki Oval "Better Life" Logosu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 3),
                  borderRadius: const BorderRadius.all(Radius.elliptical(150, 70)),
                ),
                child: const Text(
                  'Better Life',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // 2. Başlık Metni
              const Text(
                'CHOOSE A HABIT TO\nOVERCOME WITH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),

              // 3. Alışkanlık Seçenekleri (Liste)
              ..._habits.map((habit) => _buildHabitRow(habit)),

              // 4. "Other..." Seçeneği ve Metin Kutusu
              _buildOtherRow(),

              const SizedBox(height: 50), // Buton ile liste arasına boşluk

              // YENİ: 5. İleri Ok Butonu
              IconButton(
                iconSize: 60, // Oku büyük ve belirgin yapıyoruz
                icon: const Icon(Icons.arrow_circle_right_outlined),
                // Eğer en az biri seçiliyse kırmızı, hiçbiri seçili değilse gri olacak:
                color: _isAnyHabitSelected ? Colors.red : Colors.grey.shade400,
                // Eğer hiçbiri seçili değilse onPressed'i null yapıyoruz (tıklanamaz oluyor):
                onPressed: _isAnyHabitSelected ? _goToNextPage : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitRow(Map<String, dynamic> habit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: habit['selected'],
              activeColor: Colors.red,
              side: const BorderSide(color: Colors.black87, width: 2),
              onChanged: (bool? value) {
                setState(() {
                  habit['selected'] = value ?? false;
                });
              },
            ),
          ),
          Text(
            habit['name'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Text(
            habit['icon'],
            style: const TextStyle(fontSize: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: _isOtherSelected,
              activeColor: Colors.red,
              side: const BorderSide(color: Colors.black87, width: 2),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    if (_otherController.text.trim().isNotEmpty) {
                      _isOtherSelected = true;
                    }
                  } else {
                    _isOtherSelected = false;
                    _otherController.clear();
                  }
                });
              },
            ),
          ),
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 2),
              ),
              child: TextField(
                controller: _otherController,
                enabled: true,
                onChanged: (text) {
                  setState(() {
                    _isOtherSelected = text.trim().isNotEmpty;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Other... (Type in)',
                  hintStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// YENİ: Geçici (Dummy) Sonraki Sayfa
// İleride kendi gerçek sayfanı yapana kadar ok tuşuna basınca burası açılacak.
class DummyNextScreen extends StatelessWidget {
  const DummyNextScreen({super.key});

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
          'Harika! Bir sonraki sayfaya geçtin.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}