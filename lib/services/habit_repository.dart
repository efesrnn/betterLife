// habit_repository.dart (veri katmani)
// Tum Supabase erisimi bu sinifta toplanir. Modeller ve yardimcilar
// habit_models.dart dosyasinda durur, buradan re-export edilir.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'habit_models.dart';
export 'habit_models.dart';

class HabitRepository {
  final SupabaseClient _client;

  HabitRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // ========================================================
  // HABIT SEARCH & CREATE
  // ========================================================

  /// locale parametresi backend'e gider, boylece Gemini kullanicinin
  /// hangi dilde yazdigini bilir. Hata mesajlarini etkilemez
  /// (onlar anahtar olarak gelir, cevirisini Flutter yapar).
  /// [forceNew] true ise backend benzerlik eşleştirmesini atlar ve doğrudan
  /// yeni habit oluşturur (kullanıcı "benzeri olsa da yeni ekle" dediğinde).
  Future<HabitSearchResult> searchOrCreateHabit({
    required String userInput,
    String locale = 'tr',
    bool forceNew = false,
  }) async {
    final response = await _client.functions.invoke(
      'search-similar-habit',
      body: {
        'user_input': userInput,
        'locale': locale,
        'force_new': forceNew,
      },
    );

    if (response.status != 200 && response.status != 201) {
      throw HabitQuestException.fromResponse(response.data);
    }
    return HabitSearchResult.fromJson(response.data);
  }

  // ========================================================
  // USER HABIT MANAGEMENT
  // ========================================================

  Future<UserHabit> addUserHabit({
    required String habitId,
    required ProgramType programType,
    double? startValue,
    double? targetValue,
    int? phaseDurationDays,
    double? phaseStepAmount,
    DateTime? targetDate,
    Map<String, dynamic>? milestoneConfig,
    double? unitCost,
  }) async {
    // maybeSingle: habit RLS/0-satır durumunda çökmemek için.
    final habit =
        await _client.from('habits').select().eq('id', habitId).maybeSingle();

    final effectiveStart =
        startValue ?? (habit?['default_start_value'] as num?)?.toDouble();
    final effectiveTarget =
        targetValue ?? (habit?['default_target_value'] as num?)?.toDouble();

    double? initialDailyTarget;
    switch (programType) {
      case ProgramType.gradualDecrease:
        initialDailyTarget = effectiveStart;
        break;
      case ProgramType.gradualIncrease:
        final step = phaseStepAmount ??
            ((effectiveTarget ?? 0) - (effectiveStart ?? 0)) / 4;
        initialDailyTarget = (effectiveStart ?? 0) + step;
        break;
      case ProgramType.quit:
      case ProgramType.reduce:
      case ProgramType.maintain:
        initialDailyTarget = effectiveTarget;
        break;
    }

    // upsert: aynı (user_id, habit_id) daha önce 'kaldırılmış' (duraklatılmış)
    // olabilir - satır DB'de kalır. insert yerine upsert ile o satırı yeniden
    // etkinleştirip baştan başlatıyoruz (23505 unique çakışmasını önler).
    final data = await _client
        .from('user_habits')
        .upsert({
      'user_id': _userId,
      'habit_id': habitId,
      'program_type': programType.value,
      'start_value': effectiveStart,
      'target_value': effectiveTarget,
      'current_daily_target': initialDailyTarget,
      'phase_duration_days': phaseDurationDays ?? 7,
      'phase_step_amount': phaseStepAmount,
      'target_date': targetDate?.toIso8601String(),
      'milestone_config': milestoneConfig,
      'unit_cost': unitCost,
      'is_active': true,
      'paused_at': null,
      'started_at': DateTime.now().toIso8601String(),
      'current_streak': 0,
    }, onConflict: 'user_id,habit_id')
        .select()
        .maybeSingle();

    // Insert başarılı ama RLS RETURNING'i gizlemiş olabilir -> null gelebilir.
    // Bu durumda eklendi kabul edip minimal nesne döndürürüz (çağıran zaten
    // listeyi yeniden yüklüyor).
    if (data == null) {
      return UserHabit(
        id: '', habitId: habitId, programType: programType,
        startValue: effectiveStart, targetValue: effectiveTarget,
        currentDailyTarget: initialDailyTarget,
      );
    }
    return UserHabit.fromJson(data);
  }

