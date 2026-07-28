// =========================================================
// File: lib/screens/timetable_screen.dart
// Screen for generating and displaying an optimal timetable based on desired courses.
// =========================================================

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../registry.dart';
import 'models.dart';

class TimetableScreen extends StatefulWidget {
  final int desiredCourses;

  const TimetableScreen({super.key, required this.desiredCourses});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<List<SelectedCourse>> timetables = [];
  int currentIndex = 0;
  String message = '';

  @override
  void initState() {
    super.initState();
    generateTimetable();
  }

  void generateTimetable() {
    final groups = Registry().courseGroups;

    final sumMin = groups.fold<int>(0, (sum, g) => sum + (g.min ?? 0));
    final sumMax = groups.fold<int>(0, (sum, g) => sum + (g.max ?? g.courses.length));

    if (widget.desiredCourses < sumMin || widget.desiredCourses > sumMax) {
      setState(() {
        message = 'No timetable possible for ${widget.desiredCourses} courses. Minimum: $sumMin, Maximum: $sumMax';
      });
      return;
    }

    final courseConfigs = <Course, List<List<Session>>>{};
    for (var group in groups) {
      for (var course in group.courses) {
        courseConfigs[course] = generateConfigs(course);
      }
    }

    final allTimetables = <List<SelectedCourse>>[];
    final tt = <SelectedCourse>[];
    final sel = <CourseGroup, Set<Course>>{for (var g in groups) g: <Course>{}};

    buildMinimums(groups, 0, tt, sel, courseConfigs, allTimetables);

    setState(() {
      timetables = allTimetables;
      if (timetables.isEmpty) {
        message = 'No timetable possible for ${widget.desiredCourses} courses.';
      }
    });
  }

  void buildMinimums(
    List<CourseGroup> groups,
    int groupIndex,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    List<List<SelectedCourse>> allTimetables,
  ) {
    if (groupIndex == groups.length) {
      final remaining = widget.desiredCourses - currentTT.length;
      buildExtras(groups, 0, remaining, currentTT, selected, configs, allTimetables);
      return;
    }
    final group = groups[groupIndex];
    final minReq = group.min ?? 0;
    buildNCoursesForGroup(
      group,
      minReq,
      currentTT,
      selected,
      configs,
      () => buildMinimums(groups, groupIndex + 1, currentTT, selected, configs, allTimetables),
    );
  }

  void buildExtras(
    List<CourseGroup> groups,
    int groupIndex,
    int remaining,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    List<List<SelectedCourse>> allTimetables,
  ) {
    if (groupIndex == groups.length) {
      if (remaining == 0) {
        allTimetables.add(List.from(currentTT));
      }
      return;
    }
    final group = groups[groupIndex];
    final curr = selected[group]!.length;
    final maxP = group.max ?? group.courses.length;
    final maxExtra = maxP - curr;
    for (int extra = 0; extra <= maxExtra && extra <= remaining; extra++) {
      buildNCoursesForGroup(
        group,
        extra,
        currentTT,
        selected,
        configs,
        () => buildExtras(groups, groupIndex + 1, remaining - extra, currentTT, selected, configs, allTimetables),
      );
    }
  }

  void buildNCoursesForGroup(
    CourseGroup group,
    int toAdd,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    void Function() recurseNext,
  ) {
    final available = group.courses.where((c) => !selected[group]!.contains(c)).toList()
      ..sort((a, b) => a.courseCode.compareTo(b.courseCode));

    void choose(int start, int rem) {
      if (rem == 0) {
        recurseNext();
        return;
      }
      for (int i = start; i < available.length; i++) {
        final course = available[i];
        for (final config in configs[course]!) {
          if (!hasClashWithTT(currentTT, config)) {
            currentTT.add(SelectedCourse(course: course, sessions: config));
            selected[group]!.add(course);
            choose(i + 1, rem - 1);
            currentTT.removeLast();
            selected[group]!.remove(course);
          }
        }
      }
    }

    choose(0, toAdd);
  }

  List<List<Session>> generateConfigs(Course course) {
    final configs = <List<Session>>[];
    void buildConfig(List<Session> current, int groupIndex) {
      if (groupIndex == course.sessionGroups.length) {
        if (!hasInternalClash(current) && isSessionCodesConsistent(current)) {
          configs.add(List.from(current));
        }
        return;
      }
      final sg = course.sessionGroups[groupIndex];
      for (final session in sg.sessionOptions) {
        current.add(session);
        buildConfig(current, groupIndex + 1);
        current.removeLast();
      }
    }
    buildConfig([], 0);
    return configs;
  }

