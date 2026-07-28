// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';

// // ============================
// // University Course Planner — Flutter Web (main.dart)
// // NOW WITH:
// // - Course Groups (priority, min, max). Courses belong to a group.
// // - Optimizer respects hard group min–max and picks a largest clash-free set
// //   (<= desired N). Among feasible candidates: maximize sum of group priorities,
// //   then break ties by sum of course priorities.
// // - Persistence via SharedPreferences (courses + groups are restored on restart).
// // - Export current optimized timetable to PDF.
// // ============================

// // ======== Models ========

// enum Weekday { mon, tue, wed, thu, fri, sat, sun }

// String weekdayLabel(Weekday d) =>
//     ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.index];

// class Session {
//   final Weekday day;
//   final int startMinutes; // minutes from 00:00
//   final int endMinutes;   // minutes from 00:00
//   final String type; // Lecture / Tutorial / Lab / Other

//   Session({
//     required this.day,
//     required this.startMinutes,
//     required this.endMinutes,
//     required this.type,
//   });

//   bool clashes(Session other) {
//     if (day != other.day) return false;
//     return startMinutes < other.endMinutes && endMinutes > other.startMinutes;
//   }

//   String get timeLabel => '${_fmtTime(startMinutes)} - ${_fmtTime(endMinutes)}';

//   Map<String, dynamic> toJson() => {
//     'day': day.index,
//     'start': startMinutes,
//     'end': endMinutes,
//     'type': type,
//   };

//   static Session fromJson(Map<String, dynamic> j) => Session(
//     day: Weekday.values[j['day'] as int],
//     startMinutes: j['start'] as int,
//     endMinutes: j['end'] as int,
//     type: j['type'] as String,
//   );
// }

// class SessionGroup { // choose exactly one option if options is not empty
//   final String label; // e.g., Tutorial A/B/C
//   final List<Session> options;
//   SessionGroup({required this.label, required this.options});

//   Map<String, dynamic> toJson() => {
//     'label': label,
//     'options': options.map((e) => e.toJson()).toList(),
//   };

//   static SessionGroup fromJson(Map<String, dynamic> j) => SessionGroup(
//     label: j['label'] as String,
//     options: (j['options'] as List).cast<Map<String, dynamic>>()
//         .map(Session.fromJson).toList(),
//   );
// }

// class CourseGroupDef {
//   final String id; // stable id
//   final String label;
//   final int priority; // higher is better in tie-break
//   final int minCourses; // hard constraint
//   final int maxCourses; // hard constraint

//   const CourseGroupDef({
//     required this.id,
//     required this.label,
//     required this.priority,
//     required this.minCourses,
//     required this.maxCourses,
//   });

//   CourseGroupDef copyWith({String? label, int? priority, int? minCourses, int? maxCourses}) => CourseGroupDef(
//     id: id,
//     label: label ?? this.label,
//     priority: priority ?? this.priority,
//     minCourses: minCourses ?? this.minCourses,
//     maxCourses: maxCourses ?? this.maxCourses,
//   );

//   Map<String, dynamic> toJson() => {
//     'id': id,
//     'label': label,
//     'priority': priority,
//     'min': minCourses,
//     'max': maxCourses,
//   };

//   static CourseGroupDef fromJson(Map<String, dynamic> j) => CourseGroupDef(
//     id: j['id'] as String,
//     label: j['label'] as String,
//     priority: j['priority'] as int,
//     minCourses: j['min'] as int,
//     maxCourses: j['max'] as int,
//   );
// }

// class Course {
//   final String code;
//   final String name;
//   final int priority; // higher means more desirable
//   // final List<Session> requiredSessions; // all must be taken
//   final List<SessionGroup> sessionGroups; // choose exactly one per group (if any)
//   final String? groupId; // nullable -> ungrouped

//   Course({
//     required this.code,
//     required this.name,
//     required this.priority,
//     // required this.requiredSessions,
//     required this.sessionGroups,
//     required this.groupId,
//   });

//   String get displayName => '$code — $name (p=$priority)';

//   Map<String, dynamic> toJson() => {
//     'code': code,
//     'name': name,
//     'priority': priority,
//     'sessionGroups': sessionGroups.map((e) => e.toJson()).toList(),
//     'groupId': groupId,
//   };

//   static Course fromJson(Map<String, dynamic> j) => Course(
//     code: j['code'] as String,
//     name: j['name'] as String,
//     priority: j['priority'] as int,
//     // requiredSessions: (j['required'] as List).cast<Map<String, dynamic>>()
//     //     .map(Session.fromJson).toList(),
//     sessionGroups: (j['sessionGroups'] as List?)
//         ?.cast<Map<String, dynamic>>()
//         .map(SessionGroup.fromJson)
//         .toList() ?? [],
//     groupId: j['groupId'] as String?,
//   );
// }

// class CourseChoice { // concrete chosen set for a course (required + one per tutorial group)
//   final Course course;
//   final List<Session> sessions;
//   CourseChoice(this.course, this.sessions);
// }

// class Scheduled { // for rendering blocks (avoid Dart 3 records dependency)
//   final Course course;
//   final Session session;
//   Scheduled(this.course, this.session);
// }

// // ======== Optimizer ========

// class OptimizeResult {
//   final List<CourseChoice> choices;
//   final int groupPrioritySum; // objective 1
//   final int coursePrioritySum; // objective 2
//   OptimizeResult(this.choices, this.groupPrioritySum, this.coursePrioritySum);
// }

