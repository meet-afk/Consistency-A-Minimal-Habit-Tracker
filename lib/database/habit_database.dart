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

  // Add habits
  Future<void> addHabit(String habitName) async {
    final newHabit = Habit()..name = habitName;
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

        // Calculate streaks
        _calculateStreaks(habit);

        await isar.habits.put(habit);
      });
    }
    readHabits();
  }

  void _calculateStreaks(Habit habit) {
    if (habit.completedDays.isEmpty) {
      habit.streak = 0;
      habit.longestStreak = 0;
      return;
    }

    habit.completedDays.sort();
    
    int currentStreak = 0;
    int maxStreak = 0;
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    bool containsToday = habit.completedDays.isNotEmpty && habit.completedDays.last.isAtSameMomentAs(todayDate);
    
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
       bool containsYesterday = habit.completedDays.any((d) => d.isAtSameMomentAs(yesterdayDate));
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
       } else {
         currentStreak = 0;
       }
    }
    
    habit.streak = currentStreak;

    // Calculate longest streak from full history
    int tempStreak = 0;
    for (int i = 0; i < habit.completedDays.length; i++) {
        if (i == 0) {
            tempStreak = 1;
        } else {
            final prev = habit.completedDays[i-1];
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
}
