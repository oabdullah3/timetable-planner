import 'package:flutter/material.dart';
import '../services/timetable_generator.dart';

class PreferencesProvider extends ChangeNotifier {
  TimePreferences _preferences = const TimePreferences();

  TimePreferences get preferences => _preferences;

  void setEarliestStart(int minutes) {
    _preferences = TimePreferences(
      earliestStartMinute: minutes,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void setLatestEnd(int minutes) {
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: minutes,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void toggleDay(String day) {
    final days = List<String>.from(_preferences.preferredDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: days,
      preferBackToBack: _preferences.preferBackToBack,
    );
    notifyListeners();
  }

  void setGapPreference(bool preferBackToBack) {
    _preferences = TimePreferences(
      earliestStartMinute: _preferences.earliestStartMinute,
      latestEndMinute: _preferences.latestEndMinute,
      preferredDays: _preferences.preferredDays,
      preferBackToBack: preferBackToBack,
    );
    notifyListeners();
  }
}
