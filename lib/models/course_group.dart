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
