# Timetable Planner — Full UX Redesign

**Date:** 2026-07-28
**Branch:** `feature/ux-redesign`
**Approach:** Approach A — Provider + Storage Abstraction

---

## 1. Purpose

Transform the current Excel-upload timetable tool into a guided, interactive course planner that lets students:
- Add and manage courses, lectures, tutorials, and labs through a custom dashboard
- Set preferences (course priority, time slots, locked must-haves)
- Generate and browse clash-free timetables sorted by preference fit
- View timetables in a familiar grid format (days × time slots)
- Persist all data automatically across sessions (web + desktop)

---

## 2. Architecture

### 2.1 File Structure

```
lib/
├── main.dart                         # App entry, theme
├── app.dart                          # MaterialApp + GoRouter setup
│
├── models/
│   ├── course_group.dart             # CourseGroup (min/max, toJson/fromJson)
│   ├── course.dart                   # Course (preferenceScore, locked, toJson/fromJson)
│   ├── session_group.dart            # SessionGroup (Lecture/Tutorial/Lab)
│   ├── session.dart                  # Session (locked, toJson/fromJson)
│   └── timetable.dart                # SelectedCourse, GeneratedTimetable
│
├── services/
│   ├── storage_service.dart          # Abstract storage + platform impl (web/desktop)
│   ├── parser_service.dart           # Excel parsing (extracted from home_screen)
│   └── timetable_generator.dart      # Core algorithm (extracted, isolated)
│
├── providers/
│   ├── course_data_provider.dart     # Course data state + all CRUD operations
│   ├── timetable_provider.dart       # Generation state, current timetable index
│   └── preferences_provider.dart     # Time preferences (start/end/days/gaps)
│
├── screens/
│   ├── wizard_screen.dart            # Onboarding wizard (first launch / explicit trigger)
│   ├── dashboard_screen.dart         # Main hub: groups, courses, sessions, preferences
│   └── timetable_screen.dart         # Grid view + multi-timetable pagination
│
├── widgets/
│   ├── timetable_grid.dart           # Custom matrix grid (days × time slots)
│   ├── session_cell.dart             # Single cell in the grid (filled or blank)
│   ├── session_detail_sheet.dart     # Bottom sheet on cell tap
│   └── preference_slider.dart        # Reusable slider card for ratings
```

### 2.2 State Management

- **Provider** (`provider` package) with `ChangeNotifier`
- Three providers:
  - `CourseDataProvider` — owns `List<CourseGroup>`, exposes CRUD methods, triggers auto-save
  - `TimetableProvider` — owns generated timetables list, current index, generation trigger
  - `PreferencesProvider` — owns time preferences (start/end/days/gaps)

### 2.3 Routing

- **GoRouter** for declarative routing
- Routes:
  - `/` → DashboardScreen (or WizardScreen if no data)
  - `/wizard` → WizardScreen
  - `/timetable` → TimetableScreen
- Navigation guard: if course data is empty, redirect `/` to `/wizard`

---

## 3. Data Models

### 3.1 CourseGroup
```dart
class CourseGroup {
  String courseType;
  List<Course> courses;
  int? min;
  int? max;

  Map<String, dynamic> toJson();
  factory CourseGroup.fromJson(Map<String, dynamic> json);
}
```

### 3.2 Course
```dart
class Course {
  String courseCode;
  String courseName;
  int preferenceScore;       // 0–5, displayed as stars/slider
  bool locked;               // true = must be in every timetable
  List<SessionGroup> sessionGroups;

  Map<String, dynamic> toJson();
  factory Course.fromJson(Map<String, dynamic> json);
}
```

### 3.3 SessionGroup
```dart
class SessionGroup {
  String sessionType;        // "Lecture", "Tutorial", "Lab"
  List<Session> sessionOptions;

  Map<String, dynamic> toJson();
  factory SessionGroup.fromJson(Map<String, dynamic> json);
}
```

### 3.4 Session
```dart
class Session {
  int crn;
  String sessionCode;        // e.g. "L01", "T01"
  String sessionDay;         // "Monday"–"Sunday"
  String sessionStartTime;   // "HH:MM"
  String sessionEndTime;     // "HH:MM"
  int sessionAvailability;   // seats available
  bool locked;               // lock this specific session slot

  Map<String, dynamic> toJson();
  factory Session.fromJson(Map<String, dynamic> json);
}
```

### 3.5 GeneratedTimetable & SelectedCourse
```dart
class SelectedCourse {
  Course course;
  List<Session> sessions;
}

class GeneratedTimetable {
  List<SelectedCourse> courses;
  int totalScore;            // aggregate preference score
}
```

---

## 4. Persistence Strategy

### 4.1 Storage Service Abstraction

```dart
abstract class StorageService {
  Future<void> save(String key, String jsonData);
  Future<String?> load(String key);
  Future<void> delete(String key);
}

class DesktopStorageService implements StorageService { /* file in app data dir */ }
class WebStorageService implements StorageService { /* localStorage via dart:html */ }
```

### 4.2 Auto-Save Flow

1. `CourseDataProvider` calls a method on every mutation (add/edit/delete course, change slider, toggle lock)
2. Mutation is debounced 1 second before serialization
3. Serialized JSON → `StorageService.save('course_data', json)`
4. On app start → `StorageService.load('course_data')` → deserialize → hydrate provider
5. Platform detection via `kIsWeb` from `foundation.dart`

