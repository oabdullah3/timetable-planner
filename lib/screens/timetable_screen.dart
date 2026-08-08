import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/course_data_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/pdf_export_service.dart';
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

  // Attached to the grid's RepaintBoundary so the PDF export can capture the
  // whole timetable as an image.
  final GlobalKey _gridCaptureKey = GlobalKey();

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
  void initState() {
    super.initState();
    // Clear previous results so the form is always shown fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().clear();
    });
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _generate() {
    final courseProvider = context.read<CourseDataProvider>();
    final prefProvider = context.read<PreferencesProvider>();
    final timetableProvider = context.read<TimetableProvider>();
    final groups = courseProvider.courseGroups;

    // Pre-flight: check each group's min against available courses
    for (final group in groups) {
      final min = group.min ?? 0;
      if (min > group.courses.length) {
        timetableProvider.setError(
          'Group "${group.courseType}" has min=$min but only ${group.courses.length} course(s). '
          'Add more courses or reduce the minimum.',
        );
        return;
      }
    }

    timetableProvider.generate(
      groups,
      int.parse(_countController.text.trim()),
      prefProvider.preferences,
    );
  }

  Future<void> _exportToPdf() async {
    final timetableProvider = context.read<TimetableProvider>();
    final current = timetableProvider.current;
    if (current == null) return;

    try {
      // Capture the ENTIRE grid (intrinsic size, not the scroll viewport) via
      // the RepaintBoundary that wraps the grid's inner content.
      final boundary =
          _gridCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showExportError('Could not capture the timetable grid.');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showExportError('Could not encode the timetable image.');
        return;
      }

      // The export service requests A3 landscape from the print dialog and
      // box-fits the capture onto whichever paper is finally selected, so the
      // whole timetable always lands on a single page.
      await PdfExportService().exportToPrint(
        timetable: current,
        gridImagePng: byteData.buffer.asUint8List(),
      );
    } catch (e) {
      _showExportError('Export failed: $e');
    }
  }

  void _showExportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int _sumMins(List<CourseGroup> groups) {
    int s = 0;
    for (var g in groups) {
      s += g.min ?? 0;
    }
    return s;
  }

  int _sumMaxes(List<CourseGroup> groups) {
    int s = 0;
    for (var g in groups) {
      s += g.max ?? g.courses.length;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, ttProvider, _) {
        final groups = context.watch<CourseDataProvider>().courseGroups;

        // Show error first (before "empty" check, since both share timetables.isEmpty)
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
                                  final maxRequired = _sumMaxes(groups);
                                  if (v < minRequired) return 'Minimum required is $minRequired';
                                  if (v > maxRequired) return 'Maximum possible is $maxRequired';
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
                    captureKey: _gridCaptureKey,
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
}
