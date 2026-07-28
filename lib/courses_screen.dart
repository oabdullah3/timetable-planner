// =========================================================
// File: lib/screens/courses_screen.dart
// Updated CoursesScreen with a form to enter number of courses
// and a button that navigates to TimetableScreen.
// =========================================================

import 'package:flutter/material.dart';
import '../registry.dart';
import 'timetable_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final TextEditingController _countController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  int _sumMins() {
    final groups = Registry().courseGroups;
    int s = 0;
    for (var g in groups) {
      s += g.min ?? 0;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final courseGroups = Registry().courseGroups;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Courses"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: courseGroups.length,
              itemBuilder: (context, index) {
                final group = courseGroups[index];
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.school, color: Colors.indigo),
                    title: Text(
                      "${group.courseType} ---- Min: ${group.min ?? 0}, Max: ${group.max ?? group.courses.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    children: group.courses.map((course) {
                      return Card(
                        color: Colors.indigo[50],
                        child: ExpansionTile(
                          leading: const Icon(Icons.book, color: Colors.indigo),
                          title: Text(
                            "${course.courseCode} - ${course.courseName}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          children: course.sessionGroups.map((sg) {
                            return Card(
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ExpansionTile(
                                leading: const Icon(Icons.event_note, color: Colors.deepPurple),
                                title: Text(
                                  sg.sessionType,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                children: sg.sessionOptions.map((session) {
                                  return ListTile(
                                    leading: const Icon(Icons.schedule, color: Colors.teal),
                                    title: Text("CRN: ${session.crn} (${session.sessionCode})"),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${session.sessionDay} | ${session.sessionStartTime} - ${session.sessionEndTime}"),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.people, size: 16, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text("Availability: ${session.sessionAvailability}"),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Divider and form
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _countController,
                      decoration: const InputDecoration(
                        labelText: 'Number of courses to take',
                        border: OutlineInputBorder(),
                        hintText: 'Enter target number (e.g. 6)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter a number';
                        final v = int.tryParse(value.trim());
                        if (v == null || v <= 0) return 'Enter a valid positive number';
                        final minRequired = _sumMins();
                        if (v < minRequired) return 'Minimum required courses across groups is $minRequired';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final n = int.parse(_countController.text.trim());
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TimetableScreen(desiredCourses: n),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    ),
                    child: const Text('Generate'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}