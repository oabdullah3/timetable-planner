import 'course.dart';
import 'session.dart';

class SelectedCourse {
  final Course course;
  final List<Session> sessions;

  SelectedCourse({required this.course, required this.sessions});
}

class TimetableScore implements Comparable<TimetableScore> {
  /// How many preference rules were broken (e.g. class before earliest time,
  /// class on a deselected day, unwanted gap). Fewer is better.
  final int violations;

  /// Cumulative time penalty (magnitude of broken rules). Lower is better.
  final int timePenalty;

  /// Sum of course preference scores (0-5 per course). Higher is better.
  final int preferenceScore;

  const TimetableScore({
    required this.violations,
    required this.timePenalty,
    required this.preferenceScore,
  });

  @override
  int compareTo(TimetableScore other) {
    // Fewer violations = better (ascending)
    if (violations != other.violations) {
      return violations.compareTo(other.violations);
    }
    // Lower time penalty = better (ascending)
    if (timePenalty != other.timePenalty) {
      return timePenalty.compareTo(other.timePenalty);
    }
    // Higher preference score = better (descending)
    return other.preferenceScore.compareTo(preferenceScore);
  }
}

class GeneratedTimetable {
  final List<SelectedCourse> courses;
  final TimetableScore totalScore;

  GeneratedTimetable({required this.courses, required this.totalScore});
}
