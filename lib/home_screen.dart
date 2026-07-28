import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';

import 'models.dart';
import 'registry.dart';
import 'courses_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  String? _error;

  // --- small helpers ---------------------------------------------------------

  String? _cellStr(Data? d) {
    if (d == null || d.value == null) return null;
    final v = d.value;
    if (v is num) {
      final asInt = (v as num?)?.toInt() ?? 0;
      return (v == asInt) ? asInt.toString() : v.toString();
    }
    return v.toString();
  }

  int? _cellInt(Data? d) {
    final s = _cellStr(d);
    if (s == null) return null;
    final digits = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)).join();
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Normalize header names like "Session CRN", "session_crn" -> "sessioncrn"
  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _findColIndex(List<Data?> headerRow, List<String> wanted) {
    final normalizedHeader =
        headerRow.map((c) => _norm(_cellStr(c) ?? '')).toList();
    for (final w in wanted) {
      final idx = normalizedHeader.indexOf(_norm(w));
      if (idx != -1) return idx;
    }
    // not found; return -1 so we can handle optional columns gracefully
    return -1;
  }

  (String, String) _splitTime(String? timeCell) {
    if (timeCell == null) return ('', '');
    final m = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(timeCell);
    if (m == null) return ('', '');
    return (m.group(1) ?? '', m.group(2) ?? '');
  }

  // --------------------------------------------------------------------------

  Future<void> _pickAndParseExcel() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // IMPORTANT for Web
      );
      if (result == null) {
        setState(() => _loading = false);
        return;
      }

      final picked = result.files.single;
      final excelBytes = picked.bytes ?? File(picked.path!).readAsBytesSync();
      final excel = Excel.decodeBytes(excelBytes);

      // We’ll collect into maps to avoid mis-grouping
      final Map<String, CourseGroup> groups = {}; // courseType -> group
      final Map<String, Map<String, Course>> coursesByGroup = {}; // courseType -> (courseCode -> course)
      final Map<String, Map<String, SessionGroup>> sessionsByCourseKey =
          {}; // courseKey -> (sessionType -> sg)

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName]!;
        if (sheet.rows.isEmpty) continue;

        // --- header detection
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
        final colAvailability =
            _findColIndex(header, ['Session Availability', 'Availability']);

        // state we carry forward for merged cells
        String lastCourseType = '';
        String lastCourseCode = '';
        String lastCourseName = '';
        String lastSessionType = '';
        int lastCourseMin = 0;
        int lastCourseMax = 0;

        for (final row in sheet.rows.skip(1)) {
          // Skip completely empty rows
          final allEmpty = row.every((c) => (_cellStr(c) ?? '').trim().isEmpty);
          if (allEmpty) continue;

          // Carry-forward strategy to handle merged cells
          final courseType =
              (colCourseType >= 0 ? _cellStr(row[colCourseType]) : null)?.trim();
          final courseMin =
              (colCourseMin >= 0 ? _cellInt(row[colCourseMin]) : null);
          final courseMax =
              (colCourseMax >= 0 ? _cellInt(row[colCourseMax]) : null);
          final courseCode =
              (colCourseCode >= 0 ? _cellStr(row[colCourseCode]) : null)?.trim();
          final courseName =
              (colCourseName >= 0 ? _cellStr(row[colCourseName]) : null)?.trim();
          final sessionType =
              (colSessionType >= 0 ? _cellStr(row[colSessionType]) : null)?.trim();

          final theCourseType =
              (courseType != null && courseType.isNotEmpty) ? courseType : lastCourseType;
          final theCourseCode =
              (courseCode != null && courseCode.isNotEmpty) ? courseCode : lastCourseCode;
          final theCourseName =
              (courseName != null && courseName.isNotEmpty) ? courseName : lastCourseName;
          final theSessionType =
              (sessionType != null && sessionType.isNotEmpty) ? sessionType : lastSessionType;
          final theCourseMin =
              (courseMin != null && courseMin >= 0) ? courseMin : lastCourseMin;
          final theCourseMax =
              (courseMax != null && courseMax >= 0) ? courseMax : lastCourseMax;

          // Update carry-forwards
          if (theCourseType.isNotEmpty) lastCourseType = theCourseType;
          if (theCourseCode.isNotEmpty) lastCourseCode = theCourseCode;
          if (theCourseName.isNotEmpty) lastCourseName = theCourseName;
          if (theSessionType.isNotEmpty) lastSessionType = theSessionType;
          if (theCourseMin >= 0) lastCourseMin = theCourseMin;
          if (theCourseMax >= 0) lastCourseMax = theCourseMax;

          if (theCourseType.isEmpty || theCourseCode.isEmpty) {
            // Not enough info; skip row safely
            continue;
          }

          // Ensure CourseGroup
          groups.putIfAbsent(
            theCourseType,
            () => CourseGroup(courseType: theCourseType, courses: [], min: theCourseMin, max: theCourseMax),
          );
          coursesByGroup.putIfAbsent(theCourseType, () => {});
          final coursesMap = coursesByGroup[theCourseType]!;

          // Ensure Course
          coursesMap.putIfAbsent(
            theCourseCode,
            () => Course(
              courseCode: theCourseCode,
              courseName: theCourseName,
              sessionGroups: [],
            ),
          );
          // If name shows up later, keep the first non-empty or update if ours is empty
          final existingCourse = coursesMap[theCourseCode]!;
          if (existingCourse.courseName.isEmpty && theCourseName.isNotEmpty) {
            coursesMap[theCourseCode] = Course(
              courseCode: existingCourse.courseCode,
              courseName: theCourseName,
              sessionGroups: existingCourse.sessionGroups,
            );
          }

          // Ensure SessionGroup (by course+type)
          final courseKey = '$theCourseType::$theCourseCode';
          sessionsByCourseKey.putIfAbsent(courseKey, () => {});
          final sgMap = sessionsByCourseKey[courseKey]!;

          if (theSessionType.isNotEmpty) {
            sgMap.putIfAbsent(
              theSessionType,
              () => SessionGroup(sessionType: theSessionType, sessionOptions: []),
            );
          }

          // Build Session if CRN present
          final crn = colCRN >= 0 ? _cellInt(row[colCRN]) : null;
          if (crn != null) {
            final code = colSessionCode >= 0 ? (_cellStr(row[colSessionCode]) ?? '') : '';
            final day = colSessionDay >= 0 ? (_cellStr(row[colSessionDay]) ?? '') : '';
            final timeCell = colSessionTime >= 0 ? _cellStr(row[colSessionTime]) : null;
            final (startTime, endTime) = _splitTime(timeCell);
            final availability =
                colAvailability >= 0 ? (_cellInt(row[colAvailability]) ?? 0) : 0;

            final sgKey = theSessionType.isEmpty ? 'Session' : theSessionType;
            sgMap.putIfAbsent(
              sgKey,
              () => SessionGroup(sessionType: sgKey, sessionOptions: []),
            );
            sgMap[sgKey]!.sessionOptions.add(
              Session(
                crn: crn,
                sessionCode: code,
                sessionDay: day,
                sessionStartTime: startTime,
                sessionEndTime: endTime,
                sessionAvailability: availability,
              ),
            );
          }
        }
      }

      // Stitch maps back into ordered lists
      final List<CourseGroup> resultGroups = [];
      for (final entry in groups.entries) {
        final type = entry.key;
        final courseMap = coursesByGroup[type] ?? {};
        final courses = courseMap.values.toList();
        final min = entry.value.min;
        final max = entry.value.max;

        // attach sessionGroups from sessionsByCourseKey
        for (final c in courses) {
          final ck = '$type::${c.courseCode}';
          final sgMap = sessionsByCourseKey[ck] ?? {};
          c.sessionGroups
            ..clear()
            ..addAll(sgMap.values.toList());
        }

        // sort (optional, for nicer UI)
        courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
        resultGroups.add(CourseGroup(courseType: type, courses: courses, min: min, max: max));
      }

      // (optional) sort groups by name for stable display
      resultGroups.sort((a, b) => a.courseType.compareTo(b.courseType));

      Registry().setCourseGroups(resultGroups);

      if (mounted) {
        setState(() => _loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoursesScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Course Planner"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndParseExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload Excel File"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
