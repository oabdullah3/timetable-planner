import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../providers/course_data_provider.dart';
import '../services/parser_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ParserService _parser = ParserService();

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
            if (nameCtrl.text.trim().isNotEmpty) {
              context.read<CourseDataProvider>().addGroup(
                nameCtrl.text.trim(),
                min: int.tryParse(minCtrl.text),
                max: int.tryParse(maxCtrl.text),
              );
              Navigator.pop(ctx);
            }
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
          FilledButton(onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty) {
              context.read<CourseDataProvider>().updateGroup(
                index,
                courseType: nameCtrl.text.trim(),
                min: int.tryParse(minCtrl.text),
                max: int.tryParse(maxCtrl.text),
              );
              Navigator.pop(ctx);
            }
          }, child: const Text('Save')),
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
          FilledButton(onPressed: () {
            if (codeCtrl.text.trim().isNotEmpty) {
              context.read<CourseDataProvider>().addCourse(
                groupIndex,
                Course(courseCode: codeCtrl.text.trim(), courseName: nameCtrl.text.trim(), sessionGroups: []),
              );
              Navigator.pop(ctx);
            }
          }, child: const Text('Add')),
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
              if (codeCtrl.text.trim().isNotEmpty && crnCtrl.text.trim().isNotEmpty) {
                context.read<CourseDataProvider>().addSession(
                  groupIndex, courseIndex, typeCtrl.text.trim().isEmpty ? 'Lecture' : typeCtrl.text.trim(),
                  Session(
                    crn: int.parse(crnCtrl.text.trim()),
                    sessionCode: codeCtrl.text.trim(),
                    sessionDay: selectedDay,
                    sessionStartTime: startCtrl.text.trim(),
                    sessionEndTime: endCtrl.text.trim(),
                    sessionAvailability: int.tryParse(availCtrl.text) ?? 0,
                  ),
                );
                Navigator.pop(ctx);
              }
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
      final bytes = result.files.single.bytes ?? File(result.files.single.path!).readAsBytesSync();
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
