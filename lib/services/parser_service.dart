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
