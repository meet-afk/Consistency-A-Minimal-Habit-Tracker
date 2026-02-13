import 'package:consistency/components/my_drawer.dart';
import 'package:consistency/components/my_habit_tile.dart';
import 'package:consistency/components/my_heat_map.dart';
import 'package:consistency/database/habit_database.dart';
import 'package:consistency/pages/habit_detail_page.dart';
import 'package:consistency/services/achievement_service.dart';
import 'package:consistency/util/habit_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _heatmapFade;
  late Animation<Offset> _heatmapSlide;
  late Animation<double> _listFade;
  late Animation<Offset> _listSlide;

  // FAB animation
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Provider.of<HabitDatabase>(context, listen: false).readHabits();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    const curve = Curves.easeOutCubic;

    _cardsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.25, curve: curve)),
    );
    _cardsSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.25, curve: curve)),
    );

    _heatmapFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.24, 0.5, curve: curve)),
    );
    _heatmapSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.24, 0.5, curve: curve)),
    );

    _listFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.36, 0.6, curve: curve)),
    );
    _listSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.36, 0.6, curve: curve)),
    );

    // FAB
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    _entranceController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _fabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Consistency',
          style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.inversePrimary,
        elevation: 0,
      ),
      drawer: const MyDrawer(),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton(
          onPressed: () => _showCreateHabitDialog(),
          backgroundColor: const Color(0xFF407CE6),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Consumer<HabitDatabase>(
        builder: (context, database, child) {
          final habits = database.currentHabits;
          final completedToday = habits
              .where((h) => isHabitCompletedToday(h.completedDays))
              .length;
          final totalHabits = habits.length;
          final progress =
              totalHabits > 0 ? completedToday / totalHabits : 0.0;
          final unlockedAchievements =
              AchievementService.unlockedCount(habits);
          final totalAchievements = AchievementService.totalCount();

          int bestStreak = 0;
          for (final h in habits) {
            if (h.longestStreak > bestStreak) bestStreak = h.longestStreak;
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              const SizedBox(height: 10),
              // Progress + Stats cards
              SlideTransition(
                position: _cardsSlide,
                child: FadeTransition(
                  opacity: _cardsFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Daily progress card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Today's Progress",
                                    style: GoogleFonts.aBeeZee(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.inversePrimary,
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    child: Text(
                                      '${(progress * 100).toInt()}%',
                                      key: ValueKey(
                                          (progress * 100).toInt()),
                                      style: GoogleFonts.aBeeZee(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF407CE6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: TweenAnimationBuilder<double>(
                                  tween:
                                      Tween(begin: 0, end: progress),
                                  duration: const Duration(
                                      milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return LinearProgressIndicator(
                                      value: value,
                                      minHeight: 10,
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                              Color>(Color(0xFF407CE6)),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Stats row
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniCard(
                                context,
                                icon: Icons.emoji_events_rounded,
                                iconColor: const Color(0xFFFFB800),
                                label: 'Achievements',
                                value: '$unlockedAchievements/$totalAchievements',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMiniCard(
                                context,
                                icon: Icons.local_fire_department_rounded,
                                iconColor: const Color(0xFFFF6B35),
                                label: 'Best Streak',
                                value: '$bestStreak days',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMiniCard(
                                context,
                                icon: Icons.checklist_rounded,
                                iconColor: Colors.green.shade600,
                                label: 'Habits',
                                value: '$totalHabits',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Heatmap
              SlideTransition(
                position: _heatmapSlide,
                child: FadeTransition(
                  opacity: _heatmapFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Activity',
                          style: GoogleFonts.aBeeZee(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.inversePrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonthlyHeatMap(
                        datasets: prepHeatMapDataset(habits),
                        totalHabits: totalHabits,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Habits list header
              SlideTransition(
                position: _listSlide,
                child: FadeTransition(
                  opacity: _listFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Habits',
                          style: GoogleFonts.aBeeZee(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.inversePrimary,
                          ),
                        ),
                        if (totalHabits > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF407CE6)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$completedToday / $totalHabits',
                              style: GoogleFonts.aBeeZee(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF407CE6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Habits
              if (habits.isEmpty)
                _buildEmptyState(context)
              else
                ...List.generate(habits.length, (index) {
                  final habit = habits[index];
                  final completed =
                      isHabitCompletedToday(habit.completedDays);

                  return TweenAnimationBuilder<double>(
                    key: ValueKey(habit.id),
                    tween: Tween(begin: 0, end: 1),
                    duration:
                        Duration(milliseconds: 400 + (index * 80)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: MyHabitTile(
                      isCompleted: completed,
                      text: habit.name,
                      streakLabel: HabitDatabase.streakLabel(habit),
                      frequencyLabel: HabitDatabase.frequencyLabel(habit),
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<HabitDatabase>()
                              .updateHabitCompletion(habit.id, val);
                        }
                      },
                      editHabit: (ctx) =>
                          _showEditHabitDialog(habit),
                      deleteHabit: (ctx) =>
                          _showDeleteDialog(habit),
                      onTileTap: () => _navigateToDetail(habit.id),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.aBeeZee(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.inversePrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.inversePrimary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No habits yet',
              style: GoogleFonts.aBeeZee(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create your first habit',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .inversePrimary
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateHabitDialog() {
    _textController.clear();
    int selectedFrequency = 0;
    List<int> selectedDays = [];
    int weeklyTarget = 3;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Habit',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'New Habit',
                          style: GoogleFonts.aBeeZee(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Enter habit name',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.secondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFrequencyPicker(
                          context,
                          selectedFrequency,
                          selectedDays,
                          weeklyTarget,
                          (freq) => setDialogState(() => selectedFrequency = freq),
                          (days) => setDialogState(() => selectedDays = days),
                          (target) => setDialogState(() => weeklyTarget = target),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final name = _textController.text.trim();
                                  if (name.isNotEmpty) {
                                    context.read<HabitDatabase>().addHabit(
                                      name,
                                      frequencyType: selectedFrequency,
                                      customDays: selectedDays,
                                      weeklyTarget: selectedFrequency == 2 ? weeklyTarget : 7,
                                    );
                                    Navigator.pop(ctx);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF407CE6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Create',
                                    style: GoogleFonts.aBeeZee(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showEditHabitDialog(dynamic habit) {
    _textController.text = habit.name;
    int selectedFrequency = habit.frequencyType;
    List<int> selectedDays = List<int>.from(habit.customDays);
    int weeklyTarget = habit.weeklyTarget;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Habit',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit Habit',
                          style: GoogleFonts.aBeeZee(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Habit name',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.secondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFrequencyPicker(
                          context,
                          selectedFrequency,
                          selectedDays,
                          weeklyTarget,
                          (freq) => setDialogState(() => selectedFrequency = freq),
                          (days) => setDialogState(() => selectedDays = days),
                          (target) => setDialogState(() => weeklyTarget = target),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final name = _textController.text.trim();
                                  if (name.isNotEmpty) {
                                    final db = context.read<HabitDatabase>();
                                    db.updateHabitName(habit.id, name);
                                    db.updateHabitFrequency(
                                      habit.id,
                                      frequencyType: selectedFrequency,
                                      customDays: selectedDays,
                                      weeklyTarget: selectedFrequency == 2 ? weeklyTarget : 7,
                                    );
                                    Navigator.pop(ctx);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF407CE6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Save',
                                    style: GoogleFonts.aBeeZee(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(dynamic habit) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete Habit',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, anim2, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade400, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delete "${habit.name}"?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.aBeeZee(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .inversePrimary
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            context
                                .read<HabitDatabase>()
                                .deleteHabit(habit.id);
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Delete',
                              style: GoogleFonts.aBeeZee(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the frequency selection widget for create/edit dialogs.
  Widget _buildFrequencyPicker(
    BuildContext context,
    int selectedFrequency,
    List<int> selectedDays,
    int weeklyTarget,
    void Function(int) onFrequencyChanged,
    void Function(List<int>) onDaysChanged,
    void Function(int) onTargetChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const dayValues = [1, 2, 3, 4, 5, 6, 7];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: GoogleFonts.aBeeZee(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.inversePrimary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Daily', style: GoogleFonts.aBeeZee(fontSize: 12)),
              selected: selectedFrequency == 0,
              selectedColor: const Color(0xFF407CE6),
              labelStyle: TextStyle(
                color: selectedFrequency == 0 ? Colors.white : colorScheme.inversePrimary,
              ),
              onSelected: (_) => onFrequencyChanged(0),
            ),
            ChoiceChip(
              label: Text('Custom Days', style: GoogleFonts.aBeeZee(fontSize: 12)),
              selected: selectedFrequency == 1,
              selectedColor: const Color(0xFF407CE6),
              labelStyle: TextStyle(
                color: selectedFrequency == 1 ? Colors.white : colorScheme.inversePrimary,
              ),
              onSelected: (_) => onFrequencyChanged(1),
            ),
            ChoiceChip(
              label: Text('X / Week', style: GoogleFonts.aBeeZee(fontSize: 12)),
              selected: selectedFrequency == 2,
              selectedColor: const Color(0xFF407CE6),
              labelStyle: TextStyle(
                color: selectedFrequency == 2 ? Colors.white : colorScheme.inversePrimary,
              ),
              onSelected: (_) => onFrequencyChanged(2),
            ),
          ],
        ),

        // Custom days picker
        if (selectedFrequency == 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(7, (index) {
              final dayValue = dayValues[index];
              final isSelected = selectedDays.contains(dayValue);
              return FilterChip(
                label: Text(
                  dayNames[index],
                  style: GoogleFonts.aBeeZee(
                    fontSize: 11,
                    color: isSelected ? Colors.white : colorScheme.inversePrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF407CE6),
                checkmarkColor: Colors.white,
                onSelected: (selected) {
                  final newDays = List<int>.from(selectedDays);
                  if (selected) {
                    newDays.add(dayValue);
                  } else {
                    newDays.remove(dayValue);
                  }
                  onDaysChanged(newDays);
                },
              );
            }),
          ),
        ],

        // Weekly target slider
        if (selectedFrequency == 2) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Target: ',
                style: GoogleFonts.aBeeZee(
                  fontSize: 13,
                  color: colorScheme.inversePrimary.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '$weeklyTarget',
                style: GoogleFonts.aBeeZee(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF407CE6),
                ),
              ),
              Text(
                ' times/week',
                style: GoogleFonts.aBeeZee(
                  fontSize: 13,
                  color: colorScheme.inversePrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF407CE6),
              inactiveTrackColor: const Color(0xFF407CE6).withValues(alpha: 0.15),
              thumbColor: const Color(0xFF407CE6),
              overlayColor: const Color(0xFF407CE6).withValues(alpha: 0.12),
            ),
            child: Slider(
              value: weeklyTarget.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$weeklyTarget',
              onChanged: (val) => onTargetChanged(val.round()),
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToDetail(int habitId) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context2, animation1, animation2) => HabitDetailPage(habitId: habitId),
        transitionsBuilder: (context2, anim, animation2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}
