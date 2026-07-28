import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const CoursePlannerApp());
}

class CoursePlannerApp extends StatelessWidget {
  const CoursePlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Course Planner",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
