import 'package:consistency/pages/achievements_page.dart';
import 'package:consistency/services/backup_service.dart';
import 'package:consistency/theme/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final date = await BackupService.getLastBackupDate();
    if (mounted) {
      setState(() => _lastBackup = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Consistency',
                  style: GoogleFonts.aBeeZee(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.inversePrimary,
                  ),
                ),
                Text(
                  'Build better habits',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.inversePrimary.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          // ── Menu Items ──

          // Achievements
          _buildDrawerItem(
            context,
            icon: Icons.emoji_events_rounded,
            label: 'Achievements',
            color: const Color(0xFFFFB800),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context2, animation1, animation2) =>
                      const AchievementsPage(),
                  transitionsBuilder: (context2, anim, animation2, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
          ),

          // Export Data
          _buildDrawerItem(
            context,
            icon: Icons.upload_rounded,
            label: 'Export Data',
            subtitle: _lastBackup != null ? 'Last: $_lastBackup' : null,
            color: Colors.green.shade600,
            onTap: () async {
              Navigator.pop(context);
              final success = await BackupService.exportData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        success ? 'Backup exported!' : 'Export cancelled'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
              _loadLastBackup();
            },
          ),

          // Import Data
          _buildDrawerItem(
            context,
            icon: Icons.download_rounded,
            label: 'Import Data',
            color: Colors.blue.shade600,
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text('Import Backup',
                      style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold)),
                  content: const Text(
                      'This will overwrite your current data. Continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF407CE6)),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );

              if (confirm != true || !context.mounted) return;

              final result = await BackupService.importData();
              if (context.mounted) {
                final isSuccess = result.startsWith('success');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isSuccess
                        ? result.replaceFirst('success: ', '')
                        : result.replaceFirst('error: ', '')),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
          ),

          const Spacer(),

          // ── Dark Mode Toggle (bottom) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: colorScheme.inversePrimary,
                  size: 22,
                ),
                title: Text(
                  'Dark Mode',
                  style: GoogleFonts.aBeeZee(
                    color: colorScheme.inversePrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                trailing: CupertinoSwitch(
                  value: themeProvider.isDarkMode,
                  activeTrackColor: const Color(0xFF407CE6),
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ),
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Text(
              'Consistency v0.2',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.inversePrimary.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.aBeeZee(
            color: colorScheme.inversePrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.inversePrimary.withValues(alpha: 0.4),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.inversePrimary.withValues(alpha: 0.3),
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
