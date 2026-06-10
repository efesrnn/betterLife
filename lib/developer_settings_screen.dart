import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'services/habit_repository.dart';

// Gelistirici araclari: benzer habit birlestirme, katalog duzenleme ve silme.
// Son kullaniciya yonelik olmadigi icin metinler bilerek Ingilizce birakildi.
class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() =>
      _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  final _repo = HabitRepository();
  final _searchCtrl = TextEditingController();
  bool _merging = false;
  bool _loading = true;
  List<Habit> _catalog = [];

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
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getHabitCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Habit> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog
        .where((h) =>
            h.titleTr.toLowerCase().contains(q) ||
            h.titleEn.toLowerCase().contains(q) ||
            h.slug.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _runMerge() async {
    setState(() => _merging = true);
    try {
      final res = await _repo.runHabitDeduplication();
      final merged = (res['merged'] as num?)?.toInt() ?? 0;
      final promoted = (res['promoted'] as num?)?.toInt() ?? 0;
      _snack(AppStrings.adminMergeDone(merged, promoted));
      _loadCatalog();
    } catch (e) {
      _snack(AppStrings.adminMergeFailed(e), isError: true);
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  Future<void> _deleteHabit(Habit h) async {
    final locale = context.locale.languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete habit',
            style:
                TextStyle(color: ctx.appText, fontWeight: FontWeight.w800)),
        content: Text(
            '"${h.title(locale)}" will be permanently removed from the catalog. This cannot be undone.',
            style: TextStyle(color: ctx.appSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancel', style: TextStyle(color: ctx.appSub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteHabit(h.id);
      _snack('Habit deleted');
      _loadCatalog();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  // Secilen habit'in alanlarini duzenleme formu (bottom sheet).
  Future<void> _editHabit(Habit h) async {
    final titleTr = TextEditingController(text: h.titleTr);
    final titleEn = TextEditingController(text: h.titleEn);
    final icon = TextEditingController(text: h.icon ?? '');
    final unit = TextEditingController(text: h.unit ?? '');
    final basePoints =
        TextEditingController(text: h.baseDailyPoints.toStringAsFixed(0));
    final difficulty =
        TextEditingController(text: h.difficultyWeight.toString());
    final category = TextEditingController(text: h.categoryTag ?? '');
    final risk = TextEditingController(text: h.riskLevel ?? '');
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit habit (${h.slug})',
                    style: TextStyle(
                        color: ctx.appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _sheetField(ctx, titleTr, 'Title (TR)'),
                _sheetField(ctx, titleEn, 'Title (EN)'),
                Row(children: [
                  Expanded(child: _sheetField(ctx, icon, 'Icon (emoji)')),
                  const SizedBox(width: 10),
                  Expanded(child: _sheetField(ctx, unit, 'Unit')),
                ]),
                Row(children: [
                  Expanded(
                      child: _sheetField(ctx, basePoints, 'Base daily points',
                          number: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _sheetField(ctx, difficulty, 'Difficulty weight',
                          number: true)),
                ]),
                Row(children: [
                  Expanded(child: _sheetField(ctx, category, 'Category tag')),
                  const SizedBox(width: 10),
                  Expanded(child: _sheetField(ctx, risk, 'Risk level')),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ctx.appAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final patch = <String, dynamic>{
                              'title_tr': titleTr.text.trim(),
                              'title_en': titleEn.text.trim(),
                              'icon': icon.text.trim(),
                              'unit': unit.text.trim(),
                            };
                            final bp = double.tryParse(
                                basePoints.text.replaceAll(',', '.'));
                            if (bp != null) patch['base_daily_points'] = bp;
                            final dw = double.tryParse(
                                difficulty.text.replaceAll(',', '.'));
                            if (dw != null) patch['difficulty_weight'] = dw;
                            if (category.text.trim().isNotEmpty) {
                              patch['category_tag'] =
                                  category.text.trim().toUpperCase();
                            }
                            if (risk.text.trim().isNotEmpty) {
                              patch['risk_level'] =
                                  risk.text.trim().toUpperCase();
                            }
                            try {
                              await _repo.updateHabitAttributes(h.id, patch);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack('Habit updated');
                              _loadCatalog();
                            } catch (e) {
                              setSheet(() => saving = false);
                              _snack('Update failed: $e', isError: true);
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(BuildContext ctx, TextEditingController c, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: ctx.appText, fontWeight: FontWeight.w600),
        cursorColor: ctx.appAccent,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ctx.appSub, fontSize: 13),
          isDense: true,
          filled: true,
          fillColor: ctx.appBg,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ctx.appBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ctx.appAccent, width: 1.5),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : context.appAccent,
    ));
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
        title: Text(AppStrings.developerSettings,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _mergeCard(context),
          const SizedBox(height: 24),
          Text('HABIT CATALOG',
              style: TextStyle(
                  color: context.appSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            cursorColor: context.appAccent,
            style:
                TextStyle(color: context.appText, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search habits',
              hintStyle: TextStyle(color: context.appSub),
              prefixIcon: Icon(Icons.search_rounded, color: context.appSub),
              isDense: true,
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
          const SizedBox(height: 12),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child:
                      CircularProgressIndicator(color: context.appAccent)),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No habits found',
                  style: TextStyle(color: context.appSub)),
            )
          else
            ..._filtered.map((h) => _habitTile(context, h, locale)),
        ],
      ),
    );
  }

  Widget _mergeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: context.appAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.merge_type_rounded,
                  color: context.appAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(AppStrings.adminMergeNow,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(AppStrings.adminMergeDesc,
              style:
                  TextStyle(color: context.appSub, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
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
              onPressed: _merging ? null : _runMerge,
              child: _merging
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                        Text(AppStrings.adminMergeRunning,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text(AppStrings.adminMergeNow,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitTile(BuildContext context, Habit h, String locale) {
    return GestureDetector(
      onTap: () => _editHabit(h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(children: [
          Text(safeHabitIcon(h.icon), style: const TextStyle(fontSize: 22)),
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
                  Text(
                      '${h.slug}  ·  ${h.baseDailyPoints.toStringAsFixed(0)} pts  ·  x${h.difficultyWeight}',
                      style: TextStyle(color: context.appSub, fontSize: 11)),
                ]),
          ),
          IconButton(
            onPressed: () => _deleteHabit(h),
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 20),
          ),
          Icon(Icons.edit_rounded, color: context.appSub, size: 16),
        ]),
      ),
    );
  }
}
