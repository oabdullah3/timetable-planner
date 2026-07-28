import 'package:flutter/material.dart';
import '../models.dart';
import 'session_detail_sheet.dart';

class TimetableGrid extends StatelessWidget {
  final GeneratedTimetable timetable;
  final List<Color> courseColors;
  final void Function(Course course, Session session, String sessionType)? onSessionTap;

  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.courseColors,
    this.onSessionTap,
  });

  static const List<String> dayOrder = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    // Collect all sessions with their course info
    final events = <_GridEvent>[];
    for (final sc in timetable.courses) {
      for (final s in sc.sessions) {
        String sessionType = '';
        for (final sg in sc.course.sessionGroups) {
          if (sg.sessionOptions.contains(s)) {
            sessionType = sg.sessionType;
            break;
          }
        }
        events.add(_GridEvent(
          session: s,
          course: sc.course,
          sessionType: sessionType,
        ));
      }
    }

    if (events.isEmpty) {
      return const Center(child: Text('No sessions in this timetable'));
    }

    // Find time range
    int minMinute = 24 * 60, maxMinute = 0;
    for (final e in events) {
      final start = _timeToMinutes(e.session.sessionStartTime);
      final end = _timeToMinutes(e.session.sessionEndTime);
      if (start < minMinute) minMinute = start;
      if (end > maxMinute) maxMinute = end;
    }
    minMinute = (minMinute ~/ 60) * 60;
    maxMinute = ((maxMinute + 59) ~/ 60) * 60;
    final slots = (maxMinute - minMinute) ~/ 60;

    // Assign color per course
    final colorMap = <String, Color>{};
    for (int i = 0; i < timetable.courses.length; i++) {
      colorMap[timetable.courses[i].course.courseCode] = courseColors[i % courseColors.length];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: Colors.grey[300]!, width: 1),
          columnWidths: {
            0: const FixedColumnWidth(80),
            for (int i = 1; i <= 7; i++) i: const FixedColumnWidth(130),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[200]),
              children: [
                _headerCell('Time'),
                ...dayOrder.map((d) => _headerCell(d)),
              ],
            ),
            for (int row = 0; row < slots; row++)
              _buildTimeRow(context, row, minMinute, events, colorMap),
          ],
        ),
      ),
    );
  }

  TableRow _buildTimeRow(BuildContext context, int row, int minMinute, List<_GridEvent> events, Map<String, Color> colorMap) {
    final slotStart = minMinute + row * 60;
    final slotEnd = slotStart + 60;
    final timeStr = '${_minutesToTime(slotStart)}-${_minutesToTime(slotEnd)}';

    return TableRow(
      children: [
        _timeCell(timeStr),
        for (final day in dayOrder) _buildDayCell(context, day, slotStart, slotEnd, events, colorMap),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, String day, int slotStart, int slotEnd, List<_GridEvent> events, Map<String, Color> colorMap) {
    // Find sessions that OVERLAP this slot (not just start in it)
    final overlapping = events.where((e) {
      if (e.session.sessionDay != day) return false;
      final start = _timeToMinutes(e.session.sessionStartTime);
      final end = _timeToMinutes(e.session.sessionEndTime);
      return start < slotEnd && end > slotStart;
    }).toList();

    if (overlapping.isEmpty) {
      return Container(
        height: 50,
        color: Colors.grey[50],
        child: const Center(child: Text('')),
      );
    }

    final e = overlapping.first;
    final color = colorMap[e.course.courseCode] ?? Colors.blue;
    final sessionStart = _timeToMinutes(e.session.sessionStartTime);
    final isStartingSlot = sessionStart >= slotStart && sessionStart < slotEnd;

    return GestureDetector(
      onTap: () {
        if (onSessionTap != null) {
          onSessionTap!(e.course, e.session, e.sessionType);
        } else {
          _defaultShowDetail(context, e);
        }
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isStartingSlot ? 0.15 : 0.08),
          border: isStartingSlot
              ? Border(left: BorderSide(color: color, width: 4))
              : Border(left: BorderSide(color: color.withValues(alpha: 0.4), width: 2)),
        ),
        child: isStartingSlot
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.course.courseCode,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    e.session.sessionCode,
                    style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _defaultShowDetail(BuildContext context, _GridEvent event) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SessionDetailSheet(
        course: event.course,
        session: event.session,
        sessionType: event.sessionType,
      ),
    );
  }

  Widget _headerCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
    );
  }

  Widget _timeCell(String text) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
    );
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _GridEvent {
  final Session session;
  final Course course;
  final String sessionType;

  _GridEvent({required this.session, required this.course, required this.sessionType});
}
