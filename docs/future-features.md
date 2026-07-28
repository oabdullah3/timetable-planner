# Future Feature Ideas

Ideas scoped out but not yet scheduled for implementation. Listed in rough priority order.

---

## Import Warning Dialog

**Problem:** When importing an Excel file, the current dashboard data gets overwritten with no warning. Users may accidentally lose their work.

**Proposed solution:**
- Before the Excel import proceeds, show a confirmation dialog:
  > "Importing an Excel file will **replace all current data** in your dashboard. This cannot be undone. Continue?"
  - Options: "Cancel" / "Continue"
- After successful import, show a brief snackbar: "Imported X groups with Y courses from Excel."

**Affected components:**
- `screens/dashboard_screen.dart` — add dialog before `_importExcel()` executes the parser

**Problem:** Users can import data via Excel, but there's no way to export their dashboard data for backup or sharing.

**Proposed solution:**
- Add "Export as JSON" option (⋮ menu) — serializes current `List<CourseGroup>` to a downloadable JSON file (web: browser download; desktop: file save dialog)
- Add "Export as Excel" option — generates an `.xlsx` file matching the import schema, so exported data can be re-imported or opened in spreadsheet software

**Affected components:**
- `screens/dashboard_screen.dart` — add export menu items
- New `services/exporter_service.dart` — JSON and Excel export logic
- Reuse `excel` package (already imported) for Excel export

---

## Onboarding Guide / Tooltips

**Problem:** New users don't know what each button/feature does — lock icon, preference stars, min/max fields, etc.

**Proposed solution:**
- Add an "Instructions" or "How-To" page accessible from the dashboard app bar (ℹ️ icon)
- Or add tooltip text (`Tooltip` widget) on key UI elements explaining each one
- Or both: tooltips for at-a-glance help + a dedicated instructions page with scenarios

**Suggested content for the guide:**

| Feature | Explanation |
|---------|-------------|
| **Course Group** | A category of courses (e.g. "Core", "Elective"). Groups help you organize and set rules. |
| **Min / Max** | Minimum and maximum number of courses the generator MUST/MAY pick from this group. E.g. "Core Min=2" means at least 2 core courses in every timetable. |
| **Preference Stars** | Rate how much you want a course (0 = no preference, 5 = must-have). Higher-rated courses appear in earlier timetables. |
| **Lock 🔒** | Forces a course or session to ALWAYS be included in every generated timetable. Use for pre-enrolled courses. |
| **Session Type** | Each course can have multiple session types (Lecture, Tutorial, Lab). The generator picks ONE from each type. |
| **Session Code** | Section identifier (e.g. L01, T02). The last character can indicate pairings — L01 often pairs with T01. |
| **Generate** | Finds all valid clash-free timetables given your courses, preferences, and locks. Results are sorted best-first. |
| **Paginated Grid** | Browse through alternative timetables using the arrows. Each page is one complete schedule. |

**Implementation options:**
- A dedicated `/guide` route with the full documentation
- A `Tooltip` widget wrapping each icon/button in the dashboard
- A "Quick Start" dialog that appears on first use (in addition to the wizard)

---

## Session Binding Groups

**Problem:** Some courses require specific lecture-tutorial pairings (e.g. Lecture L01 must enroll in Tutorial T01). The current system only has a heuristic check (`isSessionCodesConsistent`) that verifies second-character code matching.

**Proposed solution:**
- Add an optional `bindingGroup` string field to `Session`
- Sessions with the same `bindingGroup` value are treated as a unit — the generator picks all or none
- Sessions without a `bindingGroup` behave as today (independent selection)
- UI: a text/badge input on session forms: "Binding Group (optional): [A]"

**Affected components:**
- `models/session.dart` — add `bindingGroup` field (nullable String)
- `services/timetable_generator.dart` — `_generateConfigs` needs to group bound sessions
- `screens/dashboard_screen.dart` — add binding group field to session add/edit dialog
- `screens/wizard_screen.dart` — add binding group field to session step
- `models/session_group.dart` — no changes needed (binding is cross-group)

---

## Drag-to-Reorder Preferences

**Problem:** Clicking stars (0-5) is functional but less intuitive than drag-to-reorder for ranking courses.

**Proposed solution:** Replace star-based preference with a reorderable list per group where users drag courses into priority order.

---

## Visual Grid PDF Export

**Problem:** PDF export is currently a text list grouped by day. A proper grid layout would be more useful for printing.

**Proposed solution:** Use the `pdf` package's Table widget to render the same matrix grid as the on-screen `TimetableGrid`.

---

## Time Preference Persistence

**Problem:** Time preferences are stored in-memory via `PreferencesProvider` but not persisted to disk. They reset on app restart.

**Proposed solution:** Add time preferences to the `StorageService` JSON alongside course data.

---

## Mobile-Responsive Layouts

**Problem:** The timetable grid and dashboard are designed for web/desktop screens. On smaller mobile screens, they may overflow or be unusable.

**Proposed solution:** Add responsive breakpoints and alternative layouts for mobile widths.
