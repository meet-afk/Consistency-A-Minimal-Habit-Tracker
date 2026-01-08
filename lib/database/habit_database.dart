import 'package:consistency/models/app_settings.dart';
import 'package:consistency/models/habit.dart';
import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class HabitDatabase extends ChangeNotifier {

  static late Isar isar;
   
    static Future<void> initialize() async{
    final dir = await getApplicationCacheDirectory();
    isar = await Isar.open([HabitSchema, AppSettingsSchema],
    directory: dir.path);
    } 

    Future<void> saveFirstLaunchDate() async{
    final esistingSettings = await isar.appSettings.where().findFirst();
      if(esistingSettings == null){
      final settings = AppSettings()..firstLaunchDate = DateTime.now();
      await isar.writeTxn(() => isar.appSettings.put(settings));
      }
    }
 
    Future<DateTime?> getFirstLaunchDate() async{
      final settings = await isar.appSettings.where().findFirst();
      return settings?.firstLaunchDate;
    }

// List of habits

    final List<Habit> currentHabits = [];

// add habits
    Future<void> addHabit(String habitName) async{

      final newHabit = Habit()..name = habitName;
      await isar.writeTxn(()=> isar.habits.put(newHabit));

      readHabits();
    }

    Future<void> readHabits() async{

      List<Habit> fetchedHabits = await isar.habits.where().findAll();

      currentHabits.clear();
      currentHabits.addAll(fetchedHabits);

      notifyListeners();
    }

//update habit
    Future<void> updateHabitCompletion(int id, bool isCompleted) async{
    

      final habit = await isar.habits.get(id);

      if(habit != null){
          await isar.writeTxn(() async{
            if(isCompleted && !habit.completedDays.contains(DateTime.now())){

              final today = DateTime.now();

              habit.completedDays.add(
                DateTime(
                  today.year,
                  today.month,
                  today.day,
                ),
              );
            }
            else{
              habit.completedDays.removeWhere(
                (date) => 
                  date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day,
              );
            }
            await isar.habits.put(habit);
        });
      }
      readHabits();
    }

//rename the habit
    Future<void> updateHabitName(int id, String newName) async{

      final habit = await isar.habits.get(id);

      if(habit != null){

        await isar.writeTxn(() async{
          habit.name = newName;

          await isar.habits.put(habit);
        });
      }
      readHabits();
    }
// delete habits 
   Future<void> deleteHabit(int id) async{
     await isar.writeTxn(() async{
      await isar.habits.delete(id);
     });

     readHabits();
   } 

}