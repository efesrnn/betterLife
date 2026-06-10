import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'lungs_screen.dart';
import 'services/habit_repository.dart';

/// Bir alışkanlığın Gemini değerlendirme alanlarını gösteren VE planını
/// (eski/normal kullanım, hedef, birim maliyet) düzenlemeye izin veren ekran.
class HabitDetailScreen extends StatefulWidget {
  final UserHabit userHabit;
  const HabitDetailScreen({super.key, required this.userHabit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final _repo = HabitRepository();
  late final TextEditingController _startCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _costCtrl;
  bool _saving = false;
  bool _changed = false;

  UserHabit get uh => widget.userHabit;
  Habit? get _h => uh.habit;
  bool get _isQuit => uh.programType == ProgramType.quit;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(
        text: uh.startValue != null ? _fmt(uh.startValue!) : '');
    _targetCtrl = TextEditingController(
        text: uh.targetValue != null ? _fmt(uh.targetValue!) : '');
    _costCtrl =
        TextEditingController(text: uh.unitCost > 0 ? _fmt(uh.unitCost) : '');
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _targetCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _save() async {
    setState(() => _saving = true);
    final start = double.tryParse(_startCtrl.text.replaceAll(',', '.'));
    final target =
        _isQuit ? 0.0 : double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.'));
    try {
      await _repo.updateUserHabit(
        userHabitId: uh.id,
        startValue: start,
        targetValue: target,
        unitCost: cost,
        syncDailyTargetToTarget: uh.programType == ProgramType.reduce,
      );
      if (!mounted) return;
      _changed = true;
      _snack(AppStrings.detailUpdated, ok: true);
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(AppStrings.errorWith(e));
    }
  }

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: ok ? context.appAccent : Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final h = _h;
    final slug = h?.slug ?? '';
    final isSmoking = slug.contains('smok') || slug.contains('cigaret');
    final unit = h?.unitFor(locale) ?? '';

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        title: Text(AppStrings.detailTitle,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Başlık kartı
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(safeHabitIcon(h?.icon),
                    style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h?.title(locale) ?? '',
                          style: TextStyle(
                              color: context.appText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(AppStrings.programType(uh.programType.value),
                          style: TextStyle(
                              color: context.appAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Düzenlenebilir plan (eski/normal kullanım, hedef, maliyet)
          _editCard(context, unit),

          // Açıklama
          if ((h?.description(locale) ?? '').isNotEmpty)
            _card(context, AppStrings.detailDescription,
                child: Text(h!.description(locale)!,
                    style: TextStyle(
                        color: context.appText, fontSize: 14, height: 1.5))),

          // Seri & program
          _card(context, AppStrings.detailProgram,
              child: Column(
                children: [
                  _kv(context, AppStrings.detailStreak, '${uh.currentStreak}'),
                  _kv(context, AppStrings.detailLongest,
                      '${uh.longestStreak}'),
                  if (uh.currentDailyTarget != null)
                    _kv(context, AppStrings.detailTarget,
                        '${uh.currentDailyTarget!.toStringAsFixed(0)} $unit'),
                ],
              )),

          // Gemini etki matrisi
          if (h != null)
            _card(context, AppStrings.detailImpact,
                child: Column(
                  children: [
                    _bar(context, AppStrings.detailHealth, h.healthImpact),
                    _bar(context, AppStrings.detailMental, h.mentalDiscipline),
                    _bar(context, AppStrings.detailFinancial,
                        h.financialImpact),
                    _bar(context, AppStrings.detailTime, h.timeImpact),
                    _bar(context, AppStrings.detailSocial, h.socialImpact),
                  ],
                )),

          // Puanlama + risk + kategori
          if (h != null)
            _card(context, AppStrings.detailScoring,
                child: Column(
                  children: [
                    _kv(context, AppStrings.detailBasePoints,
                        h.baseDailyPoints.toStringAsFixed(0)),
                    _kv(context, AppStrings.detailDifficulty,
                        '${h.difficultyWeight.toStringAsFixed(1)}x'),
                    _kv(context, AppStrings.detailCategory,
                        AppStrings.category(h.categoryTag ?? 'HEALTH')),
                    _kv(context, AppStrings.detailRisk,
                        AppStrings.riskLevel(h.riskLevel ?? 'MEDIUM')),
                  ],
                )),

          // Sigara için akciğer sağlığı (yalnızca ilgili habit'te)
          if (isSmoking) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: Text(AppStrings.lungHealthMenu,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openLungs(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editCard(BuildContext context, String unit) {
    String lbl(String base) => unit.isEmpty ? base : '$base ($unit)';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.detailEditPlan.toUpperCase(),
              style: TextStyle(
                  color: context.appSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _numField(context, _startCtrl, lbl(AppStrings.startAmount)),
          if (!_isQuit) ...[
            const SizedBox(height: 10),
            _numField(context, _targetCtrl, lbl(AppStrings.targetAmount)),
          ],
          const SizedBox(height: 10),
          _numField(context, _costCtrl, AppStrings.unitCostLabel),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(AppStrings.save,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(
      BuildContext context, TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
      cursorColor: context.appAccent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.appSub, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: context.appBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appAccent, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _openLungs(BuildContext context) async {
    double score = 10;
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        final p = await client
            .from('profiles')
            .select('lung_score')
            .eq('id', uid)
            .maybeSingle();
        if (p != null && p['lung_score'] != null) {
          score = (p['lung_score'] as num).toDouble();
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: context.appBg,
          appBar: AppBar(
            backgroundColor: context.appBg,
            elevation: 0,
            iconTheme: IconThemeData(color: context.appText),
            title: Text(AppStrings.lungHealthMenu,
                style: TextStyle(
                    color: context.appText, fontWeight: FontWeight.w800)),
            centerTitle: true,
          ),
          body: LungsScreen(lungScore: score),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: context.appSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: context.appSub, fontSize: 14)),
          Text(v,
              style: TextStyle(
                  color: context.appText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(color: context.appText, fontSize: 13)),
              Text('$value/10',
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value.clamp(0, 10)) / 10.0,
              minHeight: 6,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(context.appAccent),
            ),
          ),
        ],
      ),
    );
  }
}
