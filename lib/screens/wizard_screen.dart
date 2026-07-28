import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/course_data_provider.dart';
import '../models.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _currentStep = 0;

  // Step 1: Create groups
  final _groupNameCtrl = TextEditingController();
  final _groupMinCtrl = TextEditingController();
  final _groupMaxCtrl = TextEditingController();
  final List<_TempGroup> _tempGroups = [];

  // Step 2: Add courses
  final _courseCodeCtrl = TextEditingController();
  final _courseNameCtrl = TextEditingController();
  int _selectedGroupIndex = 0;
  final Map<int, List<_TempCourse>> _tempCourses = {};

  // Step 3: Add sessions
  final _sessionCodeCtrl = TextEditingController();
  final _sessionCrnCtrl = TextEditingController();
  final _sessionStartCtrl = TextEditingController();
  final _sessionEndCtrl = TextEditingController();
  String _sessionDay = 'Monday';
  String _sessionType = 'Lecture';
  int _sessionGroupIdx = 0;
  int _sessionCourseIdx = 0;

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _groupMinCtrl.dispose();
    _groupMaxCtrl.dispose();
    _courseCodeCtrl.dispose();
    _courseNameCtrl.dispose();
    _sessionCodeCtrl.dispose();
    _sessionCrnCtrl.dispose();
    _sessionStartCtrl.dispose();
    _sessionEndCtrl.dispose();
    super.dispose();
  }

  void _finishWizard() {
    final provider = context.read<CourseDataProvider>();
    final groups = <CourseGroup>[];

    for (final tg in _tempGroups) {
      final courses = (_tempCourses[groups.length] ?? []).map((tc) => Course(
        courseCode: tc.courseCode,
        courseName: tc.courseName,
        sessionGroups: [
          SessionGroup(
            sessionType: tc.sessionType,
            sessionOptions: tc.sessions.map((ts) => Session(
              crn: ts.crn,
              sessionCode: ts.code,
              sessionDay: ts.day,
              sessionStartTime: ts.start,
              sessionEndTime: ts.end,
              sessionAvailability: 0,
            )).toList(),
          ),
        ],
      )).toList();

      groups.add(CourseGroup(
        courseType: tg.name,
        courses: courses,
        min: tg.min,
        max: tg.max,
      ));
    }

    provider.setCourseGroups(groups);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Wizard (Step ${_currentStep + 1}/4)'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 3) {
            setState(() => _currentStep++);
          } else {
            _finishWizard();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 3 ? 'Finish' : 'Continue'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Course Groups'),
            subtitle: const Text('Create groups like "Core" or "Elective" with min/max rules'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildGroupStep(),
          ),
          Step(
            title: const Text('Add Courses'),
            subtitle: const Text('Add courses to each group'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : (_tempGroups.isEmpty ? StepState.disabled : StepState.indexed),
            content: _tempGroups.isEmpty ? const Text('Please add at least one group first.') : _buildCourseStep(),
          ),
          Step(
            title: const Text('Add Sessions'),
            subtitle: const Text('Add lecture/tutorial timeslots'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : (_hasCourses() ? StepState.indexed : StepState.disabled),
            content: !_hasCourses() ? const Text('Please add at least one course first.') : _buildSessionStep(),
          ),
          Step(
            title: const Text('Review & Finish'),
            subtitle: const Text('Review your data and generate'),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  bool _hasCourses() {
    return _tempCourses.values.any((list) => list.isNotEmpty);
  }

  Widget _buildGroupStep() {
    return Column(
      children: [
        if (_tempGroups.isNotEmpty)
          ..._tempGroups.asMap().entries.map((e) => ListTile(
            title: Text(e.value.name),
            subtitle: Text('Min: ${e.value.min ?? 0}, Max: ${e.value.max ?? '-'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => setState(() => _tempGroups.removeAt(e.key)),
            ),
          )),
        Row(
          children: [
            Expanded(child: TextField(controller: _groupNameCtrl, decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. Core'))),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: TextField(controller: _groupMinCtrl, decoration: const InputDecoration(labelText: 'Min'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: TextField(controller: _groupMaxCtrl, decoration: const InputDecoration(labelText: 'Max'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.indigo),
              onPressed: () {
                if (_groupNameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _tempGroups.add(_TempGroup(
                      name: _groupNameCtrl.text.trim(),
                      min: int.tryParse(_groupMinCtrl.text),
                      max: int.tryParse(_groupMaxCtrl.text),
                    ));
                    _groupNameCtrl.clear();
                    _groupMinCtrl.clear();
                    _groupMaxCtrl.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCourseStep() {
    // Rebuild selected group dropdown
    final selGroup = _selectedGroupIndex < _tempGroups.length ? _tempGroups[_selectedGroupIndex] : null;

    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue:_selectedGroupIndex < _tempGroups.length ? _selectedGroupIndex : 0,
          items: _tempGroups.asMap().entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value.name),
          )).toList(),
          onChanged: (v) => setState(() => _selectedGroupIndex = v!),
          decoration: const InputDecoration(labelText: 'Group'),
        ),
        if (selGroup != null) ...[
          if ((_tempCourses[_selectedGroupIndex] ?? []).isNotEmpty)
            ...(_tempCourses[_selectedGroupIndex] ?? []).asMap().entries.map((e) => ListTile(
              title: Text(e.value.courseCode),
              subtitle: Text(e.value.courseName),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _tempCourses[_selectedGroupIndex]!.removeAt(e.key)),
              ),
            )),
          Row(
            children: [
              Expanded(child: TextField(controller: _courseCodeCtrl, decoration: const InputDecoration(labelText: 'Course Code', hintText: 'e.g. CS101'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _courseNameCtrl, decoration: const InputDecoration(labelText: 'Course Name'))),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.indigo),
                onPressed: () {
                  if (_courseCodeCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _tempCourses.putIfAbsent(_selectedGroupIndex, () => []);
                      _tempCourses[_selectedGroupIndex]!.add(_TempCourse(
                        courseCode: _courseCodeCtrl.text.trim(),
                        courseName: _courseNameCtrl.text.trim(),
                      ));
                      _courseCodeCtrl.clear();
                      _courseNameCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSessionStep() {
    // Group picker
    final validGroups = <int>[];
    for (final entry in _tempCourses.entries) {
      if (entry.value.isNotEmpty) validGroups.add(entry.key);
    }
    if (validGroups.isEmpty) return const Text('No courses available. Add courses first.');

    if (!validGroups.contains(_sessionGroupIdx)) _sessionGroupIdx = validGroups.first;
    final groupCourses = _tempCourses[_sessionGroupIdx] ?? [];
    if (_sessionCourseIdx >= groupCourses.length) _sessionCourseIdx = 0;
    final course = groupCourses.isNotEmpty ? groupCourses[_sessionCourseIdx] : null;

    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue:_sessionGroupIdx,
          items: validGroups.map((g) => DropdownMenuItem(
            value: g, child: Text(_tempGroups[g].name),
          )).toList(),
          onChanged: (v) => setState(() => _sessionGroupIdx = v!),
          decoration: const InputDecoration(labelText: 'Group'),
        ),
        if (groupCourses.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            initialValue: _sessionCourseIdx < groupCourses.length ? _sessionCourseIdx : 0,
            items: groupCourses.asMap().entries.map((e) => DropdownMenuItem(
              value: e.key, child: Text(e.value.courseCode),
            )).toList(),
            onChanged: (v) => setState(() => _sessionCourseIdx = v!),
            decoration: const InputDecoration(labelText: 'Course'),
          ),
          if (course != null && course.sessions.isNotEmpty)
            ...course.sessions.asMap().entries.map((e) => ListTile(
              title: Text('${e.value.code} (CRN: ${e.value.crn})'),
              subtitle: Text('${e.value.day} | ${e.value.start} - ${e.value.end}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => course.sessions.removeAt(e.key)),
              ),
            )),
          Row(
            children: [
              SizedBox(width: 80, child: TextField(controller: _sessionCodeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'L01'))),
              const SizedBox(width: 8),
              SizedBox(width: 70, child: TextField(controller: _sessionCrnCtrl, decoration: const InputDecoration(labelText: 'CRN'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              DropdownButtonFormField<String>(
                initialValue: _sessionDay,
                items: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.substring(0, 3))))
                    .toList(),
                onChanged: (v) => setState(() => _sessionDay = v!),
                decoration: const InputDecoration(labelText: 'Day'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 80, child: TextField(controller: _sessionStartCtrl, decoration: const InputDecoration(labelText: 'Start', hintText: '10:00'))),
              const SizedBox(width: 8),
              SizedBox(width: 80, child: TextField(controller: _sessionEndCtrl, decoration: const InputDecoration(labelText: 'End', hintText: '11:30'))),
              const SizedBox(width: 8),
              DropdownButtonFormField<String>(
                initialValue: _sessionType,
                items: ['Lecture', 'Tutorial', 'Lab']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _sessionType = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.indigo),
                onPressed: () {
                  if (_sessionCodeCtrl.text.trim().isNotEmpty && _sessionCrnCtrl.text.trim().isNotEmpty && _sessionStartCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      course!.sessions.add(_TempSession(
                        code: _sessionCodeCtrl.text.trim(),
                        crn: int.parse(_sessionCrnCtrl.text.trim()),
                        day: _sessionDay,
                        start: _sessionStartCtrl.text.trim(),
                        end: _sessionEndCtrl.text.trim(),
                        type: _sessionType,
                      ));
                      _sessionCodeCtrl.clear();
                      _sessionCrnCtrl.clear();
                      _sessionStartCtrl.clear();
                      _sessionEndCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review your data:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        for (final tg in _tempGroups) ...[
          Text('${tg.name} (Min: ${tg.min ?? 0}, Max: ${tg.max ?? '-'})', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final tc in (_tempCourses[_tempGroups.indexOf(tg)] ?? []))
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('  • ${tc.courseCode} - ${tc.courseName} (${tc.sessions.length} sessions)'),
            ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        const Text('When you finish, your data will be saved and you can start generating timetables.', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _TempGroup {
  String name;
  int? min, max;
  _TempGroup({required this.name, this.min, this.max});
}

class _TempCourse {
  String courseCode;
  String courseName;
  String sessionType = 'Lecture';
  List<_TempSession> sessions = [];
  _TempCourse({required this.courseCode, required this.courseName});
}

class _TempSession {
  String code;
  int crn;
  String day, start, end, type;
  _TempSession({required this.code, required this.crn, required this.day, required this.start, required this.end, required this.type});
}
