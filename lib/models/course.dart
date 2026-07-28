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
