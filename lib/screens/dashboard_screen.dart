import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../providers/course_data_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/parser_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ParserService _parser = ParserService();

  // ---- Validation helpers ----
  bool _isValidTime(String time) {
    final m = RegExp(r'^\d{2}:\d{2}$').firstMatch(time);
    if (m == null) return false;
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? -1;
    final min = int.tryParse(parts[1]) ?? -1;
    return h >= 0 && h <= 23 && min >= 0 && min <= 59;
  }

  void _showAddGroupDialog() {
    final nameCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Course Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group Name (e.g. Core)')),
            TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min courses (optional)'), keyboardType: TextInputType.number),
            TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max courses (optional)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final name = nameCtrl.text.trim();
            final minVal = int.tryParse(minCtrl.text);
            final maxVal = int.tryParse(maxCtrl.text);
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group name is required'), backgroundColor: Colors.red));
              return;
            }
            if (minVal != null && maxVal != null && minVal > maxVal) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Min cannot be greater than Max'), backgroundColor: Colors.red));
              return;
            }
            context.read<CourseDataProvider>().addGroup(name, min: minVal, max: maxVal);
            Navigator.pop(ctx);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showEditGroupDialog(int index, CourseGroup group) {
    final nameCtrl = TextEditingController(text: group.courseType);
    final minCtrl = TextEditingController(text: group.min?.toString() ?? '');
    final maxCtrl = TextEditingController(text: group.max?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Course Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group Name')),
            TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min courses'), keyboardType: TextInputType.number),
            TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max courses'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final minVal = int.tryParse(minCtrl.text);
              final maxVal = int.tryParse(maxCtrl.text);
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group name is required'), backgroundColor: Colors.red));
                return;
              }
              if (minVal != null && maxVal != null && minVal > maxVal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Min cannot be greater than Max'), backgroundColor: Colors.red));
                return;
              }
              context.read<CourseDataProvider>().updateGroup(index,
                courseType: name, min: minVal, max: maxVal);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(int groupIndex) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Course Code (e.g. CS101)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Course Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course code is required'), backgroundColor: Colors.red));
                return;
              }
              if (code.length > 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course code too long (max 10 chars)'), backgroundColor: Colors.red));
                return;
              }
              context.read<CourseDataProvider>().addCourse(
                groupIndex,
                Course(courseCode: code, courseName: nameCtrl.text.trim(), sessionGroups: []),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSessionDialog(int groupIndex, int courseIndex) {
    final typeCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final crnCtrl = TextEditingController();
    String selectedDay = 'Monday';
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final availCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Session Type (e.g. Lecture)')),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Session Code (e.g. L01)')),
                TextField(controller: crnCtrl, decoration: const InputDecoration(labelText: 'CRN'), keyboardType: TextInputType.number),
                DropdownButtonFormField(
                  // ignore: deprecated_member_use
                  value: selectedDay,
                  items: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedDay = v!),
                  decoration: const InputDecoration(labelText: 'Day'),
                ),
                TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (HH:MM)')),
                TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Time (HH:MM)')),
                TextField(controller: availCtrl, decoration: const InputDecoration(labelText: 'Availability (optional)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              // Validate
              final type = typeCtrl.text.trim();
              final code = codeCtrl.text.trim();
              final crnText = crnCtrl.text.trim();
              final start = startCtrl.text.trim();
              final end = endCtrl.text.trim();
              final avail = availCtrl.text.trim();

              if (type.length > 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session type too long (max 20 chars)'), backgroundColor: Colors.red));
                return;
              }
              if (code.isEmpty || code.length > 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session code must be 1-6 characters'), backgroundColor: Colors.red));
                return;
              }
              if (crnText.isEmpty || crnText.length > 10 || int.tryParse(crnText) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CRN must be a number (max 10 digits)'), backgroundColor: Colors.red));
                return;
              }
              if (!_isValidTime(start)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Start time must be HH:MM (e.g. 10:00)'), backgroundColor: Colors.red));
                return;
              }
              if (!_isValidTime(end)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('End time must be HH:MM (e.g. 11:30)'), backgroundColor: Colors.red));
                return;
              }
              if (avail.isNotEmpty && (int.tryParse(avail) == null || int.parse(avail) < 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Availability must be a non-negative number'), backgroundColor: Colors.red));
                return;
              }

              context.read<CourseDataProvider>().addSession(
                groupIndex, courseIndex, type.isEmpty ? 'Lecture' : type,
                Session(
                  crn: int.parse(crnText),
                  sessionCode: code,
                  sessionDay: selectedDay,
                  sessionStartTime: start,
                  sessionEndTime: end,
                  sessionAvailability: int.tryParse(avail) ?? 0,
                ),
              );
              Navigator.pop(ctx);
            }, child: const Text('Add')),
          ],
        ),
      ),
    );
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) return;

    try {
      final bytes = result.files.single.bytes!;
      final groups = _parser.parseExcelBytes(bytes);
      if (mounted) {
        context.read<CourseDataProvider>().setCourseGroups(groups);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTimePreferences() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<PreferencesProvider>(
        builder: (context, prefs, _) {
          final p = prefs.preferences;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Time Preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('These preferences affect how timetables are scored and sorted.',
                      style: TextStyle(color: Colors.grey[600])),
                  const Divider(height: 24),

                  // Earliest start time
                  const Text('Earliest Start Time', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_minutesToTime(p.earliestStartMinute), style: const TextStyle(color: Colors.indigo)),
                  RangeSlider(
                    values: RangeValues(
                      p.earliestStartMinute.toDouble(),
                      p.latestEndMinute.toDouble(),
                    ),
                    min: 420,  // 7:00 AM
                    max: 1320,  // 10:00 PM
                    divisions: 30,
                    labels: RangeLabels(
                      _minutesToTime(p.earliestStartMinute),
                      _minutesToTime(p.latestEndMinute),
                    ),
                    onChanged: (values) {
                      prefs.setEarliestStart(values.start.round());
                      prefs.setLatestEnd(values.end.round());
                    },
                  ),
                  const SizedBox(height: 8),

                  // Preferred days
                  const Text('Preferred Days', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map((day) {
                      final selected = p.preferredDays.contains(day);
                      return FilterChip(
                        label: Text(day.substring(0, 3)),
                        selected: selected,
                        onSelected: (_) => prefs.toggleDay(day),
                        selectedColor: Colors.indigo[100],
                        checkmarkColor: Colors.indigo,
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),

                  // Gap preference
                  SwitchListTile(
                    title: const Text('Prefer back-to-back classes'),
                    subtitle: Text(
                      p.preferBackToBack
                          ? 'Minimize gaps between classes'
                          : 'Prefer gaps between classes',
                    ),
                    value: p.preferBackToBack,
                    onChanged: (v) => prefs.setGapPreference(v),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseDataProvider>(
      builder: (context, provider, _) {
        final groups = provider.courseGroups;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Course Planner'),
            centerTitle: true,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showTimePreferences,
                tooltip: 'Time Preferences',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'wizard') context.push('/wizard');
                  if (value == 'import') _importExcel();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'wizard', child: ListTile(leading: Icon(Icons.assistant), title: Text('Run Wizard'))),
                  const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Import Excel'))),
                ],
              ),
            ],
          ),
          body: groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No courses yet', style: TextStyle(fontSize: 20, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Add a group to get started', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddGroupDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Course Group'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => context.push('/wizard'),
                        icon: const Icon(Icons.assistant, size: 18),
                        label: const Text('Run the guided wizard'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _importExcel,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Import from Excel'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: groups.length + 1, // +1 for add button
                        itemBuilder: (context, index) {
                          if (index == groups.length) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: OutlinedButton.icon(
                                onPressed: _showAddGroupDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Course Group'),
                              ),
                            );
                          }
                          final group = groups[index];
                          return Card(
                            child: ExpansionTile(
                              key: PageStorageKey('group_$index'),
                              leading: const Icon(Icons.folder, color: Colors.indigo),
                              title: Text(group.courseType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Text('Min: ${group.min ?? 0}, Max: ${group.max ?? group.courses.length} · ${group.courses.length} courses'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showEditGroupDialog(index, group),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Group?'),
                                          content: Text('Delete "${group.courseType}" and all its courses?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            TextButton(onPressed: () {
                                              provider.deleteGroup(index);
                                              Navigator.pop(ctx);
                                            }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              children: [
                                ...group.courses.asMap().entries.map((entry) {
                                  final cIdx = entry.key;
                                  final course = entry.value;
                                  return Card(
                                    color: Colors.indigo[50],
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: ExpansionTile(
                                      leading: Icon(course.locked ? Icons.lock : Icons.book, color: Colors.indigo),
                                      title: Text('${course.courseCode} - ${course.courseName}'),
                                      subtitle: Row(
                                        children: [
                                          _PreferenceStars(
                                            score: course.preferenceScore,
                                            onChanged: (s) => provider.setCoursePreference(index, cIdx, s),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: Icon(
                                              course.locked ? Icons.lock : Icons.lock_open,
                                              size: 18, color: course.locked ? Colors.orange : Colors.grey,
                                            ),
                                            onPressed: () => provider.toggleCourseLock(index, cIdx),
                                            tooltip: course.locked ? 'Locked (always included)' : 'Not locked',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () {
                                              provider.deleteCourse(index, cIdx);
                                            },
                                          ),
                                        ],
                                      ),
                                      children: [
                                        ...course.sessionGroups.asMap().entries.map((sgEntry) {
                                          final sgIdx = sgEntry.key;
                                          final sg = sgEntry.value;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(sg.sessionType, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple)),
                                                ),
                                                ...sg.sessionOptions.asMap().entries.map((sEntry) {
                                                  final sIdx = sEntry.key;
                                                  final session = sEntry.value;
                                                  return ListTile(
                                                    dense: true,
                                                    leading: Icon(
                                                      session.locked ? Icons.lock : Icons.schedule,
                                                      size: 18, color: session.locked ? Colors.orange : Colors.teal,
                                                    ),
                                                    title: Text('CRN: ${session.crn} (${session.sessionCode})'),
                                                    subtitle: Text('${session.sessionDay} | ${session.sessionStartTime} - ${session.sessionEndTime}'),
                                                    trailing: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            session.locked ? Icons.lock : Icons.lock_open,
                                                            size: 16, color: session.locked ? Colors.orange : Colors.grey,
                                                          ),
                                                          onPressed: () => provider.toggleSessionLock(index, cIdx, sgIdx, sIdx),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                                          onPressed: () => provider.deleteSession(index, cIdx, sgIdx, sIdx),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                                                  child: TextButton.icon(
                                                    icon: const Icon(Icons.add, size: 16),
                                                    label: const Text('Add Session'),
                                                    onPressed: () => _showAddSessionDialog(index, cIdx),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: TextButton.icon(
                                            icon: const Icon(Icons.add, size: 16),
                                            label: Text('Add ${course.sessionGroups.isEmpty ? "Lecture" : "Session Group"}'),
                                            onPressed: () => _showAddSessionDialog(index, cIdx),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Course'),
                                    onPressed: () => _showAddCourseDialog(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () {
                            final totalMin = groups.fold<int>(0, (s, g) => s + (g.min ?? 0));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Total min courses: $totalMin. Navigate to generate.')),
                            );
                            context.push('/timetable');
                          },
                          icon: const Icon(Icons.calendar_month, size: 24),
                          label: const Text('Generate Timetables'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            textStyle: const TextStyle(fontSize: 18),
                          ),
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

class _PreferenceStars extends StatelessWidget {
  final int score;
  final ValueChanged<int> onChanged;

  const _PreferenceStars({required this.score, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (i) {
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i == 0 ? Icons.cancel_outlined : (i <= score ? Icons.star : Icons.star_border),
              size: 20,
              color: i == 0 ? Colors.grey[400] : (i <= score ? Colors.amber : Colors.grey[400]),
            ),
          ),
        );
      }),
    );
  }
}
