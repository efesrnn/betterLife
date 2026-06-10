import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'services/habit_repository.dart';

// --- Home: aktif habit'ler arasında kaydırmalı sayfalar ----------------------
class HomeHabitsPager extends StatefulWidget {
  const HomeHabitsPager({super.key});
  @override
  State<HomeHabitsPager> createState() => _HomeHabitsPagerState();
}

class _HomeHabitsPagerState extends State<HomeHabitsPager> {
  final _repo = HabitRepository();
  final _controller = PageController();
  bool _loading = true;
  List<UserHabit> _habits = [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // silent: log/relapse sonrası sessiz yenileme - tam ekran spinner gösterip
    // sayfa state'lerini yok etmez (sayaç sıfırlanmaz, takvim yerinde güncellenir).
    if (!silent) setState(() => _loading = true);
    try {
      final list = await _repo.getActiveHabits();
      if (!mounted) return;
      setState(() {
        _habits = list;
        _loading = false;
        if (_page >= list.length) _page = list.isEmpty ? 0 : list.length - 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: context.appAccent));
    }
    if (_habits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.appTextDim)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _habits.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => HabitHomeView(
                userHabit: _habits[i], onChanged: () => _load(silent: true)),
          ),
        ),
        if (_habits.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_habits.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? context.appAccent : context.appBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// --- Tek habit sayfası (program tipine duyarlı) ------------------------------
class HabitHomeView extends StatefulWidget {
  final UserHabit userHabit;
  final VoidCallback onChanged;
  const HabitHomeView(
      {super.key, required this.userHabit, required this.onChanged});

  @override
  State<HabitHomeView> createState() => _HabitHomeViewState();
}

class _HabitHomeViewState extends State<HabitHomeView>
    with AutomaticKeepAliveClientMixin {
  final _repo = HabitRepository();
  List<DailyLog> _logs = [];
  bool _busy = false;
  double _todayValue = 0;

  UserHabit get uh => widget.userHabit;
  bool get _isQuit => uh.programType == ProgramType.quit;

  // Sayfalar arasinda gecis yapilinca state korunur, sayac sifirlanmaz.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant HabitHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ust liste sessizce yenilendiginde (ornegin log sonrasi) ayni state
    // farkli bir habit verisiyle yeniden kullanilabilir, loglari tazele.
    if (oldWidget.userHabit.id != uh.id ||
        oldWidget.userHabit.lastLogDate != uh.lastLogDate) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _repo.getHabitHistory(uh.id, limit: 60);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        // Bugun zaten log atildiysa sayac 0 yerine girilen degeri gostersin.
        final today = DateTime.now().toIso8601String().substring(0, 10);
        for (final l in logs) {
          if (l.logDate.startsWith(today)) {
            _todayValue = l.reportedValue;
            break;
          }
        }
      });
    } catch (_) {}
  }

  // Kademeli plan: gün bazlı hedef. Birimler (öğün, sigara vb.) tam sayı
  // olduğu için eğriden çıkan ara değer en yakın tam sayıya yuvarlanır,
  // başlangıç ile nihai hedef arasında kalacak şekilde sınırlanır.
  double _targetForDay(int dayIndex) {
    final start = uh.startValue ?? 0;
    final target = uh.targetValue ?? 0;
    if (uh.programType == ProgramType.gradualDecrease ||
        uh.programType == ProgramType.gradualIncrease) {
      final total = uh.targetDate != null
          ? uh.targetDate!.difference(uh.sinceDate).inDays
          : 0;
      final raw = gradualTargetForDay(
          start: start, target: target, totalDays: total, dayIndex: dayIndex);
      return raw
          .roundToDouble()
          .clamp(math.min(start, target), math.max(start, target))
          .toDouble();
    }
    return uh.currentDailyTarget ?? target;
  }

  // Tam sayıysa ondalıksız, değilse tek ondalıkla gösterir (5.0 yerine 5).
  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _relapse() async {
    // Sifirlamadan once kullaniciyi uyar, onay almadan islem yapma
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.relapseConfirmTitle,
            style:
                TextStyle(color: ctx.appText, fontWeight: FontWeight.w800)),
        content: Text(AppStrings.relapseConfirmBody,
            style: TextStyle(color: ctx.appSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel,
                  style: TextStyle(color: ctx.appSub))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.relapseConfirmBtn,
                  style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.resetHabitStart(uh.id);
      // Profil akisinda gorunsun
      await _repo.logHabitEvent(
        userHabitId: uh.id,
        eventType: 'RELAPSE',
        titleTr: uh.habit?.titleTr,
        titleEn: uh.habit?.titleEn,
        icon: uh.habit?.icon,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged();
  }

  Future<void> _logToday() async {
    setState(() => _busy = true);
    bool ok = false;
    String? errMsg;
    try {
      await _repo.logDailyValue(uh.id, _todayValue);
      ok = true;
    } on HabitQuestException catch (e) {
      errMsg = (e.details != null && e.details!.isNotEmpty)
          ? '${e.messageKey.tr()}: ${e.details}'
          : e.messageKey.tr();
    } catch (e) {
      errMsg = AppStrings.errorWith(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _loadLogs(); // her durumda takvimi tazele (mevcut kayıt da görünsün)
    widget.onChanged();
    _snack(ok ? AppStrings.loggedTodayMsg : (errMsg ?? ''), ok: ok);
  }

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: ok ? context.appAccent : Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin icin gerekli
    final tr = context.locale.languageCode == 'tr';
    final locale = context.locale.languageCode;
    final now = DateTime.now();
    var diff = now.difference(uh.sinceDate);
    if (diff.isNegative) diff = Duration.zero;
    final cleanDays = diff.inDays;
    final dayIndex = cleanDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          _header(context, locale),
          const SizedBox(height: 8),
          if (_isQuit)
            _quitView(context, tr, cleanDays, diff)
          else
            _reduceView(context, tr, dayIndex),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String locale) {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final mo = now.month.toString().padLeft(2, '0');
    return Row(
      children: [
        Text(safeHabitIcon(uh.habit?.icon), style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(uh.habit?.title(locale) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(AppStrings.programType(uh.programType.value),
                  style: TextStyle(
                      color: context.appAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text('$d/$mo',
            style: TextStyle(
                color: context.appSub,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // -- QUIT görünümü (sayaç yok) -----------------------------
  Widget _quitView(
      BuildContext context, bool tr, int cleanDays, Duration diff) {
    final ms = _milestones(tr);
    int prev = 0;
    int nextDays = ms.last[0] as int;
    String nextLabel = ms.last[1] as String;
    for (final m in ms) {
      if (cleanDays < (m[0] as int)) {
        nextDays = m[0] as int;
        nextLabel = m[1] as String;
        break;
      }
      prev = m[0] as int;
    }
    final frac = nextDays > prev
        ? ((cleanDays - prev) / (nextDays - prev)).clamp(0.0, 1.0)
        : 1.0;

    final cleanStr = tr
        ? '${cleanDays}g ${diff.inHours % 24}s ${diff.inMinutes % 60}dk'
        : '${cleanDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m';
    final baseline = uh.startValue ?? 0;
    final cost = uh.unitCost;
    final saved = cleanDays * baseline * cost;
    final avoided = (cleanDays * baseline).round();
    final recovery = (cleanDays * 0.55).clamp(0, 100).toDouble();

    return Column(
      children: [
        const SizedBox(height: 8),
        _gauge(context, frac, cleanDays, nextLabel),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: _stat(context, Icons.timer_outlined, AppStrings.cleanTime,
                  cleanStr)),
          const SizedBox(width: 12),
          Expanded(
              child: _stat(context, Icons.savings_rounded,
                  AppStrings.savedShort, '₺${saved.toStringAsFixed(0)}',
                  color: context.appAccent)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _stat(context, Icons.favorite_rounded,
                  AppStrings.lifeContribution, '%${recovery.toStringAsFixed(0)}',
                  color: context.appAccent)),
          const SizedBox(width: 12),
          Expanded(
              child: _stat(context, Icons.block_rounded,
                  AppStrings.ifContinued,
                  '$avoided ${uh.habit?.unitFor(tr ? 'tr' : 'en') ?? ""}')),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(AppStrings.relapseBtn,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _busy ? null : _relapse,
          ),
        ),
      ],
    );
  }

  // -- REDUCE / GRADUAL görünümü (sayaç + takvim) ------------
  Widget _reduceView(BuildContext context, bool tr, int dayIndex) {
    final target = _targetForDay(dayIndex);
    final locale = tr ? 'tr' : 'en';
    final unit = uh.habit?.unitFor(locale) ?? '';
    final cost = uh.unitCost;
    final logged = uh.loggedToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Bugünkü hedef
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(AppStrings.todayTarget.toUpperCase(),
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text('${_fmtNum(target)} $unit',
                  style: TextStyle(
                      color: context.appAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
              if (uh.startValue != null && uh.targetValue != null) ...[
                const SizedBox(height: 4),
                Text(
                    AppStrings.schedulePreview(
                        (uh.startValue ?? 0).toStringAsFixed(0),
                        (uh.targetValue ?? 0).toStringAsFixed(0),
                        unit,
                        uh.targetDate != null
                            ? uh.targetDate!.difference(uh.sinceDate).inDays
                            : 0),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.appTextDim, fontSize: 11)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Bugünü logla
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  (logged ? AppStrings.loggedTodayMsg : AppStrings.logTodayLabel)
                      .toUpperCase(),
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _roundBtn(context, Icons.remove_rounded, () {
                    setState(() => _todayValue =
                        (_todayValue - 1).clamp(0, 9999).toDouble());
                  }),
                  Expanded(
                    child: Text('${_todayValue.toStringAsFixed(0)} $unit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.appText,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                  ),
                  _roundBtn(context, Icons.add_rounded, () {
                    setState(() => _todayValue += 1);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  // Bugün loglanmışsa da buton aktif kalır, değer güncellenebilir
                  onPressed: _busy ? null : _logToday,
                  child: Text(logged ? AppStrings.updateLogLabel : AppStrings.save,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (cost > 0) ...[
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final under = (uh.startValue ?? 0) - target;
                  final dailySave = (under < 0 ? 0 : under) * cost;
                  return Text(
                      '${AppStrings.savedShort}: ₺${dailySave.toStringAsFixed(0)}/${tr ? "gün" : "day"}',
                      style:
                          TextStyle(color: context.appAccent, fontSize: 12));
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _reduceStats(context, tr),
        const SizedBox(height: 16),
        _calendar(context, tr),
      ],
    );
  }

  // -- Tasarruf + hedefe uyum + ilerleme barı ----------------
  Widget _reduceStats(BuildContext context, bool tr) {
    final start = uh.startValue ?? 0;
    final tgt = uh.targetValue ?? 0;
    final cost = uh.unitCost;
    final savedTotal = _logs.fold<double>(
        0, (s, l) => s + ((start - l.reportedValue).clamp(0, 100000)) * cost);
    final daysOnTarget = _logs.where((l) => l.isSuccess).length;
    final isGradual = uh.programType == ProgramType.gradualDecrease ||
        uh.programType == ProgramType.gradualIncrease;
    double progress;
    String progLabel;
    if (isGradual && uh.targetDate != null) {
      final total = uh.targetDate!.difference(uh.sinceDate).inDays;
      final elapsed = DateTime.now().difference(uh.sinceDate).inDays;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
      progLabel = AppStrings.planProgress;
    } else {
      final latest = _logs.isNotEmpty ? _logs.first.reportedValue : start;
      progress = (start - tgt).abs() > 0
          ? ((start - latest) / (start - tgt)).clamp(0.0, 1.0)
          : 0.0;
      progLabel = AppStrings.toGoal;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: _stat(context, Icons.savings_rounded,
                    AppStrings.savedShort, '₺${savedTotal.toStringAsFixed(0)}',
                    color: context.appAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _stat(context, Icons.event_available_rounded,
                    AppStrings.daysOnTarget, '$daysOnTarget')),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progLabel,
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text('%${(progress * 100).toStringAsFixed(0)}',
                  style: TextStyle(
                      color: context.appAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation<Color>(context.appAccent),
            ),
          ),
        ],
      ),
    );
  }

  // -- Aylık takvim (loglar hedefe göre renkli) --------------
  Widget _calendar(BuildContext context, bool tr) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leading = (first.weekday - 1) % 7; // Pazartesi=0
    final byDate = <String, DailyLog>{};
    for (final l in _logs) {
      byDate[l.logDate.substring(0, 10)] = l;
    }
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(now.year, now.month, day);
      final key = date.toIso8601String().substring(0, 10);
      final log = byDate[key];
      final isToday = day == now.day;
      Color bg = Colors.transparent;
      Color fg = context.appTextDim;
      if (log != null) {
        bg = log.isSuccess
            ? context.appAccent.withAlpha(55)
            : Colors.redAccent.withAlpha(45);
        fg = log.isSuccess ? context.appAccent : Colors.redAccent;
      }
      cells.add(Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: context.appAccent, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    color: log != null ? fg : context.appTextDim,
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w500)),
            if (log != null)
              Text(log.reportedValue.toStringAsFixed(0),
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.calendarTitle.toUpperCase(),
              style: TextStyle(
                  color: context.appSub,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
            children: cells,
          ),
        ],
      ),
    );
  }

  // -- ortak küçük widget'lar --------------------------------
  Widget _stat(BuildContext context, IconData icon, String label, String value,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: context.appAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color ?? context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _gauge(
      BuildContext context, double frac, int cleanDays, String nextLabel) {
    return SizedBox(
      width: 230,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(210, 210),
            painter: MilestoneGaugePainter(
              fraction: frac,
              trackColor: context.appBorder,
              progressColor: context.appAccent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$cleanDays',
                  style: TextStyle(
                      fontSize: 54,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: context.appAccent)),
              const SizedBox(height: 2),
              Text(AppStrings.daysClean,
                  style: TextStyle(
                      color: context.appSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${(frac * 100).round()}%',
                  style: TextStyle(
                      color: context.appTextDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Positioned(
            bottom: 6,
            child: Column(
              children: [
                Text(AppStrings.nextLabel,
                    style: TextStyle(
                        color: context.appSub,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                Text(nextLabel,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.isDarkMode ? const Color(0xFF333333) : context.appBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.appAccent, size: 24),
      ),
    );
  }

  List<List<dynamic>> _milestones(bool tr) => [
        [1, tr ? '1 GÜN' : '1 DAY'],
        [7, tr ? '1 HAFTA' : '1 WEEK'],
        [30, tr ? '1 AY' : '1 MONTH'],
        [90, tr ? '3 AY' : '3 MONTHS'],
        [180, tr ? '6 AY' : '6 MONTHS'],
        [365, tr ? '1 YIL' : '1 YEAR'],
      ];
}

// --- Dairesel "C" milestone göstergesi (altta açıklık) -----------------------
class MilestoneGaugePainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color progressColor;
  MilestoneGaugePainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final prog = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, track);
    canvas.drawArc(rect, start, sweep * fraction.clamp(0.0, 1.0), false, prog);
  }

  @override
  bool shouldRepaint(MilestoneGaugePainter old) =>
      old.fraction != fraction ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}