import 'package:consistency/components/my_heat_map.dart';
import 'package:consistency/database/habit_database.dart';
import 'package:consistency/models/habit.dart';
import 'package:consistency/util/habit_util.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HabitDetailPage extends StatefulWidget {
  final int habitId;

  const HabitDetailPage({super.key, required this.habitId});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _statsFade;
  late Animation<Offset> _statsSlide;
  late Animation<double> _heatmapFade;
  late Animation<Offset> _heatmapSlide;
  late Animation<double> _reminderFade;
  late Animation<Offset> _reminderSlide;
  late Animation<double> _chartFade;
  late Animation<Offset> _chartSlide;

  // For the bar chart grow animation
  double _chartAnimValue = 0.0;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    const curve = Curves.easeOutCubic;

    _statsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.3, curve: curve)),
    );
    _statsSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.3, curve: curve)),
    );

    _heatmapFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.15, 0.45, curve: curve)),
    );
    _heatmapSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.15, 0.45, curve: curve)),
    );

    _reminderFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.3, 0.6, curve: curve)),
    );
    _reminderSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.3, 0.6, curve: curve)),
    );

    _chartFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.45, 0.75, curve: curve)),
    );
    _chartSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.45, 0.75, curve: curve)),
    );

    _entranceController.forward();

    // Delayed bar chart grow
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _chartAnimValue = 1.0);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitDatabase>(
      builder: (context, database, child) {
        final habit = database.currentHabits
            .firstWhere((h) => h.id == widget.habitId, orElse: () => Habit());

        if (habit.id == -1) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Habit not found")),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(
              habit.name,
              style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.inversePrimary,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats Cards ─ animated
              SlideTransition(
                position: _statsSlide,
                child: FadeTransition(
                  opacity: _statsFade,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Current Streak',
                          habit.streak,
                          '🔥',
                          const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Best Streak',
                          habit.longestStreak,
                          '🏆',
                          const Color(0xFF407CE6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Days',
                          habit.completedDays.length,
                          '📅',
                          Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Completion rate circle
              SlideTransition(
                position: _statsSlide,
                child: FadeTransition(
                  opacity: _statsFade,
                  child: _buildCompletionRate(context, habit),
                ),
              ),
              const SizedBox(height: 20),

              // Heatmap ─ animated & clickable
              SlideTransition(
                position: _heatmapSlide,
                child: FadeTransition(
                  opacity: _heatmapFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Map',
                        style: GoogleFonts.aBeeZee(
                          color:
                              Theme.of(context).colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap a date to edit completion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .inversePrimary
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<DateTime?>(
                        future: database.getFirstLaunchDate(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return MyHeatMap(
                              startDate: snapshot.data!,
                              datasets: prepHeatMapDataset([habit]),
                              onClick: (date) => _showDateEditSheet(context, date, habit, database),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Reminder ─ animated
              SlideTransition(
                position: _reminderSlide,
                child: FadeTransition(
                  opacity: _reminderFade,
                  child: _buildReminderSection(context, habit, database),
                ),
              ),
              const SizedBox(height: 20),

              // Bar chart ─ animated
              SlideTransition(
                position: _chartSlide,
                child: FadeTransition(
                  opacity: _chartFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Consistency',
                        style: GoogleFonts.aBeeZee(
                          color:
                              Theme.of(context).colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildBarChart(habit),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ── Stat Card with counting animation ──────────────
  Widget _buildStatCard(BuildContext context, String title, int value,
      String emoji, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animVal, _) {
              return Text(
                '$animVal',
                style: GoogleFonts.aBeeZee(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .inversePrimary
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion rate with animated circular indicator ─
  Widget _buildCompletionRate(BuildContext context, Habit habit) {
    // Calculate rate: days completed / days since creation
    final now = DateTime.now();
    final createdDate =
        habit.completedDays.isNotEmpty ? habit.completedDays.first : now;
    final daysSinceCreation =
        now.difference(createdDate).inDays.clamp(1, 99999);
    final rate = (habit.completedDays.length / daysSinceCreation).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: rate),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF407CE6)),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${(value * 100).toInt()}%',
                        style: GoogleFonts.aBeeZee(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completion Rate',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${habit.completedDays.length} days out of $daysSinceCreation tracked',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .inversePrimary
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reminder Section ───────────────────────────────
  Widget _buildReminderSection(
      BuildContext context, Habit habit, HabitDatabase database) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_rounded,
                      color: Theme.of(context).colorScheme.inversePrimary,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Reminder',
                    style: GoogleFonts.aBeeZee(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: habit.isReminderOn,
                activeTrackColor: const Color(0xFF407CE6),
                onChanged: (value) async {
                  if (value && habit.reminderTime == null) {
                    final now = DateTime.now();
                    final defaultTime =
                        DateTime(now.year, now.month, now.day, 9, 0);
                    await database.updateHabitReminder(
                        habit.id, defaultTime, true);
                  } else {
                    await database.updateHabitReminder(
                        habit.id, habit.reminderTime, value);
                  }
                },
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: habit.isReminderOn
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_rounded,
                  color: Color(0xFF407CE6)),
              title: const Text('Time'),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF407CE6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  habit.reminderTime != null
                      ? '${habit.reminderTime!.hour.toString().padLeft(2, '0')}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}'
                      : 'Not set',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF407CE6),
                  ),
                ),
              ),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                      habit.reminderTime ?? DateTime.now()),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  final newTime = DateTime(
                      now.year, now.month, now.day, picked.hour, picked.minute);
                  await database.updateHabitReminder(habit.id, newTime, true);
                }
              },
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Bar chart with grow animation ──────────────────
  Widget _buildBarChart(Habit habit) {
    final now = DateTime.now();
    List<BarChartGroupData> barGroups = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      int count = habit.completedDays
          .where((date) =>
              date.year == monthDate.year && date.month == monthDate.month)
          .length;

      barGroups.add(
        BarChartGroupData(
          x: 5 - i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble() * _chartAnimValue,
              color: const Color(0xFF407CE6),
              width: 20,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (count > 0 ? count + 2 : 5).toDouble(),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: BarChart(
        key: ValueKey(_chartAnimValue),
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index > 5) return const Text('');
                  final date =
                      DateTime(now.year, now.month - (5 - index), 1);
                  const months = [
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      months[date.month - 1],
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: barGroups,
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ── Date edit bottom sheet ──────────────────────────
  void _showDateEditSheet(
      BuildContext context, DateTime date, Habit habit, HabitDatabase database) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Block future dates
    if (normalizedDate.isAfter(todayNormalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot edit future dates'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final isCompleted = habit.completedDays.any((d) =>
        d.year == normalizedDate.year &&
        d.month == normalizedDate.month &&
        d.day == normalizedDate.day);

    final isToday = normalizedDate.isAtSameMomentAs(todayNormalized);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(normalizedDate);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date display
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF407CE6).withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isCompleted ? const Color(0xFF407CE6) : Colors.grey,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.aBeeZee(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday
                              ? 'Today'
                              : isCompleted
                                  ? '✅ Completed'
                                  : '⭕ Not completed',
                          style: TextStyle(
                            fontSize: 13,
                            color: isCompleted
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final result = await database.toggleHabitDate(
                        widget.habitId, normalizedDate);
                    if (result != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result
                                ? '✅ Marked as completed'
                                : '⭕ Marked as incomplete',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isCompleted ? Icons.close_rounded : Icons.check_rounded,
                  ),
                  label: Text(
                    isCompleted ? 'Remove Completion' : 'Mark as Completed',
                    style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isCompleted
                        ? Colors.red.shade400
                        : const Color(0xFF407CE6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
