import 'package:consistency/models/habit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Top-level background handler for notification actions.
/// Called when the app is NOT in the foreground and an action with
/// showsUserInterface: false is tapped (i.e. the NO button).
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) async {
  // NO button has cancelNotification: true on the Android side,
  // so the notification is already dismissed by the system.
  // Nothing else to do — NO means "leave habit incomplete".
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set this from main.dart to refresh the habit list after a
  /// notification YES action completes a habit.
  static VoidCallback? onHabitMarkedComplete;

  static const String _channelId = 'habit_persistent';
  static const String _channelName = 'Habit Check-in';
  static const String _channelDesc =
      'Persistent notifications that wait for your response';

  /// Called once during app startup.
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'habitCategory',
          actions: [
            DarwinNotificationAction.plain('yes_action', 'YES'),
            DarwinNotificationAction.plain('no_action', 'NO'),
          ],
        ),
      ],
    );

    final linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      ),
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
  }

  /// Foreground handler — app is running.
  /// YES button has showsUserInterface: true, so it always comes here.
  void _onForegroundAction(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null) return;
    final habitId = int.tryParse(payload);
    if (habitId == null) return;

    if (actionId == 'yes_action') {
      try {
        // Isar is already open in the main isolate
        final isar = Isar.getInstance();
        if (isar == null) return;

        final habit = await isar.habits.get(habitId);
        if (habit == null) return;

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        // Idempotent — don't add duplicate
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

        // Refresh the UI so the habit shows as checked
        onHabitMarkedComplete?.call();
      } catch (e) {
        debugPrint('YES action error: $e');
      }
    }
    // NO action: cancelNotification: true handles dismissal, nothing to do
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Schedule a daily persistent reminder with YES / NO action buttons.
  Future<void> scheduleReminder(int id, String title, DateTime time) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year, now.month, now.day, time.hour, time.minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: 'Did you complete this habit today?',
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: _buildNotificationDetails(),
      payload: '$id',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Dismiss the current visible notification for a habit and re-schedule
  /// for tomorrow. Call this when the user completes a habit from the app.
  Future<void> dismissAndReschedule(
      int habitId, String habitName, DateTime reminderTime) async {
    // cancel() kills both the displayed notification AND the repeating alarm
    await _plugin.cancel(id: habitId);

    // Re-schedule — scheduleReminder adds +1 day if time already passed
    await scheduleReminder(habitId, habitName, reminderTime);
  }

  /// Cancel a reminder entirely (e.g. when deleting a habit or toggling off).
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Shared notification details — persistent with YES/NO buttons.
  NotificationDetails _buildNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction(
            'yes_action',
            'YES',
            // Opens app so foreground handler can access Isar
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'no_action',
            'NO',
            // No need to open app — just dismiss
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'habitCategory',
      ),
    );
  }
}
