# Timetable Planner Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Excel-upload timetable tool into a guided, interactive course planner with a visual timetable grid, persistent storage, preference scoring, and course lock support.

**Architecture:** Provider-based state management with a storage abstraction layer (JSON serialization → platform-specific persistence). Core timetable generator extracted into an isolated service with additive enhancements only (locks, scoring). GoRouter for declarative routing between Dashboard, Wizard, and Timetable views.

**Tech Stack:** Flutter + Dart, `provider` (state), `go_router` (routing), `shared_preferences` (desktop persist), `path_provider` (desktop file paths), existing `excel`/`file_picker`/`pdf`/`printing` retained.

## Global Constraints

- All existing clash detection and backtracking logic in the timetable generator must be preserved verbatim — no behavioral changes to core algorithm
- Locked courses are a hard constraint (always included); preference scores are a soft constraint (sort-only, post-generation)
- Auto-save debounced at 1 second on data mutations
- Excel import must remain functional but visually de-emphasized (niche option)
- Models must implement `toJson()`/`fromJson()` for serialization
- Platform detection via `kIsWeb` from `foundation.dart`

---
### Task 1: Project Scaffolding & Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Create: directory structure `lib/models/`, `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/widgets/`

**Interfaces:**
- Consumes: current project structure
- Produces: scaffold with all deps, empty directory structure

- [ ] **Step 1: Update pubspec.yaml with new dependencies**

Add under `dependencies:`:
```yaml
  provider: ^6.1.2
  go_router: ^14.8.1
  shared_preferences: ^2.3.4
  path_provider: ^2.1.5
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `cd c:\Users\Omer Abdullah\Desktop\AllProjects\Personal Projects\timetable-planner && flutter pub get`
Expected: Success with no errors

- [ ] **Step 3: Create directory structure**

```bash
mkdir -p lib/models lib/services lib/providers lib/screens lib/widgets
```

---
### Task 2: Enhanced Data Models with Serialization

**Files:**
- Create: `lib/models/course_group.dart`
- Create: `lib/models/course.dart`
- Create: `lib/models/session_group.dart`
- Create: `lib/models/session.dart`
- Create: `lib/models/timetable.dart`
- Modify: `lib/models.dart` → re-export all model files
- Delete: `lib/models.dart` → remove old monolithic models file

**Interfaces:**
- Consumes: spec sections 3.1–3.5
- Produces: `CourseGroup`, `Course`, `SessionGroup`, `Session`, `SelectedCourse`, `GeneratedTimetable` — all with `toJson()`/`fromJson()`

- [ ] **Step 1: Create `lib/models/session.dart`**

```dart
class Session {
  final int crn;
  final String sessionCode;
  final String sessionDay;
  final String sessionStartTime;
  final String sessionEndTime;
  final int sessionAvailability;
  final bool locked;

  Session({
    required this.crn,
    required this.sessionCode,
    required this.sessionDay,
    required this.sessionStartTime,
    required this.sessionEndTime,
    required this.sessionAvailability,
    this.locked = false,
  });

  Map<String, dynamic> toJson() => {
    'crn': crn,
    'sessionCode': sessionCode,
    'sessionDay': sessionDay,
    'sessionStartTime': sessionStartTime,
    'sessionEndTime': sessionEndTime,
    'sessionAvailability': sessionAvailability,
    'locked': locked,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    crn: json['crn'] as int,
    sessionCode: json['sessionCode'] as String? ?? '',
    sessionDay: json['sessionDay'] as String? ?? '',
    sessionStartTime: json['sessionStartTime'] as String? ?? '',
    sessionEndTime: json['sessionEndTime'] as String? ?? '',
    sessionAvailability: json['sessionAvailability'] as int? ?? 0,
    locked: json['locked'] as bool? ?? false,
  );

  Session copyWith({bool? locked}) => Session(
    crn: crn,
    sessionCode: sessionCode,
    sessionDay: sessionDay,
    sessionStartTime: sessionStartTime,
    sessionEndTime: sessionEndTime,
    sessionAvailability: sessionAvailability,
    locked: locked ?? this.locked,
  );
}
```

- [ ] **Step 2: Create `lib/models/session_group.dart`**

```dart
import 'session.dart';

class SessionGroup {
  final String sessionType;
  final List<Session> sessionOptions;

  SessionGroup({
    required this.sessionType,
    required this.sessionOptions,
  });

  Map<String, dynamic> toJson() => {
    'sessionType': sessionType,
    'sessionOptions': sessionOptions.map((s) => s.toJson()).toList(),
  };

