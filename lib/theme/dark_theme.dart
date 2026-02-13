import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    brightness: Brightness.dark,

    surface: Colors.grey.shade900 ,
    primary: const Color.fromARGB(255, 82, 81, 81),
    secondary: const Color.fromARGB(255, 54, 54, 54),

    tertiary: Colors.grey.shade800,
    onTertiary: Colors.white,

    inversePrimary: Colors.grey.shade300,
    
  ),
);
