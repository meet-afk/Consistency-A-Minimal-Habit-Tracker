import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MyHabitTile extends StatefulWidget {
  final bool isCompleted;
  final String text;
  final String? streakLabel;
  final String frequencyLabel;
  final void Function(bool?)? onChanged;
  final void Function(BuildContext)? editHabit;
  final void Function(BuildContext)? deleteHabit;
  final void Function()? onTileTap;

  const MyHabitTile({
    super.key,
    required this.isCompleted,
    required this.text,
    this.streakLabel,
    this.frequencyLabel = 'Daily',
    required this.onChanged,
    required this.editHabit,
    required this.deleteHabit,
    required this.onTileTap,
  });

  @override
  State<MyHabitTile> createState() => _MyHabitTileState();
}

class _MyHabitTileState extends State<MyHabitTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _scaleAnim;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.isCompleted;
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant MyHabitTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted && !_wasCompleted) {
      _checkController.forward(from: 0);
    }
    _wasCompleted = widget.isCompleted;
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Slidable(
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: widget.editHabit,
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                icon: Icons.edit_rounded,
                borderRadius: BorderRadius.circular(12),
              ),
              SlidableAction(
                onPressed: widget.deleteHabit,
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                icon: Icons.delete_rounded,
                borderRadius: BorderRadius.circular(12),
              )
            ],
          ),
          child: GestureDetector(
            onTap: widget.onTileTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: widget.isCompleted
                    ? const Color(0xFF407CE6)
                    : Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: widget.isCompleted
                    ? [
                        BoxShadow(
                          color: const Color(0xFF407CE6).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: ListTile(
                title: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: widget.isCompleted
                        ? Colors.white
                        : Theme.of(context).colorScheme.inversePrimary,
                    fontSize: 16,
                    fontWeight:
                        widget.isCompleted ? FontWeight.w600 : FontWeight.normal,
                    decoration: widget.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.white54,
                  ),
                  child: Text(widget.text),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.streakLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🔥 ${widget.streakLabel}',
                          style: TextStyle(
                            color: widget.isCompleted
                                ? Colors.white70
                                : Theme.of(context)
                                    .colorScheme
                                    .inversePrimary
                                    .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (widget.frequencyLabel != 'Daily')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '📅 ${widget.frequencyLabel}',
                          style: TextStyle(
                            color: widget.isCompleted
                                ? Colors.white60
                                : Theme.of(context)
                                    .colorScheme
                                    .inversePrimary
                                    .withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                leading: Transform.scale(
                  scale: 1.15,
                  child: Checkbox(
                    activeColor: Colors.white,
                    checkColor: const Color(0xFF407CE6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    value: widget.isCompleted,
                    onChanged: widget.onChanged,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: widget.isCompleted
                      ? Colors.white54
                      : Theme.of(context)
                          .colorScheme
                          .inversePrimary
                          .withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
