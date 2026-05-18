import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'goal_selection_screen.dart';

class HabitSelectionScreen extends StatefulWidget {
  const HabitSelectionScreen({super.key});

  @override
  State<HabitSelectionScreen> createState() => _HabitSelectionScreenState();
}

class _HabitSelectionScreenState extends State<HabitSelectionScreen> {
  // Alışkanlık listemiz. 'slug' stabil tanımlayıcı; UI'da 'habit_setup.habits.<slug>'
  // i18n anahtarı ile metin gelir. 'name' (üretildiğinde) sadece yedek/log için.
  final List<Map<String, dynamic>> _habits = [
    {'slug': 'cigarettes', 'icon': '🚬', 'selected': true},
    {'slug': 'vapes', 'icon': '💨', 'selected': false},
    {'slug': 'alcohol', 'icon': '🍾', 'selected': false},
    {'slug': 'junk_food', 'icon': '🍔', 'selected': false},
    {'slug': 'screen_time', 'icon': '📱💻', 'selected': false},
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

  void _goToNextPage() {
    // Seçilen alışkanlığı tespit edelim. Stabil slug saklarız (DB ve i18n için);
    // serbest metin ise olduğu gibi geçer.
    String selectedHabitSlug = '';
    if (_isOtherSelected) {
      selectedHabitSlug = _otherController.text.trim();
    } else {
      final selected = _habits.firstWhere((h) => h['selected'] == true, orElse: () => {});
      selectedHabitSlug = (selected['slug'] as String?) ?? '';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        // Seçimi Goal ekranına yolluyoruz
        builder: (context) => GoalSelectionScreen(selectedHabit: selectedHabitSlug),
      ),
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
                child: Text(
                  'app.name'.tr(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // 2. Başlık Metni
              Text(
                'habit_setup.choose_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
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
    final slug = habit['slug'] as String;
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
            'habit_setup.habits.$slug'.tr(),
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
                decoration: InputDecoration(
                  hintText: 'habit_setup.other_hint'.tr(),
                  hintStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        title: Text('common.next'.tr(), style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Next',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
