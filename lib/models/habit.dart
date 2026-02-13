import 'package:isar/isar.dart';

part 'habit.g.dart';

/// Frequency types for habits:
/// 0 = daily (every day)
/// 1 = custom (specific weekdays, stored in customDays)
/// 2 = xPerWeek (X completions per week, stored in weeklyTarget)
@Collection()
class Habit {
  Id id = Isar.autoIncrement;

  late String name;

  List<DateTime> completedDays = [];

  // Streak tracking
  int streak = 0;
  int longestStreak = 0;

  // Reminders
  DateTime? reminderTime;
  bool isReminderOn = false;

  // Frequency customization
  /// 0 = daily, 1 = custom days, 2 = X per week
  int frequencyType = 0;

  /// Weekday indices for custom frequency (1=Mon, 2=Tue, ..., 7=Sun)
  List<int> customDays = [];

  /// Target completions per week (for frequencyType == 2)
  int weeklyTarget = 7;
}
