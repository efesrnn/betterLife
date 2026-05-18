// ============================================================
// Better Life — Data Models
// ------------------------------------------------------------
// Her sınıf:
//   * fromJson(Map<String, dynamic>)       → DB'den okuma
//   * toInsertJson()                       → DB'ye yazma (server-generated
//                                             alanları (id, created_at, vb.)
//                                             ATLAR)
//
// Supabase join sorguları için iç içe modeller desteklenir
// (örn: UserHabit.category, ActivityLog.category).
//
// NOT: Bu dosya UI'a doğrudan dokunmuyor; widget'lar bu modelleri
// SupabaseService üzerinden alır.
// ============================================================

import 'package:flutter/material.dart';

// ------------------------------------------------------------
// Yardımcı: hex → Color
// ------------------------------------------------------------
Color _hexToColor(String? hex, {Color fallback = const Color(0xFF000000)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final h = hex.replaceFirst('#', '').trim();
  if (h.length != 6 && h.length != 8) return fallback;
  final value = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return value == null ? fallback : Color(value);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

// ============================================================
// 1) Profile
// ============================================================

class Profile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int totalScore;
  final int currentStreak;
  final int longestStreak;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// LEGACY — eski tek-habit kurulumundan kalan alanlar; yeni kayıtlar
  /// için kullanılmaz, sadece geriye dönük okuma için tutulur.
  final String? legacyHabit;
  final String? legacyGoal;

  Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.totalScore = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.createdAt,
    this.updatedAt,
    this.legacyHabit,
    this.legacyGoal,
  });

  String get effectiveDisplayName =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : username;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      legacyHabit: json['habit'] as String?,
      legacyGoal: json['goal'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'username': username,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
      };

  Map<String, dynamic> toUpdateJson() => {
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
      };
}

// ============================================================
// 2) HabitCategory  (zararlı alışkanlık tanımı)
// ============================================================

class HabitCategory {
  final int? id;
  final String? slug;
  final String name;
  final String? description;
  final String iconName;
  final String colorHex;
  final int baseDailyPoints;
  final int healthImpact;
  final int socialImpact;
  final int financialImpact;
  final int addictionLevel;
  final Map<String, dynamic>? geminiEvaluation;
  final bool isValid;
  final String? createdBy;
  final DateTime? createdAt;

  HabitCategory({
    this.id,
    this.slug,
    required this.name,
    this.description,
    this.iconName = 'block',
    this.colorHex = '#EF4444',
    required this.baseDailyPoints,
    required this.healthImpact,
    required this.socialImpact,
    required this.financialImpact,
    required this.addictionLevel,
    this.geminiEvaluation,
    this.isValid = true,
    this.createdBy,
    this.createdAt,
  });

  Color get color => _hexToColor(colorHex, fallback: const Color(0xFFEF4444));

