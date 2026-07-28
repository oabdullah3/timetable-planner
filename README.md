# Course Planner — Timetable Visualizer

> Planning a timetable is a real pain — juggling course codes, lecture sections, tutorial slots, and lab sessions across different days while trying to avoid clashes is tedious and error-prone. I built this tool so I (and anyone else dealing with course enrollment) can quickly visualize their options, pick the sessions that fit, and export a clean timetable without the headache.

## Quick Start

### 1. Install Flutter

Check out [https://docs.flutter.dev/install/quick](https://docs.flutter.dev/install/quick)

Verify install with:

```bash
flutter --version
```

### 2. Get dependencies

```bash
flutter pub get
```

### 3. Launch the app

```bash
flutter run
```

This will list available devices. Pick one:

| Platform | Command |
|----------|---------|
| Windows desktop | `flutter run -d windows` |
| Web (Chrome) | `flutter run -d chrome` |
| Android emulator | `flutter run -d android` |
| iOS simulator (macOS) | `flutter run -d ios` |

> **Note:** The `dummy_courses.xlsx` file in the project root is sample data to test with.

## How to Use

1. **Launch the app** — you'll see an "Upload Excel File" button.
2. **Upload your courses** — the app expects an `.xlsx` file with these columns:

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

3. **Review your courses** — courses are grouped by type. Expand each to see sessions.
4. **Enter your target** — type how many courses you want to take and hit **Generate**.
5. **View your timetable** — the app builds a clash-free schedule from your available sessions.

## Project Structure

| File | Purpose |
|------|---------|
| [lib/main.dart](lib/main.dart) | App entry point |
| [lib/home_screen.dart](lib/home_screen.dart) | Excel upload screen |
| [lib/courses_screen.dart](lib/courses_screen.dart) | Course browser & generator |
| [lib/timetable_screen.dart](lib/timetable_screen.dart) | Timetable visualization |
| [lib/models.dart](lib/models.dart) | Data models |
| [lib/registry.dart](lib/registry.dart) | Shared state |
