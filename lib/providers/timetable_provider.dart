import 'package:flutter/material.dart';
import '../models.dart';
import '../services/timetable_generator.dart';

class TimetableProvider extends ChangeNotifier {
  final TimetableGenerator _generator = TimetableGenerator();
  List<GeneratedTimetable> _timetables = [];
  int _currentIndex = 0;
  String? _error;
  bool _generating = false;

  List<GeneratedTimetable> get timetables => _timetables;
  int get currentIndex => _currentIndex;
  String? get error => _error;
  bool get generating => _generating;
  GeneratedTimetable? get current =>
      _timetables.isNotEmpty ? _timetables[_currentIndex] : null;

  void generate(List<CourseGroup> groups, int desiredCourses, TimePreferences prefs) {
    _generating = true;
    _error = null;
    _timetables = [];
    _currentIndex = 0;
    notifyListeners();

    final request = GenerationRequest(
      groups: groups,
      desiredCourses: desiredCourses,
      timePreferences: prefs,
    );

    final result = _generator.generate(request);
    _timetables = result.timetables;
    _error = result.error;
    _generating = false;
    notifyListeners();
  }

  void clear() {
    _timetables = [];
    _currentIndex = 0;
    _error = null;
    _generating = false;
    notifyListeners();
  }

  void goToPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void goToNext() {
    if (_currentIndex < _timetables.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }
}
