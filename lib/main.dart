import 'package:consistency/database/habit_database.dart';
import 'package:consistency/pages/home_page.dart';
import 'package:consistency/services/notification_service.dart';
import 'package:consistency/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create the HabitDatabase instance that the Provider will use
  final habitDb = HabitDatabase();

  // Wire up the notification callback BEFORE init, so that if the app
  // was launched by tapping YES on a notification, the callback is ready.
  NotificationService.onHabitMarkedComplete = () => habitDb.readHabits();

  await HabitDatabase.initialize();
  await habitDb.saveFirstLaunchDate();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: habitDb),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: const HomePage(),
    );
  }
}