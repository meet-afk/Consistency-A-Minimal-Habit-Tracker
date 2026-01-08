import 'package:animated_line_through/animated_line_through.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MyHabitTile extends StatelessWidget {
  final bool isCompleted;
  final String text;
  final void Function(bool?)? onChanged;
  final void Function(BuildContext)? editHabit;
  final void Function(BuildContext)? deleteHabit;
  const MyHabitTile({super.key,
   required this.isCompleted,
   required this.text, 
   required this.onChanged, 
   required this.editHabit,
   required this.deleteHabit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [
          SlidableAction(
            onPressed: editHabit,
            backgroundColor: Colors.grey,
            icon: Icons.edit,
            borderRadius: BorderRadius.circular(8)),
            
          SlidableAction(
            onPressed: deleteHabit,
            backgroundColor: Colors.red,
            icon: Icons.delete,
            borderRadius: BorderRadius.circular(8))
            ]
            ),
        child: GestureDetector(
  onTap: () {
    if (onChanged != null) {
      onChanged!(!isCompleted);
    }
  },
  child: Container(
    decoration: BoxDecoration(
      color: isCompleted
          ? const Color.fromARGB(255, 64, 124, 230)
          : Theme.of(context).colorScheme.secondary,
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(16),
    child: ListTile(
      title: AnimatedLineThrough(
        isCrossed: isCompleted,
        duration: const Duration(milliseconds: 250),
        strokeWidth: 2,
        color: Colors.white,
        child: Text(
          text,
          style: TextStyle(
            color: isCompleted
                ? Colors.white
                : Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      ),
    ),
  ),
),
      ),
    );
  }
}