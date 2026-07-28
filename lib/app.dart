import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/course_data_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/wizard_screen.dart';
import 'screens/timetable_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CourseDataProvider>();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: provider,
      redirect: (context, state) {
        if (!provider.loaded) return null; // still loading
        if (state.matchedLocation == '/wizard') return null;
        if (provider.courseGroups.isEmpty) return '/wizard';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/wizard', builder: (context, state) => const WizardScreen()),
        GoRoute(path: '/timetable', builder: (context, state) => const TimetableScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Course Planner',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),
      routerConfig: _router,
    );
  }
}
