import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/models.dart';
import 'package:application/widgets/timetable_grid.dart';

Course _course(String code, List<SessionGroup> groups) => Course(
    courseCode: code,
    courseName: code,
    preferenceScore: 0,
    sessionGroups: groups);

SessionGroup _sg(String type, List<Session> sessions) =>
    SessionGroup(sessionType: type, sessionOptions: sessions);

Session _session(int crn, String code, String day, String start, String end) =>
    Session(
        crn: crn,
        sessionCode: code,
        sessionDay: day,
        sessionStartTime: start,
        sessionEndTime: end,
        sessionAvailability: 50);

void main() {
  final colors = const [Colors.blue, Colors.green];

  Widget buildHost(GeneratedTimetable tt,
      {void Function(Course, Session, String)? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: TimetableGrid(timetable: tt, courseColors: colors, onSessionTap: onTap),
      ),
    );
  }

  Positioned positionedFor(WidgetTester tester, Key key) {
    return tester.widget<Positioned>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Positioned)).first,
    );
  }

  testWidgets(
      'back-to-back sessions (C61 then T61 sharing a slot boundary) render as two distinct blocks at true times',
      (tester) async {
    final c61 = _session(1, 'C61', 'Wednesday', '18:30', '21:20');
    final t61 = _session(2, 'T61', 'Wednesday', '21:30', '22:20');
    final cs4487 = _course('CS4487', [
      _sg('Lecture', [c61]),
      _sg('Tutorial', [t61]),
    ]);
    final tt = GeneratedTimetable(
      courses: [SelectedCourse(course: cs4487, sessions: [c61, t61])],
      totalScore: const TimetableScore(violations: 0, timePenalty: 0, preferenceScore: 0),
    );

    Session? tapped;
    await tester.pumpWidget(buildHost(tt, onTap: (c, s, t) => tapped = s));

    final c61Key = const ValueKey('session-block-CS4487-C61');
    final t61Key = const ValueKey('session-block-CS4487-T61');

    // Both sessions are rendered as their own block (T61 is no longer hidden).
    expect(find.byKey(c61Key), findsOneWidget);
    expect(find.byKey(t61Key), findsOneWidget);

    final c61Pos = positionedFor(tester, c61Key);
    final t61Pos = positionedFor(tester, t61Key);

    // C61 18:30-21:20 -> top 30 (30 min after the 18:00 origin), height 170.
    expect(c61Pos.top, 30.0);
    expect(c61Pos.height, 170.0);
    expect(c61Pos.left, 0.0);
    expect(c61Pos.width, 130.0);

    // T61 21:30-22:20 -> top 210, height 50; starts after C61 ends, same column.
    expect(t61Pos.top, 210.0);
    expect(t61Pos.height, 50.0);
    expect(t61Pos.left, 0.0);
    expect(t61Pos.width, 130.0);

    // T61 sits below C61 (10 min gap preserved, no overlap).
    expect(t61Pos.top, greaterThanOrEqualTo(c61Pos.top! + c61Pos.height!));

    // T61 is independently tappable and reports its own session.
    await tester.tap(find.byKey(t61Key));
    expect(tapped?.crn, 2);
  });

  testWidgets('genuinely overlapping sessions are placed side by side',
      (tester) async {
    final a = _session(1, 'A01', 'Monday', '10:00', '12:00');
    final b = _session(2, 'B01', 'Monday', '11:00', '13:00');
    final course = _course('CS200', [_sg('Lecture', [a, b])]);
    final tt = GeneratedTimetable(
      courses: [SelectedCourse(course: course, sessions: [a, b])],
      totalScore: const TimetableScore(violations: 0, timePenalty: 0, preferenceScore: 0),
    );

    await tester.pumpWidget(buildHost(tt));

    final aPos = positionedFor(tester, const ValueKey('session-block-CS200-A01'));
    final bPos = positionedFor(tester, const ValueKey('session-block-CS200-B01'));

    // Two columns -> each block is half the day column; A left, B right.
    expect(aPos.width, 65.0);
    expect(bPos.width, 65.0);
    expect(aPos.left, 0.0);
    expect(bPos.left, 65.0);
  });
}
