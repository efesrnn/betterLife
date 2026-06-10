import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_theme.dart';
import 'app_strings.dart';
import 'services/habit_repository.dart';

/// Herkese açık profil: header (bu ay/toplam puan + en yüksek seri) +
/// alışkanlıklar (her birinin kendi skoru, tıklayınca ŞEFFAF puan kırılımı) +
/// son 20 aktivite (tarih/saatle).
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> profile;
  final bool isMe;
  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.profile,
    this.isMe = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _repo = HabitRepository();
  bool _loading = true;
  double _monthly = 0;
  int _bestStreak = 0;
  List<PublicHabit> _habits = [];
  List<ActivityItem> _activities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await _repo.getUserHabitsPublic(widget.userId);
      final a = await _repo.getUserActivityFeed(widget.userId, limit: 20);
      final ms = await _repo.getMonthlyScores([widget.userId]);

      // Relapse / silme olaylarini da akisa kat (tablo yoksa bos gecilir)
      List<ActivityItem> events = [];
      try {
        events = await _repo.getHabitEvents(widget.userId, limit: 20);
      } catch (_) {}
      final merged = [...a, ...events]
        ..sort((x, y) => y.ts.compareTo(x.ts));

      if (!mounted) return;
      final s = ms[widget.userId];
      setState(() {
        _habits = h;
        _activities = merged.take(20).toList();
        _monthly = s?.monthly ?? 0;
        _bestStreak = s?.bestStreak ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _dt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _activityText(ActivityItem a, String locale) {
    final habit = a.title(locale);
    switch (a.kind) {
      case 'STARTED':
        return AppStrings.activityStarted(habit);
      case 'MILESTONE':
        return AppStrings.activityMilestone(habit, a.milestoneDay ?? 0);
      case 'RELAPSE':
        return AppStrings.activityRelapse(habit);
      case 'REMOVED':
        return AppStrings.activityRemoved(habit);
      default:
        if (a.value == null) return AppStrings.activityLoggedClean(habit);
        return AppStrings.activityLogged(habit, _fmt(a.value!), a.unit ?? '');
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'STARTED':
        return Icons.flag_rounded;
      case 'MILESTONE':
        return Icons.emoji_events_rounded;
      case 'RELAPSE':
        return Icons.refresh_rounded;
      case 'REMOVED':
        return Icons.delete_outline_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  // Bir habit'e tıklayınca puanının NASIL hesaplandığını şeffaf gösterir.
  Future<void> _showBreakdown(PublicHabit h) async {
    ScoreBreakdown? bd;
    try {
      bd = await _repo.getHabitScoreBreakdown(h.userHabitId);
    } catch (_) {}
    if (!mounted || bd == null) return;
    final b = bd;
    final locale = context.locale.languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 18 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(safeHabitIcon(h.icon),
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(h.title(locale),
                    style: TextStyle(
                        color: ctx.appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(AppStrings.bdTitle,
                style: TextStyle(
                    color: ctx.appText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(AppStrings.bdFormula,
                style: TextStyle(
                    color: ctx.appSub, fontSize: 12, height: 1.4)),
            const SizedBox(height: 14),
            _bdRow(ctx, AppStrings.bdBase, b.baseDailyPoints.toStringAsFixed(1)),
            _bdRow(ctx, AppStrings.bdDifficulty,
                '×${b.difficultyWeight.toStringAsFixed(2)}'),
            _bdRow(ctx, AppStrings.bdStreakMult,
                '×${b.streakMultiplierCap.toStringAsFixed(1)}'),
            _bdRow(ctx, AppStrings.bdDays, '${b.daysLogged}'),
            _bdRow(ctx, AppStrings.bdStreakBonus,
                '+${b.sumStreakBonus.toStringAsFixed(0)}'),
            if (b.sumMilestoneBonus > 0)
              _bdRow(ctx, AppStrings.bdMilestoneBonus,
                  '+${b.sumMilestoneBonus.toStringAsFixed(0)}'),
            if (b.sumPenalty > 0)
              _bdRow(ctx, AppStrings.bdPenalty,
                  '−${b.sumPenalty.toStringAsFixed(0)}'),
            Divider(color: ctx.appBorder, height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.bdTotal,
                    style: TextStyle(
                        color: ctx.appText, fontWeight: FontWeight.w800)),
                Text('${b.total.toStringAsFixed(0)} ${AppStrings.scorePts}',
                    style: TextStyle(
                        color: ctx.appAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bdRow(BuildContext ctx, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(color: ctx.appSub, fontSize: 13)),
            Text(v,
                style: TextStyle(
                    color: ctx.appText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final username =
        (widget.profile['username'] ?? AppStrings.unknown).toString();
    final avatarUrl = widget.profile['avatar_url'] as String?;
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final total = (widget.profile['total_score'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        title: Text(username,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.appAccent))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _header(context, username, initials, avatarUrl, total),
                const SizedBox(height: 22),
                _sectionLabel(context, AppStrings.profileHabits),
                const SizedBox(height: 10),
                if (_habits.isEmpty)
                  _emptyLine(context, AppStrings.profileNoHabits)
                else
                  ..._habits.map((h) => _habitTile(context, h, locale)),
                const SizedBox(height: 22),
                _sectionLabel(context, AppStrings.profileActivity),
                const SizedBox(height: 10),
                if (_activities.isEmpty)
                  _emptyLine(context, AppStrings.profileNoActivity)
                else
                  ..._activities.map((a) => _activityTile(context, a, locale)),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String username, String initials,
      String? avatarUrl, double total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.appBorder,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(initials,
                    style: TextStyle(
                        color: context.appText,
                        fontWeight: FontWeight.w800,
                        fontSize: 22))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isMe ? AppStrings.you : username,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        '${AppStrings.scoreThisMonth}: ${_monthly.toStringAsFixed(0)} ${AppStrings.scorePts}',
                        style: TextStyle(
                            color: context.appAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text('${AppStrings.scoreTotal}: ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: context.appSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('🔥 ${AppStrings.habitDayStreak(_bestStreak)}',
                        style: TextStyle(
                            color: context.appSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitTile(BuildContext context, PublicHabit h, String locale) {
    return GestureDetector(
      onTap: () => _showBreakdown(h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(12),
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
                  Text(AppStrings.programType(h.programType),
                      style: TextStyle(color: context.appSub, fontSize: 12)),
                ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  '${h.habitTotalScore.toStringAsFixed(0)} ${AppStrings.scorePts}',
                  style: TextStyle(
                      color: context.appAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              if (h.currentStreak > 0)
                Text('🔥 ${h.currentStreak}',
                    style: TextStyle(color: context.appSub, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 6),
          Icon(Icons.info_outline_rounded, size: 16, color: context.appSub),
        ]),
      ),
    );
  }

  Widget _activityTile(BuildContext context, ActivityItem a, String locale) {
    // Olumsuz olaylar (sifirlama / silme) kirmizi gosterilir
    final negative = a.kind == 'RELAPSE' || a.kind == 'REMOVED';
    final color = negative ? Colors.redAccent : context.appAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_kindIcon(a.kind), color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activityText(a, locale),
                      style: TextStyle(
                          color: context.appText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(_dt(a.ts),
                      style: TextStyle(color: context.appSub, fontSize: 11)),
                ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: context.appSub,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1),
      );

  Widget _emptyLine(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: TextStyle(color: context.appSub)),
      );
}
