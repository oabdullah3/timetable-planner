import '../models.dart';

class TimePreferences {
  final int earliestStartMinute; // in minutes from midnight
  final int latestEndMinute;
  final List<String> preferredDays; // "Monday"..."Sunday"
  final bool preferBackToBack; // true = prefer no gaps, false = prefer gaps

  const TimePreferences({
    this.earliestStartMinute = 420, // 7:00 AM default
    this.latestEndMinute = 1260, // 9:00 PM default
    this.preferredDays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ],
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
    final sumMax =
        groups.fold<int>(0, (sum, g) => sum + (g.max ?? g.courses.length));

    if (desired < sumMin || desired > sumMax) {
      return GenerationResult(
        timetables: [],
        error:
            'No timetable possible for $desired courses. Minimum: $sumMin, Maximum: $sumMax',
      );
    }

    // ADDITIVE: handle locked courses — they are mandatory
    final lockedCourses = <CourseGroup, List<Course>>{};
    int lockedCount = 0;
    for (final group in groups) {
      final locked = group.courses.where((c) => c.locked).toList();
      if (locked.isNotEmpty) {
        lockedCourses[group] = locked;
        lockedCount += locked.length;
      }
    }

    final remainingDesired = desired - lockedCount;
    if (remainingDesired < 0) {
      return GenerationResult(
        timetables: [],
        error:
            'More locked courses ($lockedCount) than desired total ($desired).',
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
    final sel = <CourseGroup, Set<Course>>{
      for (var g in groups) g: <Course>{}
    };

    // ADDITIVE: pre-select locked courses into currentTT
    for (final entry in lockedCourses.entries) {
      for (final course in entry.value) {
        final configs = courseConfigs[course] ?? [];
        if (configs.isEmpty) {
          return GenerationResult(
            timetables: [],
            error:
                'Locked course ${course.courseCode} has no valid session configurations.',
          );
        }
        // Pick the first valid config for locked courses
        currentTT.add(SelectedCourse(course: course, sessions: List.from(configs.first)));
        sel[entry.key]!.add(course);
      }
    }

    // Now build the rest with remaining desired count
    // Phase 1: fill minimums, Phase 2: distribute extras across all groups
    // Pass original desired total so terminal case can compute remaining
    _fillMinimums(
        groups, 0, currentTT, sel, courseConfigs, allTimetables, desired);

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

  // Phase 1: Fill minimums for each group, then Phase 2: distribute extras
  // Phase 1: Fill minimums for each group, then Phase 2: distribute extras
  // [desiredTotal] is the original desiredCourses count from the user.
  void _fillMinimums(
    List<CourseGroup> groups,
    int groupIndex,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    List<List<SelectedCourse>> allTimetables,
    int desiredTotal,
  ) {
    if (groupIndex == groups.length) {
      // All minimums filled. Compute remaining extras budget (mirrors original code).
      final remaining = desiredTotal - currentTT.length;
      if (remaining >= 0) {
        _buildExtras(groups, 0, currentTT, selected, configs, allTimetables, remaining);
      }
      return;
    }
    final group = groups[groupIndex];
    final alreadySelected = selected[group]!.length;
    final minReq = (group.min ?? 0) - alreadySelected;
    if (minReq > 0) {
      _buildNCoursesForGroup(
        group,
        minReq,
        currentTT,
        selected,
        configs,
        () => _fillMinimums(groups, groupIndex + 1, currentTT, selected,
            configs, allTimetables, desiredTotal),
      );
    } else {
      // No minimum needed for this group, move to next
      _fillMinimums(groups, groupIndex + 1, currentTT, selected,
          configs, allTimetables, desiredTotal);
    }
  }

  // Phase 2: Distribute remaining courses as extras across all groups
  void _buildExtras(
    List<CourseGroup> groups,
    int groupIndex,
    List<SelectedCourse> currentTT,
    Map<CourseGroup, Set<Course>> selected,
    Map<Course, List<List<Session>>> configs,
    List<List<SelectedCourse>> allTimetables,
    int remaining,
  ) {
    if (groupIndex == groups.length) {
      if (remaining == 0) {
        allTimetables.add(List.from(currentTT));
      }
      return;
    }
    final group = groups[groupIndex];
    final alreadySelected = selected[group]!.length;
    final maxP = group.max ?? group.courses.length;
    final maxExtra = maxP - alreadySelected;
    for (int extra = 0; extra <= maxExtra && extra <= remaining; extra++) {
      _buildNCoursesForGroup(
        group,
        extra,
        currentTT,
        selected,
        configs,
        () => _buildExtras(groups, groupIndex + 1, currentTT, selected,
            configs, allTimetables, remaining - extra),
      );
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

    bool isDigit(String c) =>
        c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
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
