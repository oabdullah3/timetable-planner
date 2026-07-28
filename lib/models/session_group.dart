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
