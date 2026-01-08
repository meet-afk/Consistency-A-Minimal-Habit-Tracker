import 'package:consistency/theme/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            
            children: [
                Image(image: AssetImage('assets/images/drawer.png'), height: 150, width: 150,
                alignment: Alignment.center,
                ),
            ],
          ),
          const SizedBox(height: 40),

          ListTile(
            title: Text(
              'Dark Mode',
              style: GoogleFonts.spaceGrotesk(fontSize: 20),
            ),
            trailing: CupertinoSwitch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),

          const Spacer(),

          ListTile(
            title: Text(
              'Exit',
              style: GoogleFonts.spaceGrotesk(fontSize: 20),
            ),
            leading: const Icon(Icons.exit_to_app),
            onTap: () {
              SystemNavigator.pop();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
