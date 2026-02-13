import 'package:consistency/models/habit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Top-level background handler — runs even when app is killed.
/// Must be top-level (not a class method) for Android background execution.
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) {
  // This runs in a background isolate. We need to handle the action
  // and communicate with the main isolate if running, or directly
  // update the database.
  _handleNotificationAction(response);
}

/// Processes YES/NO actions from notification buttons.
Future<void> _handleNotificationAction(NotificationResponse response) async {
  final payload = response.payload;
  final actionId = response.actionId;

  if (payload == null || actionId == null) return;

  // Payload format: "habitId"
  final habitId = int.tryParse(payload);
  if (habitId == null) return;

  // We need to open Isar in the background isolate if it's not open
  try {
    final isar = Isar.getInstance() ?? await _openIsarInBackground();
    if (isar == null) return;

    final habit = await isar.habits.get(habitId);
    if (habit == null) return;

    if (actionId == 'yes_action') {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Idempotent: don't add duplicate
      final alreadyDone = habit.completedDays.any((d) =>
          d.year == todayDate.year &&
          d.month == todayDate.month &&
          d.day == todayDate.day);

      if (!alreadyDone) {
        await isar.writeTxn(() async {
          habit.completedDays.add(todayDate);
          await isar.habits.put(habit);
        });
      }
    }
    // NO action: do nothing — habit stays incomplete

    // Cancel the persistent notification
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: habitId + 100000); // persistent notification ID
  } catch (e) {
    debugPrint('Background notification action error: $e');
  }
}

/// Opens Isar in a background isolate (if not already open).
Future<Isar?> _openIsarInBackground() async {
  try {
    // In background, we can't use getApplicationDocumentsDirectory easily
    // Instead, try to get instance that may already be open
    return Isar.getInstance();
  } catch (e) {
    return null;
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Persistent notification channel
  static const String _persistentChannelId = 'habit_persistent';
  static const String _persistentChannelName = 'Habit Check-in';
  static const String _persistentChannelDesc =
      'Persistent notifications that wait for your response';

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'habitCategory',
          actions: [
            DarwinNotificationAction.plain('yes_action', 'YES ✅'),
            DarwinNotificationAction.plain('no_action', 'NO ❌'),
          ],
        ),
      ],
    );

    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
  }

  /// Handles actions when app is in foreground.
  void _onForegroundAction(NotificationResponse response) {
    _handleNotificationAction(response);
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Schedule a daily repeating reminder with persistent interactive notification.
  ///
  /// This schedules a zonedSchedule that repeats daily at the given time.
  /// When fired, it shows a persistent notification with YES/NO buttons.
  Future<void> scheduleReminder(int id, String title, DateTime time) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Schedule the repeating reminder (fires daily, shows persistent notification)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: 'Did you complete this habit today?',
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _persistentChannelId,
          _persistentChannelName,
          channelDescription: _persistentChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          category: AndroidNotificationCategory.reminder,
          actions: const [
            AndroidNotificationAction(
              'yes_action',
              'YES ✅',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'no_action',
              'NO ❌',
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'habitCategory',
        ),
      ),
      payload: '$id',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
    );
  }

  /// Show a persistent notification immediately (for testing or manual trigger).
  Future<void> showPersistentNotification(int habitId, String habitName) async {
    await flutterLocalNotificationsPlugin.show(
      id: habitId + 100000, // Offset ID to avoid conflict with scheduled
      title: habitName,
      body: 'Did you complete this habit today?',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _persistentChannelId,
          _persistentChannelName,
          channelDescription: _persistentChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          category: AndroidNotificationCategory.reminder,
          actions: const [
            AndroidNotificationAction(
              'yes_action',
              'YES ✅',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'no_action',
              'NO ❌',
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'habitCategory',
        ),
      ),
      payload: '$habitId',
    );
  }

  /// Cancel a scheduled reminder and any persistent notification.
  Future<void> cancelReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
    await flutterLocalNotificationsPlugin.cancel(id: id + 100000);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
