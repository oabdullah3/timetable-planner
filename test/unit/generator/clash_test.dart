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

  group('Clash detection', () {
    test('sessions on same day with overlapping times are rejected', () {
      final groups = [
        _makeGroup('Core', 2, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Monday', '10:00', '11:30')])]),
        ]),
      ];
      // Both on Monday 10:00-11:30 — they clash, so only 1 can be in each timetable
      // But min=2 requires both — impossible
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.timetables, isEmpty);
    });

    test('sessions on different days do not clash', () {
      final groups = [
        _makeGroup('Core', 2, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
    });

    test('adjacent sessions (same day, one ends when other starts) do not clash', () {
      final groups = [
        _makeGroup('Core', 2, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:00')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Monday', '11:00', '12:00')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
    });

    test('session with overlapping times across groups are rejected', () {
      final groups = [
        _makeGroup('Core', 1, 1, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '12:00')])]),
        ]),
        _makeGroup('Elective', 1, 1, [
          _makeCourse('ART101', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Monday', '11:00', '13:00')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.timetables, isEmpty);
    });
  });

  group('Internal clash (within a course)', () {
    test('course with clashing session types is rejected', () {
      // A course with Lecture Mon 10:00 and Tutorial Mon 10:00 — internal clash
      final course = _makeCourse('CS101', groups: [
        _makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')]),
        _makeSG('Tutorial', [_makeSession(2, 'T01', 'Monday', '10:00', '11:00')]),
      ]);
      final groups = [_makeGroup('Core', 1, 1, [course])];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      // The clash causes no valid config for this course
      expect(result.timetables, isEmpty);
    });
  });
}
