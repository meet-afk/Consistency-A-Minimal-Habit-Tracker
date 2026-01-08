import 'package:flutter/material.dart';

  ThemeData lightMode =ThemeData(
    colorScheme: ColorScheme.light(
      surface: Colors.grey.shade300,
      primary: Colors.grey.shade200,
      secondary: Colors.grey.shade100,

      tertiary: const Color.fromARGB(255, 255, 255, 255),
      onTertiary: Colors.black,

      inversePrimary: Colors.grey.shade900,
    ),
  );