// ============================================================
// Better Life — SupabaseService
// ------------------------------------------------------------
// Tek bir noktadan tüm Supabase erişimi (auth, CRUD, RPC).
// Singleton: SupabaseService.instance.
//
// UI doğrudan Supabase.instance.client kullanmak yerine bu servisi
// çağırır → test ve değişiklik kolaylaşır. Mevcut ekranlar şu an
// hâlâ ham client kullanıyor; sonraki parçalarda bu servise taşınacak.
//
// Bu dosya UI'a dokunmaz; sadece veri katmanını sağlar.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Mevcut auth kullanıcısının id'si; oturum yoksa fırlatır.
  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException('User is not authenticated');
    }
    return id;
  }

  // ========================================================
  // AUTH
  // ========================================================

  /// Kayıt: auth.users'a kayıt; trigger (handle_new_user) profiles
  /// satırını otomatik oluşturur. `username` raw_user_meta_data'da
  /// taşınır; trigger oradan okur.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
    String? displayName,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Stream<AuthState> get onAuthChange => _client.auth.onAuthStateChange;

  // ========================================================
  // PROFILE
  // ========================================================

  Future<Profile?> getProfile([String? userId]) async {
    final id = userId ?? _uid;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<Profile> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final update = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    final row = await _client
        .from('profiles')
        .update(update)
        .eq('id', _uid)
        .select()
        .single();
    return Profile.fromJson(row);
  }

  /// Username veya display_name içeren ilike araması (kendisi hariç).
  Future<List<Profile>> searchUsers(String query, {int limit = 20}) async {
    final q = '%${query.trim()}%';
    final rows = await _client
        .from('profiles')
        .select()
        .neq('id', _uid)
        .or('username.ilike.$q,display_name.ilike.$q')
        .limit(limit);
    return (rows as List)
        .map((r) => Profile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ========================================================
  // HABIT CATEGORIES
  // ========================================================

  Future<List<HabitCategory>> getHabitCategories({bool onlyValid = true}) async {
    var query = _client.from('habit_categories').select();
    if (onlyValid) query = query.eq('is_valid', true);
    final rows = await query.order('base_daily_points', ascending: false);
    return (rows as List)
        .map((r) => HabitCategory.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<HabitCategory?> findHabitCategoryByName(String name) async {
    final row = await _client
        .from('habit_categories')
        .select()
        .ilike('name', name)
        .maybeSingle();
    if (row == null) return null;
    return HabitCategory.fromJson(row);
  }

  Future<HabitCategory> createHabitCategory(HabitCategory category) async {
    final row = await _client
        .from('habit_categories')
        .insert({
          ...category.toInsertJson(),
          'created_by': _uid,
        })
        .select()
        .single();
    return HabitCategory.fromJson(row);
  }

  // ========================================================
  // ACTIVITY CATEGORIES
  // ========================================================

  Future<List<ActivityCategory>> getActivityCategories({
    bool onlyValid = true,
  }) async {
    var query = _client.from('activity_categories').select();
    if (onlyValid) query = query.eq('is_valid', true);
    final rows = await query.order('base_bonus_points', ascending: false);
    return (rows as List)
        .map((r) => ActivityCategory.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ActivityCategory?> findActivityCategoryByName(String name) async {
    final row = await _client
        .from('activity_categories')
        .select()
        .ilike('name', name)
        .maybeSingle();
    if (row == null) return null;
    return ActivityCategory.fromJson(row);
  }

  Future<ActivityCategory> createActivityCategory(
      ActivityCategory category) async {
    final row = await _client
        .from('activity_categories')
        .insert({
          ...category.toInsertJson(),
          'created_by': _uid,
        })
        .select()
        .single();
    return ActivityCategory.fromJson(row);
  }

  // ========================================================
  // USER HABITS  (kullanıcının bırakmak istediği alışkanlıklar)
  // ========================================================

  /// Tüm aktif (veya tümü) user_habit kayıtları; join ile kategori dolu gelir.
  Future<List<UserHabit>> getUserHabits({bool onlyActive = true}) async {
    var query = _client
        .from('user_habits')
        .select('*, habit_categories(*)')
        .eq('user_id', _uid);
    if (onlyActive) query = query.eq('is_active', true);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => UserHabit.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<UserHabit> addUserHabit({
    required int habitCategoryId,
    DateTime? quitDate,
    String? motivation,
  }) async {
    final row = await _client
        .from('user_habits')
        .insert({
          'user_id': _uid,
          'habit_category_id': habitCategoryId,
          'quit_date': (quitDate ?? DateTime.now())
              .toIso8601String()
              .substring(0, 10),
          if (motivation != null) 'motivation': motivation,
          'is_active': true,
        })
        .select('*, habit_categories(*)')
        .single();
    return UserHabit.fromJson(row);
  }

  Future<void> deactivateUserHabit(int userHabitId) async {
    await _client
        .from('user_habits')
        .update({'is_active': false})
        .eq('id', userHabitId)
        .eq('user_id', _uid);
  }

  Future<void> reactivateUserHabit(int userHabitId) async {
    await _client
        .from('user_habits')
        .update({'is_active': true})
        .eq('id', userHabitId)
        .eq('user_id', _uid);
  }

  // ========================================================
  // HABIT LOGS  (günlük check-in)
  // ========================================================

  /// Bugünün (veya verilen tarihin) check-in'ini upsert eder.
  /// `unique(user_habit_id, log_date)` constraint sayesinde aynı gün
  /// tekrar loglanırsa günceller.
  Future<HabitLog> logHabit({
    required int userHabitId,
    required bool stayedClean,
    DateTime? logDate,
    String? relapseNote,
  }) async {
    final date = (logDate ?? DateTime.now())
        .toIso8601String()
        .substring(0, 10);
    final row = await _client
        .from('habit_logs')
        .upsert(
          {
            'user_habit_id': userHabitId,
            'user_id': _uid,
            'log_date': date,
            'stayed_clean': stayedClean,
            if (relapseNote != null) 'relapse_note': relapseNote,
          },
          onConflict: 'user_habit_id,log_date',
        )
        .select()
        .single();
    return HabitLog.fromJson(row);
  }

  Future<List<HabitLog>> getHabitLogs({
    int? userHabitId,
    DateTime? since,
    DateTime? until,
    int limit = 100,
  }) async {
    var query = _client.from('habit_logs').select().eq('user_id', _uid);
    if (userHabitId != null) query = query.eq('user_habit_id', userHabitId);
    if (since != null) {
      query = query.gte('log_date', since.toIso8601String().substring(0, 10));
    }
    if (until != null) {
      query = query.lte('log_date', until.toIso8601String().substring(0, 10));
    }
    final rows = await query.order('log_date', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => HabitLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Bugün henüz loglanmamış aktif alışkanlıkları döndürür
  /// (dashboard "check-in bekleyenler" listesi için).
  Future<List<UserHabit>> getUnloggedHabitsToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final habits = await getUserHabits(onlyActive: true);
    if (habits.isEmpty) return [];

    final loggedRows = await _client
        .from('habit_logs')
        .select('user_habit_id')
        .eq('user_id', _uid)
        .eq('log_date', today);
    final loggedIds = (loggedRows as List)
        .map((r) => (r['user_habit_id'] as num).toInt())
        .toSet();

    return habits.where((h) => !loggedIds.contains(h.id)).toList();
  }

  // ========================================================
  // ACTIVITY LOGS
  // ========================================================

  Future<ActivityLog> logActivity({
    required int activityCategoryId,
    int? durationMinutes,
    String? notes,
    DateTime? logDate,
  }) async {
    final row = await _client
        .from('activity_logs')
        .insert({
          'user_id': _uid,
          'activity_category_id': activityCategoryId,
          'log_date': (logDate ?? DateTime.now())
              .toIso8601String()
              .substring(0, 10),
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
          if (notes != null) 'notes': notes,
        })
        .select('*, activity_categories(*)')
        .single();
    return ActivityLog.fromJson(row);
  }

  Future<List<ActivityLog>> getActivityLogs({
    DateTime? since,
    DateTime? until,
    int limit = 100,
  }) async {
    var query = _client
        .from('activity_logs')
        .select('*, activity_categories(*)')
        .eq('user_id', _uid);
    if (since != null) {
      query = query.gte('log_date', since.toIso8601String().substring(0, 10));
    }
    if (until != null) {
      query = query.lte('log_date', until.toIso8601String().substring(0, 10));
    }
    final rows = await query.order('log_date', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => ActivityLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteActivityLog(int id) async {
    await _client.from('activity_logs').delete().eq('id', id).eq('user_id', _uid);
  }

  // ========================================================
  // LEADERBOARD & SCORE (RPC)
  // ========================================================

  Future<List<LeaderboardEntry>> getFriendLeaderboard() async {
    final rows = await _client.rpc('get_friend_leaderboard', params: {
      'p_user_id': _uid,
    });
    return (rows as List)
        .map((r) => LeaderboardEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 7 günlük günlük puan dökümü. p_week_start verilmezse default olarak
  /// son 7 gün (bugün dahil) kullanılır.
  Future<List<DailyScore>> getWeeklyScore({DateTime? weekStart}) async {
    final params = <String, dynamic>{'p_user_id': _uid};
    if (weekStart != null) {
      params['p_week_start'] = weekStart.toIso8601String().substring(0, 10);
    }
    final rows = await _client.rpc('get_weekly_score', params: params);
    return (rows as List)
        .map((r) => DailyScore.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Toplam puanı zorla yeniden hesapla (genelde trigger'lar yapar; debug için).
  Future<int> refreshScore() async {
    final result = await _client.rpc('recalculate_user_score', params: {
      'p_user_id': _uid,
    });
    return (result as num).toInt();
  }

  // ========================================================
  // FRIENDSHIPS
  // ========================================================

  /// Arkadaşlık isteği gönder (status default 'PENDING' — mevcut UI ile uyumlu).
  Future<Friendship> sendFriendRequest(String addresseeUserId) async {
    final row = await _client
        .from('friendships')
        .insert({
          'requester_id': _uid,
          'addressee_id': addresseeUserId,
          'status': FriendshipStatus.pending.dbValue,
        })
        .select()
        .single();
    return Friendship.fromJson(row);
  }

  /// İsteğe yanıt: accept=true → ACCEPTED; false → satırı siler
  /// (mevcut UI mantığıyla aynı: reddedince DB'den kaldır).
  Future<void> respondToFriendRequest(int friendshipId,
      {required bool accept}) async {
    if (accept) {
      await _client
          .from('friendships')
          .update({'status': FriendshipStatus.accepted.dbValue})
          .eq('id', friendshipId)
          .eq('addressee_id', _uid);
    } else {
      await _client
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('addressee_id', _uid);
    }
  }

  /// Bana gelen, henüz cevaplanmamış istekler (PENDING/pending).
  Future<List<Friendship>> getPendingRequests() async {
    final rows = await _client
        .from('friendships')
        .select('*, requester:profiles!requester_id(*)')
        .eq('addressee_id', _uid)
        .or('status.eq.PENDING,status.eq.pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Friendship.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Tüm arkadaşlarımın profilleri (ACCEPTED).
  Future<List<Profile>> getFriends() async {
    final rows = await _client
        .from('friendships')
        .select('*, requester:profiles!requester_id(*), addressee:profiles!addressee_id(*)')
        .or('status.eq.ACCEPTED,status.eq.accepted')
        .or('requester_id.eq.$_uid,addressee_id.eq.$_uid');

    final profiles = <Profile>[];
    for (final r in rows as List) {
      final f = Friendship.fromJson(r as Map<String, dynamic>);
      // Ben requester'sam karşı taraf addressee, tersi de geçerli.
      final other =
          f.requesterId == _uid ? f.addresseeProfile : f.requesterProfile;
      if (other != null) profiles.add(other);
    }
    return profiles;
  }

  Future<void> removeFriend(String otherUserId) async {
    await _client
        .from('friendships')
        .delete()
        .or('requester_id.eq.$_uid,addressee_id.eq.$_uid')
        .or('requester_id.eq.$otherUserId,addressee_id.eq.$otherUserId');
  }

  // ========================================================
  // ACHIEVEMENTS
  // ========================================================

  Future<List<Achievement>> getAllAchievements() async {
    final rows = await _client
        .from('achievements')
        .select()
        .order('id', ascending: true);
    return (rows as List)
        .map((r) => Achievement.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserAchievement>> getMyAchievements() async {
    final rows = await _client
        .from('user_achievements')
        .select('*, achievements(*)')
        .eq('user_id', _uid)
        .order('earned_at', ascending: false);
    return (rows as List)
        .map((r) => UserAchievement.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

/// Kısa erişim için top-level alias — UI'da
/// `supabaseService.getProfile()` gibi kullanılır.
final supabaseService = SupabaseService.instance;
