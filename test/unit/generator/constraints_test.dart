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

  group('Min/Max constraints', () {
    test('generates timetables within valid range', () {
      final groups = [
        _makeGroup('Core', 1, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, isNull);
      expect(result.timetables.length, greaterThan(0));
      expect(result.timetables.first.courses.length, 1);
    });

    test('returns error when desired < sumMin', () {
      final groups = [
        _makeGroup('Core', 2, 4, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, contains('Minimum'));
      expect(result.timetables, isEmpty);
    });

    test('returns error when desired > sumMax', () {
      final groups = [
        _makeGroup('Core', 0, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 5));
      expect(result.error, contains('Maximum'));
      expect(result.timetables, isEmpty);
    });
  });

  group('Multiple groups', () {
    test('distributes courses across groups respecting each group min/max', () {
      final groups = [
        _makeGroup('Core', 1, 2, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
        ]),
        _makeGroup('Elective', 0, 1, [
          _makeCourse('ART101', groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      // desired = 3: Core min 1 + extra 1 + Elective 1 = 3
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 3));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      for (final tt in result.timetables) {
        expect(tt.courses.length, 3);
      }
    });

    test('returns empty when group has no courses but min > 0', () {
      // This is caught by the generator — min > available courses
      final groups = [
        _makeGroup('Core', 2, 4, []),
        _makeGroup('Elective', 0, 2, [
          _makeCourse('ART101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.timetables, isEmpty);
    });
  });

  group('Desired course count', () {
    test('each timetable has exactly desiredCourses courses', () {
      final groups = [
        _makeGroup('Core', 1, 3, [
          _makeCourse('CS101', groups: [_makeSG('Lecture', [_makeSession(1, 'L01', 'Monday', '10:00', '11:30')])]),
          _makeCourse('CS102', groups: [_makeSG('Lecture', [_makeSession(2, 'L01', 'Tuesday', '10:00', '11:30')])]),
          _makeCourse('CS103', groups: [_makeSG('Lecture', [_makeSession(3, 'L01', 'Wednesday', '10:00', '11:30')])]),
        ]),
      ];
      for (final desired in [1, 2, 3]) {
        final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: desired));
        expect(result.error, isNull);
        for (final tt in result.timetables) {
          expect(tt.courses.length, desired, reason: 'Failed for desired=$desired');
        }
      }
    });
  });
}
