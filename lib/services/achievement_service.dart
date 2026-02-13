import 'package:consistency/models/habit.dart';

/// Represents a single achievement definition
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isUnlocked;
  final DateTime? unlockedAt; // When it was first achieved

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isUnlocked,
    this.unlockedAt,
  });
}

/// Computes achievements dynamically from habit data — no extra storage needed.
class AchievementService {
  /// All achievement definitions
  static List<Achievement> computeAchievements(List<Habit> habits) {
    // Compute aggregate stats
    int totalCompletions = 0;
    int bestStreak = 0;
    int totalHabits = habits.length;

    for (final h in habits) {
      totalCompletions += h.completedDays.length;
      if (h.longestStreak > bestStreak) bestStreak = h.longestStreak;
    }

    // Check for perfect week (all habits done every day for 7 consecutive days)
    bool hasPerfectWeek = _checkPerfectWeek(habits);

    // Check for early bird (any habit completed before 8am — we can't check time
    // from DateTime(year,month,day) alone, so we approximate: if a habit was
    // created and has a streak, that counts. Instead, let's use a simpler metric:
    // completed 5 habits in a single day)
    int maxHabitsOneDay = _maxHabitsInSingleDay(habits);

    // Check for any 7-day streak
    bool has7DayStreak = habits.any((h) => h.longestStreak >= 7);
    // Check for any 30-day streak
    bool has30DayStreak = habits.any((h) => h.longestStreak >= 30);
    // Check for any 100-day streak
    bool has100DayStreak = habits.any((h) => h.longestStreak >= 100);

    // Determine unlock dates
    DateTime? firstHabitDate = _getEarliestCompletionDate(habits);
    DateTime? streak7Date = _getStreakAchievedDate(habits, 7);
    DateTime? streak30Date = _getStreakAchievedDate(habits, 30);
    DateTime? streak100Date = _getStreakAchievedDate(habits, 100);

    return [
      Achievement(
        id: 'first_habit',
        title: 'First Step',
        description: 'Create your first habit',
        emoji: '🌱',
        isUnlocked: totalHabits >= 1,
        unlockedAt: firstHabitDate,
      ),
      Achievement(
        id: 'first_completion',
        title: 'Getting Started',
        description: 'Complete a habit for the first time',
        emoji: '✅',
        isUnlocked: totalCompletions >= 1,
        unlockedAt: _getEarliestCompletionDate(habits),
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Achieve a 7-day streak on any habit',
        emoji: '🔥',
        isUnlocked: has7DayStreak,
        unlockedAt: streak7Date,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Master',
        description: 'Achieve a 30-day streak on any habit',
        emoji: '💪',
        isUnlocked: has30DayStreak,
        unlockedAt: streak30Date,
      ),
      Achievement(
        id: 'streak_100',
        title: 'Centurion',
        description: 'Achieve a 100-day streak on any habit',
        emoji: '👑',
        isUnlocked: has100DayStreak,
        unlockedAt: streak100Date,
      ),
      Achievement(
        id: 'completions_10',
        title: 'Warming Up',
        description: 'Complete 10 total check-ins',
        emoji: '🏃',
        isUnlocked: totalCompletions >= 10,
      ),
      Achievement(
        id: 'completions_50',
        title: 'Half Century',
        description: 'Complete 50 total check-ins',
        emoji: '⭐',
        isUnlocked: totalCompletions >= 50,
      ),
      Achievement(
        id: 'completions_100',
        title: 'Century Club',
        description: 'Complete 100 total check-ins',
        emoji: '💯',
        isUnlocked: totalCompletions >= 100,
      ),
      Achievement(
        id: 'completions_500',
        title: 'Unstoppable',
        description: 'Complete 500 total check-ins',
        emoji: '🚀',
        isUnlocked: totalCompletions >= 500,
      ),
      Achievement(
        id: 'habits_3',
        title: 'Triple Threat',
        description: 'Track 3 habits simultaneously',
        emoji: '🎯',
        isUnlocked: totalHabits >= 3,
      ),
      Achievement(
        id: 'habits_5',
        title: 'High Five',
        description: 'Track 5 habits simultaneously',
        emoji: '🖐️',
        isUnlocked: totalHabits >= 5,
      ),
      Achievement(
        id: 'perfect_week',
        title: 'Perfect Week',
        description: 'Complete all habits every day for a full week',
        emoji: '🏆',
        isUnlocked: hasPerfectWeek,
      ),
      Achievement(
        id: 'multitasker',
        title: 'Multitasker',
        description: 'Complete 5+ habits in a single day',
        emoji: '🎪',
        isUnlocked: maxHabitsOneDay >= 5,
      ),
      Achievement(
        id: 'perfect_day',
        title: 'Perfect Day',
        description: 'Complete all habits in one day (3+ habits)',
        emoji: '🌟',
        isUnlocked: _hasPerfectDay(habits),
      ),
    ];
  }

