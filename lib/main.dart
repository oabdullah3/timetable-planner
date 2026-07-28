import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/course_data_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/timetable_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseDataProvider()..load()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
      ],
      child: App(),
    ),
  );
}
