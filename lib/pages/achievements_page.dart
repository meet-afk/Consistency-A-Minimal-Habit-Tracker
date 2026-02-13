import 'package:consistency/database/habit_database.dart';
import 'package:consistency/services/achievement_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    const curve = Curves.easeOutCubic;

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.4, curve: curve)),
    );
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.4, curve: curve)),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Achievements',
          style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: Consumer<HabitDatabase>(
        builder: (context, database, child) {
          final habits = database.currentHabits;
          final achievements = AchievementService.computeAchievements(habits);
          final unlocked = achievements.where((a) => a.isUnlocked).length;
          final total = achievements.length;
          final progress = total > 0 ? unlocked / total : 0.0;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Header with progress
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: _buildHeader(
                      context, unlocked, total, progress),
                ),
              ),
              const SizedBox(height: 8),

              // Achievement grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (int i = 0; i < achievements.length; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 400 + (i * 60)),
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
                        child: _buildAchievementCard(
                            context, achievements[i]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, int unlocked, int total, double progress) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated progress ring
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFB800)),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Text(
                            '🏆',
                            style: const TextStyle(fontSize: 28),
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
                      'Your Progress',
                      style: GoogleFonts.aBeeZee(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: unlocked),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, val, _) {
                        return Text(
                          '$val of $total achievements unlocked',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.inversePrimary
                                .withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFB800)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, Achievement achievement) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnlocked = achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isUnlocked
              ? () => _showAchievementDetail(context, achievement)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? colorScheme.secondary
                  : colorScheme.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: isUnlocked
                  ? Border.all(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                      width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                        : colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isUnlocked ? achievement.emoji : '🔒',
                      style: TextStyle(
                        fontSize: isUnlocked ? 24 : 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: GoogleFonts.aBeeZee(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? colorScheme.inversePrimary
                              : colorScheme.inversePrimary
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnlocked
                              ? colorScheme.inversePrimary
                                  .withValues(alpha: 0.6)
                              : colorScheme.inversePrimary
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                if (isUnlocked)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFFFFB800), size: 22)
                else
                  Icon(Icons.lock_outline_rounded,
                      color: colorScheme.inversePrimary.withValues(alpha: 0.2),
                      size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAchievementDetail(BuildContext context, Achievement achievement) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Achievement',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, anim, anim2) {
        final colorScheme = Theme.of(context).colorScheme;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Big emoji badge
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFB800).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        achievement.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    achievement.title,
                    style: GoogleFonts.aBeeZee(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.inversePrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    achievement.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.inversePrimary
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (achievement.unlockedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Unlocked ${DateFormat('MMM d, yyyy').format(achievement.unlockedAt!)}',
                        style: GoogleFonts.aBeeZee(
                          fontSize: 12,
                          color: const Color(0xFFFFB800),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Awesome!',
                          style: GoogleFonts.aBeeZee(
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
