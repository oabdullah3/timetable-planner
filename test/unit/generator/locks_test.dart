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

    test('locked course with zero valid configs returns error naming the course', () {
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
      expect(result.timetables, isEmpty);
      expect(result.error, contains('CS101'));
      expect(result.error, contains('does not fit any combinations'));
    });

    test('locked course explores ALL session options in a group (bug: only first used)', () {
      final groups = [
        _makeGroup('Core', 1, 1, [
          _makeCourse('CS101', locked: true, groups: [
            _makeSG('Tutorial', [
              _makeSession(1, 'T01', 'Monday', '10:00', '11:00'),
              _makeSession(2, 'T02', 'Tuesday', '10:00', '11:00'),
              _makeSession(3, 'T03', 'Wednesday', '10:00', '11:00'),
            ]),
          ]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 1));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      final crnsUsed = <int>{};
      for (final tt in result.timetables) {
        for (final sc in tt.courses) {
          if (sc.course.courseCode == 'CS101') {
            crnsUsed.addAll(sc.sessions.map((s) => s.crn));
          }
        }
      }
      expect(crnsUsed, containsAll([1, 2, 3]),
          reason: 'All three tutorial options should appear across generated timetables');
    });

    test('two locked courses with clashing sessions produce NO timetables and name the blocker', () {
      final groups = [
        _makeGroup('GE', 1, 2, [
          _makeCourse('GE1501', locked: true, groups: [
            _makeSG('Lecture', [_makeSession(1, 'CB1', 'Thursday', '15:00', '17:50')]),
          ]),
          _makeCourse('GE1362', locked: true, groups: [
            _makeSG('Lecture', [_makeSession(2, 'C01', 'Thursday', '16:00', '17:50')]),
            _makeSG('Tutorial', [_makeSession(3, 'T01', 'Thursday', '18:00', '18:50')]),
          ]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.timetables, isEmpty,
          reason: 'Locked courses GE1501 and GE1362 clash on Thursday -> no timetable may be generated');
      expect(result.error, contains('GE1362'));
      expect(result.error, contains('does not fit any combinations'));
    });

    test('locked course tries ALL configs so a later config can fit alongside a min-required course', () {
      // CS101 (locked) has lectures Mon 10:00 (L01) and Tue 10:00 (L02).
      // CS102 (min-required, non-locked) has a lecture Mon 10:00 that clashes
      // with L01 but not L02. The generator must fall back to L02.
      final groups = [
        _makeGroup('Core', 2, 2, [
          _makeCourse('CS101', locked: true, groups: [
            _makeSG('Lecture', [
              _makeSession(1, 'L01', 'Monday', '10:00', '11:30'),
              _makeSession(2, 'L02', 'Tuesday', '10:00', '11:30'),
            ]),
          ]),
          _makeCourse('CS102', groups: [
            _makeSG('Lecture', [_makeSession(3, 'L01', 'Monday', '10:00', '11:30')]),
          ]),
        ]),
      ];
      final result = generator.generate(GenerationRequest(groups: groups, desiredCourses: 2));
      expect(result.error, isNull);
      expect(result.timetables, isNotEmpty);
      for (final tt in result.timetables) {
        final cs101 = tt.courses.firstWhere((c) => c.course.courseCode == 'CS101');
        expect(cs101.sessions.any((s) => s.crn == 2), isTrue,
            reason: 'Should use L02 so CS102 can fit without a clash');
      }
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