  /// Get count of unlocked achievements
  static int unlockedCount(List<Habit> habits) {
    return computeAchievements(habits).where((a) => a.isUnlocked).length;
  }

  /// Get total count of achievements
  static int totalCount() {
    return 14; // Total defined achievements
  }

  // ── Helper methods ─────────────────────────────

  static DateTime? _getEarliestCompletionDate(List<Habit> habits) {
    DateTime? earliest;
    for (final h in habits) {
      for (final d in h.completedDays) {
        if (earliest == null || d.isBefore(earliest)) {
          earliest = d;
        }
      }
    }
    return earliest;
  }

  /// Approximate the date when a streak of [target] was first achieved
  static DateTime? _getStreakAchievedDate(List<Habit> habits, int target) {
    for (final habit in habits) {
      if (habit.longestStreak >= target) {
        final sorted = List<DateTime>.from(habit.completedDays)..sort();
        int tempStreak = 0;
        for (int i = 0; i < sorted.length; i++) {
          if (i == 0) {
            tempStreak = 1;
          } else {
            if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
              tempStreak++;
            } else {
              tempStreak = 1;
            }
          }
          if (tempStreak >= target) return sorted[i];
        }
      }
    }
    return null;
  }

  /// Check if user ever had a perfect week (all habits done 7 consecutive days)
  static bool _checkPerfectWeek(List<Habit> habits) {
    if (habits.isEmpty) return false;

    // Collect all unique dates across all habits
    final Set<String> allDates = {};
    for (final h in habits) {
      for (final d in h.completedDays) {
        allDates.add('${d.year}-${d.month}-${d.day}');
      }
    }

    // For each date, check if the next 7 days form a perfect week
    // (every habit completed every day)
    final sorted = habits.first.completedDays.isEmpty
        ? <DateTime>[]
        : (List<DateTime>.from(habits.first.completedDays)..sort());

    if (sorted.isEmpty) return false;

    final start = sorted.first;
    final end = sorted.last;

    for (var day = start;
        day.isBefore(end.subtract(const Duration(days: 6)));
        day = day.add(const Duration(days: 1))) {
      bool allPerfect = true;
      for (int d = 0; d < 7; d++) {
        final checkDate = day.add(Duration(days: d));
        for (final habit in habits) {
          if (!habit.completedDays.any((cd) =>
              cd.year == checkDate.year &&
              cd.month == checkDate.month &&
              cd.day == checkDate.day)) {
            allPerfect = false;
            break;
          }
        }
        if (!allPerfect) break;
      }
      if (allPerfect) return true;
    }
    return false;
  }

  /// Max number of distinct habits completed in a single day
  static int _maxHabitsInSingleDay(List<Habit> habits) {
    final Map<String, int> dayCounts = {};
    for (final h in habits) {
      final Set<String> uniqueDays = {};
      for (final d in h.completedDays) {
        final key = '${d.year}-${d.month}-${d.day}';
        if (uniqueDays.add(key)) {
          dayCounts[key] = (dayCounts[key] ?? 0) + 1;
        }
      }
    }
    if (dayCounts.isEmpty) return 0;
    return dayCounts.values.reduce((a, b) => a > b ? a : b);
  }

  /// Check if user completed all habits (3+) in any single day
  static bool _hasPerfectDay(List<Habit> habits) {
    if (habits.length < 3) return false;
    final Map<String, int> dayCounts = {};
    for (final h in habits) {
      final Set<String> uniqueDays = {};
      for (final d in h.completedDays) {
        final key = '${d.year}-${d.month}-${d.day}';
        if (uniqueDays.add(key)) {
          dayCounts[key] = (dayCounts[key] ?? 0) + 1;
        }
      }
    }
    return dayCounts.values.any((count) => count >= habits.length);
  }
}
