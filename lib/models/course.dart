import 'session_group.dart';
import '../utils/abbreviation.dart';

class Course {
  final String courseCode;
  final String courseName;
  final int preferenceScore;
  final bool locked;
  final String note;
  final List<SessionGroup> sessionGroups;

  Course({
    required this.courseCode,
    required this.courseName,
    this.preferenceScore = 0,
    this.locked = false,
    this.note = '',
    required this.sessionGroups,
  });

  /// Auto-derived abbreviation of the course name (e.g. "CCHP"), falling back
  /// to the course code when the name can't be abbreviated.
  String get abbreviation => courseAbbreviation(courseName, fallback: courseCode);

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'preferenceScore': preferenceScore,
    'locked': locked,
    'note': note,
    'sessionGroups': sessionGroups.map((sg) => sg.toJson()).toList(),
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    courseCode: json['courseCode'] as String,
    courseName: json['courseName'] as String? ?? '',
    preferenceScore: json['preferenceScore'] as int? ?? 0,
    locked: json['locked'] as bool? ?? false,
    note: json['note'] as String? ?? '',
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
    String? note,
    List<SessionGroup>? sessionGroups,
  }) => Course(
    courseCode: courseCode ?? this.courseCode,
    courseName: courseName ?? this.courseName,
    preferenceScore: preferenceScore ?? this.preferenceScore,
    locked: locked ?? this.locked,
    note: note ?? this.note,
    sessionGroups: sessionGroups ?? this.sessionGroups,
  );
}