  Future<List<UserHabit>> getActiveHabits() async {
    final data = await _client
        .from('user_habits')
        .select('*, habits(*)')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .order('started_at', ascending: false);

    return (data as List).map((e) => UserHabit.fromJson(e)).toList();
  }

  Future<void> toggleHabitPause(String userHabitId) async {
    final current = await _client
        .from('user_habits')
        .select('is_active')
        .eq('id', userHabitId)
        .single();

    await _client.from('user_habits').update({
      'is_active': !(current['is_active'] as bool),
      'paused_at': (current['is_active'] as bool)
          ? DateTime.now().toIso8601String()
          : null,
    }).eq('id', userHabitId);
  }

  /// Günlük değeri doğrudan submit_daily_log RPC ile loglar (edge function'sız).
  /// Streak/puan/combo DB tarafında hesaplanır. Hata jsonb içinde döner.
  Future<Map<String, dynamic>> logDailyValue(
      String userHabitId, double reportedValue) async {
    // Yalnızca zorunlu parametreler - opsiyonellere açıkça null göndermek
    // PostgREST'te fonksiyon eşleşmesini bozabiliyor; DB default'larına bırak.
    final res = await _client.rpc('submit_daily_log', params: {
      'p_user_habit_id': userHabitId,
      'p_reported_value': reportedValue,
    });
    final map =
        (res is Map) ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    // RPC handled hataları jsonb {error: '...'} olarak döner -> görünür yap.
    if (map['error'] != null) {
      throw HabitQuestException('errors.${map['error']}',
          details: map['detail']?.toString());
    }
    return map;
  }

  /// QUIT relapse: temiz sayacı sıfırla (started_at = şimdi, streak = 0).
  Future<void> resetHabitStart(String userHabitId) async {
    await _client.from('user_habits').update({
      'started_at': DateTime.now().toIso8601String(),
      'current_streak': 0,
    }).eq('id', userHabitId);
  }

  /// Profil akışında görünen olay kaydı (RELAPSE veya REMOVED).
  /// Habit başlığı ve ikon o anki haliyle saklanır ki habit sonradan
  /// silinse bile akışta düzgün görünsün. Tablo yoksa sessizce geçilir.
  Future<void> logHabitEvent({
    required String userHabitId,
    required String eventType,
    String? titleTr,
    String? titleEn,
    String? icon,
  }) async {
    try {
      await _client.from('habit_events').insert({
        'user_id': _userId,
        'user_habit_id': userHabitId,
        'event_type': eventType,
        'title_tr': titleTr,
        'title_en': titleEn,
        'icon': icon,
      });
    } catch (_) {
      // olay kaydı tutulamasa bile asıl işlemi engellemeyelim
    }
  }

