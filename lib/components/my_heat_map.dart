import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MonthlyHeatMap extends StatefulWidget {
  final Map<DateTime, int> datasets;
  final int totalHabits;
  final void Function(DateTime date)? onDayTap;

  const MonthlyHeatMap({
    super.key,
    required this.datasets,
    required this.totalHabits,
    this.onDayTap,
  });

  @override
  State<MonthlyHeatMap> createState() => _MonthlyHeatMapState();
}

class _MonthlyHeatMapState extends State<MonthlyHeatMap> {
  late PageController _pageController;
  late int _currentPage;

  // We allow navigating from Jan 2020 to Dec 2030
  static final DateTime _startMonth = DateTime(2020, 1);
  static final DateTime _endMonth = DateTime(2030, 12);

  int get _totalPages =>
      (_endMonth.year - _startMonth.year) * 12 +
      _endMonth.month -
      _startMonth.month +
      1;

  int _pageForMonth(DateTime date) =>
      (date.year - _startMonth.year) * 12 + date.month - _startMonth.month;

  DateTime _monthForPage(int page) {
    final year = _startMonth.year + ((_startMonth.month - 1 + page) ~/ 12);
    final month = (_startMonth.month - 1 + page) % 12 + 1;
    return DateTime(year, month);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentPage = _pageForMonth(now);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayMonth = _monthForPage(_currentPage);

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month header with arrows
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: colorScheme.inversePrimary.withValues(alpha: 0.6),
                  ),
                  onPressed: _currentPage > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
                Text(
                  '${months[displayMonth.month - 1]} ${displayMonth.year}',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.inversePrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.inversePrimary.withValues(alpha: 0.6),
                  ),
                  onPressed: _currentPage < _totalPages - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),

          // Day-of-week headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            d,
                            style: GoogleFonts.aBeeZee(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.inversePrimary
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Swipeable calendar grid
          SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, page) {
                final month = _monthForPage(page);
                return _buildMonthGrid(context, month);
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, DateTime month) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    // Sunday = 0

    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - firstWeekday + 1;

                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 40, height: 40);
                }

                final date = DateTime(month.year, month.month, dayNum);
                final isToday = date.isAtSameMomentAs(today);
                final isFuture = date.isAfter(today);
                final completions = widget.datasets[date] ?? 0;

                // Intensity: 0 = none, up to totalHabits = max
                final maxHabits =
                    widget.totalHabits > 0 ? widget.totalHabits : 1;
                final intensity =
                    (completions / maxHabits).clamp(0.0, 1.0);

                return _buildDayTile(
                  context,
                  date: date,
                  dayNum: dayNum,
                  isToday: isToday,
                  isFuture: isFuture,
                  completions: completions,
                  intensity: intensity,
                  colorScheme: colorScheme,
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayTile(
    BuildContext context, {
    required DateTime date,
    required int dayNum,
    required bool isToday,
    required bool isFuture,
    required int completions,
    required double intensity,
    required ColorScheme colorScheme,
  }) {
    // Base tile color
    Color tileColor;
    Color textColor;

    if (isFuture) {
      tileColor = colorScheme.surface.withValues(alpha: 0.3);
      textColor = colorScheme.inversePrimary.withValues(alpha: 0.2);
    } else if (completions > 0) {
      // Gradient from light blue to deep blue based on intensity
      tileColor = Color.lerp(
        const Color(0xFF407CE6).withValues(alpha: 0.25),
        const Color(0xFF407CE6),
        intensity,
      )!;
      textColor = intensity > 0.5 ? Colors.white : Colors.white70;
    } else {
      tileColor = colorScheme.surface.withValues(alpha: 0.6);
      textColor = colorScheme.inversePrimary.withValues(alpha: 0.5);
    }

    final canTap = !isFuture && widget.onDayTap != null;

    return GestureDetector(
      onTap: canTap ? () => widget.onDayTap!(date) : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(
                  color: colorScheme.inversePrimary.withValues(alpha: 0.8),
                  width: 1.5,
                )
              : null,
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: colorScheme.inversePrimary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$dayNum',
            style: GoogleFonts.aBeeZee(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday
                  ? colorScheme.inversePrimary
                  : textColor,
            ),
          ),
        ),
      ),
    );
  }
}