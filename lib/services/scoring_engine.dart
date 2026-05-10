// ============================================================
// HabitQuest - scoring_engine.dart (v2 - Multi-Habit + Combo)
//
// Client-side scoring (preview amaçlı).
// Source of truth: Supabase DB fonksiyonları.
//
// Her habit'in puanı BAĞIMSIZ hesaplanır.
// Combo bonus ayrı bir mekanizmadır ve DB tarafında yönetilir.
// Bu dosya sadece preview/tahmin sunar.
// ============================================================

import 'dart:math';

class ScoringEngine {
  const ScoringEngine._();

  // ========================
  // STREAK MULTIPLIER (tek habit)
  // ========================
  static double calcStreakMultiplier(int streakDays, {double cap = 2.0}) {
    if (streakDays <= 7) return 1.0;
    final multiplier = 1.0 + ((streakDays - 7) * 0.05);
    return min(multiplier, cap);
  }

  // ========================
  // COMBO BONUS TAHMİNİ
  // 2 habit streak'te → 5, 3 → 7, 4 → 10, 5+ → 15
  // Her 14 günde bir verilir.
  // ========================
  static double getComboBonus(int activeStreakCount) {
    if (activeStreakCount >= 5) return 15.0;
    if (activeStreakCount == 4) return 10.0;
    if (activeStreakCount == 3) return 7.0;
    if (activeStreakCount == 2) return 5.0;
    return 0.0;
  }

  /// Combo streak özetini hesapla
  static ComboPreview estimateComboStreak({
    required List<int> habitStreaks, // Her habit'in streak değeri
    required DateTime? lastComboBonusDate,
  }) {
    final activeCount = habitStreaks.where((s) => s >= 1).length;
    final bonus = getComboBonus(activeCount);
    final today = DateTime.now();

    int daysUntilNext = 0;
    if (lastComboBonusDate != null) {
      final daysSince = today.difference(lastComboBonusDate).inDays;
      daysUntilNext = max(0, 14 - daysSince);
    }

    return ComboPreview(
      activeStreakCount: activeCount,
      potentialBonus: bonus,
      daysUntilNextBonus: daysUntilNext,
      isEligible: activeCount >= 2 && daysUntilNext == 0,
    );
  }

  // ========================
  // TEK HABİT GÜNLÜK PUAN TAHMİNİ
  // ========================
  static ScorePreview estimateDailyScore({
    required double reportedValue,
    required double dailyTarget,
    required String targetDirection,
    required String programType,
    required double baseDailyPoints,
    required double difficultyWeight,
    required double streakMultiplierCap,
    required int currentStreak,     // BU HABİT'İN streak'i
    double stepPenaltyReward = 0,
    double effortMultiplier = 0,
    double? caloriesBurned,
    double calorieToPointRate = 0,
    List<ActivityBonus> activityBonuses = const [],
  }) {
    double basePoints = 0;
    double penalty = 0;
    double effortBonus = 0;
    double activityBonus = 0;
    bool isSuccess = false;

    switch (programType) {
      case 'QUIT':
      case 'REDUCE':
        if (targetDirection == 'DECREASE') {
          if (reportedValue <= dailyTarget) {
            basePoints = baseDailyPoints * difficultyWeight;
            isSuccess = true;
          } else {
            final exceeded = reportedValue - dailyTarget;
            penalty = exceeded * stepPenaltyReward.abs();
            basePoints = max(0, baseDailyPoints - penalty);
          }
        }
        break;

      case 'GRADUAL_DECREASE':
        if (reportedValue <= dailyTarget) {
          basePoints = baseDailyPoints * difficultyWeight;
          isSuccess = true;
          if (dailyTarget > 0 && reportedValue < dailyTarget * 0.5) {
            basePoints *= 1.15;
          }
        } else {
          final exceeded = reportedValue - dailyTarget;
          penalty = exceeded * stepPenaltyReward.abs();
          basePoints = max(0, baseDailyPoints - penalty);
        }
        break;

      case 'GRADUAL_INCREASE':
        if (dailyTarget > 0) {
          final ratio = min(reportedValue / dailyTarget, 1.5);
          basePoints = ratio * baseDailyPoints * difficultyWeight;
          isSuccess = reportedValue >= dailyTarget;
          if (reportedValue > dailyTarget) {
            effortBonus += (reportedValue - dailyTarget) * stepPenaltyReward;
          }
        } else {
          basePoints = baseDailyPoints;
          isSuccess = true;
        }
        break;

      case 'MAINTAIN':
        if (targetDirection == 'INCREASE') {
          final ratio =
              dailyTarget > 0 ? min(reportedValue / dailyTarget, 1.0) : 1.0;
          basePoints = ratio * baseDailyPoints * difficultyWeight;
          isSuccess = reportedValue >= dailyTarget;
        } else {
          isSuccess = reportedValue <= dailyTarget;
          if (isSuccess) {
            basePoints = baseDailyPoints * difficultyWeight;
          } else {
            final exceeded = reportedValue - dailyTarget;
            penalty = exceeded * stepPenaltyReward.abs();
            basePoints = max(0, baseDailyPoints - penalty);
          }
        }
        break;
    }

    // Bu habit'in bağımsız streak'i
    final newStreak = isSuccess ? currentStreak + 1 : 0;
    final streakMult =
        calcStreakMultiplier(newStreak, cap: streakMultiplierCap);
    final streakBonus = basePoints * (streakMult - 1.0);

    // Effort
    if (targetDirection == 'INCREASE' && effortMultiplier > 0) {
      effortBonus += reportedValue * effortMultiplier;
    }

    if (caloriesBurned != null && calorieToPointRate > 0) {
      effortBonus += caloriesBurned * calorieToPointRate;
    }

    // Activities
    for (final b in activityBonuses) {
      activityBonus += min(b.value * b.pointConversion, b.maxBonusLimit);
    }

    final total = max(
      0.0,
      _r(basePoints) +
          _r(streakBonus) +
          _r(effortBonus) +
          _r(activityBonus) -
          _r(penalty),
    );

    return ScorePreview(
      basePoints: _r(basePoints),
      streakMultiplier: _r(streakMult),
      streakBonus: _r(streakBonus),
      effortBonus: _r(effortBonus),
      activityBonus: _r(activityBonus),
      penalty: _r(penalty),
      totalPoints: _r(total),
      isSuccess: isSuccess,
      newStreak: newStreak,
    );
  }