  factory HabitCategory.fromJson(Map<String, dynamic> json) {
    return HabitCategory(
      id: (json['id'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String? ?? 'block',
      colorHex: json['color_hex'] as String? ?? '#EF4444',
      baseDailyPoints: (json['base_daily_points'] as num).toInt(),
      healthImpact: (json['health_impact'] as num).toInt(),
      socialImpact: (json['social_impact'] as num).toInt(),
      financialImpact: (json['financial_impact'] as num).toInt(),
      addictionLevel: (json['addiction_level'] as num).toInt(),
      geminiEvaluation: json['gemini_evaluation'] as Map<String, dynamic>?,
      isValid: json['is_valid'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        if (slug != null) 'slug': slug,
        'name': name,
        if (description != null) 'description': description,
        'icon_name': iconName,
        'color_hex': colorHex,
        'base_daily_points': baseDailyPoints,
        'health_impact': healthImpact,
        'social_impact': socialImpact,
        'financial_impact': financialImpact,
        'addiction_level': addictionLevel,
        if (geminiEvaluation != null) 'gemini_evaluation': geminiEvaluation,
        'is_valid': isValid,
        if (createdBy != null) 'created_by': createdBy,
      };
}

// ============================================================
// 3) ActivityCategory  (olumlu aktivite tanımı)
// ============================================================

class ActivityCategory {
  final int? id;
  final String? slug;
  final String name;
  final String? description;
  final String iconName;
  final String colorHex;
  final int baseBonusPoints;
  final int healthBenefit;
  final int mentalBenefit;
  final bool isDurationBased;
  final double pointsPerMinute;
  final int minDurationMinutes;
  final Map<String, dynamic>? geminiEvaluation;
  final bool isValid;
  final String? createdBy;
  final DateTime? createdAt;

  ActivityCategory({
    this.id,
    this.slug,
    required this.name,
    this.description,
    this.iconName = 'fitness_center',
    this.colorHex = '#22C55E',
    required this.baseBonusPoints,
    required this.healthBenefit,
    required this.mentalBenefit,
    this.isDurationBased = false,
    this.pointsPerMinute = 0,
    this.minDurationMinutes = 0,
    this.geminiEvaluation,
    this.isValid = true,
    this.createdBy,
    this.createdAt,
  });

  Color get color => _hexToColor(colorHex, fallback: const Color(0xFF22C55E));

  factory ActivityCategory.fromJson(Map<String, dynamic> json) {
    return ActivityCategory(
      id: (json['id'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String? ?? 'fitness_center',
      colorHex: json['color_hex'] as String? ?? '#22C55E',
      baseBonusPoints: (json['base_bonus_points'] as num).toInt(),
      healthBenefit: (json['health_benefit'] as num).toInt(),
      mentalBenefit: (json['mental_benefit'] as num).toInt(),
      isDurationBased: json['is_duration_based'] as bool? ?? false,
      pointsPerMinute:
          (json['points_per_minute'] as num?)?.toDouble() ?? 0,
      minDurationMinutes:
          (json['min_duration_minutes'] as num?)?.toInt() ?? 0,
      geminiEvaluation: json['gemini_evaluation'] as Map<String, dynamic>?,
      isValid: json['is_valid'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        if (slug != null) 'slug': slug,
        'name': name,
        if (description != null) 'description': description,
        'icon_name': iconName,
        'color_hex': colorHex,
        'base_bonus_points': baseBonusPoints,
        'health_benefit': healthBenefit,
        'mental_benefit': mentalBenefit,
        'is_duration_based': isDurationBased,
        'points_per_minute': pointsPerMinute,
        'min_duration_minutes': minDurationMinutes,
        if (geminiEvaluation != null) 'gemini_evaluation': geminiEvaluation,
        'is_valid': isValid,
        if (createdBy != null) 'created_by': createdBy,
      };
}

// ============================================================
// 4) UserHabit  (kullanıcının bırakmak istediği bir alışkanlık)
// ============================================================

class UserHabit {
  final int? id;
  final String userId;
  final int habitCategoryId;
  final DateTime quitDate;
  final String? motivation;
  final bool isActive;
  final DateTime? createdAt;

  /// Supabase join geldiyse dolu olur (`*, habit_categories(*)`)
  final HabitCategory? category;

  UserHabit({
    this.id,
    required this.userId,
    required this.habitCategoryId,
    required this.quitDate,
    this.motivation,
    this.isActive = true,
    this.createdAt,
    this.category,
  });

  int get daysSinceQuit {
    final today = DateTime.now();
    final start = DateTime(quitDate.year, quitDate.month, quitDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return now.difference(start).inDays;
  }

  factory UserHabit.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['habit_categories'] as Map<String, dynamic>?;
    return UserHabit(
      id: (json['id'] as num?)?.toInt(),
      userId: json['user_id'] as String,
      habitCategoryId: (json['habit_category_id'] as num).toInt(),
      quitDate: _parseDate(json['quit_date']) ?? DateTime.now(),
      motivation: json['motivation'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDate(json['created_at']),
      category:
          categoryJson != null ? HabitCategory.fromJson(categoryJson) : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'habit_category_id': habitCategoryId,
        'quit_date':
            '${quitDate.year.toString().padLeft(4, '0')}-${quitDate.month.toString().padLeft(2, '0')}-${quitDate.day.toString().padLeft(2, '0')}',
        if (motivation != null) 'motivation': motivation,
        'is_active': isActive,
      };
}

// ============================================================
// 5) HabitLog  (günlük "bugün yapmadım/yaptım" kaydı)
// ============================================================

class HabitLog {
  final int? id;
  final int userHabitId;
  final String userId;
  final DateTime logDate;
  final bool stayedClean;

  /// Trigger tarafından hesaplanır; insert sırasında 0 gönderilir.
  final int pointsEarned;
  final String? relapseNote;
  final DateTime? createdAt;

  HabitLog({
    this.id,
    required this.userHabitId,
    required this.userId,
    required this.logDate,
    required this.stayedClean,
    this.pointsEarned = 0,
    this.relapseNote,
    this.createdAt,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: (json['id'] as num?)?.toInt(),
      userHabitId: (json['user_habit_id'] as num).toInt(),
      userId: json['user_id'] as String,
      logDate: _parseDate(json['log_date']) ?? DateTime.now(),
      stayedClean: json['stayed_clean'] as bool,
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
      relapseNote: json['relapse_note'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_habit_id': userHabitId,
        'user_id': userId,
        'log_date':
            '${logDate.year.toString().padLeft(4, '0')}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}',
        'stayed_clean': stayedClean,
        if (relapseNote != null) 'relapse_note': relapseNote,
        // points_earned trigger tarafından hesaplanır — göndermiyoruz.
      };
}

// ============================================================
// 6) ActivityLog  (günlük aktivite kaydı)
// ============================================================

class ActivityLog {
  final int? id;
  final String userId;
  final int activityCategoryId;
  final DateTime logDate;
  final int? durationMinutes;
  final int pointsEarned;
  final String? notes;
  final DateTime? createdAt;

  /// Supabase join geldiyse dolu olur (`*, activity_categories(*)`)
  final ActivityCategory? category;

  ActivityLog({
    this.id,
    required this.userId,
    required this.activityCategoryId,
    required this.logDate,
    this.durationMinutes,
    this.pointsEarned = 0,
    this.notes,
    this.createdAt,
    this.category,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final categoryJson =
        json['activity_categories'] as Map<String, dynamic>?;
    return ActivityLog(
      id: (json['id'] as num?)?.toInt(),
      userId: json['user_id'] as String,
      activityCategoryId: (json['activity_category_id'] as num).toInt(),
      logDate: _parseDate(json['log_date']) ?? DateTime.now(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['created_at']),
      category: categoryJson != null
          ? ActivityCategory.fromJson(categoryJson)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'activity_category_id': activityCategoryId,
        'log_date':
            '${logDate.year.toString().padLeft(4, '0')}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}',
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (notes != null) 'notes': notes,
      };
}

// ============================================================
// 7) Friendship
// ============================================================

enum FriendshipStatus {
  pending,
  accepted,
  rejected,
  blocked;

  /// DB'den gelen string'i normalize et (mevcut UI uppercase yazıyor).
  static FriendshipStatus fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'rejected':
        return FriendshipStatus.rejected;
      case 'blocked':
        return FriendshipStatus.blocked;
      case 'pending':
      default:
        return FriendshipStatus.pending;
    }
  }

  /// Mevcut UI ile uyumlu kalsın diye DB'ye uppercase yazıyoruz.
  String get dbValue {
    switch (this) {
      case FriendshipStatus.pending:
        return 'PENDING';
      case FriendshipStatus.accepted:
        return 'ACCEPTED';
      case FriendshipStatus.rejected:
        return 'REJECTED';
      case FriendshipStatus.blocked:
        return 'BLOCKED';
    }
  }
}

class Friendship {
  final int? id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// İsteğe bağlı olarak join ile gelen profiller
  final Profile? requesterProfile;
  final Profile? addresseeProfile;

  Friendship({
    this.id,
    required this.requesterId,
    required this.addresseeId,
    this.status = FriendshipStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.requesterProfile,
    this.addresseeProfile,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    final reqJson = json['requester'] as Map<String, dynamic>?;
    final addrJson = json['addressee'] as Map<String, dynamic>?;
    return Friendship(
      id: (json['id'] as num?)?.toInt(),
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: FriendshipStatus.fromString(
        json['status'] as String? ?? 'PENDING',
      ),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      requesterProfile: reqJson != null ? Profile.fromJson(reqJson) : null,
      addresseeProfile: addrJson != null ? Profile.fromJson(addrJson) : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': status.dbValue,
      };
}

// ============================================================
// 8) Achievement
// ============================================================

class Achievement {
  final int? id;
  final String name;
  final String? description;
  final String iconName;
  final int? requiredStreak;
  final int? requiredScore;
  final String category;
  final DateTime? createdAt;

  Achievement({
    this.id,
    required this.name,
    this.description,
    this.iconName = 'emoji_events',
    this.requiredStreak,
    this.requiredScore,
    this.category = 'general',
    this.createdAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String? ?? 'emoji_events',
      requiredStreak: (json['required_streak'] as num?)?.toInt(),
      requiredScore: (json['required_score'] as num?)?.toInt(),
      category: json['category'] as String? ?? 'general',
      createdAt: _parseDate(json['created_at']),
    );
  }
}

// ============================================================
// 9) UserAchievement
// ============================================================

class UserAchievement {
  final int? id;
  final String userId;
  final int achievementId;
  final DateTime? earnedAt;
  final Achievement? achievement;

  UserAchievement({
    this.id,
    required this.userId,
    required this.achievementId,
    this.earnedAt,
    this.achievement,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    final aJson = json['achievements'] as Map<String, dynamic>?;
    return UserAchievement(
      id: (json['id'] as num?)?.toInt(),
      userId: json['user_id'] as String,
      achievementId: (json['achievement_id'] as num).toInt(),
      earnedAt: _parseDate(json['earned_at']),
      achievement: aJson != null ? Achievement.fromJson(aJson) : null,
    );
  }
}

// ============================================================
// 10) LeaderboardEntry  (RPC: get_friend_leaderboard sonucu)
// ============================================================

class LeaderboardEntry {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int totalScore;
  final int currentStreak;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.totalScore,
    required this.currentStreak,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: (json['display_name'] as String?) ?? json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num).toInt(),
    );
  }
}

// ============================================================
// 11) DailyScore  (RPC: get_weekly_score sonucu — günlük satır)
// ============================================================

class DailyScore {
  final DateTime day;
  final int habitPoints;
  final int activityPoints;
  final int totalPoints;

  DailyScore({
    required this.day,
    required this.habitPoints,
    required this.activityPoints,
    required this.totalPoints,
  });

  factory DailyScore.fromJson(Map<String, dynamic> json) {
    return DailyScore(
      day: _parseDate(json['day']) ?? DateTime.now(),
      habitPoints: (json['habit_points'] as num?)?.toInt() ?? 0,
      activityPoints: (json['activity_points'] as num?)?.toInt() ?? 0,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
    );
  }
}
