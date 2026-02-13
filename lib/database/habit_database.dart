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

  // List of habits
  final List<Habit> currentHabits = [];

  // Init habits
  Future<void> init() async {
    await readHabits();
  }

  // Add habits with frequency
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
    final fetchedHabits = await isar.habits.where().findAll();
    currentHabits.clear();
    currentHabits.addAll(fetchedHabits);
    notifyListeners();
  }

  // Update habit completion
  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    final habit = await isar.habits.get(id);

    if (habit != null) {
      await isar.writeTxn(() async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (isCompleted) {
          // Avoid duplicates
          if (!habit.completedDays.any((d) =>
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day)) {
            habit.completedDays.add(todayDate);
          }
        } else {
          habit.completedDays.removeWhere(
            (date) =>
                date.year == today.year &&
                date.month == today.month &&
                date.day == today.day,
          );
        }

        _calculateStreaks(habit);
        await isar.habits.put(habit);
      });
    }
    readHabits();
  }

  /// Frequency-aware streak calculation.
  ///
  /// - **Daily (type 0):** Every consecutive day must be completed.
  /// - **Custom days (type 1):** Only scheduled weekdays count. Gaps on
  ///   non-scheduled days do NOT break the streak.
  /// - **X per week (type 2):** Each calendar week (Mon-Sun) where the
  ///   weekly target is met counts as one streak unit.
  void _calculateStreaks(Habit habit) {
    if (habit.completedDays.isEmpty) {
      habit.streak = 0;
      habit.longestStreak = 0;
      return;
    }

    habit.completedDays.sort();

    if (habit.frequencyType == 0) {
      _calculateDailyStreaks(habit);
    } else if (habit.frequencyType == 1) {
      _calculateCustomDaysStreaks(habit);
    } else if (habit.frequencyType == 2) {
      _calculateWeeklyTargetStreaks(habit);
    }
  }

  /// Daily: original logic — every consecutive calendar day.
  void _calculateDailyStreaks(Habit habit) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    int currentStreak = 0;

    bool containsToday = habit.completedDays.last.isAtSameMomentAs(todayDate);

    if (containsToday) {
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
      bool containsYesterday =
          habit.completedDays.any((d) => d.isAtSameMomentAs(yesterdayDate));
      if (containsYesterday) {
        currentStreak = 0;
        DateTime checkDate = yesterdayDate;
        for (int i = habit.completedDays.length - 1; i >= 0; i--) {
          if (habit.completedDays[i].isAtSameMomentAs(checkDate)) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            if (habit.completedDays[i].isBefore(checkDate)) break;
          }
        }
      }
    }

    habit.streak = currentStreak;

    // Longest streak
    int tempStreak = 0;
    int maxStreak = 0;
    for (int i = 0; i < habit.completedDays.length; i++) {
      if (i == 0) {
        tempStreak = 1;
      } else {
        final prev = habit.completedDays[i - 1];
        final curr = habit.completedDays[i];
        if (curr.difference(prev).inDays == 1) {
          tempStreak++;
        } else {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 1;
        }
      }
    }
    if (tempStreak > maxStreak) maxStreak = tempStreak;
    habit.longestStreak = maxStreak;
  }

  /// Custom days: streak counts scheduled days completed in sequence.
  /// Missing a non-scheduled day does NOT break the streak.
  void _calculateCustomDaysStreaks(Habit habit) {
    if (habit.customDays.isEmpty) {
      // No days selected → treat as daily
      _calculateDailyStreaks(habit);
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Build set of completed dates for O(1) lookup
    final completedSet = <String>{};
    for (final d in habit.completedDays) {
      completedSet.add('${d.year}-${d.month}-${d.day}');
    }

    // Walk backward from today through scheduled days
    int currentStreak = 0;

    // Go back max 365 days to find streak
    for (int dayOffset = 0; dayOffset < 365; dayOffset++) {
      final d = todayDate.subtract(Duration(days: dayOffset));
      final weekday = d.weekday; // 1=Mon ... 7=Sun

      if (!habit.customDays.contains(weekday)) continue; // Skip non-scheduled

      final key = '${d.year}-${d.month}-${d.day}';
      if (completedSet.contains(key)) {
        currentStreak++;
      } else {
        // Today not completed yet is OK — don't break streak
        if (dayOffset == 0) continue;
        break;
      }
    }

    habit.streak = currentStreak;

    // Longest streak: walk forward through all scheduled days
    int maxStreak = 0;
    int tempStreak = 0;

    // Get all dates in range
    if (habit.completedDays.isNotEmpty) {
      final firstDate = habit.completedDays.first;
      final dayCount = todayDate.difference(firstDate).inDays + 1;

      for (int i = 0; i < dayCount; i++) {
        final d = firstDate.add(Duration(days: i));
        if (!habit.customDays.contains(d.weekday)) continue;

        final key = '${d.year}-${d.month}-${d.day}';
        if (completedSet.contains(key)) {
          tempStreak++;
        } else {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 0;
        }
      }
      if (tempStreak > maxStreak) maxStreak = tempStreak;
    }

    habit.longestStreak = maxStreak;
  }

  /// X per week: each Mon-Sun week where completions >= weeklyTarget
  /// counts as one streak unit (consecutive weeks).
  void _calculateWeeklyTargetStreaks(Habit habit) {
    if (habit.weeklyTarget <= 0) {
      habit.streak = 0;
      habit.longestStreak = 0;
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Group completions by ISO week
    final Map<String, int> weekCounts = {};
    for (final d in habit.completedDays) {
      final weekKey = _isoWeekKey(d);
      weekCounts[weekKey] = (weekCounts[weekKey] ?? 0) + 1;
    }

    // Get current week key
    final currentWeekKey = _isoWeekKey(todayDate);

    // Walk backward through weeks
    int currentStreak = 0;
    DateTime checkDate = _startOfWeek(todayDate);

    for (int weekOffset = 0; weekOffset < 52; weekOffset++) {
      final weekStart = checkDate.subtract(Duration(days: weekOffset * 7));
      final weekKey = _isoWeekKey(weekStart);
      final count = weekCounts[weekKey] ?? 0;

      if (count >= habit.weeklyTarget) {
        currentStreak++;
      } else {
        // Current incomplete week is OK
        if (weekKey == currentWeekKey && weekOffset == 0) continue;
        break;
      }
    }

    habit.streak = currentStreak;

    // Longest streak of consecutive qualifying weeks
    if (habit.completedDays.isEmpty) {
      habit.longestStreak = 0;
      return;
    }

    final firstDate = habit.completedDays.first;
    final totalWeeks =
        (todayDate.difference(firstDate).inDays / 7).ceil() + 1;
    DateTime weekStart = _startOfWeek(firstDate);

    int maxStreak = 0;
    int tempStreak = 0;

    for (int w = 0; w < totalWeeks; w++) {
      final ws = weekStart.add(Duration(days: w * 7));
      final wk = _isoWeekKey(ws);
      final count = weekCounts[wk] ?? 0;

      if (count >= habit.weeklyTarget) {
        tempStreak++;
      } else {
        if (tempStreak > maxStreak) maxStreak = tempStreak;
        tempStreak = 0;
      }
    }
    if (tempStreak > maxStreak) maxStreak = tempStreak;
    habit.longestStreak = maxStreak;
  }

  /// Returns the Monday of the week containing [date].
  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Returns "YYYY-WNN" ISO week key for grouping.
  String _isoWeekKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final monday = _startOfWeek(d);
    // Calculate ISO week number
    final jan1 = DateTime(monday.year, 1, 1);
    final weekNumber =
        ((monday.difference(jan1).inDays) / 7).floor() + 1;
    return '${monday.year}-W$weekNumber';
  }

  // Toggle completion for a specific date (past editing)
  Future<bool?> toggleHabitDate(int id, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    if (normalizedDate.isAfter(todayNormalized)) {
      return null;
    }

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

  // Rename the habit
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

  // Update frequency settings
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

  // Update reminder
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

  // Delete habits
  Future<void> deleteHabit(int id) async {
    await _notificationService.cancelReminder(id);
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });
    readHabits();
  }

  /// Helper: check if today is a scheduled day for this habit
  static bool isTodayScheduled(Habit habit) {
    final todayWeekday = DateTime.now().weekday; // 1=Mon ... 7=Sun
    switch (habit.frequencyType) {
      case 0: // daily
        return true;
      case 1: // custom days
        return habit.customDays.contains(todayWeekday);
      case 2: // x per week → always allowed
        return true;
      default:
        return true;
    }
  }

  /// Helper: get a human-readable frequency label
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
}
