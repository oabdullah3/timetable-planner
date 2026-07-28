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
