# Future Feature Ideas

Ideas scoped out but not yet scheduled for implementation. Listed in rough priority order.

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