  /// Bir kullanıcının relapse / habit kaldırma olayları (profil akışı için).
  Future<List<ActivityItem>> getHabitEvents(String userId,
      {int limit = 20}) async {
    final data = await _client
        .from('habit_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) {
      return ActivityItem(
        kind: e['event_type']?.toString() ?? 'RELAPSE',
        ts: DateTime.tryParse(e['created_at'].toString())?.toLocal() ??
            DateTime.now(),
        slug: '',
        titleTr: e['title_tr'] ?? '',
        titleEn: e['title_en'] ?? '',
        icon: e['icon'],
      );
    }).toList();
  }

  /// Detay ekranından plan düzenleme: başlangıç (eski kullanım), hedef, maliyet.
  /// Yalnızca verilen alanlar güncellenir. REDUCE'da current_daily_target da
  /// hedefe çekilir ki Home/takvim tutarlı olsun.
  Future<void> updateUserHabit({
    required String userHabitId,
    double? startValue,
    double? targetValue,
    double? unitCost,
    bool syncDailyTargetToTarget = false,
  }) async {
    final patch = <String, dynamic>{};
    if (startValue != null) patch['start_value'] = startValue;
    if (targetValue != null) patch['target_value'] = targetValue;
    if (unitCost != null) patch['unit_cost'] = unitCost;
    if (syncDailyTargetToTarget && targetValue != null) {
      patch['current_daily_target'] = targetValue;
    }
    if (patch.isEmpty) return;
    await _client.from('user_habits').update(patch).eq('id', userHabitId);
  }

  /// Admin: benzer alışkanlıkları tek çatı altında toplayan 12/24 saatlik
  /// birleştirme işini (duplicate-habits edge function) elle tetikler.
  /// Dönüş: {status, merged, promoted, details, ...}
  Future<Map<String, dynamic>> runHabitDeduplication() async {
    final res = await _client.functions.invoke('duplicate-habits');
    if (res.status != 200) {
      throw HabitQuestException.fromResponse(
          res.data is Map ? Map<String, dynamic>.from(res.data) : null);
    }
    return res.data is Map
        ? Map<String, dynamic>.from(res.data)
        : <String, dynamic>{};
  }

  // ========================================================
  // DAILY LOG & SCORING
  // ========================================================

  Future<DailyScoreResult> submitDailyLog({
    required String userHabitId,
    required double reportedValue,
    double? caloriesBurned,
    List<ActivityEntry>? activityEntries,
    String? notes,
  }) async {
    final response = await _client.functions.invoke(
      'calculate-daily-score',
      body: {
        'user_habit_id': userHabitId,
        'reported_value': reportedValue,
        'calories_burned': caloriesBurned,
        'activity_entries':
        activityEntries?.map((e) => e.toJson()).toList() ?? [],
        'notes': notes,
      },
    );

    if (response.status != 200) {
      throw HabitQuestException.fromResponse(response.data);
    }
    return DailyScoreResult.fromJson(response.data);
  }

  Future<List<DailyLog>> getTodayLogs() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await _client
        .from('daily_logs')
        .select('*, user_habits(*, habits(*))')
        .eq('user_id', _userId)
        .eq('log_date', today);

    return (data as List).map((e) => DailyLog.fromJson(e)).toList();
  }

  Future<List<DailyLog>> getHabitHistory(
      String userHabitId, {
        int limit = 30,
      }) async {
    final data = await _client
        .from('daily_logs')
        .select()
        .eq('user_habit_id', userHabitId)
        .order('log_date', ascending: false)
        .limit(limit);

    return (data as List).map((e) => DailyLog.fromJson(e)).toList();
  }

  // ========================================================
  // COMBO STREAK
  // ========================================================

  Future<ComboStreakResult> checkComboBonus() async {
    final response = await _client.functions.invoke('check-combo-bonus');
    if (response.status != 200) {
      throw HabitQuestException.fromResponse(response.data);
    }
    return ComboStreakResult.fromJson(response.data);
  }

  Future<List<ComboStreakLog>> getComboHistory({int limit = 10}) async {
    final data = await _client
        .from('combo_streak_logs')
        .select()
        .eq('user_id', _userId)
        .order('combo_date', ascending: false)
        .limit(limit);

    return (data as List).map((e) => ComboStreakLog.fromJson(e)).toList();
  }

  // ========================================================
  // DASHBOARD
  // ========================================================

  Future<DashboardData> getDashboard() async {
    final data = await _client.rpc(
      'get_user_dashboard',
      params: {'p_user_id': _userId},
    );
    return DashboardData.fromJson(data);
  }

  // ========================================================
  // LEADERBOARD & FRIENDS
  // ========================================================

  Future<List<LeaderboardEntry>> getFriendLeaderboard() async {
    final data = await _client.rpc(
      'get_friend_leaderboard',
      params: {'p_user_id': _userId},
    );
    return (data as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
  }

  Future<void> sendFriendRequest(String addresseeUsername) async {
    final target = await _client
        .from('profiles')
        .select('id')
        .eq('username', addresseeUsername)
        .single();
    await _client.from('friendships').insert({
      'requester_id': _userId,
      'addressee_id': target['id'],
    });
  }

  Future<List<FriendRequest>> getPendingRequests() async {
    final data = await _client
        .from('friendships')
        .select('*, requester:profiles!requester_id(*)')
        .eq('addressee_id', _userId)
        .eq('status', 'PENDING');
    return (data as List).map((e) => FriendRequest.fromJson(e)).toList();
  }

  Future<void> respondToFriendRequest(
      String friendshipId, {
        required bool accept,
      }) async {
    if (accept) {
      await _client
          .from('friendships')
          .update({'status': 'ACCEPTED'}).eq('id', friendshipId);
    } else {
      await _client.from('friendships').delete().eq('id', friendshipId);
    }
  }

  // ========================================================
  // CATALOG & MILESTONES
  // ========================================================

  /// Gelistirici araci: katalogdaki bir habit'in alanlarini elle gunceller.
  /// RLS'e takilmamak icin SECURITY DEFINER bir RPC kullanilir; yetki
  /// kontrolu fonksiyonun icinde yapilir (docs/sql/habits_admin_policy.sql).
  Future<void> updateHabitAttributes(
      String habitId, Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    final res = await _client.rpc('admin_update_habit', params: {
      'p_habit_id': habitId,
      'p_patch': patch,
    });
    final map =
        (res is Map) ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    if (map['error'] != null) {
      throw Exception(
          "admin_update_habit: ${map['error']} (fonksiyon kurulu mu? docs/sql/habits_admin_policy.sql)");
    }
  }

  /// Gelistirici araci: habit'i katalogdan kaldirir.
  /// Satiri gercekten silmek yerine is_valid=false yapilir (soft delete);
  /// boylece bu habit'e bagli eski kullanici kayitlari bozulmaz ve katalog
  /// sorgulari (is_valid=true filtresi) habit'i artik gostermez.
  Future<void> deleteHabit(String habitId) async {
    await updateHabitAttributes(habitId, {'is_valid': false});
  }

  Future<List<Habit>> getHabitCatalog({String? categoryTag}) async {
    var query = _client.from('habits').select().eq('is_valid', true);
    if (categoryTag != null) query = query.eq('category_tag', categoryTag);
    final data = await query.order('base_daily_points', ascending: false);
    return (data as List).map((e) => Habit.fromJson(e)).toList();
  }

  Future<List<Milestone>> getMilestones(String userHabitId) async {
    final data = await _client
        .from('milestone_logs')
        .select()
        .eq('user_habit_id', userHabitId)
        .order('milestone_day', ascending: true);
    return (data as List).map((e) => Milestone.fromJson(e)).toList();
  }

  // ========================================================
  // PUBLIC PROFILE (herkes herkesi görebilir - SECURITY DEFINER RPC)
  // ========================================================

  /// Bir kullanıcının (herkese açık) aktif alışkanlıkları.
  Future<List<PublicHabit>> getUserHabitsPublic(String userId) async {
    final data = await _client
        .rpc('get_user_habits_public', params: {'p_user_id': userId});
    return (data as List)
        .map((e) => PublicHabit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bir kullanıcının son N aktivitesi (yeni habit / günlük log / milestone).
  Future<List<ActivityItem>> getUserActivityFeed(String userId,
      {int limit = 20}) async {
    final data = await _client.rpc('get_user_activity_feed',
        params: {'p_user_id': userId, 'p_limit': limit});
    return (data as List)
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Verilen kullanıcıların BU AYKİ skoru + en yüksek habit serisi.
  /// Aylık skor = bu ayki günlük puanlar + combo bonusları (her ay sıfırlanır).
  /// best_streak = aktif habitler arasında en yüksek current_streak.
  Future<Map<String, UserScore>> getMonthlyScores(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final data = await _client
        .rpc('get_monthly_scores', params: {'p_user_ids': userIds});
    final map = <String, UserScore>{};
    for (final row in (data as List)) {
      map[row['user_id'].toString()] = UserScore(
        monthly: (row['monthly_score'] as num?)?.toDouble() ?? 0,
        bestStreak: (row['best_streak'] as num?)?.toInt() ?? 0,
      );
    }
    return map;
  }

  /// Bir habit'in puanının nasıl oluştuğu (şeffaf kırılım).
  Future<ScoreBreakdown?> getHabitScoreBreakdown(String userHabitId) async {
    final data = await _client.rpc('get_habit_score_breakdown',
        params: {'p_user_habit_id': userHabitId});
    final list = data as List;
    if (list.isEmpty) return null;
    return ScoreBreakdown.fromJson(list.first as Map<String, dynamic>);
  }
}

// ============================================================
// ENUMS
// ============================================================
