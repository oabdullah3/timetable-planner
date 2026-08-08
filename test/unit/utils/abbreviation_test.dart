import 'package:flutter_test/flutter_test.dart';
import 'package:application/utils/abbreviation.dart';

void main() {
  group('courseAbbreviation', () {
    test('abbreviates first letters of meaningful words (CCHP example)', () {
      expect(
        courseAbbreviation('Chinese Civilisation - History and Philosophy'),
        'CCHP',
      );
    });

    test('skips connector words', () {
      expect(courseAbbreviation('AI for Software Engineering'), 'ASE');
      expect(courseAbbreviation('Business Programming with Spreadsheet'), 'BPS');
      expect(courseAbbreviation('Design & Analysis of Algorithms'), 'DAA');
    });

    test('single word yields its first letter', () {
      expect(courseAbbreviation('Algebra'), 'A');
    });

    test('skips tokens that do not start with a letter', () {
      expect(courseAbbreviation('3D Modelling'), 'M');
    });

    test('caps at maxLength letters (default 6)', () {
      expect(
        courseAbbreviation('Advanced Computational Optimization Techniques '
            'Methods Engineering Principles Systems'),
        'ACOTME',
      );
    });

    test('returns fallback when nothing can be derived', () {
      expect(courseAbbreviation('', fallback: 'CS101'), 'CS101');
      expect(courseAbbreviation('   ', fallback: 'CS101'), 'CS101');
      expect(courseAbbreviation('!!!', fallback: 'CS101'), 'CS101');
    });
  });
}
