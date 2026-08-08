import 'dart:ui' as ui;

import 'package:application/models.dart';
import 'package:application/services/pdf_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

Session _session(int crn, String code, String day, String start, String end) =>
    Session(
        crn: crn,
        sessionCode: code,
        sessionDay: day,
        sessionStartTime: start,
        sessionEndTime: end,
        sessionAvailability: 50);

Course _course(String code, String name, {String note = ''}) => Course(
    courseCode: code,
    courseName: name,
    note: note,
    sessionGroups: [
      SessionGroup(sessionType: 'Lecture', sessionOptions: [
        _session(1001, 'L01', 'Monday', '10:00', '11:30'),
      ]),
    ]);

GeneratedTimetable _timetable() => GeneratedTimetable(
      courses: [
        SelectedCourse(
          course: _course('GE1501', 'Chinese Civilisation - History and Philosophy',
              note: 'Midterm in week 8.'),
          sessions: [_session(1001, 'L01', 'Monday', '10:00', '11:30')],
        ),
        SelectedCourse(
          course: _course('CS4487', 'Machine Learning'),
          sessions: [_session(2001, 'C61', 'Wednesday', '18:30', '21:20')],
        ),
      ],
      totalScore: const TimetableScore(violations: 0, timePenalty: 0, preferenceScore: 0),
    );

void main() {
  // Builds a real 1x1 PNG via dart:ui so MemoryImage can decode it.
  Future<ui.Image> tinyImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    return picture.toImage(1, 1);
  }

  test('buildPdf returns a non-empty PDF with all three pages', () async {
    final image = await tinyImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final png = byteData!.buffer.asUint8List();

    final service = PdfExportService();
    final bytes = await service.buildPdf(timetable: _timetable(), gridImagePng: png);

    // Valid PDF header, non-trivial size.
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(500));
  });

  test('buildPdf succeeds with a custom page format', () async {
    final image = await tinyImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final png = byteData!.buffer.asUint8List();

    final service = PdfExportService();
    final bytes = await service.buildPdf(
      timetable: _timetable(),
      gridImagePng: png,
      pageFormat: const PdfPageFormat(1122, 794, marginAll: 8),
    );

    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  });
}
