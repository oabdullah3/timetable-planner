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

  group('Locked courses', () {
    test('locked course is always included in every timetable', () {
      final groups = [
        _makeGroup('Core', 0, 3, [
          _makeCourse('CS101', locked: true, groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      for (final tt in result.timetables) {
        expect(tt.courses.any((c) => c.course.courseCode == 'CS101'), isTrue, reason: 'Locked course CS101 missing');
      }
    });

    test('returns error when locked courses exceed desired count', () {
      final groups = [
        _makeGroup('Core', 0, 3, [
          _makeCourse('CS101', locked: true, groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', locked: true, groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, contains('locked courses'));
    });

    test('locked course with zero valid configs returns error', () {
      final groups = [
        _makeGroup('Core', 0, 3, [
          _makeCourse('CS101', locked: true, groups: [
            _makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')]),
            _makeSG('Tutorial', [_makeSession(2, 'T01', 'Monday', '10:00', '11:00')]),
          ]),  // clashing sessions -> no valid configs
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, contains('no valid session configurations'));
    });
  });

  group('Locked sessions', () {
    test('locked session forces that specific slot when course is selected', () {
      final groups = [
        _makeGroup('Core', 1, 1, [
          _makeCourse('CS101', groups: [
            _makeSG('Lecture', [
              _makeSession(1, 'L01', 'Monday', '10:00', '11:30', locked: true),
              _makeSession(2, 'L02', 'Wednesday', '10:00', '11:30'),
            ]),
          ]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      for (final tt in result.timetables) {
        final cs101 = tt.courses.firstWhere((c) => c.course.courseCode == 'CS101');
        expect(cs101.sessions.any((s) => s.crn == 1), isTrue, reason: 'Locked CRN 1 should always be selected');
        expect(cs101.sessions.any((s) => s.crn == 2), isFalse, reason: 'Unlocked CRN 2 should not appear with locked CRN 1');
      }
    });

    test('multiple locked sessions in different groups all get applied', () {
      final groups = [
        _makeGroup('Core', 1, 1, [
          _makeCourse('CS101', groups: [
            _makeSG('Lecture', [
              _makeSession(1, 'L01', 'Monday', '10:00', '11:30', locked: true),
            ]),
            _makeSG('Tutorial', [
              _makeSession(2, 'T01', 'Wednesday', '14:00', '15:00', locked: true),
            ]),
          ]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      for (final tt in result.timetables) {
        final cs101 = tt.courses.firstWhere((c) => c.course.courseCode == 'CS101');
        expect(cs101.sessions.any((s) => s.crn == 1), isTrue);
        expect(cs101.sessions.any((s) => s.crn == 2), isTrue);
      }
    });
  });
}
