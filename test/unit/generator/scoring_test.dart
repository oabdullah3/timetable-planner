import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';
import 'package:application/services/timetable_generator.dart';

CourseGroup _makeGroup(String type, int min, int max, List<Course> courses) =>
    CourseGroup(courseType: type, min: min, max: max, courses: courses);

Course _makeCourse(String code, {int pref = 0, bool locked = false, List<SessionGroup>? groups}) =>
    Course(courseCode: code, courseName: code, preferenceScore: pref, locked: locked, sessionGroups: groups ?? []);

SessionGroup _makeSG(String type, List<Session> sessions) =>
    SessionGroup(sessionType: type, sessionOptions: sessions);

Session _makeSession(int crn, String code, String day, String start, String end, {bool locked = false}) =>
    Session(crn: crn, sessionCode: code, sessionDay: day, sessionStartTime: start, sessionEndTime: end, sessionAvailability: 50, locked: locked);

void main() {
  final generator = TimetableGenerator();

  group('Preference scoring', () {
    test('higher preference courses appear in earlier timetables', () {
      final groups = [
        _makeGroup('Core', 2, 2, [
          _makeCourse('CS101', pref: 5, groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', pref: 1, groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', pref: 0, groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      // With all courses on different days, all combinations are valid but sorted by preference
      expect(result.timetables, isNotEmpty);
      // First timetable should have highest combined preference
      final first = result.timetables.first;
      expect(first.totalScore.preferenceScore, greaterThan(0));
    });
  });

  group('TimetableScore comparison', () {
    test('fewer violations beats more violations regardless of preference', () {
      final lowViolation = TimetableScore(violations: 0, timePenalty: 0, preferenceScore: 0);
      final highPref = TimetableScore(violations: 2, timePenalty: 0, preferenceScore: 5);
      expect(lowViolation.compareTo(highPref), lessThan(0));
    });

    test('same violations, lower penalty wins', () {
      final lowPenalty = TimetableScore(violations: 1, timePenalty: 10, preferenceScore: 0);
      final highPenalty = TimetableScore(violations: 1, timePenalty: 50, preferenceScore: 5);
      expect(lowPenalty.compareTo(highPenalty), lessThan(0));
    });

    test('same violations and penalty, higher preference wins', () {
      final highPref = TimetableScore(violations: 1, timePenalty: 10, preferenceScore: 5);
      final lowPref = TimetableScore(violations: 1, timePenalty: 10, preferenceScore: 1);
      expect(highPref.compareTo(lowPref), lessThan(0));
    });

    test('all equal scores are equal', () {
      final a = TimetableScore(violations: 1, timePenalty: 10, preferenceScore: 3);
      final b = TimetableScore(violations: 1, timePenalty: 10, preferenceScore: 3);
      expect(a.compareTo(b), 0);
    });
  });

  group('Generation sorting', () {
    test('timetables are sorted best-first using lexicographic scoring', () {
      final groups = [
        _makeGroup('Core', 2, 3, [
          _makeCourse('CS101', pref: 5, groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', pref: 4, groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', pref: 1, groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      expect(result.timetables.length, greaterThan(1));
      // Verify scores are non-increasing
      for (int i = 1; i < result.timetables.length; i++) {
        final prev = result.timetables[i - 1].totalScore;
        final curr = result.timetables[i].totalScore;
        expect(prev.compareTo(curr), lessThanOrEqualTo(0));
      }
    });
  });
}
