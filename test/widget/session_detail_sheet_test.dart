import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';
import 'package:application/widgets/session_detail_sheet.dart';

Session _session() => Session(
    crn: 1001,
    sessionCode: 'L01',
    sessionDay: 'Monday',
    sessionStartTime: '10:00',
    sessionEndTime: '11:30',
    sessionAvailability: 50);

Widget _host(Course course) => MaterialApp(
      home: Scaffold(
        body: SessionDetailSheet(course: course, session: _session(), sessionType: 'Lecture'),
      ),
    );

void main() {
  testWidgets('shows the note block when a note is set', (tester) async {
    final course = Course(
      courseCode: 'CS101',
      courseName: 'Programming',
      note: 'Bring a calculator',
      sessionGroups: [],
    );

    await tester.pumpWidget(_host(course));

    expect(find.byIcon(Icons.note_alt), findsOneWidget);
    expect(find.text('Bring a calculator'), findsOneWidget);
  });

  testWidgets('hides the note block when no note is set', (tester) async {
    final course = Course(
      courseCode: 'CS101',
      courseName: 'Programming',
      note: '',
      sessionGroups: [],
    );

    await tester.pumpWidget(_host(course));

    expect(find.byIcon(Icons.note_alt), findsNothing);
    expect(find.text('Bring a calculator'), findsNothing);
  });
}
