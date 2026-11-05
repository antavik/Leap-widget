# Workflow Summary — A-79

- **Run:** 2026-11-05 ~21:20 CET, autonomous multi-agent workflow
- **Issue:** [A-79](https://linear.app/insta21/issue/A-79/two-months-widget-shows-wrong-year-on-january-when-set-to-next-in) — Two Months widget shows wrong year on January when set to Next in December (Bug, High)
- **Branch:** `antavik/a-79-two-months-widget-shows-wrong-year-on-january-when-set-to` (worktree `antavik-a-79-two-months-widget-shows-wrong-year-on-january-when-set-to`, base `origin/main` @ ba2f678)
- **PR:** https://github.com/antavik/Leap-widget/pull/2 (draft) — commit e76a144
- **Linear:** In Progress → In Review, comment with PR link posted

## Final plan (approved, v2)

Bug: `monthRow` derived ONE year label from the offset-0 month; `MultiMonthView` pinned it to the LAST displayed month → December + Companion.next rendered "JANUARY ’26" for January 2027, and December never carried a label.

Fix: per-month year labels in the functional core.
- New public `YearLabel(text:isCurrent:)` (Equatable, Sendable) in `MonthRow.swift`.
- `monthRow` → `(models: [MonthModel], yearLabels: [YearLabel?])`, index-parallel.
  - Spanning row (a model's year ≠ reference month's year; for consecutive offsets that IS the Dec–Jan case, and generalizes per-calendar) → every month labeled with its own year; `isCurrent = (model.year == currentYear)`.
  - Non-spanning → unchanged: nil except LAST index, current label.
  - Formatting per model: gregorian → `yearLabel(forYear:)` ("’26"), else `String(year)`.
- Views: `MonthGridView` overlay `isCurrent ? .red : .secondary` (week numbers' grey); `MultiMonthView`/`CalendarSurface` per-index plumbing; `CalendarEntryModel.yearLabels`; app + widget extension migrated.
- Goldens: only 20-medium-december-week-numbers and 27-medium-previous-companion-january re-recorded.
- Follow-up commit 8c7f7bb (user request): new dark-scheme goldens 33-medium-december-dark and 34-medium-previous-companion-january-dark pin the spanning labels on dark; recorded fresh, no existing golden moved.

## TDD evidence

- Task 1 (implementation): @test wrote `YearLabelRowTests.swift` + pixel render test first. RED = build failure (missing `YearLabel`/`yearLabels` API) — correct for a compile-atomic Swift API change; baseline before test files was green (138 tests). @make implemented to GREEN.
  - Escalation 1 (@test → @check): pixel-test review; strict grey-vs-week-number colour-equality assertion judged flake-prone → deleted; grey-class (channel spread ≤24) + red/no-red checks kept; goldens remain the shade oracle.
  - Escalation 2 (@make → @test): buddhist fixture built the December date from Gregorian-era components on a buddhist calendar (got 2026/2027 instead of 2569/2570) → fixed; lint fixes (parameter alignment; pixel test moved to new `YearLabelColorTests.swift` for file_length ≤500).
- Task 2 (verification): golden re-record — SnapshotTests 20/27 mismatch was the RED, green after `make snapshots-record`; exactly those two goldens + toolchain.txt moved.
- Post-review cleanups (@simplify, trivial): removed unused `Pixel.x`, removed redundant `thePreviousCompanionInsideOneYearStillLabelsTheLastMonth` unit test.

## Verification

- `make test`: GREEN — 148 tests / 21 suites (after cleanups) + L0 consistency scripts.
- `swiftlint lint --strict --quiet`: clean.
- `xcodebuild build-for-testing` + `test-without-building -only-testing:LeapWidgetTests` (Debug, isolated `build/` derivedDataPath, debug app `lsregister -u`'d afterwards per project rule): TEST EXECUTE SUCCEEDED.
- `make ui-test` (L4, takes over the screen): NOT run in autonomous session — recommended before merge.

## Review outcomes

- Plan review: cycle 1 @check NEEDS WORK (spanning scope, `isCurrent` semantics, colour-test strength, plumbing coverage) + @simplify NEEDS WORK (public API, parallel arrays, test bloat, task ceremony). Cycle 2: @check ACCEPTABLE, @simplify JUSTIFIED COMPLEXITY. Conflicts resolved by merge rules (@check won on keeping buddhist test + colour verification; @simplify won on test cuts; public YearLabel + parallel array justified by module boundaries and builder's lack of row context).
- Final review: @check ACCEPTABLE (1 MEDIUM — widget target uncompiled — closed in-session via build-for-testing + LeapWidgetTests run), @simplify ACCEPTABLE (3 low-payoff findings: 2 applied, MultiMonthView defensive indexing kept as-is because `first ?? nil` is a type-level flatten and the bounds check guards mismatched arrays from independent test callers).
- Unresolved blockers: none.

## Files changed (18)

Sources: LeapCore MonthRow.swift, MonthGridView.swift, MultiMonthView.swift, CalendarSurface.swift, Timeline.swift; LeapWidget/CalendarWidgetView.swift; Leap/AppDelegate+Menu.swift.
Tests: new YearLabelRowTests.swift, YearLabelColorTests.swift; migrated CalendarMathTests, TimelineTests, ConfigurationChangeTests, LayoutInvariantTests, GoldenCase, WidgetViewRenderTests; goldens 20 + 27 + toolchain.txt.
