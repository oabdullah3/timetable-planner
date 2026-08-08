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

  static const double _timeColumnWidth = 80;
  static const double _dayColumnWidth = 130;
  static const double _pxPerMinute = 1.0; // 60 px per hour

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

    // Find time range, aligned to whole hours.
    int minMinute = 24 * 60, maxMinute = 0;
    for (final e in events) {
      final start = _timeToMinutes(e.session.sessionStartTime);
      final end = _timeToMinutes(e.session.sessionEndTime);
      if (start < minMinute) minMinute = start;
      if (end > maxMinute) maxMinute = end;
    }
    minMinute = (minMinute ~/ 60) * 60;
    maxMinute = ((maxMinute + 59) ~/ 60) * 60;
    final totalHeight = (maxMinute - minMinute) * _pxPerMinute;

    // Assign color per course
    final colorMap = <String, Color>{};
    for (int i = 0; i < timetable.courses.length; i++) {
      colorMap[timetable.courses[i].course.courseCode] = courseColors[i % courseColors.length];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                SizedBox(
                  width: _timeColumnWidth,
                  child: _headerCell('Time'),
                ),
                for (final day in dayOrder)
                  SizedBox(width: _dayColumnWidth, child: _headerCell(day)),
              ],
            ),
            // Body: time gutter + one column per day. Each session is rendered
            // as a block spanning its ACTUAL start/end time (not snapped to
            // whole hours), so back-to-back sessions like a lecture ending
            // 21:20 and a tutorial starting 21:30 render as two distinct blocks.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeGutter(minMinute, maxMinute, totalHeight),
                for (final day in dayOrder)
                  _buildDayColumn(
                      context, day, events, minMinute, maxMinute, totalHeight, colorMap),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeGutter(int minMinute, int maxMinute, double totalHeight) {
    return SizedBox(
      width: _timeColumnWidth,
      height: totalHeight,
      child: Stack(
        children: [
          for (int m = minMinute; m <= maxMinute; m += 60)
            Positioned(
              top: (m - minMinute) * _pxPerMinute,
              left: 0,
              right: 0,
              child: Container(
                height: 18,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _minutesToTime(m),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    String day,
    List<_GridEvent> events,
    int minMinute,
    int maxMinute,
    double totalHeight,
    Map<String, Color> colorMap,
  ) {
    final dayEvents = events.where((e) => e.session.sessionDay == day).toList();
    final placements = _layoutDay(dayEvents, minMinute);

    return SizedBox(
      width: _dayColumnWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Hour gridlines
          for (int m = minMinute; m <= maxMinute; m += 60)
            Positioned(
              top: (m - minMinute) * _pxPerMinute,
              left: 0,
              right: 0,
              child: Container(
                height: 0,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
                ),
              ),
            ),
          // Session blocks at their true positions
          for (final p in placements)
            Positioned(
              left: p.left,
              top: p.top,
              width: p.width,
              height: p.height,
              child: _buildSessionBlock(context, p.event, colorMap),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionBlock(
      BuildContext context, _GridEvent e, Map<String, Color> colorMap) {
    final color = colorMap[e.course.courseCode] ?? Colors.blue;
    return GestureDetector(
      onTap: () {
        if (onSessionTap != null) {
          onSessionTap!(e.course, e.session, e.sessionType);
        } else {
          _defaultShowDetail(context, e);
        }
      },
      child: Container(
        key: ValueKey('session-block-${e.course.courseCode}-${e.session.sessionCode}'),
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.all(2),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.course.courseCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              e.session.sessionCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.grey[700]),
            ),
            Text(
              '${e.session.sessionStartTime}-${e.session.sessionEndTime}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Lays sessions out so each occupies its real time span. Sessions that
  // overlap in time are placed side by side (shared columns); back-to-back
  // sessions (one ends exactly when or before the next starts) reuse the same
  // column and stack vertically with the true gap preserved.
  List<_BlockPlacement> _layoutDay(List<_GridEvent> dayEvents, int minMinute) {
    final sorted = List<_GridEvent>.from(dayEvents)..sort((a, b) {
      final byStart = _startOf(a).compareTo(_startOf(b));
      if (byStart != 0) return byStart;
      return _endOf(b).compareTo(_endOf(a)); // longer block first on ties
    });

    final columnFreeAt = <int>[]; // column index -> minute it becomes free
    final assigned = <_GridEvent, int>{};
    for (final e in sorted) {
      final start = _startOf(e);
      var col = -1;
      for (int c = 0; c < columnFreeAt.length; c++) {
        if (columnFreeAt[c] <= start) {
          col = c;
          break;
        }
      }
      if (col == -1) {
        col = columnFreeAt.length;
        columnFreeAt.add(0);
      }
      final end = _endOf(e);
      if (end > columnFreeAt[col]) columnFreeAt[col] = end;
      assigned[e] = col;
    }

    final numCols = columnFreeAt.isEmpty ? 1 : columnFreeAt.length;
    final blockWidth = _dayColumnWidth / numCols;

    return [
      for (final e in sorted)
        _BlockPlacement(
          event: e,
          left: assigned[e]! * blockWidth,
          top: (_startOf(e) - minMinute) * _pxPerMinute,
          height: (_endOf(e) - _startOf(e)) * _pxPerMinute,
          width: blockWidth,
        ),
    ];
  }

  int _startOf(_GridEvent e) => _timeToMinutes(e.session.sessionStartTime);
  int _endOf(_GridEvent e) => _timeToMinutes(e.session.sessionEndTime);

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

class _BlockPlacement {
  final _GridEvent event;
  final double left;
  final double top;
  final double width;
  final double height;

  _BlockPlacement({
    required this.event,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}
