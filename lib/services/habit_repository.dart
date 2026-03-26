// ============================================================
// HabitQuest - habit_repository.dart (v3 - key-based i18n)
//
// Backend returns `error_key` / `message_key` (e.g. "errors.missing_auth")
// Flutter's easy_localization translates via tr.json / en.json / xx.json
//
// Usage in UI:
//   try {
//     await repo.submitDailyLog(...);
//   } on HabitQuestException catch (e) {
//     showError(e.messageKey.tr());  // easy_localization .tr() extension
//   }
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class HabitRepository {
  final SupabaseClient _client;

  HabitRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // ========================================================
  // HABIT SEARCH & CREATE
  // ========================================================

  /// locale parameter is passed to backend so Gemini knows
  /// what language the user typed in. Does NOT affect error messages
  /// (those come as keys, Flutter translates them).
  Future<HabitSearchResult> searchOrCreateHabit({
    required String userInput,
    String locale = 'tr',
  }) async {
    final response = await _client.functions.invoke(
      'search-similar-habit',
      body: {'user_input': userInput, 'locale': locale},
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
  }) async {
    final habit =
    await _client.from('habits').select().eq('id', habitId).single();

    final effectiveStart =
        startValue ?? (habit['default_start_value'] as num?)?.toDouble();
    final effectiveTarget =
        targetValue ?? (habit['default_target_value'] as num?)?.toDouble();

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

    final data = await _client
        .from('user_habits')
        .insert({
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
    })
        .select()
        .single();

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
}

// ============================================================
// ENUMS
// ============================================================

enum ProgramType {
  quit('QUIT'),
  gradualDecrease('GRADUAL_DECREASE'),
  reduce('REDUCE'),
  gradualIncrease('GRADUAL_INCREASE'),
  maintain('MAINTAIN');

  const ProgramType(this.value);
  final String value;

  static ProgramType fromString(String s) =>
      ProgramType.values.firstWhere((e) => e.value == s);

  /// Returns the translation key for this program type.
  /// Usage: programType.titleKey.tr()  (with easy_localization)
  String get titleKey => 'program_types.$value';
}

// ============================================================
// EXCEPTION (carries message_key for easy_localization)
// ============================================================

class HabitQuestException implements Exception {
  /// The i18n key from backend (e.g. "errors.already_logged_today")
  /// Translate in UI: e.messageKey.tr()
  final String messageKey;

  /// Optional raw details for debugging
  final String? details;

  HabitQuestException(this.messageKey, {this.details});

  /// Parse from backend JSON response
  factory HabitQuestException.fromResponse(Map<String, dynamic>? data) {
    return HabitQuestException(
      data?['error_key'] ?? data?['error'] ?? 'errors.internal_error',
      details: data?['details'],
    );
  }

  @override
  String toString() => 'HabitQuestException: $messageKey${details != null ? ' ($details)' : ''}';
}

// ============================================================
// MODELS
// ============================================================

class HabitSearchResult {
  final String action;

  /// i18n key — translate with: result.messageKey.tr()
  final String messageKey;

  final String? habitId;
  final List<HabitSuggestion>? suggestions;
  final Map<String, dynamic>? habit;
  final List<String>? suggestedPrograms;
  final bool geminiCalled;

  /// For INVALID_HABIT: Gemini's rejection reason per locale
  /// {"tr": "...", "en": "..."}
  final Map<String, dynamic>? rejectionReason;

  HabitSearchResult({
    required this.action,
    required this.messageKey,
    this.habitId,
    this.suggestions,
    this.habit,
    this.suggestedPrograms,
    this.geminiCalled = false,
    this.rejectionReason,
  });

  bool get isExactMatch => action == 'EXACT_MATCH';
  bool get isMaybeMatch => action == 'MAYBE_MATCH';
  bool get isNewHabit => action == 'NEW_HABIT_CREATED';
  bool get isInvalid => action == 'INVALID_HABIT';

  /// Get rejection reason for a specific locale (for INVALID_HABIT)
  String? getRejectionReason(String locale) =>
      rejectionReason?[locale] ?? rejectionReason?['en'];

  factory HabitSearchResult.fromJson(Map<String, dynamic> json) {
    return HabitSearchResult(
      action: json['action'],
      messageKey: json['message_key'] ?? '',
      habitId: json['habit_id'] ?? json['match']?['habit_id'],
      suggestions: json['suggestions'] != null
          ? (json['suggestions'] as List)
          .map((e) => HabitSuggestion.fromJson(e as Map<String, dynamic>))
          .toList()
          : null,
      habit: json['habit'] as Map<String, dynamic>?,
      suggestedPrograms: json['suggested_programs'] != null
          ? List<String>.from(json['suggested_programs'])
          : null,
      geminiCalled: json['gemini_called'] ?? false,
      rejectionReason: json['rejection_reason'] as Map<String, dynamic>?,
    );
  }
}

class HabitSuggestion {
  final String habitId;
  final String slug;
  final String titleTr;
  final String titleEn;
  final double similarity;

  HabitSuggestion({
    required this.habitId,
    required this.slug,
    required this.titleTr,
    required this.titleEn,
    required this.similarity,
  });

  /// Locale-aware title getter
  String title(String locale) => locale == 'tr' ? titleTr : titleEn;

  factory HabitSuggestion.fromJson(Map<String, dynamic> json) {
    return HabitSuggestion(
      habitId: json['habit_id'],
      slug: json['slug'],
      titleTr: json['title_tr'] ?? '',
      titleEn: json['title_en'] ?? '',
      similarity: (json['similarity'] as num).toDouble(),
    );
  }
}

class Habit {
  final String id;
  final String slug;
  final String titleTr;
  final String titleEn;
  final String? descriptionTr;
  final String? descriptionEn;
  final String? icon;
  final String? unit;
  final String type;
  final double baseDailyPoints;
  final double difficultyWeight;
  final String targetDirection;
  final int healthImpact;
  final int mentalDiscipline;
  final int financialImpact;
  final int timeImpact;
  final int socialImpact;
  final String? categoryTag;
  final String? riskLevel;

  Habit({
    required this.id, required this.slug,
    required this.titleTr, required this.titleEn,
    this.descriptionTr, this.descriptionEn,
    this.icon, this.unit, required this.type,
    required this.baseDailyPoints, required this.difficultyWeight,
    required this.targetDirection,
    required this.healthImpact, required this.mentalDiscipline,
    required this.financialImpact, required this.timeImpact,
    required this.socialImpact, this.categoryTag, this.riskLevel,
  });

  String title(String locale) => locale == 'tr' ? titleTr : titleEn;
  String? description(String locale) => locale == 'tr' ? descriptionTr : descriptionEn;

  /// Translation key for the category tag
  /// Usage: habit.categoryKey.tr()
  String get categoryKey => 'categories.${categoryTag ?? "HEALTH"}';

  /// Translation key for risk level
  String get riskKey => 'risk_levels.${riskLevel ?? "MEDIUM"}';

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'], slug: json['slug'],
      titleTr: json['title_tr'] ?? '', titleEn: json['title_en'] ?? '',
      descriptionTr: json['description_tr'], descriptionEn: json['description_en'],
      icon: json['icon'], unit: json['unit'], type: json['type'],
      baseDailyPoints: (json['base_daily_points'] as num).toDouble(),
      difficultyWeight: (json['difficulty_weight'] as num).toDouble(),
      targetDirection: json['target_direction'],
      healthImpact: json['health_impact'], mentalDiscipline: json['mental_discipline'],
      financialImpact: json['financial_impact'], timeImpact: json['time_impact'],
      socialImpact: json['social_impact'],
      categoryTag: json['category_tag'], riskLevel: json['risk_level'],
    );
  }
}