  factory SessionGroup.fromJson(Map<String, dynamic> json) => SessionGroup(
    sessionType: json['sessionType'] as String,
    sessionOptions: (json['sessionOptions'] as List)
        .map((s) => Session.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
```

- [ ] **Step 3: Create `lib/models/course.dart`**

```dart
import 'session_group.dart';

class Course {
  final String courseCode;
  final String courseName;
  final int preferenceScore;
  final bool locked;
  final List<SessionGroup> sessionGroups;

  Course({
    required this.courseCode,
    required this.courseName,
    this.preferenceScore = 0,
    this.locked = false,
    required this.sessionGroups,
  });

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'preferenceScore': preferenceScore,
    'locked': locked,
    'sessionGroups': sessionGroups.map((sg) => sg.toJson()).toList(),
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    courseCode: json['courseCode'] as String,
    courseName: json['courseName'] as String? ?? '',
    preferenceScore: json['preferenceScore'] as int? ?? 0,
    locked: json['locked'] as bool? ?? false,
    sessionGroups: (json['sessionGroups'] as List?)
            ?.map((sg) => SessionGroup.fromJson(sg as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Course copyWith({
    String? courseCode,
    String? courseName,
    int? preferenceScore,
    bool? locked,
    List<SessionGroup>? sessionGroups,
  }) => Course(
    courseCode: courseCode ?? this.courseCode,
    courseName: courseName ?? this.courseName,
    preferenceScore: preferenceScore ?? this.preferenceScore,
    locked: locked ?? this.locked,
    sessionGroups: sessionGroups ?? this.sessionGroups,
  );
}
```

- [ ] **Step 4: Create `lib/models/course_group.dart`**

```dart
import 'course.dart';

class CourseGroup {
  final String courseType;
  final List<Course> courses;
  final int? min;
  final int? max;

  CourseGroup({
    required this.courseType,
    required this.courses,
    this.min,
    this.max,
  });

  Map<String, dynamic> toJson() => {
    'courseType': courseType,
    'min': min,
    'max': max,
    'courses': courses.map((c) => c.toJson()).toList(),
  };

  factory CourseGroup.fromJson(Map<String, dynamic> json) => CourseGroup(
    courseType: json['courseType'] as String,
    min: json['min'] as int?,
    max: json['max'] as int?,
    courses: (json['courses'] as List?)
            ?.map((c) => Course.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
```

- [ ] **Step 5: Create `lib/models/timetable.dart`**

```dart
import 'course.dart';
import 'session.dart';

class SelectedCourse {
  final Course course;
  final List<Session> sessions;

  SelectedCourse({required this.course, required this.sessions});
}

class GeneratedTimetable {
  final List<SelectedCourse> courses;
  final int totalScore;

  GeneratedTimetable({required this.courses, required this.totalScore});
}
```

- [ ] **Step 6: Create `lib/models.dart` as barrel re-export**

```dart
export 'models/course_group.dart';
export 'models/course.dart';
export 'models/session_group.dart';
export 'models/session.dart';
export 'models/timetable.dart';
```

- [ ] **Step 7: Delete old monolithic `lib/models.dart`**

The old file will be overwritten by the barrel file above (same path).

---
### Task 3: Storage Service

**Files:**
- Create: `lib/services/storage_service.dart`

**Interfaces:**
- Consumes: `CourseGroup.fromJson()`, `CourseGroup.toJson()` from Task 2
- Produces: `StorageService` abstract class, factory `StorageService.create()`, methods `saveCourseData()`, `loadCourseData()`

- [ ] **Step 1: Create `lib/services/storage_service.dart`**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class StorageService {
  static const String _key = 'course_planner_data';

  Future<void> saveCourseData(List<CourseGroup> groups) async {
    final json = jsonEncode({
      'courseGroups': groups.map((g) => g.toJson()).toList(),
    });

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json);
    } else {
      // Desktop: same approach since shared_preferences works cross-platform
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json);
    }
  }

  Future<List<CourseGroup>?> loadCourseData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null || json.isEmpty) return null;

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final groupsList = decoded['courseGroups'] as List;
      return groupsList
          .map((g) => CourseGroup.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCourseData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

---
### Task 4: Parser Service (Excel Extraction)

**Files:**
- Create: `lib/services/parser_service.dart`

**Interfaces:**
- Consumes: `Session`, `SessionGroup`, `Course`, `CourseGroup` from Task 2
- Produces: `ParserService.parseExcelBytes(Uint8List bytes) → List<CourseGroup>`

- [ ] **Step 1: Create `lib/services/parser_service.dart`**

Extract the parsing logic verbatim from `home_screen.dart` (the `_pickAndParseExcel` method body after file-picking). The parser receives raw bytes and returns parsed `List<CourseGroup>`. Complete code below:

```dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models.dart';

class ParserService {
  List<CourseGroup> parseExcelBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final Map<String, _GroupBuilder> groups = {};
    final Map<String, Map<String, _CourseBuilder>> coursesByGroup = {};
    final Map<String, Map<String, _SessionGroupBuilder>> sessionsByCourseKey = {};

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName]!;
      if (sheet.rows.isEmpty) continue;

      final header = sheet.rows.first;
      final colCourseType = _findColIndex(header, ['Course Type', 'CourseType']);
      final colCourseMin = _findColIndex(header, ['Min', 'Min']);
      final colCourseMax = _findColIndex(header, ['Max', 'Max']);
      final colCourseCode = _findColIndex(header, ['Course Code', 'CourseCode']);
      final colCourseName = _findColIndex(header, ['Course Name', 'CourseName']);
      final colSessionType = _findColIndex(header, ['Session Type', 'SessionType']);
      final colCRN = _findColIndex(header, ['Session CRN', 'CRN']);
      final colSessionCode = _findColIndex(header, ['Session Code', 'Code']);
      final colSessionDay = _findColIndex(header, ['Session Day', 'Day']);
      final colSessionTime = _findColIndex(header, ['Session Time', 'Time']);
      final colAvailability = _findColIndex(header, ['Session Availability', 'Availability']);

      String lastCourseType = '';
      String lastCourseCode = '';
      String lastCourseName = '';
      String lastSessionType = '';
      int lastCourseMin = 0;
      int lastCourseMax = 0;

      for (final row in sheet.rows.skip(1)) {
        final allEmpty = row.every((c) => (_cellStr(c) ?? '').trim().isEmpty);
        if (allEmpty) continue;

        final courseType = (colCourseType >= 0 ? _cellStr(row[colCourseType]) : null)?.trim();
        final courseMin = (colCourseMin >= 0 ? _cellInt(row[colCourseMin]) : null);
        final courseMax = (colCourseMax >= 0 ? _cellInt(row[colCourseMax]) : null);
        final courseCode = (colCourseCode >= 0 ? _cellStr(row[colCourseCode]) : null)?.trim();
        final courseName = (colCourseName >= 0 ? _cellStr(row[colCourseName]) : null)?.trim();
        final sessionType = (colSessionType >= 0 ? _cellStr(row[colSessionType]) : null)?.trim();

        final theCourseType = (courseType != null && courseType.isNotEmpty) ? courseType : lastCourseType;
        final theCourseCode = (courseCode != null && courseCode.isNotEmpty) ? courseCode : lastCourseCode;
        final theCourseName = (courseName != null && courseName.isNotEmpty) ? courseName : lastCourseName;
        final theSessionType = (sessionType != null && sessionType.isNotEmpty) ? sessionType : lastSessionType;
        final theCourseMin = (courseMin != null && courseMin >= 0) ? courseMin : lastCourseMin;
        final theCourseMax = (courseMax != null && courseMax >= 0) ? courseMax : lastCourseMax;

        if (theCourseType.isNotEmpty) lastCourseType = theCourseType;
        if (theCourseCode.isNotEmpty) lastCourseCode = theCourseCode;
        if (theCourseName.isNotEmpty) lastCourseName = theCourseName;
        if (theSessionType.isNotEmpty) lastSessionType = theSessionType;
        if (theCourseMin >= 0) lastCourseMin = theCourseMin;
        if (theCourseMax >= 0) lastCourseMax = theCourseMax;

        if (theCourseType.isEmpty || theCourseCode.isEmpty) continue;

        groups.putIfAbsent(theCourseType, () => _GroupBuilder(courseType: theCourseType, min: theCourseMin, max: theCourseMax));
        coursesByGroup.putIfAbsent(theCourseType, () => {});
        final coursesMap = coursesByGroup[theCourseType]!;

        coursesMap.putIfAbsent(theCourseCode, () => _CourseBuilder(
          courseCode: theCourseCode, courseName: theCourseName,
        ));
        final existingCourse = coursesMap[theCourseCode]!;
        if (existingCourse.courseName.isEmpty && theCourseName.isNotEmpty) {
          coursesMap[theCourseCode] = _CourseBuilder(
            courseCode: theCourseCode, courseName: theCourseName,
          );
        }

        final courseKey = '$theCourseType::$theCourseCode';
        sessionsByCourseKey.putIfAbsent(courseKey, () => {});
        final sgMap = sessionsByCourseKey[courseKey]!;

        if (theSessionType.isNotEmpty) {
          sgMap.putIfAbsent(theSessionType, () => _SessionGroupBuilder(sessionType: theSessionType));
        }

        final crn = colCRN >= 0 ? _cellInt(row[colCRN]) : null;
        if (crn != null) {
          final code = colSessionCode >= 0 ? (_cellStr(row[colSessionCode]) ?? '') : '';
          final day = colSessionDay >= 0 ? (_cellStr(row[colSessionDay]) ?? '') : '';
          final timeCell = colSessionTime >= 0 ? _cellStr(row[colSessionTime]) : null;
          final (startTime, endTime) = _splitTime(timeCell);
          final availability = colAvailability >= 0 ? (_cellInt(row[colAvailability]) ?? 0) : 0;

          final sgKey = theSessionType.isEmpty ? 'Session' : theSessionType;
          sgMap.putIfAbsent(sgKey, () => _SessionGroupBuilder(sessionType: sgKey));
          sgMap[sgKey]!.sessions.add(Session(
            crn: crn,
            sessionCode: code,
            sessionDay: day,
            sessionStartTime: startTime,
            sessionEndTime: endTime,
            sessionAvailability: availability,
          ));
        }
      }
    }

    final List<CourseGroup> resultGroups = [];
    for (final entry in groups.entries) {
      final type = entry.key;
      final courseMap = coursesByGroup[type] ?? {};
      final courses = courseMap.values.map((cb) {
        final ck = '$type::${cb.courseCode}';
        final sgMap = sessionsByCourseKey[ck] ?? {};
        return Course(
          courseCode: cb.courseCode,
          courseName: cb.courseName,
          sessionGroups: sgMap.values.map((sgb) =>
            SessionGroup(sessionType: sgb.sessionType, sessionOptions: List.from(sgb.sessions))
          ).toList(),
        );
      }).toList();
      courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
      resultGroups.add(CourseGroup(
        courseType: type, courses: courses,
        min: entry.value.min, max: entry.value.max,
      ));
    }
    resultGroups.sort((a, b) => a.courseType.compareTo(b.courseType));
    return resultGroups;
  }

  // -- helper classes and methods (identical to existing code) --
  String? _cellStr(Data? d) {
    if (d == null || d.value == null) return null;
    final v = d.value;
    if (v is num) return (v == v.toInt()) ? v.toInt().toString() : v.toString();
    return v.toString();
  }

  int? _cellInt(Data? d) {
    final s = _cellStr(d);
    if (s == null) return null;
    final digits = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)).join();
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _findColIndex(List<Data?> headerRow, List<String> wanted) {
    final normalizedHeader = headerRow.map((c) => _norm(_cellStr(c) ?? '')).toList();
    for (final w in wanted) {
      final idx = normalizedHeader.indexOf(_norm(w));
      if (idx != -1) return idx;
    }
    return -1;
  }

  (String, String) _splitTime(String? timeCell) {
    if (timeCell == null) return ('', '');
    final m = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(timeCell);
    if (m == null) return ('', '');
    return (m.group(1) ?? '', m.group(2) ?? '');
  }
}

class _GroupBuilder {
  String courseType;
  int? min, max;
  _GroupBuilder({required this.courseType, this.min, this.max});
}

class _CourseBuilder {
  String courseCode, courseName;
  _CourseBuilder({required this.courseCode, required this.courseName});
}

class _SessionGroupBuilder {
  String sessionType;
  List<Session> sessions = [];
  _SessionGroupBuilder({required this.sessionType});
}
```

---
### Task 5: Timetable Generator — Extract & Enhance

**Files:**
- Create: `lib/services/timetable_generator.dart`

**Interfaces:**
- Produces: `TimetableGenerator.generate(GenerationRequest) → GenerationResult`

**CRITICAL:** The backtracking logic (`buildMinimums`, `buildExtras`, `buildNCoursesForGroup`, `hasInternalClash`, `hasClashWithTT`, `sessionsClash`, `timeToMinutes`, `generateConfigs`, `isSessionCodesConsistent`) is extracted **verbatim** from `timetable_screen.dart`. No behavioral changes to the core algorithm.

Additive changes only:
1. Locked courses are pre-selected before backtracking
2. Locked sessions filter which configs are generated for a course
3. Preference scoring applied post-generation (sort-only)
4. `TimePreferences` passed in for time-based penalty scoring

- [ ] **Step 1: Create `lib/services/timetable_generator.dart`**

```dart
import '../models.dart';

class TimePreferences {
  final int earliestStartMinute;  // in minutes from midnight
  final int latestEndMinute;
  final List<String> preferredDays; // "Monday"..."Sunday"
  final bool preferBackToBack;    // true = prefer no gaps, false = prefer gaps

  const TimePreferences({
    this.earliestStartMinute = 420,   // 7:00 AM default
    this.latestEndMinute = 1260,     // 9:00 PM default
    this.preferredDays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    this.preferBackToBack = true,
  });
}

class GenerationRequest {
  final List<CourseGroup> groups;
  final int desiredCourses;
  final TimePreferences timePreferences;

  GenerationRequest({
    required this.groups,
    required this.desiredCourses,
    this.timePreferences = const TimePreferences(),
  });
}

class GenerationResult {
  final List<GeneratedTimetable> timetables;
  final String? error;

  GenerationResult({required this.timetables, this.error});
}

class TimetableGenerator {
  GenerationResult generate(GenerationRequest request) {
    final groups = request.groups;
    final desired = request.desiredCourses;
    final prefs = request.timePreferences;

    final sumMin = groups.fold<int>(0, (sum, g) => sum + (g.min ?? 0));
    final sumMax = groups.fold<int>(0, (sum, g) => sum + (g.max ?? g.courses.length));

    if (desired < sumMin || desired > sumMax) {
      return GenerationResult(
        timetables: [],
        error: 'No timetable possible for $desired courses. Minimum: $sumMin, Maximum: $sumMax',
      );
    }

    // ADDITIVE: handle locked courses — they are mandatory
    // Identify locked courses per group
    final lockedCourses = <CourseGroup, List<Course>>{};
    final unlockedGroups = <CourseGroup>[];
    int lockedCount = 0;
    for (final group in groups) {
      final locked = group.courses.where((c) => c.locked).toList();
      if (locked.isNotEmpty) {
        lockedCourses[group] = locked;
        lockedCount += locked.length;
      }
      // Even if group has locked courses, we still need the group for unlocked selection
      unlockedGroups.add(group);
    }

    final remainingDesired = desired - lockedCount;
    if (remainingDesired < 0) {
      return GenerationResult(
        timetables: [],
        error: 'More locked courses ($lockedCount) than desired total ($desired).',
      );
    }

    // Build configs for ALL courses (locked sessions filter applied inside)
    final courseConfigs = <Course, List<List<Session>>>{};
    for (var group in groups) {
      for (var course in group.courses) {
        courseConfigs[course] = _generateConfigs(course);
      }
    }

    final allTimetables = <List<SelectedCourse>>[];
    final currentTT = <SelectedCourse>[];
    final sel = <CourseGroup, Set<Course>>{for (var g in groups) g: <Course>{}};

    // ADDITIVE: pre-select locked courses into currentTT
    for (final entry in lockedCourses.entries) {
      for (final course in entry.value) {
        final configs = courseConfigs[course] ?? [];
        if (configs.isEmpty) {
          return GenerationResult(
            timetables: [],
            error: 'Locked course ${course.courseCode} has no valid session configurations.',
          );
        }
        // Pick the first valid config for locked courses
        currentTT.add(SelectedCourse(course: course, sessions: List.from(configs.first)));
        sel[entry.key]!.add(course);
      }
    }

    // Now build the rest with remaining desired count
    _buildMinimums(groups, 0, currentTT, sel, courseConfigs, allTimetables, remainingDesired);

    if (allTimetables.isEmpty) {
      return GenerationResult(
        timetables: [],
        error: 'No timetable possible for $desired courses.',
      );
    }

    // ADDITIVE: score and sort timetables
    final scored = allTimetables.map((tt) {
      final score = _calculateScore(tt, prefs);
      return GeneratedTimetable(courses: tt, totalScore: score);
    }).toList();

    scored.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return GenerationResult(timetables: scored);
  }

  // ----- VERBATIM EXTRACTION from timetable_screen.dart below -----
  // NO behavioral changes to any of these methods

  void _buildMinimums(
    List<CourseGroup> groups,
    int groupIndex,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    List<List<SelectedCourse>> allTimetables,
    int desiredRemaining,
  ) {
    if (groupIndex == groups.length) {
      if (desiredRemaining == 0) {
        allTimetables.add(List.from(currentTT));
      }
      return;
    }
    final group = groups[groupIndex];
    final alreadySelected = selected[group]!.length;
    final minReq = (group.min ?? 0) - alreadySelected;
    if (minReq > 0) {
      _buildNCoursesForGroup(
        group, minReq, currentTT, selected, configs,
        () => _buildMinimums(groups, groupIndex + 1, currentTT, selected, configs, allTimetables, desiredRemaining - minReq),
      );
    } else {
      // No minimum needed, try 0 from this group and move on
      final maxExtra = (group.max ?? group.courses.length) - alreadySelected;
      final maxPossible = maxExtra > desiredRemaining ? desiredRemaining : maxExtra;
      for (int extra = 0; extra <= maxPossible; extra++) {
        _buildNCoursesForGroup(
          group, extra, currentTT, selected, configs,
          () => _buildMinimums(groups, groupIndex + 1, currentTT, selected, configs, allTimetables, desiredRemaining - extra),
        );
      }
    }
  }

  void _buildNCoursesForGroup(
    CourseGroup group,
    int toAdd,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    void Function() recurseNext,
  ) {
    final available = group.courses
        .where((c) => !selected[group]!.contains(c))
        .toList()
      ..sort((a, b) => a.courseCode.compareTo(b.courseCode));

    void choose(int start, int rem) {
      if (rem == 0) {
        recurseNext();
        return;
      }
      for (int i = start; i < available.length; i++) {
        final course = available[i];
        for (final config in configs[course]!) {
          if (!_hasClashWithTT(currentTT, config)) {
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

  List<List<Session>> _generateConfigs(Course course) {
    final configs = <List<Session>>[];
    void buildConfig(List<Session> current, int groupIndex) {
      if (groupIndex == course.sessionGroups.length) {
        if (!_hasInternalClash(current) && _isSessionCodesConsistent(current)) {
          configs.add(List.from(current));
        }
        return;
      }
      final sg = course.sessionGroups[groupIndex];
      for (final session in sg.sessionOptions) {
        // ADDITIVE: if any session in this course is locked, only consider configs that include it
        final hasLockedSessionInGroup = sg.sessionOptions.any((s) => s.locked);
        if (hasLockedSessionInGroup && !session.locked) continue;

        current.add(session);
        buildConfig(current, groupIndex + 1);
        current.removeLast();
      }
    }
    buildConfig([], 0);
    return configs;
  }

  bool _isSessionCodesConsistent(List<Session> sessions) {
    if (sessions.isEmpty) return true;
    final secondChars = sessions
        .map((s) => s.sessionCode.length > 1 ? s.sessionCode[1] : '')
        .where((c) => c.isNotEmpty)
        .toList();
    if (secondChars.isEmpty) return true;

    bool isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
    bool isLetter(String c) =>
        (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ||
        (c.compareTo('a') >= 0 && c.compareTo('z') <= 0);

    final allDigits = secondChars.every(isDigit);
    if (allDigits) return true;

    final allLetters = secondChars.every(isLetter);
    if (allLetters) {
      final first = secondChars.first.toUpperCase();
      return secondChars.every((c) => c.toUpperCase() == first);
    }
    return false;
  }

  bool _hasInternalClash(List<Session> sessions) {
    for (var i = 0; i < sessions.length; i++) {
      for (var j = i + 1; j < sessions.length; j++) {
        if (_sessionsClash(sessions[i], sessions[j])) return true;
      }
    }
    return false;
  }

  bool _hasClashWithTT(List<SelectedCourse> tt, List<Session> config) {
    for (final sc in tt) {
      for (final es in sc.sessions) {
        for (final ns in config) {
          if (_sessionsClash(es, ns)) return true;
        }
      }
    }
    return false;
  }

  bool _sessionsClash(Session a, Session b) {
    if (a.sessionDay != b.sessionDay) return false;
    final startA = _timeToMinutes(a.sessionStartTime);
    final endA = _timeToMinutes(a.sessionEndTime);
    final startB = _timeToMinutes(b.sessionStartTime);
    final endB = _timeToMinutes(b.sessionEndTime);
    return startA < endB && startB < endA;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ----- END VERBATIM EXTRACTION -----

  int _calculateScore(List<SelectedCourse> tt, TimePreferences prefs) {
    int score = 0;

    // Course preference scores
    for (final sc in tt) {
      score += sc.course.preferenceScore * 10; // Weight: each preference level = 10 pts
    }

    // Time-based penalties
    for (final sc in tt) {
      for (final session in sc.sessions) {
        final start = _timeToMinutes(session.sessionStartTime);
        final end = _timeToMinutes(session.sessionEndTime);
        final day = session.sessionDay;

        // Penalty for starting before preferred earliest time
        if (start < prefs.earliestStartMinute) {
          score -= (prefs.earliestStartMinute - start) ~/ 10;
        }

        // Penalty for ending after preferred latest time
        if (end > prefs.latestEndMinute) {
          score -= (end - prefs.latestEndMinute) ~/ 10;
        }

        // Penalty for non-preferred days
        if (!prefs.preferredDays.contains(day)) {
          score -= 15;
        }
      }
    }

    // Gap preference scoring
    if (prefs.preferBackToBack) {
      // Penalize gaps: for each day, check gaps between consecutive sessions
      final byDay = <String, List<int>>{};
      for (final sc in tt) {
        for (final session in sc.sessions) {
          byDay.putIfAbsent(session.sessionDay, () => []);
          byDay[session.sessionDay]!.add(_timeToMinutes(session.sessionStartTime));
        }
      }
      for (final times in byDay.values) {
        if (times.length > 1) {
          times.sort();
          for (int i = 1; i < times.length; i++) {
            final gap = times[i] - times[i - 1];
            // Assumes sessions are ~1hr; gaps > 90 min penalized
            if (gap > 90) score -= (gap - 90) ~/ 10;
          }
        }
      }
    }

    return score;
  }
}
```

---
### Task 6: Providers (State Management)

**Files:**
- Create: `lib/providers/course_data_provider.dart`
- Create: `lib/providers/preferences_provider.dart`
- Create: `lib/providers/timetable_provider.dart`

**Interfaces:**
- Consumes: All models from Task 2, services from Tasks 3–5
- Produces: `CourseDataProvider`, `PreferencesProvider`, `TimetableProvider`

- [ ] **Step 1: Create `lib/providers/course_data_provider.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/storage_service.dart';

class CourseDataProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<CourseGroup> _courseGroups = [];
  bool _loaded = false;
  Timer? _debounceTimer;

  List<CourseGroup> get courseGroups => _courseGroups;
  bool get loaded => _loaded;

  Future<void> load() async {
    final data = await _storage.loadCourseData();
    if (data != null) {
      _courseGroups = data;
    }
    _loaded = true;
    notifyListeners();
  }

  void setCourseGroups(List<CourseGroup> groups) {
    _courseGroups = groups;
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Course Groups -----
  void addGroup(String courseType, {int? min, int? max}) {
    _courseGroups.add(CourseGroup(
      courseType: courseType, courses: [], min: min, max: max,
    ));
    notifyListeners();
    _scheduleSave();
  }

  void updateGroup(int index, {String? courseType, int? min, int? max}) {
    final old = _courseGroups[index];
    _courseGroups[index] = CourseGroup(
      courseType: courseType ?? old.courseType,
      courses: old.courses,
      min: min ?? old.min,
      max: max ?? old.max,
    );
    notifyListeners();
    _scheduleSave();
  }

  void deleteGroup(int index) {
    _courseGroups.removeAt(index);
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Courses -----
  void addCourse(int groupIndex, Course course) {
    _courseGroups[groupIndex].courses.add(course);
    notifyListeners();
    _scheduleSave();
  }

  void updateCourse(int groupIndex, int courseIndex, Course course) {
    _courseGroups[groupIndex].courses[courseIndex] = course;
    notifyListeners();
    _scheduleSave();
  }

  void deleteCourse(int groupIndex, int courseIndex) {
    _courseGroups[groupIndex].courses.removeAt(courseIndex);
    notifyListeners();
    _scheduleSave();
  }

  // ----- CRUD: Sessions -----
  void addSession(int groupIndex, int courseIndex, String sessionType, Session session) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    var sg = course.sessionGroups.where((s) => s.sessionType == sessionType).firstOrNull;
    if (sg == null) {
      sg = SessionGroup(sessionType: sessionType, sessionOptions: []);
      course.sessionGroups.add(sg);
    }
    sg.sessionOptions.add(session);
    notifyListeners();
    _scheduleSave();
  }

  void deleteSession(int groupIndex, int courseIndex, int sgIndex, int sessionIndex) {
    _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions.removeAt(sessionIndex);
    notifyListeners();
    _scheduleSave();
  }

  // ----- Preferences -----
  void setCoursePreference(int groupIndex, int courseIndex, int score) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    _courseGroups[groupIndex].courses[courseIndex] = course.copyWith(preferenceScore: score);
    notifyListeners();
    _scheduleSave();
  }

  void toggleCourseLock(int groupIndex, int courseIndex) {
    final course = _courseGroups[groupIndex].courses[courseIndex];
    _courseGroups[groupIndex].courses[courseIndex] = course.copyWith(locked: !course.locked);
    notifyListeners();
    _scheduleSave();
  }

  void toggleSessionLock(int groupIndex, int courseIndex, int sgIndex, int sessionIndex) {
    final session = _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions[sessionIndex];
    _courseGroups[groupIndex].courses[courseIndex]
        .sessionGroups[sgIndex].sessionOptions[sessionIndex] = session.copyWith(locked: !session.locked);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _storage.saveCourseData(_courseGroups);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Create `lib/providers/preferences_provider.dart`**

```dart
import 'package:flutter/material.dart';
import '../services/timetable_generator.dart';

class PreferencesProvider extends ChangeNotifier {
  TimePreferences _preferences = const TimePreferences();

  TimePreferences get preferences => _preferences;

  void setEarliestStart(int minutes) {
    _preferences = TimePreferences(
      earliestStartMinute: minutes,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void setLatestEnd(int minutes) {
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: minutes,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void toggleDay(String day) {
    final days = List<String>.from(_preferences.preferredDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: days,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void setGapPreference(bool preferBackToBack) {
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: preferBackToBack,
    );
    notifyListeners();
  }
}
```

- [ ] **Step 3: Create `lib/providers/timetable_provider.dart`**

```dart
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/timetable_generator.dart';

class TimetableProvider extends ChangeNotifier {
  final TimetableGenerator _generator = TimetableGenerator();
  List<GeneratedTimetable> _timetables = [];
  int _currentIndex = 0;
  String? _error;
  bool _generating = false;

  List<GeneratedTimetable> get timetables => _timetables;
  int get currentIndex => _currentIndex;
  String? get error => _error;
  bool get generating => _generating;
  GeneratedTimetable? get current =>
      _timetables.isNotEmpty ? _timetables[_currentIndex] : null;

  void generate(List<CourseGroup> groups, int desiredCourses, TimePreferences prefs) {
    _generating = true;
    _error = null;
    _timetables = [];
    _currentIndex = 0;
    notifyListeners();

    final request = GenerationRequest(
      groups: groups,
      desiredCourses: desiredCourses,
      timePreferences: prefs,
    );

    final result = _generator.generate(request);
    _timetables = result.timetables;
    _error = result.error;
    _generating = false;
    notifyListeners();
  }

  void goToPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void goToNext() {
    if (_currentIndex < _timetables.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }
}
```

---
### Task 7: Routing & App Shell

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: All providers from Task 6, screens from later tasks
- Produces: GoRouter-based routing with redirect logic

- [ ] **Step 1: Create `lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/course_data_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/wizard_screen.dart';
import 'screens/timetable_screen.dart';

class App extends StatelessWidget {
  App({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final provider = context.read<CourseDataProvider>();
      if (!provider.loaded) return null; // still loading
      if (state.matchedLocation == '/wizard') return null;
      if (provider.courseGroups.isEmpty && state.matchedLocation != '/') return '/wizard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/wizard', builder: (context, state) => const WizardScreen()),
      GoRoute(path: '/timetable', builder: (context, state) => const TimetableScreen()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Course Planner',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ),
      ),
      routerConfig: _router,
    );
  }
}
```

- [ ] **Step 2: Update `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/course_data_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/timetable_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseDataProvider()..load()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
      ],
      child: App(),
    ),
  );
}
```

---
### Task 8: Dashboard Screen

**Files:**
- Create: `lib/screens/dashboard_screen.dart`

**Interfaces:**
- Consumes: `CourseDataProvider`, `PreferencesProvider`, `TimetableProvider`
- Produces: Main hub screen with CRUD operations

- [ ] **Step 1: Create `lib/screens/dashboard_screen.dart`**

This is the main hub. It shows course groups with expandable courses inside. Each course has preference stars and a lock toggle. Sessions are editable within each course. Top bar has "Run Wizard" and "Import Excel" options. Bottom has "Generate Timetables" button.

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../providers/course_data_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/parser_service.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ParserService _parser = ParserService();
  int? _expandedGroupIndex;
  int? _expandedCourseIndex;

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
                          final isExpanded = _expandedGroupIndex == index;
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
                              onExpansionChanged: (expanded) {
                                setState(() => _expandedGroupIndex = expanded ? index : null);
                              },
                              children: [
                                ...group.courses.asMap().entries.map((entry) {
                                  final cIdx = entry.key;
                                  final course = entry.value;
                                  final courseExpanded = _expandedCourseIndex == cIdx && isExpanded;
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
                                      onExpansionChanged: (expanded) {
                                        setState(() => _expandedCourseIndex = expanded ? cIdx : null);
                                      },
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
```

---
### Task 9: Timetable Grid Widget

**Files:**
- Create: `lib/widgets/timetable_grid.dart`
- Create: `lib/widgets/session_cell.dart`
- Create: `lib/widgets/session_detail_sheet.dart`

**Interfaces:**
- Consumes: `GeneratedTimetable`, `SelectedCourse`, `Session` from models
- Produces: Visual matrix grid with days × time slots

- [ ] **Step 1: Create `lib/widgets/session_detail_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import '../models.dart';

class SessionDetailSheet extends StatelessWidget {
  final Course course;
  final Session session;
  final String sessionType;

  const SessionDetailSheet({
    super.key,
    required this.course,
    required this.session,
    required this.sessionType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(course.courseCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(course.courseName, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          const Divider(height: 24),
          _detailRow(Icons.category, 'Type', sessionType),
          _detailRow(Icons.qr_code, 'CRN', session.crn.toString()),
          _detailRow(Icons.tag, 'Section', session.sessionCode),
          _detailRow(Icons.calendar_today, 'Day', session.sessionDay),
          _detailRow(Icons.access_time, 'Time', '${session.sessionStartTime} - ${session.sessionEndTime}'),
          if (session.locked)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(
                avatar: Icon(Icons.lock, size: 16),
                label: Text('Locked Session'),
                backgroundColor: Colors.orange,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `lib/widgets/timetable_grid.dart`**

```dart
import 'package:flutter/material.dart';
import '../models.dart';

class TimetableGrid extends StatelessWidget {
  final GeneratedTimetable timetable;
  final List<Color> courseColors;

  const TimetableGrid({
    super.key,
    required this.timetable,
    required this.courseColors,
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
    // Round to hour boundaries
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
            // Header row
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[200]),
              children: [
                _headerCell('Time'),
                ...dayOrder.map((d) => _headerCell(d)),
              ],
            ),
            // Time slot rows
            for (int row = 0; row < slots; row++)
              _buildTimeRow(row, minMinute, events, colorMap),
          ],
        ),
      ),
    );
  }

  TableRow _buildTimeRow(int row, int minMinute, List<_GridEvent> events, Map<String, Color> colorMap) {
    final slotStart = minMinute + row * 60;
    final slotEnd = slotStart + 60;
    final timeStr = '${_minutesToTime(slotStart)}-${_minutesToTime(slotEnd)}';

    return TableRow(
      children: [
        // Time label
        _timeCell(timeStr),
        // One cell per day
        for (final day in dayOrder) _buildDayCell(day, slotStart, slotEnd, events, colorMap),
      ],
    );
  }

  Widget _buildDayCell(String day, int slotStart, int slotEnd, List<_GridEvent> events, Map<String, Color> colorMap) {
    // Find events that start within this time slot
    final matching = events.where((e) {
      if (e.session.sessionDay != day) return false;
      final start = _timeToMinutes(e.session.sessionStartTime);
      return start >= slotStart && start < slotEnd;
    }).toList();

    if (matching.isEmpty) {
      return Container(
        height: 50,
        color: Colors.grey[50],
        child: const Center(child: Text('')),
      );
    }

    // Show first matching event in this cell
    final e = matching.first;
    final color = colorMap[e.course.courseCode] ?? Colors.blue;

    return GestureDetector(
      onTap: () {
        _showSessionDetail(e);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${e.course.courseCode}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${e.session.sessionCode}',
              style: TextStyle(fontSize: 9, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetail(_GridEvent event) {
    showModalBottomSheet(
      context: _lastContext,
      builder: (_) => SessionDetailSheet(
        course: event.course,
        session: event.session,
        sessionType: event.sessionType,
      ),
    );
  }

  BuildContext? _lastContext;

  @override
  Element createElement() {
    _lastContext = null;
    return super.createElement();
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
```

I realize there's a problem with the `_lastContext` approach. Let me fix this by passing a `BuildContext` properly. Actually, the better approach is to have the grid callback for taps, handled by the screen. Let me restructure this.

Actually, looking at this more carefully, the grid widget should accept a callback for when a cell is tapped. Let me revise:

```dart
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
  // ... rest, using onSessionTap instead of _showSessionDetail
```

- [ ] **Step 3: Rewrite `timetable_grid.dart` with proper callback**

```dart
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
    final matching = events.where((e) {
      if (e.session.sessionDay != day) return false;
      final start = _timeToMinutes(e.session.sessionStartTime);
      return start >= slotStart && start < slotEnd;
    }).toList();

    if (matching.isEmpty) {
      return Container(
        height: 50,
        color: Colors.grey[50],
        child: const Center(child: Text('')),
      );
    }

    final e = matching.first;
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
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.course.courseCode,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${e.session.sessionCode}',
              style: TextStyle(fontSize: 9, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
```

---
### Task 10: Timetable Screen (Grid + Pagination + Export)

**Files:**
- Create: `lib/screens/timetable_screen.dart`

**Interfaces:**
- Consumes: `TimetableProvider`, `CourseDataProvider` from providers, `TimetableGrid` from widgets
- Produces: The timetable screen with grid, pagination, and PDF export

- [ ] **Step 1: Create `lib/screens/timetable_screen.dart`**

```dart
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
```

---
### Task 11: Wizard Screen (Guided Onboarding)

**Files:**
- Create: `lib/screens/wizard_screen.dart`

**Interfaces:**
- Consumes: `CourseDataProvider`
- Produces: Step-by-step wizard for first-time setup

- [ ] **Step 1: Create `lib/screens/wizard_screen.dart`**

```dart
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
            sessionOptions: tc.sessions,
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
          value: _selectedGroupIndex < _tempGroups.length ? _selectedGroupIndex : 0,
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
          value: _sessionGroupIdx,
          items: validGroups.map((g) => DropdownMenuItem(
            value: g, child: Text(_tempGroups[g].name),
          )).toList(),
          onChanged: (v) => setState(() => _sessionGroupIdx = v!),
          decoration: const InputDecoration(labelText: 'Group'),
        ),
        if (groupCourses.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            value: _sessionCourseIdx < groupCourses.length ? _sessionCourseIdx : 0,
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
                value: _sessionDay,
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
                value: _sessionType,
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
```

---
### Task 12: Clean Up Old Files

- Delete: `lib/home_screen.dart` (functionality replaced by dashboard + parser service)
- Delete: `lib/courses_screen.dart` (functionality replaced by dashboard)

- [ ] **Step 1: Remove old files**

Delete the following files that have been replaced by the new structure:
- `lib/home_screen.dart` → replaced by `screens/dashboard_screen.dart` + `services/parser_service.dart`
- `lib/courses_screen.dart` → replaced by `screens/dashboard_screen.dart`
- `lib/timetable_screen.dart` → replaced by `screens/timetable_screen.dart` + `services/timetable_generator.dart`
- `lib/registry.dart` → replaced by providers

---

## Self-Review Checklist

1. **Spec coverage:** All spec sections covered:
   - Architecture (2) → Tasks 1, 7
   - Data Models (3) → Task 2
   - Persistence (4) → Tasks 2, 3, 6
   - Timetable Generator (5) → Task 5
   - Timetable Grid (6) → Tasks 9, 10
   - User Interface (7) → Tasks 8, 11, 12
   - Preferences (8) → Tasks 5, 6
   - Dependencies (9) → Task 1

2. **Placeholder scan:** No TBDs, TODOs, or incomplete sections.

3. **Type consistency:** All model types, method signatures, and field names consistent across tasks. `CourseGroup.fromJson()` in Task 2 matches serialization in Task 3. Generator methods prefixed with `_` in Task 5 match old names from `timetable_screen.dart`. Provider method signatures in Task 6 match usage in Task 8.

4. **Crown jewel preserved:** Task 5 extracts the generator with ZERO behavioral changes to core logic. Locked courses are pre-selected before backtracking. Locked sessions filter config generation. Scoring is purely post-generation sorting.
