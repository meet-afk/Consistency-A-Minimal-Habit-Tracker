import 'package:consistency/models/app_settings.dart';
import 'package:consistency/models/habit.dart';
import 'package:consistency/services/notification_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class HabitDatabase extends ChangeNotifier {
  static late Isar isar;
  static final NotificationService _notificationService = NotificationService();

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [HabitSchema, AppSettingsSchema],
      directory: dir.path,
    );
    await _notificationService.init();
    await _notificationService.requestPermissions();
  }

  Future<void> saveFirstLaunchDate() async {
    final existingSettings = await isar.appSettings.where().findFirst();
    if (existingSettings == null) {
      final settings = AppSettings()..firstLaunchDate = DateTime.now();
      await isar.writeTxn(() => isar.appSettings.put(settings));
    }
  }

  Future<DateTime?> getFirstLaunchDate() async {
    final settings = await isar.appSettings.where().findFirst();
    return settings?.firstLaunchDate;
  }

  final List<Habit> currentHabits = [];

  Future<void> init() async {
    await readHabits();
  }

  // ───────────────────────── CRUD ─────────────────────────

  Future<void> addHabit(
    String habitName, {
    int frequencyType = 0,
    List<int> customDays = const [],
    int weeklyTarget = 7,
  }) async {
    final newHabit = Habit()
      ..name = habitName
      ..frequencyType = frequencyType
      ..customDays = customDays
      ..weeklyTarget = weeklyTarget;
    await isar.writeTxn(() => isar.habits.put(newHabit));
    readHabits();
  }

  Future<void> readHabits() async {
    final fetched = await isar.habits.where().findAll();
    currentHabits.clear();
    currentHabits.addAll(fetched);
    notifyListeners();
  }

  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (isCompleted) {
          if (!habit.completedDays.any((d) =>
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day)) {
            habit.completedDays.add(todayDate);
          }
        } else {
          habit.completedDays.removeWhere((d) =>
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day);
        }

        _calculateStreaks(habit);
        await isar.habits.put(habit);
      });

      // Dismiss persistent notification if completed & has reminder
      if (isCompleted && habit.isReminderOn && habit.reminderTime != null) {
        await _notificationService.dismissAndReschedule(
          id, habit.name, habit.reminderTime!,
        );
      }
    }
    readHabits();
  }

  Future<bool?> toggleHabitDate(int id, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    if (normalizedDate.isAfter(todayNormalized)) return null;

    final habit = await isar.habits.get(id);
    if (habit == null) return null;

    bool nowCompleted = false;

    await isar.writeTxn(() async {
      final alreadyCompleted = habit.completedDays.any((d) =>
          d.year == normalizedDate.year &&
          d.month == normalizedDate.month &&
          d.day == normalizedDate.day);

      if (alreadyCompleted) {
        habit.completedDays.removeWhere((d) =>
            d.year == normalizedDate.year &&
            d.month == normalizedDate.month &&
            d.day == normalizedDate.day);
        nowCompleted = false;
      } else {
        habit.completedDays.add(normalizedDate);
        nowCompleted = true;
      }

      _calculateStreaks(habit);
      await isar.habits.put(habit);
    });

    readHabits();
    return nowCompleted;
  }

  Future<void> updateHabitName(int id, String newName) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        habit.name = newName;
        await isar.habits.put(habit);
      });
    }
    readHabits();
  }

  Future<void> updateHabitFrequency(
    int id, {
    required int frequencyType,
    List<int> customDays = const [],
    int weeklyTarget = 7,
  }) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        habit.frequencyType = frequencyType;
        habit.customDays = customDays;
        habit.weeklyTarget = weeklyTarget;
        _calculateStreaks(habit);
        await isar.habits.put(habit);
      });
    }
    readHabits();
  }

  Future<void> updateHabitReminder(int id, DateTime? time, bool isOn) async {
    final habit = await isar.habits.get(id);
    if (habit != null) {
      await isar.writeTxn(() async {
        habit.reminderTime = time;
        habit.isReminderOn = isOn;
        await isar.habits.put(habit);
      });
      if (isOn && time != null) {
        await _notificationService.scheduleReminder(id, habit.name, time);
      } else {
        await _notificationService.cancelReminder(id);
      }
    }
    readHabits();
  }

  Future<void> deleteHabit(int id) async {
    await _notificationService.cancelReminder(id);
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });
    readHabits();
  }

  // ───────────────────────── STREAK CALCULATION ─────────────────────────

  void _calculateStreaks(Habit habit) {
    if (habit.completedDays.isEmpty) {
      habit.streak = 0;
      habit.longestStreak = 0;
      return;
    }
    habit.completedDays.sort();

    switch (habit.frequencyType) {
      case 0:
        _calculateDailyStreaks(habit);
        break;
      case 1:
        _calculateCustomDaysStreaks(habit);
        break;
      case 2:
        _calculateWeeklyTargetStreaks(habit);
        break;
      default:
        _calculateDailyStreaks(habit);
    }
  }

  /// Daily: every consecutive calendar day.
  void _calculateDailyStreaks(Habit habit) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    int currentStreak = 0;

    if (habit.completedDays.last.isAtSameMomentAs(todayDate)) {
      currentStreak = 1;
      DateTime checkDate = yesterdayDate;
      for (int i = habit.completedDays.length - 2; i >= 0; i--) {
        if (habit.completedDays[i].isAtSameMomentAs(checkDate)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    } else {
      if (habit.completedDays.any((d) => d.isAtSameMomentAs(yesterdayDate))) {
        DateTime checkDate = yesterdayDate;
        for (int i = habit.completedDays.length - 1; i >= 0; i--) {
          if (habit.completedDays[i].isAtSameMomentAs(checkDate)) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else if (habit.completedDays[i].isBefore(checkDate)) {
            break;
          }
        }
      }
    }
    habit.streak = currentStreak;

    // Longest streak (full history)
    int temp = 0, max = 0;
    for (int i = 0; i < habit.completedDays.length; i++) {
      if (i == 0) {
        temp = 1;
      } else {
        temp = (habit.completedDays[i]
                    .difference(habit.completedDays[i - 1])
                    .inDays ==
                1)
            ? temp + 1
            : 1;
      }
      if (temp > max) max = temp;
    }
    habit.longestStreak = max;
  }

  /// Custom days: WEEK streak — consecutive weeks where every scheduled
  /// weekday was completed.
  ///
  /// Uses the first completion date as a proxy for "habit creation".
  /// Scheduled days before the first completion are ignored (the habit
  /// didn't exist yet). Today is treated leniently — not completing today
  /// doesn't break the streak.
  void _calculateCustomDaysStreaks(Habit habit) {
    if (habit.customDays.isEmpty) {
      _calculateDailyStreaks(habit);
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // First completion is the earliest date the habit was ever done
    final firstCompletion = habit.completedDays.first; // already sorted

    // Build O(1) lookup set
    final completedSet = <String>{};
    for (final d in habit.completedDays) {
      completedSet.add('${d.year}-${d.month}-${d.day}');
    }

    final sortedDays = List<int>.from(habit.customDays)..sort();

    // Monday of a date
    DateTime monday(DateTime d) =>
        DateTime(d.year, d.month, d.day)
            .subtract(Duration(days: d.weekday - 1));

    /// Check if a week is satisfied.
    /// For the current week: skip future days and today (if not done).
    /// Always skip days before [firstCompletion] (habit didn't exist).
    /// Needs at least one completion in the week to count.
    bool isWeekSatisfied(DateTime weekStart, bool isCurrentWeek) {
      bool hasAnyCompletion = false;
      for (final dayNum in sortedDays) {
        final date = weekStart.add(Duration(days: dayNum - 1));
        final key = '${date.year}-${date.month}-${date.day}';

        // Skip days before the habit existed
        if (date.isBefore(firstCompletion)) continue;

        // Skip future days in the current week
        if (isCurrentWeek && date.isAfter(todayDate)) continue;

        // Today: count if done, skip if not (don't penalise)
        if (isCurrentWeek && date.isAtSameMomentAs(todayDate)) {
          if (completedSet.contains(key)) hasAnyCompletion = true;
          continue; // either way, don't fail the week for today
        }

        // Past scheduled day — must be completed
        if (completedSet.contains(key)) {
          hasAnyCompletion = true;
        } else {
          return false; // missed a past scheduled day
        }
      }
      return hasAnyCompletion; // need at least one completion to count
    }

    // Walk backward from current week
    int currentStreak = 0;
    final currentMonday = monday(todayDate);

    for (int w = 0; w < 200; w++) {
      final ws = currentMonday.subtract(Duration(days: w * 7));

      // Don't check weeks entirely before the habit existed
      final weekEnd = ws.add(const Duration(days: 6));
      if (weekEnd.isBefore(firstCompletion)) break;

      if (isWeekSatisfied(ws, w == 0)) {
        currentStreak++;
      } else {
        // Current week that's not satisfied yet: don't count, don't break
        if (w == 0) continue;
        break;
      }
    }
    habit.streak = currentStreak;

    // Longest streak (scan full history)
    final firstMonday = monday(firstCompletion);
    final totalWeeks =
        (currentMonday.difference(firstMonday).inDays ~/ 7) + 1;

    int temp = 0, max = 0;
    for (int w = 0; w < totalWeeks; w++) {
      final ws = firstMonday.add(Duration(days: w * 7));
      final isCurrent = ws.isAtSameMomentAs(currentMonday);
      if (isWeekSatisfied(ws, isCurrent)) {
        temp++;
      } else {
        if (temp > max) max = temp;
        temp = 0;
      }
    }
    if (temp > max) max = temp;
    habit.longestStreak = max;
  }

  /// X per week: WEEK streak — consecutive weeks where completions ≥ target.
  ///
  /// Current (incomplete) week doesn't break the streak but only counts
  /// if the target is already met.
  void _calculateWeeklyTargetStreaks(Habit habit) {
    if (habit.weeklyTarget <= 0) {
      habit.streak = 0;
      habit.longestStreak = 0;
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final firstCompletion = habit.completedDays.first; // already sorted

    // Group completions by week (key = Monday date string)
    DateTime monday(DateTime d) =>
        DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

    final Map<String, int> weekCounts = {};
    for (final d in habit.completedDays) {
      final m = monday(d);
      final key = '${m.year}-${m.month}-${m.day}';
      weekCounts[key] = (weekCounts[key] ?? 0) + 1;
    }

    String weekKey(DateTime ws) => '${ws.year}-${ws.month}-${ws.day}';

    final currentMonday = monday(todayDate);
    final firstMonday = monday(firstCompletion);

    // Walk backward
    int currentStreak = 0;
    for (int w = 0; w < 200; w++) {
      final ws = currentMonday.subtract(Duration(days: w * 7));

      // Don't check weeks before the habit existed
      final weekEnd = ws.add(const Duration(days: 6));
      if (weekEnd.isBefore(firstCompletion)) break;

      final count = weekCounts[weekKey(ws)] ?? 0;

      if (count >= habit.weeklyTarget) {
        currentStreak++;
      } else {
        // Current incomplete week — don't break, but don't count either
        if (w == 0) continue;
        break;
      }
    }
    habit.streak = currentStreak;

    // Longest streak
    final totalWeeks =
        (currentMonday.difference(firstMonday).inDays ~/ 7) + 1;

    int temp = 0, max = 0;
    for (int w = 0; w < totalWeeks; w++) {
      final ws = firstMonday.add(Duration(days: w * 7));
      final count = weekCounts[weekKey(ws)] ?? 0;
      if (count >= habit.weeklyTarget) {
        temp++;
      } else {
        if (temp > max) max = temp;
        temp = 0;
      }
    }
    if (temp > max) max = temp;
    habit.longestStreak = max;
  }

  // ───────────────────────── HELPERS ─────────────────────────

  /// Check if today is a scheduled day for this habit.
  static bool isTodayScheduled(Habit habit) {
    final todayWeekday = DateTime.now().weekday;
    switch (habit.frequencyType) {
      case 0:
        return true;
      case 1:
        return habit.customDays.contains(todayWeekday);
      case 2:
        return true;
      default:
        return true;
    }
  }

  /// Human-readable frequency label (e.g. "Mon, Wed, Fri" or "3x / week").
  static String frequencyLabel(Habit habit) {
    switch (habit.frequencyType) {
      case 0:
        return 'Daily';
      case 1:
        if (habit.customDays.isEmpty) return 'Daily';
        const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sorted = List<int>.from(habit.customDays)..sort();
        return sorted.map((d) => names[d]).join(', ');
      case 2:
        return '${habit.weeklyTarget}x / week';
      default:
        return 'Daily';
    }
  }

  /// Streak text for display: "5 day streak" or "3 week streak".
  /// Returns null if streak is 0.
  static String? streakLabel(Habit habit) {
    if (habit.streak <= 0) return null;
    final unit = habit.frequencyType == 0 ? 'day' : 'week';
    return '${habit.streak} $unit streak';
  }
}