class UserHabit {
  final String id;
  final String habitId;
  final ProgramType programType;
  final double? startValue;
  final double? targetValue;
  final double? currentDailyTarget;
  final int currentStreak;
  final int longestStreak;
  final double habitTotalScore;
  final bool isActive;
  final String? lastLogDate;
  final Habit? habit;

  UserHabit({
    required this.id, required this.habitId, required this.programType,
    this.startValue, this.targetValue, this.currentDailyTarget,
    this.currentStreak = 0, this.longestStreak = 0, this.habitTotalScore = 0,
    this.isActive = true, this.lastLogDate, this.habit,
  });

  String title(String locale) => habit?.title(locale) ?? '';
  String get programTitleKey => programType.titleKey;

  factory UserHabit.fromJson(Map<String, dynamic> json) {
    return UserHabit(
      id: json['id'], habitId: json['habit_id'],
      programType: ProgramType.fromString(json['program_type']),
      startValue: (json['start_value'] as num?)?.toDouble(),
      targetValue: (json['target_value'] as num?)?.toDouble(),
      currentDailyTarget: (json['current_daily_target'] as num?)?.toDouble(),
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      habitTotalScore: (json['habit_total_score'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] ?? true,
      lastLogDate: json['last_log_date'],
      habit: json['habits'] != null
          ? Habit.fromJson(json['habits'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DailyLog {
  final String id;
  final String userHabitId;
  final String logDate;
  final double reportedValue;
  final double dailyTarget;
  final double totalPoints;
  final double streakMultiplier;
  final int streakDay;
  final bool isSuccess;

  DailyLog({
    required this.id, required this.userHabitId, required this.logDate,
    required this.reportedValue, required this.dailyTarget,
    required this.totalPoints, required this.streakMultiplier,
    required this.streakDay, required this.isSuccess,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'], userHabitId: json['user_habit_id'],
      logDate: json['log_date'],
      reportedValue: (json['reported_value'] as num?)?.toDouble() ?? 0,
      dailyTarget: (json['daily_target'] as num?)?.toDouble() ?? 0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0,
      streakMultiplier: (json['streak_multiplier'] as num?)?.toDouble() ?? 1.0,
      streakDay: json['streak_day'] ?? 0,
      isSuccess: json['is_success'] ?? false,
    );
  }
}

class DailyScoreResult {
  final String logId;
  final Map<String, dynamic> score;
  final ComboStreakResult? comboStreak;

  DailyScoreResult({required this.logId, required this.score, this.comboStreak});

  double get totalPoints => (score['total_points'] as num?)?.toDouble() ?? 0;
  double get basePoints => (score['base_points'] as num?)?.toDouble() ?? 0;
  double get streakBonus => (score['streak_bonus'] as num?)?.toDouble() ?? 0;
  double get effortBonus => (score['effort_bonus'] as num?)?.toDouble() ?? 0;
  double get penalty => (score['penalty'] as num?)?.toDouble() ?? 0;
  double get milestoneBonus => (score['milestone_bonus'] as num?)?.toDouble() ?? 0;
  bool get isSuccess => score['is_success'] ?? false;
  int get newStreak => score['new_streak'] ?? 0;

  factory DailyScoreResult.fromJson(Map<String, dynamic> json) {
    return DailyScoreResult(
      logId: json['log_id'],
      score: json['score'] as Map<String, dynamic>,
      comboStreak: json['combo_streak'] != null
          ? ComboStreakResult.fromJson(json['combo_streak'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ComboStreakResult {
  final bool comboAwarded;
  final int activeStreakCount;
  final double? comboBonusPoints;
  final String? reason;
  final int? daysUntilNext;
  final String? nextBonusDate;
  final List<Map<String, dynamic>>? qualifyingHabits;

  ComboStreakResult({
    required this.comboAwarded, required this.activeStreakCount,
    this.comboBonusPoints, this.reason, this.daysUntilNext,
    this.nextBonusDate, this.qualifyingHabits,
  });

  factory ComboStreakResult.fromJson(Map<String, dynamic> json) {
    return ComboStreakResult(
      comboAwarded: json['combo_awarded'] ?? false,
      activeStreakCount: json['active_streak_count'] ?? 0,
      comboBonusPoints: (json['combo_bonus_points'] as num?)?.toDouble(),
      reason: json['reason'],
      daysUntilNext: json['days_until_next'],
      nextBonusDate: json['next_bonus_date'],
      qualifyingHabits: json['qualifying_habits'] != null
          ? List<Map<String, dynamic>>.from(json['qualifying_habits'])
          : null,
    );
  }
}

class ComboStreakLog {
  final String id;
  final String comboDate;
  final int activeStreakCount;
  final double comboBonusPoints;
  final List<dynamic> qualifyingHabits;

  ComboStreakLog({
    required this.id, required this.comboDate,
    required this.activeStreakCount, required this.comboBonusPoints,
    required this.qualifyingHabits,
  });

  factory ComboStreakLog.fromJson(Map<String, dynamic> json) {
    return ComboStreakLog(
      id: json['id'], comboDate: json['combo_date'],
      activeStreakCount: json['active_streak_count'],
      comboBonusPoints: (json['combo_bonus_points'] as num).toDouble(),
      qualifyingHabits: json['qualifying_habits'] ?? [],
    );
  }
}

class DashboardData {
  final Map<String, dynamic> profile;
  final List<DashboardHabit> activeHabits;
  final DashboardCombo comboStreak;

  DashboardData({required this.profile, required this.activeHabits, required this.comboStreak});

  String get username => profile['username'] ?? '';
  double get totalScore => (profile['total_score'] as num?)?.toDouble() ?? 0;
  double get weeklyScore => (profile['weekly_score'] as num?)?.toDouble() ?? 0;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      profile: json['profile'] as Map<String, dynamic>,
      activeHabits: (json['active_habits'] as List)
          .map((e) => DashboardHabit.fromJson(e as Map<String, dynamic>))
          .toList(),
      comboStreak: DashboardCombo.fromJson(json['combo_streak'] as Map<String, dynamic>),
    );
  }
}

class DashboardHabit {
  final String userHabitId;
  final String habitSlug;
  final String habitTitleTr;
  final String icon;
  final String programType;
  final int currentStreak;
  final int longestStreak;
  final double? currentDailyTarget;
  final double habitTotalScore;
  final String? lastLogDate;
  final bool loggedToday;

  DashboardHabit({
    required this.userHabitId, required this.habitSlug,
    required this.habitTitleTr, required this.icon,
    required this.programType, required this.currentStreak,
    required this.longestStreak, this.currentDailyTarget,
    required this.habitTotalScore, this.lastLogDate,
    required this.loggedToday,
  });

  String get programTitleKey => 'program_types.$programType';

  factory DashboardHabit.fromJson(Map<String, dynamic> json) {
    return DashboardHabit(
      userHabitId: json['user_habit_id'],
      habitSlug: json['habit_slug'],
      habitTitleTr: json['habit_title_tr'] ?? '',
      icon: json['icon'] ?? '🎯',
      programType: json['program_type'],
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      currentDailyTarget: (json['current_daily_target'] as num?)?.toDouble(),
      habitTotalScore: (json['habit_total_score'] as num?)?.toDouble() ?? 0,
      lastLogDate: json['last_log_date'],
      loggedToday: json['logged_today'] ?? false,
    );
  }
}

class DashboardCombo {
  final int activeStreakCount;
  final double potentialBonus;
  final int daysUntilNextBonus;
  final String nextBonusDate;

  DashboardCombo({
    required this.activeStreakCount, required this.potentialBonus,
    required this.daysUntilNextBonus, required this.nextBonusDate,
  });

  factory DashboardCombo.fromJson(Map<String, dynamic> json) {
    return DashboardCombo(
      activeStreakCount: json['active_streak_count'] ?? 0,
      potentialBonus: (json['potential_bonus'] as num?)?.toDouble() ?? 0,
      daysUntilNextBonus: json['days_until_next_bonus'] ?? 0,
      nextBonusDate: json['next_bonus_date'] ?? '',
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final double totalScore;
  final double weeklyScore;
  final int activeHabits;
  final int rank;

  LeaderboardEntry({
    required this.userId, required this.username,
    this.displayName, this.avatarUrl,
    required this.totalScore, required this.weeklyScore,
    required this.activeHabits, required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'], username: json['username'],
      displayName: json['display_name'], avatarUrl: json['avatar_url'],
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
      weeklyScore: (json['weekly_score'] as num?)?.toDouble() ?? 0,
      activeHabits: json['active_habits'] ?? 0,
      rank: json['rank'],
    );
  }
}

class FriendRequest {
  final String id;
  final String requesterId;
  final String requesterUsername;
  final String? requesterDisplayName;
  final String? requesterAvatar;

  FriendRequest({
    required this.id, required this.requesterId,
    required this.requesterUsername,
    this.requesterDisplayName, this.requesterAvatar,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final r = json['requester'] as Map<String, dynamic>?;
    return FriendRequest(
      id: json['id'], requesterId: json['requester_id'],
      requesterUsername: r?['username'] ?? '',
      requesterDisplayName: r?['display_name'],
      requesterAvatar: r?['avatar_url'],
    );
  }
}

class ActivityEntry {
  final String slug;
  final double value;
  final String unit;
  ActivityEntry({required this.slug, required this.value, required this.unit});
  Map<String, dynamic> toJson() => {'slug': slug, 'value': value, 'unit': unit};
}

class Milestone {
  final String id;
  final int milestoneDay;
  final double bonusPoints;
  final DateTime achievedAt;
  Milestone({required this.id, required this.milestoneDay, required this.bonusPoints, required this.achievedAt});
  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'], milestoneDay: json['milestone_day'],
      bonusPoints: (json['bonus_points'] as num).toDouble(),
      achievedAt: DateTime.parse(json['achieved_at']),
    );
  }
}