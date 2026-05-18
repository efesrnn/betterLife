import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'models/models.dart';
import 'services/gemini_service.dart';
import 'services/supabase_service.dart';

class UsernameSelectionScreen extends StatefulWidget {
  final String selectedHabit; // slug ('cigarettes' vb.) veya serbest metin
  final String selectedGoal;  // slug ('quit_at_once', 'reduce_percent_10', ...)

  const UsernameSelectionScreen({
    super.key,
    required this.selectedHabit,
    required this.selectedGoal,
  });

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isReadyToProceed = false;
  bool _isLoading = false;
  String? _loadingMessage; // "AI değerlendiriyor..." gibi

  final supabase = Supabase.instance.client;

  // Setup wizard'da kullanılan UI slug'larından oluşan beyaz liste.
  // Diğer her metin "serbest metin" sayılır → Gemini'ye gönderilir.
  static const _kBuiltInSlugs = <String>{
    'cigarettes',
    'vapes',
    'alcohol',
    'junk_food',
    'screen_time',
  };

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  /// Habit'in DB'deki HabitCategory karşılığını bulur veya oluşturur.
  ///
  /// Akış:
  ///   1) Built-in slug → findHabitCategoryBySlug
  ///   2) Serbest metin → findHabitCategoryByName (cache)
  ///   3) Yoksa Gemini → değerlendir
  ///      - geçersiz: kullanıcıya gerekçeyi göster, null döndür
  ///      - geçerli: onay dialog'u; onay → createHabitCategory
  ///
  /// `null` döndürürse setup'ı tamamlamaya devam etmemeli.
  Future<HabitCategory?> _resolveHabitCategory(String habitRaw) async {
    final raw = habitRaw.trim();
    if (raw.isEmpty) return null;

    // 1) Built-in slug?
    if (_kBuiltInSlugs.contains(raw)) {
      setState(() => _loadingMessage = null);
      final cat = await SupabaseService.instance.findHabitCategoryBySlug(raw);
      if (cat != null) return cat;
      // (Slug migration deploy edilmemiş olabilir — DB hatalı kurulum.)
      _showSnack('errors.habit_not_found'.tr(), Colors.red);
      return null;
    }

    // 2) Cache lookup (serbest metin önceki bir kullanıcı tarafından açılmış olabilir)
    final cached = await SupabaseService.instance.findHabitCategoryByName(raw);
    if (cached != null) return cached;

    // 3) Gemini
    if (!GeminiService.instance.isAvailable) {
      _showSnack('gemini.unavailable'.tr(), Colors.red);
      return null;
    }

    setState(() => _loadingMessage = 'gemini.evaluating'.tr());
    final result = await GeminiService.instance.evaluateHabit(raw);
    setState(() => _loadingMessage = null);

    if (!result.isValid) {
      final locale = context.locale.languageCode;
      final reason = (locale == 'tr'
              ? result.rejectionTr
              : (locale == 'en' ? result.rejectionEn : result.rejectionTr)) ??
          'gemini.invalid_default'.tr();
      await _showInvalidDialog(reason);
      return null;
    }

    final suggested = result.suggestedCategory!;
    final confirmed = await _showConfirmDialog(suggested);
    if (confirmed != true) return null;

    try {
      return await SupabaseService.instance.createHabitCategory(suggested);
    } catch (e) {
      _showSnack('errors.internal_error'.tr(), Colors.red);
      return null;
    }
  }

  // Ok tuşuna basıldığında çalışacak Supabase Kayıt Fonksiyonu
  Future<void> _saveUsernameAndProceed() async {
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      // ----------------------------------------------------------------
      // 1) Önce alışkanlığı kategoriye eşle (Gemini gerekebilir).
      //    Kullanıcının arkadaşları kabul ederse veya iptal ederse
      //    setup'tan çıkmadan geri dönmeli.
      // ----------------------------------------------------------------
      final category = await _resolveHabitCategory(widget.selectedHabit);
      if (category == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ----------------------------------------------------------------
      // 2) Auth metadata'yı güncelle (LEGACY alanlar geriye dönük uyumlu).
      // ----------------------------------------------------------------
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'habit': widget.selectedHabit, // slug (eski home_screen okuması)
            'goal': widget.selectedGoal,
            'is_setup_complete': true,
          },
        ),
      );

      // ----------------------------------------------------------------
      // 3) profiles upsert + display_name set.
      // ----------------------------------------------------------------
      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'display_name': username,
        'habit': widget.selectedHabit,
        'goal': widget.selectedGoal,
      });

      // ----------------------------------------------------------------
      // 4) user_habits kaydını oluştur (zaten varsa unique constraint
      //    nedeniyle insert düşer → onu yakalayıp yutuyoruz).
      // ----------------------------------------------------------------
      try {
        await SupabaseService.instance.addUserHabit(
          habitCategoryId: category.id!,
          motivation: null,
        );
      } on PostgrestException catch (e) {
        // 23505 = unique_violation (aynı user için aynı habit zaten var)
        if (e.code != '23505') rethrow;
      }

      // 5) Ana ekrana geç
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } on AuthException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (_) {
      _showSnack('username_setup.save_error'.tr(), Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------------------
  // UI YARDIMCILARI
  // ----------------------------------------------------------------------

  void _showSnack(String message, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }

  /// Mevcut hand-drawn tasarımla uyumlu, siyah border'lı bilgi dialog'u
  Future<void> _showInvalidDialog(String reason) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: Text(
          'gemini.invalid_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        content: Text(
          reason,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.ok'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Gemini önerisini kullanıcıya gösterip onay alır.
  Future<bool?> _showConfirmDialog(HabitCategory cat) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        title: Column(
          children: [
            Text(
              'gemini.confirm_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'gemini.confirm_subtitle'.tr(),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Habit adı + (opsiyonel) açıklama
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  if (cat.description != null && cat.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cat.description!,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Puanlar
            _ScoreRow(label: 'gemini.scores.daily'.tr(),       value: '${cat.baseDailyPoints}'),
            _ScoreRow(label: 'gemini.scores.health'.tr(),      value: '${cat.healthImpact}/10'),
            _ScoreRow(label: 'gemini.scores.social'.tr(),      value: '${cat.socialImpact}/10'),
            _ScoreRow(label: 'gemini.scores.financial'.tr(),   value: '${cat.financialImpact}/10'),
            _ScoreRow(label: 'gemini.scores.addiction'.tr(),   value: '${cat.addictionLevel}/10'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'gemini.confirm_cancel'.tr(),
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'gemini.confirm_add'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'username_setup.title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: TextField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  onChanged: (text) {
                    setState(() {
                      _isReadyToProceed = text.trim().length >= 3;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'username_setup.hint'.tr(),
                    hintStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'username_setup.min_chars'.tr(),
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60),
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.black),
                    if (_loadingMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _loadingMessage!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                )
              else
                IconButton(
                  iconSize: 60,
                  icon: const Icon(Icons.arrow_circle_right_outlined),
                  color: _isReadyToProceed ? Colors.red : Colors.grey.shade300,
                  onPressed: _isReadyToProceed ? _saveUsernameAndProceed : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// PRIVATE WIDGETS
// ----------------------------------------------------------------------

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
