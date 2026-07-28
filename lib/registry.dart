import 'models.dart';

class Registry {
  static final Registry _instance = Registry._internal();
  factory Registry() => _instance;

  Registry._internal();

  final List<CourseGroup> _courseGroups = [];

  List<CourseGroup> get courseGroups => _courseGroups;

  void setCourseGroups(List<CourseGroup> groups) {
    _courseGroups
      ..clear()
      ..addAll(groups);
  }
}
