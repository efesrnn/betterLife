import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'habit_detail_screen.dart';
import 'services/habit_repository.dart';

// ─── Habits sekmesi (Home içinde body olarak kullanılır) ──────────────────────
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _repo = HabitRepository();
  bool _loading = true;
  List<UserHabit> _habits = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getActiveHabits();
      if (!mounted) return;
      setState(() {
        _habits = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const AddHabitScreen()));
    if (added == true) _load();
  }

  Future<void> _openCatalog() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const HabitCatalogScreen()));
  }

  Future<void> _remove(UserHabit uh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.removeHabit,
            style:
                TextStyle(color: context.appText, fontWeight: FontWeight.w800)),
        content: Text(
            AppStrings.removeHabitConfirm(
                uh.habit?.title(context.locale.languageCode) ?? ''),
            style: TextStyle(color: context.appSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel,
                  style: TextStyle(color: context.appSub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.remove,
                  style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.toggleHabitPause(uh.id);
    } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Text(AppStrings.myHabits,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              _iconBtn(context, Icons.menu_book_rounded, _openCatalog),
              const SizedBox(width: 10),
              _iconBtn(context, Icons.add_rounded, _openAdd),
            ],
          ),
        ),
        Divider(color: context.appBorder, height: 1),
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: context.appAccent))
              : _habits.isEmpty
                  ? _empty(context)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: context.appAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _habits.length,
                        itemBuilder: (_, i) =>
                            _habitCard(context, _habits[i], locale),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_outlined, size: 52, color: context.appSub),
          const SizedBox(height: 12),
          Text(AppStrings.habitsEmptyTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appSub)),
          const SizedBox(height: 4),
          Text(AppStrings.habitsEmptySub,
              style: TextStyle(fontSize: 13, color: context.appTextDim)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppStrings.addHabit,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openAdd,
          ),
        ],
      ),
    );
  }

  Widget _habitCard(BuildContext context, UserHabit uh, String locale) {
    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(context,
            MaterialPageRoute(builder: (_) => HabitDetailScreen(userHabit: uh)));
        if (changed == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(safeHabitIcon(uh.habit?.icon),
                style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(uh.habit?.title(locale) ?? '',
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(AppStrings.programType(uh.programType.value),
                      style: TextStyle(color: context.appSub, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(AppStrings.habitDayStreak(uh.currentStreak),
                      style: TextStyle(
                          color: context.appAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _remove(uh),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pause_rounded,
                    color: Colors.redAccent, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration:
            BoxDecoration(color: context.appCard, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: context.appText),
      ),
    );
  }
}

// ─── Yeni alışkanlık ekleme (Gemini değerlendirmesi) ──────────────────────────
class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _repo = HabitRepository();
  final _searchCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '4');
  bool _durMonths = false; // false = hafta, true = ay

  // Katalog (anlık metin araması) — seed + topluluk habit'leri.
  List<Habit> _catalog = [];
  bool _catalogLoading = true;

  // AI değerlendirme sonucu (yalnızca katalogda yoksa kullanılır).
  HabitSearchResult? _ai;
  bool _aiLoading = false;

  // Seçilen habit + plan durumu.
  String? _selectedId;
  String _selectedTitle = '';
  String _selectedUnit = '';
  bool _selectedPositive = false; // POSITIVE_BUILD / INCREASE → artır/koru
  ProgramType _program = ProgramType.quit;
  int _step = 0; // 0 = ara/seç, 1 = planla
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _startCtrl.dispose();
    _targetCtrl.dispose();
    _costCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await _repo.getHabitCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _catalogLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _catalogLoading = false);
    }
  }

  List<Habit> _filteredCatalog(String locale) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog.where((h) {
      return h.title(locale).toLowerCase().contains(q) ||
          h.titleTr.toLowerCase().contains(q) ||
          h.titleEn.toLowerCase().contains(q) ||
          h.slug.toLowerCase().contains(q);
    }).toList();
  }

  // Habit seçilince program/birim/yön çözülür ve plan adımına geçilir.
  void _select(String id, String title,
      {String? type, String? direction, String? unit}) {
    String? t = type, d = direction, u = unit;
    if (t == null || d == null || u == null) {
      final inCat = _catalog.where((h) => h.id == id).toList();
      if (inCat.isNotEmpty) {
        t ??= inCat.first.type;
        d ??= inCat.first.targetDirection;
        u ??= inCat.first.unit;
      }
    }
    final positive = t == 'POSITIVE_BUILD' || d == 'INCREASE';
    setState(() {
      _selectedId = id;
      _selectedTitle = title;
      _selectedUnit = u ?? '';
      _selectedPositive = positive;
      _program = positive ? ProgramType.gradualIncrease : ProgramType.quit;
      _step = 1;
    });
  }

  // forceNew=true → benzerlik olsa da yeni habit oluştur.
  Future<void> _evaluate({bool forceNew = false}) async {
    final locale = context.locale.languageCode;
    final text = _searchCtrl.text.trim();
    if (text.length < 2) return;
    setState(() {
      _aiLoading = true;
      if (!forceNew) _ai = null;
    });
    try {
      final res = await _repo.searchOrCreateHabit(
          userInput: text, locale: locale, forceNew: forceNew);
      if (!mounted) return;
      setState(() {
        _ai = res;
        _aiLoading = false;
      });
      // EXACT veya NEW → doğrudan plan adımına geç.
      if (res.isExactMatch || res.isNewHabit) {
        final id = res.habitId ?? '';
        final m = res.habit?['habit_metadata'] as Map<String, dynamic>?;
        final p = res.habit?['progression'] as Map<String, dynamic>?;
        final cat = _catalog.where((h) => h.id == id).toList();
        String title = text;
        if (cat.isNotEmpty) {
          title = cat.first.title(locale);
        } else if (m != null) {
          final raw = locale == 'tr' ? m['title_tr'] : m['title_en'];
          if (raw is String && raw.trim().isNotEmpty) title = raw;
        }
        String? unitVal;
        if (m != null) {
          final picked = locale == 'tr' ? m['unit_tr'] : m['unit_en'];
          unitVal = (picked ?? m['unit_tr'] ?? m['unit_en']) as String?;
        }
        _select(
          id,
          title,
          type: m?['type'] as String?,
          direction: p?['target_direction'] as String?,
          unit: unitVal,
        );
      }
    } on HabitQuestException catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      _snack(e.messageKey.tr());
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      _snack(AppStrings.errorWith(e));
    }
  }

  Future<void> _add() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _busy = true);

    final start = double.tryParse(_startCtrl.text.replaceAll(',', '.'));
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.'));
    final isGradual = _program == ProgramType.gradualDecrease ||
        _program == ProgramType.gradualIncrease;
    DateTime? targetDate;
    int? phaseDays;
    if (isGradual) {
      final n = int.tryParse(_durationCtrl.text) ?? 4;
      final days = (_durMonths ? n * 30 : n * 7).clamp(7, 3650);
      targetDate = DateTime.now().add(Duration(days: days));
      phaseDays = days;
    }

    try {
      await _repo.addUserHabit(
        habitId: id,
        programType: _program,
        startValue: start,
        targetValue: _program == ProgramType.quit ? 0 : target,
        unitCost: cost,
        targetDate: targetDate,
        phaseDurationDays: phaseDays,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on HabitQuestException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.messageKey.tr());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(AppStrings.errorWith(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(AppStrings.addHabit,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body:
          _step == 0 ? _searchStep(context, locale) : _planStep(context, locale),
    );
  }

  // ── Adım 0: katalogdan ara/seç veya AI ile yeni ekle ──
  Widget _searchStep(BuildContext context, String locale) {
    final q = _searchCtrl.text.trim();
    final filtered = _filteredCatalog(locale);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _searchCtrl,
          cursorColor: context.appAccent,
          style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: AppStrings.searchHint,
            hintStyle: TextStyle(color: context.appSub),
            prefixIcon: Icon(Icons.search_rounded, color: context.appSub),
            filled: true,
            fillColor: context.appCard,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.appBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.appAccent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(AppStrings.pickFromCatalog.toUpperCase(),
            style: TextStyle(
                color: context.appSub,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        if (_catalogLoading)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: context.appAccent)),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(AppStrings.noCatalogMatch,
                style: TextStyle(color: context.appSub)),
          )
        else
          ...filtered.map((h) => _catalogTile(context, h, locale)),
        const SizedBox(height: 16),
        if (q.length >= 2) _aiButton(context, q),
        const SizedBox(height: 12),
        if (_aiLoading)
          Center(
            child: Column(children: [
              CircularProgressIndicator(color: context.appAccent),
              const SizedBox(height: 10),
              Text(AppStrings.evaluating,
                  style: TextStyle(color: context.appSub)),
            ]),
          )
        else if (_ai != null)
          _aiResultView(context, locale),
      ],
    );
  }

  Widget _catalogTile(BuildContext context, Habit h, String locale) {
    return GestureDetector(
      onTap: () => _select(h.id, h.title(locale),
          type: h.type, direction: h.targetDirection, unit: h.unitFor(locale)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(children: [
          Text(safeHabitIcon(h.icon), style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.title(locale),
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(AppStrings.category(h.categoryTag ?? 'HEALTH'),
                      style: TextStyle(color: context.appSub, fontSize: 11)),
                ]),
          ),
          Icon(Icons.add_circle_outline_rounded, color: context.appAccent),
        ]),
      ),
    );
  }

  Widget _aiButton(BuildContext context, String q) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appAccent.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppStrings.orCreateAi,
            style: TextStyle(
                color: context.appText,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(AppStrings.evaluateInput(q),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _aiLoading ? null : () => _evaluate(),
          ),
        ),
      ]),
    );
  }

  Widget _aiResultView(BuildContext context, String locale) {
    final r = _ai!;
    if (r.isInvalid) {
      return _infoCard(context,
          icon: Icons.block_rounded,
          color: Colors.redAccent,
          title: AppStrings.habitInvalid,
          body: r.getRejectionReason(locale) ?? '');
    }
    // MAYBE → tekilleştirilmiş öneriler + "yine de yeni oluştur" (engellemez)
    if (r.isMaybeMatch && r.suggestions != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoCard(context,
            icon: Icons.info_outline_rounded,
            color: context.appAccent,
            title: AppStrings.aiSuggestTitle,
            body: ''),
        const SizedBox(height: 10),
        ...r.suggestions!.map((s) => GestureDetector(
              onTap: () => _select(s.habitId, s.title(locale)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(s.title(locale),
                        style: TextStyle(
                            color: context.appText,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(
                      '${(s.similarity * 100).round()}% ${AppStrings.matchLabel}',
                      style: TextStyle(color: context.appSub, fontSize: 11)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: context.appSub),
                ]),
              ),
            )),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appAccent,
              side: BorderSide(color: context.appAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppStrings.createAnyway,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _aiLoading ? null : () => _evaluate(forceNew: true),
          ),
        ),
      ]);
    }
    // EXACT/NEW → _evaluate zaten plan adımına geçirdi.
    return const SizedBox.shrink();
  }

  // ── Adım 1: program + plan ──
  Widget _planStep(BuildContext context, String locale) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: context.appAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_selectedTitle,
                style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 18),
        _programSelector(context),
        const SizedBox(height: 18),
        _planSection(context),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy ? null : _add,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(AppStrings.addToMyHabits,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _planSection(BuildContext context) {
    final isGradual = _program == ProgramType.gradualDecrease ||
        _program == ProgramType.gradualIncrease;
    final showStart = _program != ProgramType.maintain;
    final showTarget = _program != ProgramType.quit;
    final start = double.tryParse(_startCtrl.text.replaceAll(',', '.'));
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
    final n = int.tryParse(_durationCtrl.text) ?? 4;
    final days = _durMonths ? n * 30 : n * 7;
    final showPreview = isGradual &&
        start != null &&
        target != null &&
        ((_program == ProgramType.gradualDecrease && start > target) ||
            (_program == ProgramType.gradualIncrease && target > start));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.planTitle.toUpperCase(),
              style: TextStyle(
                  color: context.appSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          if (showStart) ...[
            _numField(context, _startCtrl, _unitLabel(AppStrings.startAmount)),
            const SizedBox(height: 10),
          ],
          if (showTarget) ...[
            _numField(
                context, _targetCtrl, _unitLabel(AppStrings.targetAmount)),
            const SizedBox(height: 10),
          ],
          _numField(context, _costCtrl, AppStrings.unitCostLabel),
          if (isGradual) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _numField(
                      context, _durationCtrl, AppStrings.durationLabel)),
              const SizedBox(width: 10),
              _durToggle(context),
            ]),
            if (showPreview) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.timeline_rounded,
                    size: 16, color: context.appAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      AppStrings.schedulePreview(
                          _fmt(start), _fmt(target), _selectedUnit, days),
                      style: TextStyle(
                          color: context.appAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  // Birim biliniyorsa etikete ekler: "Normalde günde ne kadar? (saat)".
  String _unitLabel(String base) =>
      _selectedUnit.isEmpty ? base : '$base ($_selectedUnit)';

  Widget _numField(
      BuildContext context, TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
      cursorColor: context.appAccent,
      onChanged: (_) => setState(() {}),
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

  Widget _durToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(children: [
        _durPill(context, AppStrings.weeksLabel, !_durMonths,
            () => setState(() => _durMonths = false)),
        _durPill(context, AppStrings.monthsLabel, _durMonths,
            () => setState(() => _durMonths = true)),
      ]),
    );
  }

  Widget _durPill(
      BuildContext context, String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? context.appAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : context.appSub,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }

  // Negatif (bırak/azalt) vs pozitif (artır/koru) habit'e göre uygun programlar.
  List<ProgramType> get _programOptions => _selectedPositive
      ? [ProgramType.gradualIncrease, ProgramType.maintain]
      : [ProgramType.quit, ProgramType.gradualDecrease, ProgramType.reduce];

  Widget _programSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.chooseProgram.toUpperCase(),
            style: TextStyle(
                color: context.appSub,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        ..._programOptions.map((pt) {
          final sel = _program == pt;
          return GestureDetector(
            onTap: () => setState(() => _program = pt),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel ? context.appAccent.withAlpha(22) : context.appCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sel ? context.appAccent : context.appBorder,
                    width: sel ? 2 : 1),
              ),
              child: Row(children: [
                Icon(
                    sel
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: sel ? context.appAccent : context.appSub,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.programType(pt.value),
                            style: TextStyle(
                                color: context.appText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(AppStrings.programDesc(pt.value),
                            style: TextStyle(
                                color: context.appSub, fontSize: 12)),
                      ]),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _infoCard(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 14)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body,
                      style:
                          TextStyle(color: context.appText, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Katalog (varsayılan + topluluk alışkanlıkları) ───────────────────────────
class HabitCatalogScreen extends StatefulWidget {
  const HabitCatalogScreen({super.key});

  @override
  State<HabitCatalogScreen> createState() => _HabitCatalogScreenState();
}

class _HabitCatalogScreenState extends State<HabitCatalogScreen> {
  final _repo = HabitRepository();
  bool _loading = true;
  List<Habit> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.getHabitCatalog();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        title: Text(AppStrings.catalogTitle,
            style: TextStyle(
                color: context.appText, fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.appAccent))
          : _items.isEmpty
              ? Center(
                  child: Text(AppStrings.noCatalog,
                      style: TextStyle(color: context.appSub)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final h = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appCard,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(safeHabitIcon(h.icon),
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.title(locale),
                                    style: TextStyle(
                                        color: context.appText,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    '${AppStrings.category(h.categoryTag ?? 'HEALTH')} · ${AppStrings.riskLevel(h.riskLevel ?? 'MEDIUM')}',
                                    style: TextStyle(
                                        color: context.appSub, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
