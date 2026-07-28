# Automated Test Suite — Implementation Plan

**Goal:** Create a comprehensive automated test suite covering the timetable generator, data models, and parser service. Tests can be run by phase (directory) or all at once.

**Architecture:** Standard `package:flutter_test` unit tests. Generator tests construct models directly. Parser tests use a binary fixture. No widget tests.

## Global Constraints

- All tests must pass with `flutter test` — no skipped tests, no warnings
- Each test file is independently runnable via `flutter test <path>`
- No Flutter widget tree required — pure Dart unit tests
- Models used in tests must match the actual `lib/models/` classes exactly

---
### Task 1: Create test fixture and directory structure

**Files:**
- Create: `test/fixtures/minimal_test.xlsx` (binary, committed to git)
- Create: directory structure `test/unit/generator/`, `test/unit/models/`, `test/unit/services/`

**Interfaces:**
- Consumes: none
- Produces: directory structure, Excel fixture for parser tests

- [ ] **Step 1: Create directories**
```bash
mkdir -p test/fixtures test/unit/generator test/unit/models test/unit/services
```

- [ ] **Step 2: Create minimal Excel fixture**

Use Python/dart to generate a minimal valid `.xlsx` file with:
- Header row: Course Type, Min, Max, Course Code, Course Name, Session Type, Session CRN, Session Code, Session Day, Session Time, Availability
- Row 1: Core, 1, 2, CS101, Programming, Lecture, 1001, L01, Monday, 10:00-11:30, 50
- Row 2: (merged cells) Core, , , CS101, , Tutorial, 2001, T01, Wednesday, 14:00-15:00, 30
- Row 3: (merged cells) Core, , , CS102, Data Structures, Lecture, 1002, L01, Tuesday, 10:00-11:30, 40

Saved to `test/fixtures/minimal_test.xlsx`

---
### Task 2: Generator — Constraint Tests

**Files:**
- Create: `test/unit/generator/constraints_test.dart`

**Interfaces:**
- Consumes: `TimetableGenerator`, `GenerationRequest`, `CourseGroup`, `Course`, `SessionGroup`, `Session`
- Produces: tests for min/max constraints, desired range validation

- [ ] **Step 1: Create the test file**

```dart
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
```

- [ ] **Step 2: Run tests to verify**

```bash
flutter test test/unit/generator/constraints_test.dart
```
Expected: All tests pass

---
### Task 3: Generator — Lock Tests

**Files:**
- Create: `test/unit/generator/locks_test.dart`

**Interfaces:**
- Consumes: same models as Task 2
- Produces: tests for locked courses (always included) and locked sessions (forced slot)

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';
import 'package:application/services/timetable_generator.dart';