// class GroupAwareOptimizer {
//   final List<Course> courses;
//   final List<CourseGroupDef> groups; // constraints and group objective
//   final int desiredCount; // target, not hard. We aim to maximize #courses first.

//   GroupAwareOptimizer({
//     required this.courses,
//     required this.groups,
//     required this.desiredCount,
//   });

//   OptimizeResult solve() {
//     // Precompute feasible combinations per course (due to tutorial options)
//     final Map<Course, List<CourseChoice>> combos = {};
//     for (final c in courses) {
//       combos[c] = _enumerateCourseCombos(c);
//     }

//     // For pruning we sort courses by priority desc (heuristic)
//     final sorted = [...courses]..sort((a, b) => b.priority.compareTo(a.priority));

//     // Map groupId -> def (plus synthetic for ungrouped)
//     final Map<String, CourseGroupDef> groupById = {
//       for (final g in groups) g.id: g,
//     };
//     const String ungroupedId = '__UNGROUPED__';
//     groupById.putIfAbsent(ungroupedId, () => const CourseGroupDef(
//       id: ungroupedId, label: 'Ungrouped', priority: 0, minCourses: 0, maxCourses: 9999,
//     ));

//     // Helper to get the course's group id (fallback to ungrouped)
//     String gidOf(Course c) => c.groupId ?? ungroupedId;

//     // Best according to: 1) max picked length, 2) max groupPrioritySum, 3) max coursePrioritySum
//     OptimizeResult best = OptimizeResult([], -1, -1);

//     // Track counts per group during DFS
//     final Map<String, int> pickCount = { for (final id in groupById.keys) id: 0 };

//     void dfs(int idx, List<CourseChoice> picked, List<Session> scheduled, int coursePrioSum, int pickedCount) {
//       // Prune if exceeding desiredCount hard? No — we allow <= desiredCount. But we can prune if pickedCount > desiredCount.
//       if (pickedCount > desiredCount) return;

//       // If end reached, check group constraints hard (min/max) and update best
//       if (idx == sorted.length) {
//         if (!_satisfiesAllMin(groupById, pickCount)) return;
//         // compute group priority sum counting only groups with >=1 selected course
//         final int gp = groups.fold(0, (sum, g) => sum + ((pickCount[g.id] ?? 0) > 0 ? g.priority : 0));
//         final candidate = OptimizeResult(List.of(picked), gp, coursePrioSum);
//         if (_isBetter(candidate, best)) best = candidate;
//         return;
//       }

//       // Upper bound pruning on size: even if we take all remaining, can we beat best length?
//       final remaining = sorted.length - idx;
//       final possibleMaxSize = pickedCount + remaining;
//       final bestSize = best.choices.length;
//       if (possibleMaxSize < bestSize) return;

//       final course = sorted[idx];
//       final courseGroupId = gidOf(course);
//       final def = groupById[courseGroupId]!;

//       // Try taking course with each feasible combo if it fits and does not exceed group max
//       if ((pickCount[courseGroupId] ?? 0) < def.maxCourses) {
//         for (final choice in combos[course]!) {
//           if (_fits(scheduled, choice.sessions)) {
//             picked.add(choice);
//             final added = [...scheduled, ...choice.sessions];
//             pickCount[courseGroupId] = (pickCount[courseGroupId] ?? 0) + 1;

//             // Future feasibility pruning: check if remaining capacity across groups can still meet min for those not yet satisfied
//             if (_canStillMeetMins(sorted, idx + 1, pickCount, groupById, gidOf)) {
//               dfs(idx + 1, picked, added, coursePrioSum + course.priority, pickedCount + 1);
//             }

//             pickCount[courseGroupId] = (pickCount[courseGroupId] ?? 1) - 1;
//             picked.removeLast();
//           }
//         }
//       }

//       // Option: skip course
//       if (_canStillMeetMins(sorted, idx + 1, pickCount, groupById, gidOf)) {
//         dfs(idx + 1, picked, scheduled, coursePrioSum, pickedCount);
//       }
//     }

//     dfs(0, [], [], 0, 0);
//     return best;
//   }

//   static bool _fits(List<Session> scheduled, List<Session> newOnes) {
//     for (final n in newOnes) {
//       for (final s in scheduled) {
//         if (n.clashes(s)) return false;
//       }
//     }
//     return true;
//   }

//   static bool _satisfiesAllMin(Map<String, CourseGroupDef> groupById, Map<String, int> pickCount) {
//     for (final g in groupById.values) {
//       final cnt = pickCount[g.id] ?? 0;
//       if (cnt < g.minCourses) return false;
//       if (cnt > g.maxCourses) return false;
//     }
//     return true;
//   }

//   // Check quickly if it's still possible to meet every group's min with remaining courses
//   bool _canStillMeetMins(List<Course> sorted, int nextIdx, Map<String, int> pickCount,
//       Map<String, CourseGroupDef> groupById, String Function(Course) gidOf) {
//     // Remaining courses per group
//     final rem = <String, int>{ for (final id in groupById.keys) id: 0 };
//     for (int i = nextIdx; i < sorted.length; i++) {
//       rem[gidOf(sorted[i])] = (rem[gidOf(sorted[i])] ?? 0) + 1;
//     }
//     for (final g in groupById.values) {
//       final have = pickCount[g.id] ?? 0;
//       final need = (g.minCourses - have).clamp(0, 1<<16);
//       if (need > (rem[g.id] ?? 0)) return false;
//       // also if have already exceeds max, infeasible
//       if (have > g.maxCourses) return false;
//     }
//     return true;
//   }

