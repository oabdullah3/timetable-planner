import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/storage_service.dart';

class CourseDataProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<CourseGroup> _courseGroups = [];
  bool _loaded = false;
  Timer? _debounceTimer;

  List<CourseGroup> get courseGroups => _courseGroups;
  bool get loaded => _loaded;

  Future<void> load() async {
    final data = await _storage.loadCourseData();
    if (data != null) {
      _courseGroups = data;
    }
    _loaded = true;
    notifyListeners();
  }

  void setCourseGroups(List<CourseGroup> groups) {
    _courseGroups = groups;
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Course Groups -----
  void addGroup(String courseType, {int? min, int? max}) {
    _courseGroups.add(CourseGroup(
      courseType: courseType, courses: [], min: min, max: max,
    ));
    notifyListeners();
    _scheduleSave();
  }

  void updateGroup(int index, {String? courseType, int? min, int? max}) {
    final old = _courseGroups[index];
    _courseGroups[index] = CourseGroup(
      courseType: courseType ?? old.courseType,
      courses: old.courses,
      min: min ?? old.min,
      max: max ?? old.max,
    );
    notifyListeners();
    _scheduleSave();
  }

  void deleteGroup(int index) {
    _courseGroups.removeAt(index);
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Courses -----
  void addCourse(int groupIndex, Course course) {
    _courseGroups[groupIndex].courses.add(course);
    notifyListeners();
    _scheduleSave();
  }

  void updateCourse(int groupIndex, int courseIndex, Course course) {
    _courseGroups[groupIndex].courses[courseIndex] = course;
    notifyListeners();
    _scheduleSave();
  }

  void deleteCourse(int groupIndex, int courseIndex) {
    _courseGroups[groupIndex].courses.removeAt(courseIndex);
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Sessions -----
  void addSession(int groupIndex, int courseIndex, String sessionType, Session session) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    var sg = course.sessionGroups.where((s) => s.sessionType == sessionType).firstOrNull;
    if (sg == null) {
      sg = SessionGroup(sessionType: sessionType, sessionOptions: []);
      course.sessionGroups.add(sg);
    }
    sg.sessionOptions.add(session);
    notifyListeners();
    _scheduleSave();
  }

  void deleteSession(int groupIndex, int courseIndex, int sgIndex, int sessionIndex) {
    _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions.removeAt(sessionIndex);
    notifyListeners();
    _scheduleSave();
  }

  // ----- Preferences -----
  void setCoursePreference(int groupIndex, int courseIndex, int score) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    _courseGroups[groupIndex].courses[courseIndex] = course.copyWith(preferenceScore: score);
    notifyListeners();
    _scheduleSave();
  }

  void updateCourseNote(int groupIndex, int courseIndex, String note) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    _courseGroups[groupIndex].courses[courseIndex] = course.copyWith(note: note);
    notifyListeners();
    _scheduleSave();
  }

  void toggleCourseLock(int groupIndex, int courseIndex) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    _courseGroups[groupIndex].courses[courseIndex] = course.copyWith(locked: !course.locked);
    notifyListeners();
    _scheduleSave();
  }

  void toggleSessionLock(int groupIndex, int courseIndex, int sgIndex, int sessionIndex) {
    final session = _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions[sessionIndex];
    _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions[sessionIndex] = session.copyWith(locked: !session.locked);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _storage.saveCourseData(_courseGroups);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