// reuse _make helpers from constraints_test or define inline

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
      expect(result.error, contains('More locked courses than desired'));
    });

    test('locked course with zero valid configs returns error', () {
      final groups = [
        _makeGroup('Core', 0, 3, [
          _makeCourse('CS101', locked: true, groups: []),  // no sessions at all
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
```

- [ ] **Step 2: Run tests to verify**

```bash
flutter test test/unit/generator/locks_test.dart
```
Expected: All tests pass

---
### Task 4: Generator — Clash Detection Tests

**Files:**
- Create: `test/unit/generator/clash_test.dart`

**Interfaces:**
- Consumes: same models
- Produces: tests for session clash detection

- [ ] **Step 1: Create the test file**

```dart
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
```

- [ ] **Step 2: Run tests to verify**

```bash
flutter test test/unit/generator/clash_test.dart
```
Expected: All tests pass

---
### Task 5: Generator — Scoring Tests

**Files:**
- Create: `test/unit/generator/scoring_test.dart`

**Interfaces:**
- Consumes: same models, `TimetableScore`
- Produces: tests for lexicographic scoring (violations > penalty > preference)

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';
import 'package:application/services/timetable_generator.dart';

// ... helpers ...

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
```

- [ ] **Step 2: Run tests to verify**

```bash
flutter test test/unit/generator/scoring_test.dart
```
Expected: All tests pass

---
### Task 6: Model Serialization Tests

**Files:**
- Create: `test/unit/models/serialization_test.dart`

**Interfaces:**
- Consumes: `CourseGroup`, `Course`, `SessionGroup`, `Session`, `TimetableScore`
- Produces: tests for JSON roundtrip and copy semantics

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';

void main() {
  group('Session serialization', () {
    test('toJson/fromJson roundtrip preserves all fields', () {
      final original = Session(crn: 1001, sessionCode: 'L01', sessionDay: 'Monday',
          sessionStartTime: '10:00', sessionEndTime: '11:30', sessionAvailability: 50, locked: true);
      final json = original.toJson();
      final restored = Session.fromJson(json);
      expect(restored.crn, original.crn);
      expect(restored.sessionCode, original.sessionCode);
      expect(restored.sessionDay, original.sessionDay);
      expect(restored.sessionStartTime, original.sessionStartTime);
      expect(restored.sessionEndTime, original.sessionEndTime);
      expect(restored.sessionAvailability, original.sessionAvailability);
      expect(restored.locked, original.locked);
    });

    test('copyWith creates modified copy without mutating original', () {
      final original = Session(crn: 1, sessionCode: 'L01', sessionDay: 'Monday',
          sessionStartTime: '10:00', sessionEndTime: '11:30', sessionAvailability: 50);
      final modified = original.copyWith(locked: true);
      expect(original.locked, isFalse);
      expect(modified.locked, isTrue);
      expect(modified.crn, original.crn);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {'crn': 1001, 'sessionCode': 'L01', 'sessionDay': 'Monday',
          'sessionStartTime': '10:00', 'sessionEndTime': '11:30'};
      final session = Session.fromJson(json);
      expect(session.sessionAvailability, 0);
      expect(session.locked, isFalse);
    });
  });

  group('Course serialization', () {
    test('toJson/fromJson roundtrip preserves preferenceScore and locked', () {
      final original = Course(
        courseCode: 'CS101', courseName: 'Programming',
        preferenceScore: 4, locked: true,
        sessionGroups: [
          SessionGroup(sessionType: 'Lecture', sessionOptions: [
            Session(crn: 1, sessionCode: 'L01', sessionDay: 'Monday',
                sessionStartTime: '10:00', sessionEndTime: '11:30', sessionAvailability: 50),
          ]),
        ],
      );
      final json = original.toJson();
      final restored = Course.fromJson(json);
      expect(restored.courseCode, original.courseCode);
      expect(restored.courseName, original.courseName);
      expect(restored.preferenceScore, 4);
      expect(restored.locked, isTrue);
      expect(restored.sessionGroups.length, 1);
      expect(restored.sessionGroups.first.sessionOptions.length, 1);
    });

    test('copyWith modifies specific fields only', () {
      final original = Course(courseCode: 'CS101', courseName: 'Old', sessionGroups: []);
      final modified = original.copyWith(courseName: 'New', preferenceScore: 5);
      expect(original.courseName, 'Old');
      expect(modified.courseName, 'New');
      expect(modified.preferenceScore, 5);
      expect(modified.courseCode, 'CS101');
    });
  });

  group('CourseGroup serialization', () {
    test('toJson/fromJson roundtrip preserves min/max and courses', () {
      final original = CourseGroup(
        courseType: 'Core', min: 2, max: 4,
        courses: [
          Course(courseCode: 'CS101', courseName: 'Programming', sessionGroups: []),
        ],
      );
      final json = original.toJson();
      final restored = CourseGroup.fromJson(json);
      expect(restored.courseType, 'Core');
      expect(restored.min, 2);
      expect(restored.max, 4);
      expect(restored.courses.length, 1);
    });
  });

  group('TimetableScore', () {
    test('compareTo orders by violations first', () {
      expect(
        TimetableScore(violations: 0, timePenalty: 0, preferenceScore: 0)
            .compareTo(TimetableScore(violations: 1, timePenalty: 0, preferenceScore: 5)),
        lessThan(0),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify**

```bash
flutter test test/unit/models/serialization_test.dart
```
Expected: All tests pass

---
### Task 7: Parser Service Tests

**Files:**
- Create: `test/unit/services/parser_test.dart`
- Create: `test/fixtures/minimal_test.xlsx`

**Interfaces:**
- Consumes: `ParserService`, Excel fixture file
- Produces: tests for Excel parsing

- [ ] **Step 1: Generate the minimal test Excel file**

Create a dart script that generates `test/fixtures/minimal_test.xlsx`:

```dart
// Save as tool/generate_test_excel.dart and run: dart tool/generate_test_excel.dart
import 'package:excel/excel.dart';
import 'dart:io';

void main() {
  final excel = Excel.createExcel();
  final sheet = excel['Courses'];
  
  // Header row
  sheet.appendRow([
    TextCellValue('Course Type'), TextCellValue('Min'), TextCellValue('Max'),
    TextCellValue('Course Code'), TextCellValue('Course Name'),
    TextCellValue('Session Type'), TextCellValue('Session CRN'), TextCellValue('Session Code'),
    TextCellValue('Session Day'), TextCellValue('Session Time'), TextCellValue('Availability'),
  ]);
  
  // Row 1: CS101 Lecture + Tutorial
  sheet.appendRow([
    TextCellValue('Core'), IntCellValue(1), IntCellValue(2),
    TextCellValue('CS101'), TextCellValue('Programming'),
    TextCellValue('Lecture'), IntCellValue(1001), TextCellValue('L01'),
    TextCellValue('Monday'), TextCellValue('10:00 - 11:30'), IntCellValue(50),
  ]);
  
  // Row 2: CS101 Tutorial (course code carried forward)
  sheet.appendRow([
    TextCellValue('Core'), IntCellValue(1), IntCellValue(2),
    TextCellValue('CS101'), TextCellValue('Programming'),
    TextCellValue('Tutorial'), IntCellValue(2001), TextCellValue('T01'),
    TextCellValue('Wednesday'), TextCellValue('14:00 - 15:00'), IntCellValue(30),
  ]);
  
  // Row 3: CS102 Lecture
  sheet.appendRow([
    TextCellValue('Core'), IntCellValue(1), IntCellValue(2),
    TextCellValue('CS102'), TextCellValue('Data Structures'),
    TextCellValue('Lecture'), IntCellValue(1002), TextCellValue('L01'),
    TextCellValue('Tuesday'), TextCellValue('10:00 - 11:30'), IntCellValue(40),
  ]);
  
  final bytes = excel.encode()!;
  File('test/fixtures/minimal_test.xlsx').writeAsBytesSync(bytes);
  print('Created test/fixtures/minimal_test.xlsx');
}
```

Run:
```bash
mkdir -p test/fixtures
dart tool/generate_test_excel.dart
```

- [ ] **Step 2: Create `test/unit/services/parser_test.dart`**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/services/parser_service.dart';

void main() {
  group('ParserService', () {
    late ParserService parser;
    
    setUp(() {
      parser = ParserService();
    });

    test('parses valid Excel into correct group/course/session structure', () {
      final bytes = File('test/fixtures/minimal_test.xlsx').readAsBytesSync();
      final groups = parser.parseExcelBytes(bytes);
      
      expect(groups.length, 1);  // One group: Core
      expect(groups.first.courseType, 'Core');
      expect(groups.first.min, 1);
      expect(groups.first.max, 2);
      expect(groups.first.courses.length, 2);  // CS101, CS102
      
      final cs101 = groups.first.courses.firstWhere((c) => c.courseCode == 'CS101');
      expect(cs101.sessionGroups.length, 2);  // Lecture + Tutorial
      
      final cs101lecture = cs101.sessionGroups.firstWhere((sg) => sg.sessionType == 'Lecture');
      expect(cs101lecture.sessionOptions.length, 1);
      expect(cs101lecture.sessionOptions.first.crn, 1001);
      expect(cs101lecture.sessionOptions.first.sessionDay, 'Monday');
      
      final cs101tutorial = cs101.sessionGroups.firstWhere((sg) => sg.sessionType == 'Tutorial');
      expect(cs101tutorial.sessionOptions.length, 1);
      expect(cs101tutorial.sessionOptions.first.crn, 2001);
      
      final cs102 = groups.first.courses.firstWhere((c) => c.courseCode == 'CS102');
      expect(cs102.sessionGroups.length, 1);
    });

    test('handles empty bytes gracefully', () {
      expect(() => parser.parseExcelBytes(Uint8List(0)), throwsA(isA<Exception>()));
    });
  });
}
```

Note: for the empty bytes test, the excel package will throw — that's expected. If it throws a specific type, adjust the matcher.

- [ ] **Step 3: Run tests to verify**

```bash
flutter test test/unit/services/parser_test.dart
```
Expected: All tests pass

---
### Task 8: Run All Tests

- [ ] **Step 1: Run full test suite**

```bash
flutter test
```
Expected: All tests across all files pass with 0 failures

- [ ] **Step 2: Run each directory independently to verify phase targeting**

```bash
flutter test test/unit/generator/
flutter test test/unit/models/
flutter test test/unit/services/
```
Expected: Each directory runs its tests independently