//   bool _isBetter(OptimizeResult a, OptimizeResult b) {
//     if (a.choices.length != b.choices.length) return a.choices.length > b.choices.length;
//     if (a.groupPrioritySum != b.groupPrioritySum) return a.groupPrioritySum > b.groupPrioritySum;
//     if (a.coursePrioritySum != b.coursePrioritySum) return a.coursePrioritySum > b.coursePrioritySum;
//     // final tie: lexicographical by course code
//     final acodes = a.choices.map((e) => e.course.code).toList()..sort();
//     final bcodes = b.choices.map((e) => e.course.code).toList()..sort();
//     for (int i = 0; i < acodes.length && i < bcodes.length; i++) {
//       final cmp = acodes[i].compareTo(bcodes[i]);
//       if (cmp != 0) return cmp < 0;
//     }
//     return false; // equal
//   }

//   static List<CourseChoice> _enumerateCourseCombos(Course c) {
//     // Build cartesian product of picking 1 option per tutorial group (or none if group empty),
//     // then add required sessions.
//     final List<List<Session>> picksPerGroup = [];
//     for (final g in c.sessionGroups) {
//       if (g.options.isEmpty) {
//         picksPerGroup.add([/*choose none*/]);
//       } else {
//         picksPerGroup.add(g.options);
//       }
//     }

//     List<List<Session>> products = [[]];
//     for (final groupOptions in picksPerGroup) {
//       final List<List<Session>> next = [];
//       if (groupOptions.isEmpty) {
//         for (final p in products) {
//           next.add(List.of(p));
//         }
//       } else {
//         for (final p in products) {
//           for (final opt in groupOptions) {
//             next.add([...p, opt]);
//           }
//         }
//       }
//       products = next;
//     }

//     // If there are no tutorial groups, we still need one combination with just required sessions
//     if (c.sessionGroups.isEmpty) {
//       products = [[]];
//     }

//     final combos = <CourseChoice>[];
//     for (final pick in products) {
//       final sessions = pick;
//       combos.add(CourseChoice(c, sessions));
//     }
//     return combos;
//   }
// }

// // ======== Persistence (Courses + Groups) ========

// class AppStore {
//   static const _coursesKey = 'courses_v2';
//   static const _groupsKey = 'groups_v2';

//   static Future<void> save({required List<Course> courses, required List<CourseGroupDef> groups}) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_coursesKey, jsonEncode(courses.map((e) => e.toJson()).toList()));
//     await prefs.setString(_groupsKey, jsonEncode(groups.map((e) => e.toJson()).toList()));
//   }

//   static Future<(List<Course>, List<CourseGroupDef>)> load() async {
//     final prefs = await SharedPreferences.getInstance();
//     final cRaw = prefs.getString(_coursesKey);
//     final gRaw = prefs.getString(_groupsKey);
//     final courses = cRaw == null ? <Course>[] : (jsonDecode(cRaw) as List).cast<Map<String, dynamic>>().map(Course.fromJson).toList();
//     final groups = gRaw == null ? <CourseGroupDef>[] : (jsonDecode(gRaw) as List).cast<Map<String, dynamic>>().map(CourseGroupDef.fromJson).toList();
//     return (courses, groups);
//   }
// }

// // ======== PDF Export ========

// Future<void> exportTimetablePdf(OptimizeResult result) async {
//   final doc = pw.Document();

//   List<pw.Widget> _buildBody() {
//     if (result.choices.isEmpty) {
//       return [pw.Paragraph(text: 'No valid timetable generated.')];
//     }
//     // Group sessions by day for readability
//     final byDay = <Weekday, List<(Course, Session)>>{};
//     for (final cc in result.choices) {
//       for (final s in cc.sessions) {
//         byDay.putIfAbsent(s.day, () => []).add((cc.course, s));
//       }
//     }
//     final dayWidgets = <pw.Widget>[];
//     for (final d in Weekday.values) {
//       final rows = byDay[d];
//       if (rows == null || rows.isEmpty) continue;
//       rows.sort((a, b) => a.$2.startMinutes.compareTo(b.$2.startMinutes));
//       dayWidgets.add(pw.Header(level: 2, text: weekdayLabel(d)));
//       dayWidgets.add(
//         pw.Table.fromTextArray(
//           headers: ['Course', 'Name', 'Type', 'Start', 'End'],
//           data: rows.map((e) => [
//             e.$1.code,
//             e.$1.name,
//             e.$2.type,
//             _fmtTime(e.$2.startMinutes),
//             _fmtTime(e.$2.endMinutes),
//           ]).toList(),
//         ),
//       );
//     }
//     return [
//       pw.Header(level: 0, text: 'Optimized Timetable'),
//       pw.Paragraph(text: 'Courses: ${result.choices.length}  |  Group Priority: ${result.groupPrioritySum}  |  Course Priority: ${result.coursePrioritySum}'),
//       ...dayWidgets,
//     ];
//   }

//   doc.addPage(
//     pw.MultiPage(
//       build: (ctx) => _buildBody(),
//     ),
//   );

//   await Printing.layoutPdf(onLayout: (format) async => doc.save());
// }

// // ======== Helpers (shared with UI) ========

// String _fmtTime(int minutes) {
//   final h = minutes ~/ 60;
//   final m = minutes % 60;
//   final period = h < 12 ? 'AM' : 'PM';
//   final h12 = h % 12 == 0 ? 12 : h % 12;
//   final mm = m.toString().padLeft(2, '0');
//   return '$h12:$mm $period';
// }


// // ======== UI ========

// void main() {
//   runApp(const CoursePlannerApp());
// }

