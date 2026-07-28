import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class StorageService {
  static const String _key = 'course_planner_data';

  Future<void> saveCourseData(List<CourseGroup> groups) async {
    final json = jsonEncode({
      'courseGroups': groups.map((g) => g.toJson()).toList(),
    });

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json);
    } else {
      // Desktop: same approach since shared_preferences works cross-platform
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json);
    }
  }

  Future<List<CourseGroup>?> loadCourseData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null || json.isEmpty) return null;

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final groupsList = decoded['courseGroups'] as List;
      return groupsList
          .map((g) => CourseGroup.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCourseData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
