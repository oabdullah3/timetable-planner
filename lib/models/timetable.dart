import 'course.dart';
import 'session.dart';

class SelectedCourse {
  final Course course;
  final List<Session> sessions;

  SelectedCourse({required this.course, required this.sessions});
}

class GeneratedTimetable {
  final List<SelectedCourse> courses;
  final int totalScore;

  GeneratedTimetable({required this.courses, required this.totalScore});
}