### 4.3 JSON Schema

The saved JSON mirrors the model hierarchy:
```json
{
  "courseGroups": [
    {
      "courseType": "Core",
      "min": 2,
      "max": 4,
      "courses": [
        {
          "courseCode": "CS101",
          "courseName": "Programming",
          "preferenceScore": 4,
          "locked": false,
          "sessionGroups": [
            {
              "sessionType": "Lecture",
              "sessionOptions": [
                {
                  "crn": 1001,
                  "sessionCode": "L01",
                  "sessionDay": "Monday",
                  "sessionStartTime": "10:00",
                  "sessionEndTime": "11:30",
                  "sessionAvailability": 50,
                  "locked": false
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 5. Timetable Generator (Core Algorithm)

### 5.1 Isolation

The generator is extracted from `timetable_screen.dart` into its own `services/timetable_generator.dart` file with zero behavioral changes. It receives clean inputs and returns clean outputs.

### 5.2 Input
```dart
class GenerationRequest {
  List<CourseGroup> groups;
  int desiredCourses;
  TimePreferences? timePreferences;  // optional scoring params
}
```

### 5.3 Output
```dart
class GenerationResult {
  List<GeneratedTimetable> timetables;  // sorted by score descending
  String? error;
}
```

### 5.4 Additive Changes (beyond extraction)

1. **Locked courses**: pre-select locked courses before backtracking begins — they become fixed members of every timetable
2. **Locked sessions**: when generating configs for a locked course, only the locked session configs are considered
3. **Preference scoring**: after all valid timetables are generated, each is scored and sorted — no impact on generation logic
4. **Time preferences**: penalty-based scoring applied post-generation (deductions for early/late sessions, undesired days, unwanted gaps)

The clash detection, backtracking (`buildMinimums`, `buildExtras`, `buildNCoursesForGroup`), `hasInternalClash`, `hasClashWithTT`, `sessionsClash`, and `timeToMinutes` functions remain **untouched** in their extracted form.

---

## 6. Timetable Grid (Visual)

### 6.1 Layout

- Matrix with time slots as rows (left column) and days (Mon–Sun) as column headers
- First row: "Time" | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
- 1-hour rows from earliest to latest start time across all sessions
- Sessions occupying multiple rows (rowspan) when they span >1 hour
- Empty cells shown as blank/light grey
- Each course assigned a consistent color; all its sessions share that color

### 6.2 Interaction

- **Tap session cell**: opens `SessionDetailSheet` (bottom sheet) showing:
  - Course code & name
  - Session type (Lecture/Tutorial/Lab)
  - Section code + CRN
  - Time span
- **Multi-timetable navigation**: pagination dots or arrows at bottom, one timetable per page
- **Export**: PDF generation preserved and updated for grid layout

### 6.3 Implementation

Custom `Table`-based widget (`TimetableGrid`) using `LayoutBuilder` for responsive sizing. `rowspan` handled via Flutter's `TableCell` vertical spanning.

---

## 7. User Interface Flow

### 7.1 Empty State → Wizard

First launch (no saved data) or explicit "Run Wizard" trigger:
1. Welcome screen explaining the app's purpose
2. Step 1: Create course groups (name + min/max)
3. Step 2: Add courses to each group
4. Step 3: Add sessions (lectures/tutorials) to each course
5. Step 4: Set preferences (course sliders + time preferences)
6. Step 5: "Generate Timetables" → takes user to the grid

### 7.2 Dashboard (Post-Wizard)

Main hub showing:
- All course groups as expandable cards
- Inside each group: course list with preference stars + lock icon
- Expand course → see/add/edit sessions
- Top bar: "Run Wizard" button (subtle), "Import Excel" (subtle)
- "Generate Timetables" button at bottom

### 7.3 CRUD Operations

- Add Group/Course/Session via forms/dialogs
- Edit via pre-filled form dialog
- Delete with confirmation dialog
- Excel import moved to a niche option (file menu or settings)

### 7.4 Excel Import (Niche)

- Accessible from a small text link or overflow menu in the top bar
- "Import from Excel" → file picker → parse → merge with existing data or replace
- Inform user of what was parsed

---

## 8. Preferences & Scoring

### 8.1 Course Preferences
- 0–5 star/slider per course in the dashboard
- 0 = No preference, 5 = Must-have
- Locked toggle overrides preference (hard constraint)

### 8.2 Time Preferences (Global)
- Earliest acceptable start time (slider)
- Latest acceptable end time (slider)
- Preferred days (toggle Mon–Sun)
- Gap preference (back-to-back vs gaps)

### 8.3 Scoring Formula
- Base score = sum of preference scores of included courses
- Penalties deducted for:
  - Sessions starting before earliest start time
  - Sessions ending after latest end time
  - Sessions on undesired days
- Result: timetables sorted by score descending
- All valid timetables are still shown (filter-based, not hard constraints)

---

## 9. Dependencies Added

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `go_router` | Declarative routing |
| `shared_preferences` | Desktop key-value storage |
| `path_provider` | Desktop file paths |

Existing dependencies retained: `file_picker`, `excel`, `pdf`, `printing`.

---

## 10. Out of Scope (for this phase)

- Drag-and-drop timetable editing
- Real-time timetable sharing / multi-user
- Integration with university APIs
- Mobile-specific responsive breakpoints (web + desktop only)
- Push notifications