// class CoursePlannerApp extends StatelessWidget {
//   const CoursePlannerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Course Planner',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
//         useMaterial3: true,
//       ),
//       home: const PlannerHome(),
//     );
//   }
// }

// class PlannerHome extends StatefulWidget {
//   const PlannerHome({super.key});
//   @override
//   State<PlannerHome> createState() => _PlannerHomeState();
// }

// class _PlannerHomeState extends State<PlannerHome> {
//   final List<Course> _courses = [];
//   final List<CourseGroupDef> _groups = [];
//   int _desiredCount = 6; // target

//   OptimizeResult? _result;
//   Course? _editingCourse; // null means adding new, non-null means editing


//   // Temp builders for creating a course
//   final _codeCtrl = TextEditingController();
//   final _nameCtrl = TextEditingController();
//   final _priorityCtrl = TextEditingController(text: '10');
//   String? _selectedGroupId; // assignment

//   // final List<Session> _requiredSessions = [];
//   final List<SessionGroup> _sessionGroups = [];

//   // Session builder controls
//   Weekday _tmpDay = Weekday.mon;
//   TimeOfDay _tmpStart = const TimeOfDay(hour: 9, minute: 0);
//   TimeOfDay _tmpEnd = const TimeOfDay(hour: 10, minute: 0);
//   String _tmpType = 'Lecture';

//   // Tutorial group builder
//   final _tgLabelCtrl = TextEditingController(text: 'Session Group');
//   final List<Session> _tgOptions = [];

//   // Group builder controls
//   final _groupLabelCtrl = TextEditingController();
//   final _groupPriorityCtrl = TextEditingController(text: '10');
//   final _groupMinCtrl = TextEditingController(text: '0');
//   final _groupMaxCtrl = TextEditingController(text: '2');

//   @override
//   void initState() {
//     super.initState();
//     // Load persisted data
//     AppStore.load().then((data) {
//       setState(() {
//         _courses
//           ..clear()
//           ..addAll(data.$1);
//         _groups
//           ..clear()
//           ..addAll(data.$2);
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _codeCtrl.dispose();
//     _nameCtrl.dispose();
//     _priorityCtrl.dispose();
//     _tgLabelCtrl.dispose();
//     _groupLabelCtrl.dispose();
//     _groupPriorityCtrl.dispose();
//     _groupMinCtrl.dispose();
//     _groupMaxCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('University Course Planner — Web (Groups+PDF+Persist)'),
//         actions: [
//           IconButton(
//             tooltip: 'Reset all',
//             onPressed: () async {
//               setState(() {
//                 _courses.clear();
//                 _groups.clear();
//                 _result = null;
//                 // _requiredSessions.clear();
//                 _sessionGroups.clear();
//                 _tgOptions.clear();
//                 _selectedGroupId = null;
//               });
//               await AppStore.save(courses: _courses, groups: _groups);
//             },
//             icon: const Icon(Icons.delete_sweep_outlined),
//           )
//         ],
//       ),
//       body: Row(
//         children: [
//           Expanded(
//             flex: 2,
//             child: _buildInputPane(context),
//           ),
//           const VerticalDivider(width: 1),
//           Expanded(
//             flex: 3,
//             child: _buildResultPane(context),
//           ),
//         ],
//       ),
//     );
//   }

//   // ===== Input Pane =====
//   Widget _buildInputPane(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildGroupManagerCard(),
//           const SizedBox(height: 16),
//           const Text('1) Desired number of courses (target, not hard)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               SizedBox(
//                 width: 160,
//                 child: TextFormField(
//                   decoration: const InputDecoration(labelText: 'Target Count'),
//                   initialValue: '6',
//                   keyboardType: TextInputType.number,
//                   onChanged: (v) {
//                     final n = int.tryParse(v);
//                     if (n != null && n > 0) setState(() => _desiredCount = n);
//                   },
//                 ),
//               ),
//               const SizedBox(width: 16),
//               ElevatedButton.icon(
//                 onPressed: _runOptimizer,
//                 icon: const Icon(Icons.auto_fix_high),
//                 label: const Text('Optimize Timetable'),
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),
//           const Divider(),
//           const Text('2) Add a course (assign to a group)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//           const SizedBox(height: 8),
//           _courseForm(),
//           const SizedBox(height: 12),
//           // _sessionBuilderCard(),
//           // const SizedBox(height: 12),
//           _sessionGroupBuilderCard(),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 12,
//             runSpacing: 8,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: _addCourse,
//                 icon: const Icon(Icons.add),
//                 label: const Text('Add Course to List'),
//               ),
//               Text(
//                 //'Required sessions: ${_requiredSessions.length}   |   Tutorial groups: ${_tutorialGroups.length}',
//                 'Session groups: ${_sessionGroups.length}',
//               ),
//             ],
//           ),

