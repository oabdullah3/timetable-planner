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