  bool isSessionCodesConsistent(List<Session> sessions) {
    if (sessions.isEmpty) return true;
    final secondChars = sessions.map((s) => s.sessionCode.length > 1 ? s.sessionCode[1] : '').where((c) => c.isNotEmpty).toList();
    if (secondChars.isEmpty) return true;

    bool isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
    bool isLetter(String c) => (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) || (c.compareTo('a') >= 0 && c.compareTo('z') <= 0);

    final allDigits = secondChars.every(isDigit);
    if (allDigits) return true;

    final allLetters = secondChars.every(isLetter);
    if (allLetters) {
      final first = secondChars.first.toUpperCase();
      return secondChars.every((c) => c.toUpperCase() == first);
    }

    return false;
  }

  bool hasInternalClash(List<Session> sessions) {
    for (var i = 0; i < sessions.length; i++) {
      for (var j = i + 1; j < sessions.length; j++) {
        if (sessionsClash(sessions[i], sessions[j])) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasClashWithTT(List<SelectedCourse> tt, List<Session> config) {
    for (final sc in tt) {
      for (final es in sc.sessions) {
        for (final ns in config) {
          if (sessionsClash(es, ns)) return true;
        }
      }
    }
    return false;
  }

  bool sessionsClash(Session a, Session b) {
    if (a.sessionDay != b.sessionDay) return false;
    final startA = timeToMinutes(a.sessionStartTime);
    final endA = timeToMinutes(a.sessionEndTime);
    final startB = timeToMinutes(b.sessionStartTime);
    final endB = timeToMinutes(b.sessionEndTime);
    return startA < endB && startB < endA;
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> exportToPdf() async {
    if (timetables.isEmpty) return;
    final current = timetables[currentIndex];

    final pdf = pw.Document();
    final events = <Map<String, dynamic>>[];
    for (final sc in current) {
      for (final s in sc.sessions) {
        String sessionType = '';
        for (final sg in sc.course.sessionGroups) {
          if (sg.sessionOptions.contains(s)) {
            sessionType = sg.sessionType;
            break;
          }
        }
        events.add({
          'day': s.sessionDay,
          'start': timeToMinutes(s.sessionStartTime),
          'end': timeToMinutes(s.sessionEndTime),
          'title': '${sc.course.courseCode} - ${s.sessionCode}($sessionType) - ${s.crn}',
          'name': sc.course.courseName,
        });
      }
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      grouped.update(e['day'], (list) => list..add(e), ifAbsent: () => [e]);
    }

    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text('Timetable for ${widget.desiredCourses} Courses', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          for (final day in dayOrder.where(grouped.containsKey))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(day, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                for (final e in (grouped[day]!..sort((a, b) => a['start'].compareTo(b['start']))))
                  pw.Text('${minutesToTime(e['start'])} - ${minutesToTime(e['end'])}: ${e['title']} - ${e['name']}'),
                pw.SizedBox(height: 20),
              ],
            ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (message.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timetable')),
        body: Center(child: Text(message, style: const TextStyle(fontSize: 18, color: Colors.red))),
      );
    }

    final current = timetables[currentIndex];

    final events = <Map<String, dynamic>>[];
    for (final sc in current) {
      for (final s in sc.sessions) {
        String sessionType = '';
        for (final sg in sc.course.sessionGroups) {
          if (sg.sessionOptions.contains(s)) {
            sessionType = sg.sessionType;
            break;
          }
        }
        events.add({
          'day': s.sessionDay,
          'start': timeToMinutes(s.sessionStartTime),
          'end': timeToMinutes(s.sessionEndTime),
          'title': '${sc.course.courseCode} - ${s.sessionCode}($sessionType) - ${s.crn}',
          'name': sc.course.courseName,
        });
      }
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      grouped.update(e['day'], (list) => list..add(e), ifAbsent: () => [e]);
    }

    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
            onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
            icon: const Icon(Icons.arrow_left),
          ),
          Text(' ${currentIndex + 1} / ${timetables.length} '),
          IconButton(
            onPressed: currentIndex < timetables.length - 1 ? () => setState(() => currentIndex++) : null,
            icon: const Icon(Icons.arrow_right),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Timetable for ${widget.desiredCourses} Courses', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          for (final day in dayOrder.where(grouped.containsKey))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                for (final e in (grouped[day]!..sort((a, b) => a['start'].compareTo(b['start']))))
                  Card(
                    child: ListTile(
                      title: Text(e['title']),
                      subtitle: Text('${minutesToTime(e['start'])} - ${minutesToTime(e['end'])}\n${e['name']}'),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: exportToPdf,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}

class SelectedCourse {
  final Course course;
  final List<Session> sessions;

  SelectedCourse({required this.course, required this.sessions});
}