//           const SizedBox(height: 24),
//           const Divider(),
//           const Text('3) Current courses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//           const SizedBox(height: 8),
//           ..._courses.map((c) => Card(
//                 child: ExpansionTile(
//                   title: Text('${c.displayName}  •  Group: \'${_groupLabel(c.groupId)}\''),
//                   childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
//                   children: [
//                     // if (c.requiredSessions.isNotEmpty) const Align(alignment: Alignment.centerLeft, child: Text('Required:')),
//                     // ...c.requiredSessions.map((s) => Align(
//                     //       alignment: Alignment.centerLeft,
//                     //       child: Text('• ${weekdayLabel(s.day)} ${s.timeLabel} (${s.type})'),
//                     //     )),
//                     if (c.sessionGroups.isNotEmpty) const SizedBox(height: 6),
//                     ...c.sessionGroups.map((g) => Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Choose 1 — ${g.label}'),
//                             ...g.options.map((s) => Text('◦ ${weekdayLabel(s.day)} ${s.timeLabel} (${s.type})')),
//                           ],
//                         )),
//                     const SizedBox(height: 6),
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(
//                             onPressed: () {
//                               // populate form with this course's data
//                               _codeCtrl.text = c.code;
//                               _nameCtrl.text = c.name;
//                               _priorityCtrl.text = c.priority.toString();
//                               _selectedGroupId = c.groupId;
//                               // TODO: populate sessionGroups selections if needed
                              
//                               // optionally track which course is being edited
//                               _editingCourse = c;
//                             },
//                             icon: const Icon(Icons.edit_outlined),
//                           ),
//                           IconButton(
//                             onPressed: () async {
//                               setState(() => _courses.remove(c));
//                               await AppStore.save(courses: _courses, groups: _groups);
//                             },
//                             icon: const Icon(Icons.delete_outline),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               )),
//           const SizedBox(height: 100),
//         ],
//       ),
//     );
//   }

//   String _groupLabel(String? id) {
//     if (id == null) return 'Ungrouped';
//     return _groups.firstWhere((g) => g.id == id, orElse: () => CourseGroupDef(id: id, label: 'Unknown', priority: 0, minCourses: 0, maxCourses: 9999)).label;
//   }

//   Widget _buildGroupManagerCard() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('0) Manage Course Groups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//             const SizedBox(height: 8),
//             Wrap(
//               spacing: 12,
//               runSpacing: 8,
//               crossAxisAlignment: WrapCrossAlignment.center,
//               children: [
//                 SizedBox(
//                   width: 200,
//                   child: TextField(
//                     controller: _groupLabelCtrl,
//                     decoration: const InputDecoration(labelText: 'Group Label (e.g., Core, Biz Req)'),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 120,
//                   child: TextField(
//                     controller: _groupPriorityCtrl,
//                     keyboardType: TextInputType.number,
//                     decoration: const InputDecoration(labelText: 'Priority'),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 120,
//                   child: TextField(
//                     controller: _groupMinCtrl,
//                     keyboardType: TextInputType.number,
//                     decoration: const InputDecoration(labelText: 'Min'),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 120,
//                   child: TextField(
//                     controller: _groupMaxCtrl,
//                     keyboardType: TextInputType.number,
//                     decoration: const InputDecoration(labelText: 'Max'),
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () async {
//                     final label = _groupLabelCtrl.text.trim();
//                     final pr = int.tryParse(_groupPriorityCtrl.text.trim()) ?? 0;
//                     final gmin = int.tryParse(_groupMinCtrl.text.trim()) ?? 0;
//                     final gmax = int.tryParse(_groupMaxCtrl.text.trim()) ?? 0;
//                     if (label.isEmpty) {
//                       _snack(context, 'Group label required');
//                       return;
//                     }
//                     if (gmin < 0 || gmax < gmin) {
//                       _snack(context, 'Invalid min/max');
//                       return;
//                     }
//                     final id = '${DateTime.now().millisecondsSinceEpoch}_${label.replaceAll(' ', '_')}';
//                     setState(() {
//                       _groups.add(CourseGroupDef(id: id, label: label, priority: pr, minCourses: gmin, maxCourses: gmax));
//                       if (_selectedGroupId == null) _selectedGroupId = id;
//                     });
//                     await AppStore.save(courses: _courses, groups: _groups);
//                     _groupLabelCtrl.clear();
//                   },
//                   icon: const Icon(Icons.add),
//                   label: const Text('Add Group'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (_groups.isNotEmpty)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Groups:'),
//                   const SizedBox(height: 6),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: _groups.map((g) => Chip(
//                       label: Text("${g.label} • p${g.priority} • ${g.minCourses}-${g.maxCourses}"),
//                       onDeleted: () async {
//                         setState(() => _groups.remove(g));
//                         await AppStore.save(courses: _courses, groups: _groups);
//                       },
//                     )).toList(),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _courseForm({Course? existingCourse}) {
//   if (existingCourse != null) {
//     _codeCtrl.text = existingCourse.code;
//     _nameCtrl.text = existingCourse.name;
//     _priorityCtrl.text = existingCourse.priority.toString();
//     _selectedGroupId = existingCourse.groupId;
//     // Optionally pre-fill sessionGroups
//   } else {
//     _codeCtrl.clear();
//     _nameCtrl.clear();
//     _priorityCtrl.clear();
//     _selectedGroupId = null;
//   }

//   return Card(
//     child: Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Wrap(
//         spacing: 12,
//         runSpacing: 12,
//         children: [
//           SizedBox(
//             width: 180,
//             child: TextField(
//               controller: _codeCtrl,
//               decoration: const InputDecoration(labelText: 'Course Code'),
//             ),
//           ),
//           SizedBox(
//             width: 220,
//             child: TextField(
//               controller: _nameCtrl,
//               decoration: const InputDecoration(labelText: 'Course Name'),
//             ),
//           ),
//           SizedBox(
//             width: 140,
//             child: TextField(
//               controller: _priorityCtrl,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: 'Priority'),
//             ),
//           ),
//           SizedBox(
//             width: 220,
//             child: DropdownButtonFormField<String?>(
//               value: _selectedGroupId,
//               decoration: const InputDecoration(labelText: 'Assign Group'),
//               items: [
//                 const DropdownMenuItem<String?>(value: null, child: Text('Ungrouped')),
//                 ..._groups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.label))),
//               ],
//               onChanged: (v) => setState(() => _selectedGroupId = v),
//             ),
//           ),
//           ElevatedButton.icon(
//             onPressed: () {
//               if (existingCourse != null) {
//                 _updateCourse(existingCourse);
//               } else {
//                 _addCourse();
//               }
//             },
//             icon: const Icon(Icons.save),
//             label: const Text('Save'),
//           ),
//         ],
//       ),
//     ),
//   );
// }




//   // Widget _sessionBuilderCard() {
//   //   return Card(
//   //     child: Padding(
//   //       padding: const EdgeInsets.all(12.0),
//   //       child: Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           const Text('Required Session', style: TextStyle(fontWeight: FontWeight.w600)),
//   //           const SizedBox(height: 8),
//   //           Wrap(
//   //             spacing: 12,
//   //             runSpacing: 8,
//   //             crossAxisAlignment: WrapCrossAlignment.center,
//   //             children: [
//   //               _weekdayDropdown(
//   //                 value: _tmpDay,
//   //                 onChanged: (d) => setState(() => _tmpDay = d ?? Weekday.mon),
//   //               ),
//   //               _timePickerField('Start', _tmpStart, (t) => setState(() => _tmpStart = t ?? _tmpStart)),
//   //               _timePickerField('End', _tmpEnd, (t) => setState(() => _tmpEnd = t ?? _tmpEnd)),
//   //               _typeDropdown(value: _tmpType, onChanged: (v) => setState(() => _tmpType = v ?? 'Lecture')),
//   //               ElevatedButton.icon(
//   //                 onPressed: () {
//   //                   final s = Session(
//   //                     day: _tmpDay,
//   //                     startMinutes: _tmpStart.hour * 60 + _tmpStart.minute,
//   //                     endMinutes: _tmpEnd.hour * 60 + _tmpEnd.minute,
//   //                     type: _tmpType,
//   //                   );
//   //                   if (s.endMinutes <= s.startMinutes) {
//   //                     _snack(context, 'End time must be after start');
//   //                     return;
//   //                   }
//   //                   setState(() => _requiredSessions.add(s));
//   //                 },
//   //                 icon: const Icon(Icons.add),
//   //                 label: const Text('Add Required'),
//   //               ),
//   //             ],
//   //           ),
//   //           const SizedBox(height: 8),
//   //           if (_requiredSessions.isNotEmpty)
//   //             Wrap(
//   //               spacing: 8,
//   //               children: _requiredSessions
//   //                   .map((s) => Chip(
//   //                         label: Text('${s.type}: ${weekdayLabel(s.day)} ${s.timeLabel}'),
//   //                         onDeleted: () => setState(() => _requiredSessions.remove(s)),
//   //                       ))
//   //                   .toList(),
//   //             ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }

//   Widget _sessionGroupBuilderCard() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Session Options (Choose 1)', style: TextStyle(fontWeight: FontWeight.w600)),
//             const SizedBox(height: 8),
//             TextField(
//               controller: _tgLabelCtrl,
//               decoration: const InputDecoration(labelText: 'Group Label (e.g., Lectures)'),
//             ),
//             const SizedBox(height: 8),
//             Wrap(
//               spacing: 12,
//               runSpacing: 8,
//               crossAxisAlignment: WrapCrossAlignment.center,
//               children: [
//                 _weekdayDropdown(
//                   value: _tmpDay,
//                   onChanged: (d) => setState(() => _tmpDay = d ?? Weekday.mon),
//                 ),
//                 _timePickerField('Start', _tmpStart, (t) => setState(() => _tmpStart = t ?? _tmpStart)),
//                 _timePickerField('End', _tmpEnd, (t) => setState(() => _tmpEnd = t ?? _tmpEnd)),
//                 _typeDropdown(value: _tmpType, onChanged: (v) => setState(() => _tmpType = v ?? 'Lecture')),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     final s = Session(
//                       day: _tmpDay,
//                       startMinutes: _tmpStart.hour * 60 + _tmpStart.minute,
//                       endMinutes: _tmpEnd.hour * 60 + _tmpEnd.minute,
//                       type: _tmpType,
//                     );
//                     if (s.endMinutes <= s.startMinutes) {
//                       _snack(context, 'End time must be after start');
//                       return;
//                     }
//                     setState(() => _tgOptions.add(s));
//                   },
//                   icon: const Icon(Icons.add),
//                   label: const Text('Add Option'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (_tgOptions.isNotEmpty)
//               Wrap(
//                 spacing: 8,
//                 children: _tgOptions
//                     .map((s) => Chip(
//                           label: Text('${weekdayLabel(s.day)} ${s.timeLabel} (${s.type})'),
//                           onDeleted: () => setState(() => _tgOptions.remove(s)),
//                         ))
//                     .toList(),
//               ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     if (_tgOptions.isEmpty) {
//                       _snack(context, 'Add at least one option before creating a group');
//                       return;
//                     }
//                     setState(() {
//                       _sessionGroups.add(SessionGroup(
//                         label: _tgLabelCtrl.text.trim().isEmpty ? 'Sessions' : _tgLabelCtrl.text.trim(),
//                         options: List.of(_tgOptions),
//                       ));
//                       _tgOptions.clear();
//                       _tgLabelCtrl.text = 'Session Group';
//                     });
//                   },
//                   icon: const Icon(Icons.folder_open),
//                   label: const Text('Create Session Group'),
//                 ),
//                 const SizedBox(width: 12),
//                 Text('Groups: ${_sessionGroups.length}')
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (_sessionGroups.isNotEmpty)
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: _sessionGroups
//                     .map((g) => Card(
//                           color: Colors.indigo.withOpacity(0.05),
//                           child: ListTile(
//                             title: Text(g.label),
//                             subtitle: Wrap(
//                               spacing: 6,
//                               children: g.options
//                                   .map((s) => Chip(label: Text('${weekdayLabel(s.day)} ${s.timeLabel} (${s.type})')))
//                                   .toList(),
//                             ),
//                             trailing: IconButton(
//                               icon: const Icon(Icons.delete_outline),
//                               onPressed: () => setState(() => _sessionGroups.remove(g)),
//                             ),
//                           ),
//                         ))
//                     .toList(),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _updateCourse(Course existing) {
//     final updated = Course(
//         code: _codeCtrl.text,
//         name: _nameCtrl.text,
//         priority: int.tryParse(_priorityCtrl.text) ?? 0,
//         sessionGroups: existing.sessionGroups, // optionally allow editing sessionGroups
//         groupId: _selectedGroupId,
//       );

//       setState(() {
//         final index = _courses.indexOf(existing);
//         if (index != -1) _courses[index] = updated;
//       });

//       _clearForm();
//   }

//   void _clearForm() {
//     _codeCtrl.clear();
//     _nameCtrl.clear();
//     _priorityCtrl.clear();
//     _selectedGroupId = null;
//     // Optionally reset any session group selections here
//     setState(() {});
//   }

//   void _addCourse() async {
//   final code = _codeCtrl.text.trim();
//   final name = _nameCtrl.text.trim();
//   final pr = int.tryParse(_priorityCtrl.text.trim());

//   if (code.isEmpty || name.isEmpty || pr == null) {
//     _snack(context, 'Please fill code, name, and priority (integer).');
//     return;
//   }
//   if (_sessionGroups.isEmpty) {
//     _snack(context, 'Add at least one required session (e.g., lecture).');
//     return;
//   }

//   final course = Course(
//     code: code,
//     name: name,
//     priority: pr,
//     sessionGroups: List.of(_sessionGroups),
//     groupId: _selectedGroupId,
//   );

//   setState(() {
//     if (_editingCourse != null) {
//       // Update existing course
//       final index = _courses.indexOf(_editingCourse!);
//       if (index != -1) _courses[index] = course;
//       _editingCourse = null;
//     } else {
//       // Add new course
//       _courses.add(course);
//     }

//     // Clear form
//     _sessionGroups.clear();
//     _codeCtrl.clear();
//     _nameCtrl.clear();
//     _priorityCtrl.text = '10';
//     _selectedGroupId = null;
//   });

//   await AppStore.save(courses: _courses, groups: _groups);
// }


//   void _runOptimizer() {
//     if (_desiredCount <= 0) {
//       _snack(context, 'Desired course count must be positive.');
//       return;
//     }
//     if (_courses.isEmpty) {
//       _snack(context, 'Add some courses first.');
//       return;
//     }

//     final opt = GroupAwareOptimizer(
//       courses: List.of(_courses),
//       groups: List.of(_groups),
//       desiredCount: _desiredCount,
//     ).solve();

//     setState(() => _result = opt);

//     if (opt.choices.isEmpty) {
//       _snack(context, 'No clash-free schedule found that satisfies all group mins/maxes. Try adjusting groups or times.');
//     }
//   }

//   // ===== Result Pane =====
//   Widget _buildResultPane(BuildContext context) {
//     final hasResult = _result != null && _result!.choices.isNotEmpty;
//     final List<Scheduled> scheduled = hasResult
//         ? _result!.choices
//             .expand((c) => c.sessions.map((s) => Scheduled(c.course, s)))
//             .toList()
//         : <Scheduled>[];

//     final chosenCourses = hasResult ? _result!.choices.map((c) => c.course).toList() : <Course>[];
//     final colorMap = assignColorsForCourses(chosenCourses);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text('Optimized Timetable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//               const SizedBox(height: 6),
//               if (hasResult)
//                 Text('Selected ${_result!.choices.length} courses • Group Priority: ${_result!.groupPrioritySum} • Course Priority: ${_result!.coursePrioritySum}')
//               else
//                 const Text('No result yet. Add courses and click Optimize.'),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   ElevatedButton.icon(
//                     onPressed: hasResult ? () => exportTimetablePdf(_result!) : null,
//                     icon: const Icon(Icons.picture_as_pdf_outlined),
//                     label: const Text('Export PDF'),
//                   ),
//                 ],
//               )
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Expanded(
//           child: hasResult
//               ? TimetableGrid(sessions: scheduled, colorMap: colorMap)
//               : const Center(child: Text('Your timetable will appear here')),
//         ),
//         if (hasResult)
//           Container(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Included Courses:', style: TextStyle(fontWeight: FontWeight.w600)),
//                 const SizedBox(height: 8),
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: chosenCourses
//                       .map((c) => Chip(
//                             label: Text(c.code),
//                             avatar: CircleAvatar(backgroundColor: colorMap[c] ?? Colors.indigo),
//                           ))
//                       .toList(),
//                 ),
//                 const SizedBox(height: 8),
//                 ..._result!.choices.map((cc) {
//                   final gLabel = _groupLabel(cc.course.groupId);
//                   return Text('• ${cc.course.displayName}  •  Group: $gLabel');
//                 }),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   // ===== Small UI helpers =====
//   Widget _weekdayDropdown({required Weekday value, required ValueChanged<Weekday?> onChanged}) {
//     return DropdownButton<Weekday>(
//       value: value,
//       onChanged: onChanged,
//       items: Weekday.values
//           .map((d) => DropdownMenuItem(value: d, child: Text(weekdayLabel(d))))
//           .toList(),
//     );
//   }

//   Widget _typeDropdown({required String value, required ValueChanged<String?> onChanged}) {
//     const types = ['Lecture', 'Tutorial', 'Lab', 'Other'];
//     return DropdownButton<String>(
//       value: value,
//       onChanged: onChanged,
//       items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
//     );
//   }

//   Widget _timePickerField(String label, TimeOfDay value, ValueChanged<TimeOfDay?> onPicked) {
//     return OutlinedButton(
//       onPressed: () async {
//         final picked = await showTimePicker(context: context, initialTime: value);
//         if (picked != null) onPicked(picked);
//       },
//       child: Text('$label: ${value.format(context)}'),
//     );
//   }
// }

// void _snack(BuildContext ctx, String msg) {
//   ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
// }

// // ======== Colors helper (shared) ========
// Map<Course, Color> assignColorsForCourses(List<Course> courses) {
//   final palette = [
//     Colors.indigo,
//     Colors.blue,
//     Colors.green,
//     Colors.orange,
//     Colors.pink,
//     Colors.purple,
//     Colors.teal,
//     Colors.red,
//     Colors.cyan,
//     Colors.brown,
//     Colors.deepOrange,
//     Colors.lime,
//   ];
//   final map = <Course, Color>{};
//   for (int i = 0; i < courses.length; i++) {
//     map[courses[i]] = palette[i % palette.length].withOpacity(0.65);
//   }
//   return map;
// }

// // ======== Timetable Grid ========

// class TimetableGrid extends StatelessWidget {
//   final List<Scheduled> sessions; // scheduled blocks
//   final Map<Course, Color> colorMap;
//   const TimetableGrid({super.key, required this.sessions, required this.colorMap});

//   static const startHour = 8; // show from 8:00
//   static const endHour = 20;  // to 20:00

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         const dayCount = 6; // Mon-Sat
//         final hourCount = endHour - startHour;

//         final colWidth = constraints.maxWidth / (dayCount + 0.8); // + time gutter
//         final rowHeight = constraints.maxHeight / (hourCount + 0.5);

//         return Stack(
//           children: [
//             // Grid background
//             Positioned.fill(
//               child: CustomPaint(
//                 painter: _GridPainter(colWidth: colWidth, rowHeight: rowHeight, dayCount: dayCount),
//               ),
//             ),
//             // Day labels
//             for (int d = 0; d < dayCount; d++)
//               Positioned(
//                 left: (d + 0.8) * colWidth + 4,
//                 top: 4,
//                 child: Text(weekdayLabel(Weekday.values[d]), style: const TextStyle(fontWeight: FontWeight.w600)),
//               ),
//             // Hour labels
//             for (int h = startHour; h <= endHour; h++)
//               Positioned(
//                 left: 4,
//                 top: (h - startHour + 1) * rowHeight - 8,
//                 child: Text(_hourLabel(h), style: const TextStyle(fontSize: 12, color: Colors.black87)),
//               ),
//             // Session blocks
//             ...sessions.map((sb) {
//               final course = sb.course;
//               final s = sb.session;
//               if (s.day.index > 5) return const SizedBox.shrink(); // only Mon–Sat shown
//               final day = s.day.index;
//               final top = ((s.startMinutes / 60) - startHour) * rowHeight + rowHeight * 1; // offset one header row
//               final height = ((s.endMinutes - s.startMinutes) / 60.0) * rowHeight;
//               final left = (day + 0.8) * colWidth + 6;
//               final width = colWidth - 12;
//               return Positioned(
//                 left: left,
//                 top: top,
//                 width: width,
//                 height: height,
//                 child: _SessionCard(course: course, session: s, color: colorMap[course] ?? Colors.indigo),
//               );
//             }).toList(),
//           ],
//         );
//       },
//     );
//   }

//   static String _hourLabel(int h) {
//     final period = h < 12 ? 'AM' : 'PM';
//     final h12 = h % 12 == 0 ? 12 : h % 12;
//     return '$h12 $period';
//   }
// }

// class _GridPainter extends CustomPainter {
//   final double colWidth;
//   final double rowHeight;
//   final int dayCount;
//   const _GridPainter({required this.colWidth, required this.rowHeight, required this.dayCount});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.grey.withOpacity(0.25)
//       ..style = PaintingStyle.stroke;

//     // Time gutter width ~ 0.8 col
//     final gutter = 0.8 * colWidth;

//     // Horizontal lines for hours
//     for (int r = 0; r <= TimetableGrid.endHour - TimetableGrid.startHour + 1; r++) {
//       final y = r * rowHeight;
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
//     }

//     // Vertical lines: gutter + day columns
//     for (int c = 0; c <= dayCount; c++) {
//       final x = gutter + c * colWidth;
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
//     }

//     // Outline
//     canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
//   }

//   @override
//   bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
// }

// class _SessionCard extends StatelessWidget {
//   final Course course;
//   final Session session;
//   final Color color;
//   const _SessionCard({required this.course, required this.session, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: color,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       child: Padding(
//         padding: const EdgeInsets.all(6.0),
//         child: FittedBox(
//           alignment: Alignment.topLeft,
//           fit: BoxFit.scaleDown,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('${course.code} • ${session.type}', style: const TextStyle(fontWeight: FontWeight.w600)),
//               Text(course.name, maxLines: 1, overflow: TextOverflow.ellipsis),
//               Text(session.timeLabel),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
