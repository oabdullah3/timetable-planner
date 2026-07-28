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

  // Row 1: CS101 Lecture
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
