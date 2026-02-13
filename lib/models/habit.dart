import 'package:isar/isar.dart';

part 'habit.g.dart';

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
}