  // ========================
  // KADEMELİ HEDEF
  // ========================
  static double calculateNextPhaseTarget({
    required double currentTarget,
    required double finalTarget,
    required double stepAmount,
    required String targetDirection,
  }) {
    if (targetDirection == 'DECREASE') {
      return max(finalTarget, currentTarget - stepAmount);
    } else {
      return min(finalTarget, currentTarget + stepAmount);
    }
  }

  // ========================
  // KALORİ TAHMİNİ
  // ========================
  static double estimateCalories({
    required double durationMinutes,
    required double caloriesPerMinute,
  }) =>
      durationMinutes * caloriesPerMinute;

  /// Yaygın aktivitelerin dk başına kcal (70kg yetişkin)
  static const Map<String, double> defaultCaloriesPerMinute = {
    'walking_slow': 3.5,
    'walking_brisk': 5.0,
    'running_light': 8.5,
    'running': 11.5,
    'cycling_light': 5.5,
    'cycling_moderate': 8.0,
    'swimming': 7.0,
    'yoga': 3.0,
    'weight_training': 6.0,
    'hiit': 12.0,
    'dancing': 5.5,
    'climbing_stairs': 9.0,
  };

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

// ============================================================
// MODELS
// ============================================================

class ScorePreview {
  final double basePoints;
  final double streakMultiplier;
  final double streakBonus;
  final double effortBonus;
  final double activityBonus;
  final double penalty;
  final double totalPoints;
  final bool isSuccess;
  final int newStreak;

  const ScorePreview({
    required this.basePoints,
    required this.streakMultiplier,
    required this.streakBonus,
    required this.effortBonus,
    required this.activityBonus,
    required this.penalty,
    required this.totalPoints,
    required this.isSuccess,
    required this.newStreak,
  });

  @override
  String toString() =>
      'Score(total: $totalPoints, base: $basePoints, '
      'streak: ${streakMultiplier}x +$streakBonus, effort: +$effortBonus, '
      'activity: +$activityBonus, penalty: -$penalty, '
      'success: $isSuccess, streak: $newStreak days)';
}

class ComboPreview {
  final int activeStreakCount;
  final double potentialBonus;
  final int daysUntilNextBonus;
  final bool isEligible;

  const ComboPreview({
    required this.activeStreakCount,
    required this.potentialBonus,
    required this.daysUntilNextBonus,
    required this.isEligible,
  });

  @override
  String toString() =>
      'Combo(active: $activeStreakCount, bonus: +$potentialBonus, '
      'eligible: $isEligible, days_left: $daysUntilNextBonus)';
}

class ActivityBonus {
  final String slug;
  final double value;
  final double pointConversion;
  final double maxBonusLimit;

  const ActivityBonus({
    required this.slug,
    required this.value,
    required this.pointConversion,
    required this.maxBonusLimit,
  });
}
