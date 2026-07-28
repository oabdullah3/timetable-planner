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
}

class Course {
  final String courseCode;
  final String courseName;
  final List<SessionGroup> sessionGroups;

  Course({
    required this.courseCode,
    required this.courseName,
    required this.sessionGroups,
  });
}

class SessionGroup {
  final String sessionType;
  final List<Session> sessionOptions;

  SessionGroup({
    required this.sessionType,
    required this.sessionOptions,
  });
}

class Session {
  final int crn;
  final String sessionCode;
  final String sessionDay;
  final String sessionStartTime;
  final String sessionEndTime;
  final int sessionAvailability;

  Session({
    required this.crn,
    required this.sessionCode,
    required this.sessionDay,
    required this.sessionStartTime,
    required this.sessionEndTime,
    required this.sessionAvailability,
  });
}
