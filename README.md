# Course Planner — Timetable Optimizer

> Juggling multiple courses with overlapping lectures, tutorials, and labs is a pain. This tool lets you add all your course options, set your preferences, and instantly see every possible clash-free timetable sorted by what works best for you.

## How It Works

1. **Add your courses** — via the guided wizard, the dashboard, or import from Excel
2. **Set preferences** — star-rating for must-have courses, lock specific sessions, configure time preferences
3. **Generate** — the engine finds every valid combination and ranks them best-first
4. **Browse** — flip through timetable grids, tap sessions for details, export to PDF

---

## Quick Start

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (the app targets Dart SDK `^3.8.1`)
- Chrome (for web) or a desktop platform (Windows/macOS/Linux)

### Launch

```bash
# Get dependencies
flutter pub get

# Web (use fixed port so localStorage persists between restarts)
flutter run -d chrome --web-port 8080

# Windows desktop
flutter run -d windows

# macOS desktop
flutter run -d macos

# Linux desktop
flutter run -d linux
```

### Run Tests

```bash
# All tests
flutter test

# By phase (recommended during development)
flutter test test/unit/generator/   # Constraint, lock, clash, scoring tests
flutter test test/unit/models/      # Serialization roundtrip tests
flutter test test/unit/services/    # Excel parser tests
```

---

## First-Time Use

On first launch (no saved data), you'll see a **4-step Setup Wizard**:

| Step | What to do |
|------|-----------|
| **1. Course Groups** | Create categories like "Core" or "Elective". Set min/max rules — e.g. at least 2 core courses, at most 4. |
| **2. Add Courses** | Add course codes and names to each group. |
| **3. Add Sessions** | Add lecture/tutorial/lab time slots with day, time, and CRN. |
| **4. Review & Finish** | Check your data and save. You'll be taken to the dashboard. |

> You can re-run the wizard anytime via the ⋮ menu in the dashboard.

---

## Dashboard Guide

The dashboard is your main workspace. Here's what everything does:

### Course Groups

Groups are containers like "Core" or "Elective" that help organize courses.

- **Min** — Minimum number of courses the generator MUST pick from this group
- **Max** — Maximum number of courses the generator MAY pick from this group
- ✏️ Edit a group's name or min/max
- ❎ Delete a group and all its courses

### Courses

Inside each group, courses are listed with controls:

- ⭐ **Preference stars** (0–5) — Rate how much you want this course. Higher-rated courses appear first in generated timetables. 0 = no preference, 5 = must-have.
- 🔒 **Lock** — Forces this course to ALWAYS appear in every generated timetable. Use for pre-enrolled courses.
- ❎ Delete a course
- Expand a course to see and manage its sessions

### Sessions

Each course can have multiple session types (Lecture, Tutorial, Lab). The generator picks **one session from each type**.

- 🔒 **Lock a session** — If that course is selected, this specific session slot is forced. (The course itself remains optional unless it's also locked.)
- ❎ Delete a session
- "Add Session" to add more time slots

### Time Preferences 🎛️

Tap the 🎛️ icon in the app bar to configure:

| Setting | What it does |
|---------|-------------|
| **Earliest Start Time** | Penalizes sessions starting before this time |
| **Latest End Time** | Penalizes sessions ending after this time |
| **Preferred Days** | Toggle days on/off — sessions on non-preferred days get penalties |
| **Prefer Back-to-Back** | Penalizes gaps between sessions on the same day (when on), or rewards gaps (when off) |

### Generation

Tap "Generate Timetables" at the bottom of the dashboard, enter your target course count, and the engine finds every valid combination. Results are sorted by:

1. **Fewest preference violations** — timetables that respect your time/day settings come first
2. **Lowest time penalty** — among equal-violation options, the one with milder penalties wins
3. **Highest course preference** — tiebreaker

Browse through alternative timetables using the arrows on the grid screen.

---

## Excel Import

> This is a secondary feature for bulk import. The dashboard and wizard are the primary way to enter data.

The app accepts `.xlsx` files with these columns:

| Column | Example | Description |
|--------|---------|-------------|
| `Course Type` | Core / Elective | Groups courses together |
| `Min` / `Max` | 2 / 4 | Min/max courses to take from this group |
| `Course Code` | CS101 | Unique course identifier |
| `Course Name` | Intro to Programming | Full course title |
| `Session Type` | Lecture / Tutorial / Lab | Type of session |
| `Session CRN` | 1001 | Unique session number |
| `Session Code` | L01 | Section code |
| `Session Day` | Monday | Day of the week |
| `Session Time` | 10:00 - 11:30 | Start and end time |
| `Availability` | 50 | Seats available |

Rows with merged/empty cells are supported — the parser carries values forward.

Import via the ⋮ menu → "Import Excel". A sample file `dummy_courses.xlsx` is included in the project root.

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # GoRouter + theme
├── models.dart                  # Barrel export
├── models/
│   ├── course_group.dart        # CourseGroup with min/max
│   ├── course.dart              # Course with preferenceScore, locked
│   ├── session_group.dart       # SessionGroup (Lecture/Tutorial/Lab)
│   ├── session.dart             # Session with locked, serialization
│   └── timetable.dart           # SelectedCourse, TimetableScore, GeneratedTimetable
├── services/
│   ├── storage_service.dart      # Auto-save via SharedPreferences
│   ├── parser_service.dart       # Excel parsing
│   └── timetable_generator.dart  # Core algorithm (clash detection, backtracking, scoring)
├── providers/
│   ├── course_data_provider.dart # CRUD + auto-save
│   ├── preferences_provider.dart # Time/time preferences
│   └── timetable_provider.dart   # Generation state + pagination
├── screens/
│   ├── dashboard_screen.dart     # Main CRUD hub
│   ├── wizard_screen.dart        # 4-step onboarding wizard
│   └── timetable_screen.dart     # Grid view + pagination + PDF export
└── widgets/
    ├── timetable_grid.dart       # Days × time slots matrix
    └── session_detail_sheet.dart  # Session info bottom sheet

test/
└── unit/
    ├── generator/
    │   ├── constraints_test.dart  # Min/max, count validation
    │   ├── locks_test.dart        # Locked courses/sessions
    │   ├── clash_test.dart        # Overlap detection
    │   └── scoring_test.dart      # Preference scoring + sort
    ├── models/
    │   └── serialization_test.dart # JSON roundtrip
    └── services/
        └── parser_test.dart       # Excel parsing
```
