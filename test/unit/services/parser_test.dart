import 'dart:io';
import 'dart:typed_data';
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
      expect(() => parser.parseExcelBytes(Uint8List(0)), throwsA(isA<Error>()));
    });
  });
}
