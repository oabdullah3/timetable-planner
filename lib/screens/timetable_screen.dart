import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/timetable_provider.dart';
import '../providers/course_data_provider.dart';
import '../providers/preferences_provider.dart';
import '../widgets/timetable_grid.dart';
import '../widgets/session_detail_sheet.dart';
import '../models.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TextEditingController _countController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const List<Color> _courseColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _generate() {
    final courseProvider = context.read<CourseDataProvider>();
    final prefProvider = context.read<PreferencesProvider>();
    final timetableProvider = context.read<TimetableProvider>();

    timetableProvider.generate(
      courseProvider.courseGroups,
      int.parse(_countController.text.trim()),
      prefProvider.preferences,
    );
  }

  Future<void> _exportToPdf() async {
    final timetableProvider = context.read<TimetableProvider>();
    final current = timetableProvider.current;
    if (current == null) return;

    final pdf = pw.Document();
    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final events = <Map<String, dynamic>>[];
    for (final sc in current.courses) {
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
          'start': _timeToMinutes(s.sessionStartTime),
          'end': _timeToMinutes(s.sessionEndTime),
          'title': '${sc.course.courseCode} - ${s.sessionCode}($sessionType) - ${s.crn}',
          'name': sc.course.courseName,
        });
      }
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      grouped.update(e['day'], (list) => list..add(e), ifAbsent: () => [e]);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text('Timetable', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          for (final day in dayOrder.where(grouped.containsKey))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(day, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                for (final e in (grouped[day]!..sort((a, b) => a['start'].compareTo(b['start']))))
                  pw.Text('${_minutesToTime(e['start'])} - ${_minutesToTime(e['end'])}: ${e['title']} - ${e['name']}'),
                pw.SizedBox(height: 20),
              ],
            ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  int _sumMins(List<CourseGroup> groups) {
    int s = 0;
    for (var g in groups) {
      s += g.min ?? 0;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, ttProvider, _) {
        final groups = context.watch<CourseDataProvider>().courseGroups;

        // If no timetables yet and not generating, show form
        if (ttProvider.timetables.isEmpty && !ttProvider.generating) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Generate Timetable'),
              centerTitle: true,
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.calendar_month, size: 64, color: Colors.indigo),
                        const SizedBox(height: 16),
                        const Text('Generate your timetable', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Choose how many courses you want to take and we\'ll find the best clash-free combinations.', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _countController,
                                decoration: const InputDecoration(
                                  labelText: 'Number of courses',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g. 6',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Enter a number';
                                  final v = int.tryParse(value.trim());
                                  if (v == null || v <= 0) return 'Enter a valid positive number';
                                  final minRequired = _sumMins(groups);
                                  if (v < minRequired) return 'Minimum required is $minRequired';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    if (_formKey.currentState?.validate() ?? false) {
                                      _generate();
                                    }
                                  },
                                  icon: const Icon(Icons.search),
                                  label: const Text('Generate'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Show error
        if (ttProvider.error != null && ttProvider.timetables.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Timetable'),
              centerTitle: true,
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(ttProvider.error!, style: const TextStyle(fontSize: 18, color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
                ],
              ),
            ),
          );
        }

        // Show loading
        if (ttProvider.generating) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Timetable'),
              centerTitle: true,
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Finding the best combinations...'),
              ],
            )),
          );
        }

        // Show timetable grid
        final current = ttProvider.current!;
        final total = ttProvider.timetables.length;
        final currentIdx = ttProvider.currentIndex;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Timetable'),
            centerTitle: true,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _exportToPdf,
                tooltip: 'Export PDF',
              ),
            ],
          ),
          body: Column(
            children: [
              // Page indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: currentIdx > 0 ? () => ttProvider.goToPrevious() : null,
                    ),
                    Text('$currentIdx / ${total - 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: currentIdx < total - 1 ? () => ttProvider.goToNext() : null,
                    ),
                  ],
                ),
              ),
              // Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TimetableGrid(
                    timetable: current,
                    courseColors: _courseColors,
                    onSessionTap: (course, session, sessionType) {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SessionDetailSheet(
                          course: course,
                          session: session,
                          sessionType: sessionType,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
