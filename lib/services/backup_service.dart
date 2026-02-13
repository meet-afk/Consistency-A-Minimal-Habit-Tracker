import 'dart:convert';
import 'dart:io';

import 'package:consistency/database/habit_database.dart';
import 'package:consistency/models/habit.dart';
import 'package:consistency/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
          'completedDays': habit.completedDays
              .map((d) => d.toIso8601String())
              .toList(),
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
      final validFilename =
          'consistency_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$validFilename');
      await file.writeAsString(jsonString);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Consistency Data Backup',
          text: 'Backup from ${DateFormat.yMMMd().format(DateTime.now())}',
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }

  static Future<String> importData() async {
    try {
      debugPrint('Starting import...');

      // Pick file using the same pattern as your working app
      final filePickerRes = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (filePickerRes == null) {
        debugPrint('File picker cancelled');
        return 'Import cancelled';
      }

      // Read file using xFile.path like your working code
      final file = File(filePickerRes.files.first.xFile.path);

      if (!await file.exists()) {
        return 'error: Could not access the selected file';
      }

      final jsonString = await file.readAsString();

      if (jsonString.trim().isEmpty) {
        return 'error: The selected file is empty';
      }

      // Parse and import
      return await _parseAndImport(jsonString);
    } catch (e, stackTrace) {
      debugPrint('Import error: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'error: Import failed: $e';
    }
  }

  static Future<String> _parseAndImport(String jsonString) async {
    try {
      debugPrint('Parsing JSON...');

      // Parse JSON
      final Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(jsonString);
        if (decoded is! Map<String, dynamic>) {
          return 'error: Invalid backup file format';
        }
        data = decoded;
      } catch (e) {
        debugPrint('JSON parse error: $e');
        return 'error: Invalid JSON file';
      }

      // Validate backup structure
      if (data['appName'] != 'Consistency') {
        return 'error: Not a valid Consistency backup file';
      }

      if (data['habits'] == null || data['habits'] is! List) {
        return 'error: Backup file is corrupted';
      }

      final List<dynamic> habitList = data['habits'];
      debugPrint('Found ${habitList.length} habits to import');

      if (habitList.isEmpty) {
        return 'error: Backup file contains no habits';
      }

      // Import to database
      final isar = HabitDatabase.isar;
      final notificationService = NotificationService();
      int successCount = 0;

      await isar.writeTxn(() async {
        // Clear existing habits
        await isar.habits.clear();
        debugPrint('Cleared existing habits');

        // Import each habit
        for (var i = 0; i < habitList.length; i++) {
          try {
            final hData = habitList[i];

            if (hData is! Map<String, dynamic>) {
              debugPrint('Skipping invalid habit at index $i');
              continue;
            }

            final habit = Habit()
              ..name = hData['name']?.toString() ?? 'Unnamed Habit'
              ..completedDays = _parseCompletedDays(hData['completedDays'])
              ..streak = _parseInt(hData['streak'], 0)
              ..longestStreak = _parseInt(hData['longestStreak'], 0)
              ..reminderTime = _parseDateTime(hData['reminderTime'])
              ..isReminderOn = hData['isReminderOn'] == true
              ..frequencyType = _parseInt(hData['frequencyType'], 0)
              ..customDays = _parseIntList(hData['customDays'])
              ..weeklyTarget = _parseInt(hData['weeklyTarget'], 7);

            final newId = await isar.habits.put(habit);
            successCount++;
            debugPrint('Imported habit: ${habit.name} (ID: $newId)');

            // Schedule reminder if enabled
            if (habit.isReminderOn && habit.reminderTime != null) {
              try {
                await notificationService.scheduleReminder(
                  newId,
                  habit.name,
                  habit.reminderTime!,
                );
              } catch (e) {
                debugPrint('Failed to schedule reminder: $e');
              }
            }
          } catch (e) {
            debugPrint('Error importing habit $i: $e');
          }
        }
      });

      debugPrint('Import complete: $successCount habits imported');

      if (successCount == 0) {
        return 'error: Failed to import any habits';
      }

      return 'success: Successfully imported $successCount ${successCount == 1 ? 'habit' : 'habits'}!';
    } catch (e, stackTrace) {
      debugPrint('Parse error: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'error: Failed to process backup: $e';
    }
  }

  // Helper methods for safe parsing
  static List<DateTime> _parseCompletedDays(dynamic data) {
    if (data == null || data is! List) return [];

    final List<DateTime> dates = [];
    for (final item in data) {
      try {
        if (item is String) {
          dates.add(DateTime.parse(item));
        }
      } catch (e) {
        debugPrint('Failed to parse date: $item');
      }
    }
    return dates;
  }

  static int _parseInt(dynamic data, int defaultValue) {
    if (data == null) return defaultValue;
    if (data is int) return data;
    if (data is String) {
      return int.tryParse(data) ?? defaultValue;
    }
    if (data is double) return data.toInt();
    return defaultValue;
  }

  static DateTime? _parseDateTime(dynamic data) {
    if (data == null) return null;
    if (data is DateTime) return data;
    if (data is String) {
      try {
        return DateTime.parse(data);
      } catch (e) {
        debugPrint('Failed to parse datetime: $data');
        return null;
      }
    }
    return null;
  }

  static List<int> _parseIntList(dynamic data) {
    if (data == null || data is! List) return [];

    final List<int> result = [];
    for (final item in data) {
      if (item is int) {
        result.add(item);
      } else if (item is String) {
        final parsed = int.tryParse(item);
        if (parsed != null) result.add(parsed);
      } else if (item is double) {
        result.add(item.toInt());
      }
    }
    return result;
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
