import 'dart:convert';
import 'dart:io';
import 'package:consistency/database/habit_database.dart';
import 'package:consistency/models/habit.dart';
import 'package:consistency/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const _lastBackupKey = 'lastBackupDate';

  static Future<bool> exportData() async {
    try {
      final isar = HabitDatabase.isar;
      final habits = await isar.habits.where().findAll();

      final List<Map<String, dynamic>> habitList = habits.map((habit) {
        return {
          'id': habit.id,
          'name': habit.name,
          'completedDays':
              habit.completedDays.map((d) => d.toIso8601String()).toList(),
          'streak': habit.streak,
          'longestStreak': habit.longestStreak,
          'reminderTime': habit.reminderTime?.toIso8601String(),
          'isReminderOn': habit.isReminderOn,
          'frequencyType': habit.frequencyType,
          'customDays': habit.customDays,
          'weeklyTarget': habit.weeklyTarget,
        };
      }).toList();

      final backupData = {
        'appName': 'Consistency',
        'version': 3,
        'exportDate': DateTime.now().toIso8601String(),
        'habits': habitList,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final fileName =
          'consistency_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath == null) return false;

      final file = File(outputPath);
      await file.writeAsString(jsonString);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return 'cancelled';

      final filePath = result.files.single.path;
      if (filePath == null) return 'error: Could not read file path.';

      final file = File(filePath);
      final jsonString = await file.readAsString();

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonString);
      } catch (_) {
        return 'error: Invalid JSON file.';
      }

      if (data['appName'] != 'Consistency' || data['habits'] == null) {
        return 'error: This is not a valid Consistency backup file.';
      }

      final List<dynamic> habitList = data['habits'];
      final isar = HabitDatabase.isar;
      final notificationService = NotificationService();

      await isar.writeTxn(() async {
        await isar.habits.clear();

        for (final hData in habitList) {
          final habit = Habit()
            ..name = hData['name'] ?? 'Unnamed'
            ..completedDays = (hData['completedDays'] as List<dynamic>?)
                    ?.map((d) => DateTime.parse(d as String))
                    .toList() ??
                []
            ..streak = hData['streak'] ?? 0
            ..longestStreak = hData['longestStreak'] ?? 0
            ..reminderTime = hData['reminderTime'] != null
                ? DateTime.parse(hData['reminderTime'])
                : null
            ..isReminderOn = hData['isReminderOn'] ?? false
            ..frequencyType = hData['frequencyType'] ?? 0
            ..customDays = (hData['customDays'] as List<dynamic>?)
                    ?.map((d) => d as int)
                    .toList() ??
                []
            ..weeklyTarget = hData['weeklyTarget'] ?? 7;

          final newId = await isar.habits.put(habit);

          if (habit.isReminderOn && habit.reminderTime != null) {
            await notificationService.scheduleReminder(
                newId, habit.name, habit.reminderTime!);
          }
        }
      });

      return 'success: Imported ${habitList.length} habits.';
    } catch (e) {
      return 'error: $e';
    }
  }

  static Future<String?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_lastBackupKey);
    if (dateStr == null) return null;
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return null;
    }
  }
}
