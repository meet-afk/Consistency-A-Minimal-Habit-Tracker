import 'package:consistency/components/my_drawer.dart';
import 'package:consistency/components/my_habit_tile.dart';
import 'package:consistency/components/my_heat_map.dart';
import 'package:consistency/database/habit_database.dart';
import 'package:consistency/models/habit.dart';
import 'package:consistency/util/habit_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

  final TextEditingController textController = TextEditingController();

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    Provider.of<HabitDatabase>(context, listen: false).readHabits();
    
    super.initState();
  }


  void createNewHabit() {
    showDialog(context: context,
     builder: (context)=> AlertDialog(
      content: TextField(
        cursorColor: Theme.of(context).colorScheme.inversePrimary,
        controller: textController,
        decoration: InputDecoration(
          hintText: "Create a new habit",
          hintStyle: TextStyle(
            color: Colors.grey
          )
        ),
      ),
      actions: [
        MaterialButton(onPressed: (){
          String newHabitName = textController.text;

          context.read<HabitDatabase>().addHabit(newHabitName);
          Navigator.pop(context);
          textController.clear();

        },
        child: const Text("Save"),
        ),

        MaterialButton(onPressed: (){
          Navigator.pop(context);
          textController.clear();
        },
        child: const Text("Cancel"),)
      ],
     )); 
  }

  void checkHabitOnOff(bool? value, Habit habit) {
     if (value != null) {
      context.read<HabitDatabase>().updateHabitCompletion(habit.id, value);
    }
  }

  void editHabitBox(Habit habit){
    textController.text = habit.name;
    showDialog(context: context, builder: (context)=> 
    AlertDialog(
      content: TextField(
        cursorColor: Theme.of(context).colorScheme.inversePrimary,
        controller : textController,
      ),
      actions: [
        MaterialButton(onPressed: (){
          String newHabitName = textController.text;

          context.read<HabitDatabase>().updateHabitName(habit.id, newHabitName);
          Navigator.pop(context);
          textController.clear();

        },
        child: const Text("Save"),
        ),

        MaterialButton(onPressed: (){
          Navigator.pop(context);
          textController.clear();
        },
        child: const Text("Cancel"),)
      ],
    ));
  }

  void deleteHabitBox(Habit habit){
    showDialog(context: context, builder: (context)=> 
    AlertDialog(
      title: const Text("Are you sure you want to delete?",
      style: TextStyle(
        fontSize: 18,
      ),),
      actions: [
        MaterialButton(onPressed: (){
          context.read<HabitDatabase>().deleteHabit(habit.id);
          Navigator.pop(context);

        },
        child: const Text("Delete"),
        ),

        MaterialButton(onPressed: (){
          Navigator.pop(context);
        },
        child: const Text("Cancel"),)
      ],
    ));
  }

  DateTime now = DateTime.now();
  String get formattedDate => DateFormat('d MMMM, yyyy').format(now);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(formattedDate,
          style: GoogleFonts.spaceGrotesk(fontSize: 20.0),
          
        ),centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: const MyDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: createNewHabit,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        child: const Icon(Icons.add), 
      ),
      body: ListView(
        children: [
          _buildHeatMap(),

          _buildHabitList()
        ],
      ),
    );
  }

  Widget _buildHeatMap(){
    final habitDatabase = context.watch<HabitDatabase>();
    
    List<Habit> currentHabits = habitDatabase.currentHabits;

    return FutureBuilder<DateTime?>(future: habitDatabase.getFirstLaunchDate(),
     builder: (context, snapshot){
      if(snapshot.hasData){
        return MyHeatMap(
          startDate: snapshot.data!,
          datasets: prepHeatMapDataset( currentHabits),
        );
      } else {
        return Container();
      }
     });
  }


Widget _buildHabitList(){

  final habitDatabase = context.watch<HabitDatabase>();
  List<Habit> currentHabits = habitDatabase.currentHabits;
  
  return ListView.builder(
    itemCount: currentHabits.length,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),

    itemBuilder:(context, index){
      final habit = currentHabits[index];
      
      bool iscompletedToday = isHabitCompletedToday(habit.completedDays);

      return MyHabitTile(isCompleted: iscompletedToday, text: habit.name,
       onChanged: (value) => checkHabitOnOff(value, habit),
       editHabit: (context) => editHabitBox(habit),
       deleteHabit: (context) => deleteHabitBox(habit),
       );
  }
  );
}

}
