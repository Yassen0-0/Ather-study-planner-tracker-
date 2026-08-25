# AI-Slop Audit

Phase 1, read-only. Repo at commit `d8ff4e022b1a96571201eb2b3ef74bf75a534657`.

Scope swept: every hand-written `.dart` under `lib/`, `test/`, `tool/` plus root scripts (`tool/check_invariants.sh`, `tool/*.py`). Generated files excluded per brief (`*.g.dart`, `lib/core/l10n/generated/*`, `tool/render/*` outputs, android build outputs). `wt-session-a/` and `wt-session-b/` are untracked, gitignored worktree snapshots (untracked deliberately by commit `3245385`) — treated as out of scope.

Method: systematic greps (TODO/FIXME/HACK/XXX/WIP, `print(`, emoji ranges, `====` section markers, "for now"/placeholder/stub, commented-out statements, generic identifier names, duplicated imports, orphan private symbols via cross-tree reference counting), followed by context reads of every hit. Sample-reads performed in full: `main.dart`, `app_shell.dart`, `exam_entry_screen.dart`, `dashboard_screen.dart`, `settings_screen.dart`, `icon_motion.dart`, `day_picker.dart`, `ather_icons.dart`, `insights_generator.dart`, `drift_study_repository.dart`, all of `lib/presentation/share/` (`mastery_card.dart`, `widget_raster.dart`), plus tests `snapshot_load_test.dart`, `fixtures.dart`, `day_picker_test.dart`, `dashboard_p3_test.dart`, `shell_first_frame_test.dart`, `widget_test.dart`, and root scripts `tool/check_invariants.sh`, `tool/*.py`.

Audit-environment note: `flutter analyze` cannot run here (environment Flutter SDK pins intl ^0.20.3 vs the project's pinned intl 0.20.2 — dependency resolution fails before analysis). Plain `dart analyze` was used instead; its mass `override_on_non_overriding_member` and several `dead_code` hits are artifacts of unresolved Flutter/Firebase types, not findings (see House-style observations).

## Findings

Ordered by severity. No P0, no P1. Five P2s.

### S1 — `_combineLatest6`'s doc comment fused onto the wrong declaration · **P2**

- File: `lib/data/repositories/drift_study_repository.dart:1042-1054`
- Evidence:

  ```dart
  /// Minimal combineLatest for exactly six streams.
  ///
  /// Hand-rolled rather than pulling in rxdart for one operator. Emits nothing
  /// until every source has produced a value, then emits on each subsequent
  /// change -- which is what makes a snapshot internally consistent.
  /// How long the combined snapshot stream waits for a burst of table events to
  /// finish before emitting.
  ///
  /// One frame. Named rather than inlined because ...
  const Duration kSnapshotCoalesceWindow = Duration(milliseconds: 16);

  Stream<R> _combineLatest6<A, B, C, D, E, F, R>( ...)
  ```

- Why it's residue, not authorship: the first four lines describe `_combineLatest6`, the function declared *below* the constant — but they are attached as the API doc of `kSnapshotCoalesceWindow`. Two unrelated subjects also run together with no blank `///` between "...internally consistent." and "How long the combined snapshot stream waits...". This is the shape of an edit artifact: the coalesce-window constant was inserted between a function and its documentation and the seam was never re-stitched. Everywhere else in this repository doc comments sit on exactly the declaration they describe.
- Proposed fix: split into two blocks. Move "Minimal combineLatest ... internally consistent." onto `_combineLatest6`; leave "How long the combined snapshot stream waits ... changed." on the constant, separated from it by a blank `///`.
- Risk of fix: none — comment-only relocation; no behaviour, no generated docs consumers affected.

### S2 — Same fact stated twice inside `_goBranch`; second statement restates what the first already established · **P2**

- File: `lib/presentation/shell/app_shell.dart:111-124`
- Evidence (both sides quoted):

  Lines 112-117:

  ```dart
  // PH-04: picking a tab is a `select` cue -- but only when it *is* a pick.
  // Tapping the already-selected tab returns to that branch's root, which is
  // navigation housekeeping rather than a choice being registered, so it
  // stays silent.
  ```

  Lines 120-122 (eight lines lower, same method):

  ```dart
  // Tapping the already-selected tab returns to that branch's root, the
  // behaviour a bottom bar is expected to have.
  initialLocation: index == navigationShell.currentIndex,
  ```

- Why it's residue, not authorship: within one twelve-line method the same behavioural fact ("already-selected tab → branch root") is written twice. The first occurrence carries the non-obvious payload (why the haptic stays silent); the second adds nothing except proximity to the parameter, and its placement directly above `initialLocation:` makes it read as a tutorial-comment restating the next line — the one comment pattern the house style rules out. Elsewhere in this file every comment earns its place exactly once.
- Proposed fix: delete lines 120-122. The PH-04 block already explains both the silence and (by naming "returns to that branch's root") what `initialLocation` does.
- Risk of fix: none — deletion of a redundant comment only.

### S3 — Hand-pasted helper left unformatted inside `widget_test.dart`'s wizard group · **P2**

- File: `test/widget_test.dart:256-265`
- Evidence:

  ```dart
    group('the exam wizard does not lose what has been typed', () {
    Future<void> openWizard(WidgetTester tester) async {
      await tester.pumpWidget(await bootApp(snapshot: overdueSnapshot()));
      ...
    }

      testWidgets('leaving with nothing typed just closes', (tester) async {
  ```

- Why it's residue, not authorship: `openWizard` sits at the same indent level as the `group(` call that contains it, while its sibling `testWidgets` blocks are correctly nested one level deeper. No formatter output ever looks like this — it is the signature of a helper pasted in by hand/tool and never run through `dart format`. Verified against the formatter: `dart format` re-nests the whole block. Nothing else in the sampled files shows structural misindentation, so this is a single un-repaired seam, not a style.
- Proposed fix: run `dart format test/widget_test.dart` (or hand-indent the helper two spaces).
- Risk of fix: none. Note for the future: CI (`.github/workflows/*`) runs `flutter analyze` and `flutter test` but never `dart format --set-exit-if-changed .`, so nothing mechanical catches this class of drift today. Adding the format gate would have caught this one.

### S4 — Stock `flutter create` template prose retained verbatim in `analysis_options.yaml` · **P2**

- File: `analysis_options.yaml:19-33`
- Evidence:

  ```yaml
  linter:
    # The lint rules applied to this project can be customized in the
    # section below to disable rules from the `package:flutter_lints/flutter.yaml`
    # included above or to enable additional rules. A list of all available lints
    # and their documentation are published at https://dart.dev/lints.
    #
    # Instead of disabling a lint rule for the entire project in the
    # section below, it can also be suppressed for a single line of code
    # or a specific dart file by using the `// ignore: name_of_lint` and
    # `// ignore_for_file: name_of_lint` syntax on the line or in the file
    # producing the lint.
    rules:
      # avoid_print: false  # Uncomment to disable the `avoid_print` rule
      # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
  ```

  (quoted from the file; wording is the stock scaffold's)

- Why it's residue, not authorship: this is the generator's default costume, untouched since `flutter create`. Every other configuration surface in this repository speaks in the project's own voice and records decisions (pubspec.yaml explains fl_chart's removal and the Downloads-folder refusal; CLAUDE.md documents release failures; check_invariants.sh explains each check's incident). A file that answers "why these lints?" with boilerplate — including two commented-out example rules nobody uncommented — is filler by contrast, even though it came from Flutter's generator rather than an agent.
- Proposed fix: replace with two or three lines in house voice, e.g. "Stock `package:flutter_lints`. Nothing disabled. If a rule ever fights the design, fix the code — or record here, with the reason, which rule and why."
- Risk of fix: none. Do not add rules casually in the same edit; this is a copy change only.

### S5 — Three one-shot ARB migration scripts retained after their work landed · **P2**

- Files: `tool/add_p5_arb.py`, `tool/add_p5_rich_arb.py`, `tool/fix_p3_arb.py`
- Evidence: their own headers —

  - `add_p5_arb.py`: "# P5-04 exam-eve mode: appends the batch's keys to both ARB files. … refuses to run twice on the same tree."
  - `fix_p3_arb.py`: "# One-shot repair: the P3 ARB additions were written through a PowerShell pipe whose console encoding mangled every non-ASCII character into '?'. … This script restores them verbatim…"

  All three scripts' effects are already committed into `lib/l10n/*.arb` and reflected in `lib/core/l10n/generated/`. They have nothing left to do.
- Why it's residue, not authorship: completed one-shot mutation scripts kept beside live tools (`check_invariants.sh`, `check_deployed_rules.sh`, `branding/`) are classic leftover-agent-artifact material. The honest counter-argument, and why this is only P2: their headers carry real incident history (the PowerShell console-encoding mangling that corrupted Arabic strings once already), which is exactly the kind of record this house deliberately keeps. The tension is real and belongs to the owner, not the auditor.
- Proposed fix: pick one deliberately. Either (a) delete all three and first move `fix_p3_arb.py`'s encoding lesson into CLAUDE.md or PROJECT.md where the other incident records live; or (b) keep them and say so in one line in RELEASING.md/CLAUDE.md ("tool/*.py are retained as records of the ARB encoding incidents; do not run them"), so the next reader knows they are archives and not part of the build pipeline.
- Risk of fix: deleting without first relocating the header prose would lose the UTF-8/PowerShell lesson, which has already paid for itself once. Option (b) has essentially no risk.

## House-style observations

What follows lists what IS consistent and authored, so future reviewers do not false-positive on it. Each item below was checked and cleared.

- **Long prose comments recording decisions, rejected alternatives, and incidents are the house style** (pubspec.yaml's fl_chart and Downloads-folder notes; `app_shell.dart`'s history of the removed "+" tab; `day_picker.dart`'s account of the seven-cell strip; `main.dart`'s App Check rollout sequencing; `drift_study_repository.dart`'s sort-stability note verified at n=31/n=34). Comments of this shape are authorship. Tutorial-comments ("// return the result") were grepped for explicitly: none exist anywhere in scope.
- **`print()` in `test/data/snapshot_load_test.dart:55,162,166,170` is deliberate**, documented in the file header: `[P2-07]`-prefixed performance baselines meant to be greppable in CI logs. Not debug leftovers. No other `print(` exists in scope; production logging uses `debugPrint` consistently, always prefixed `'Ather: '` (main.dart, lock_screen.dart, chapter_screen.dart, chapter_report_screen.dart, write_guard.dart, dashboard_screen.dart, exam_entry_screen.dart, backup_gate.dart, backup_screen.dart).
- **Every `catch (_)` / swallow has a written reason** (e.g. `firebase_auth_repository.dart:268-270` "Never let the Google plugin turn a completed deletion into a failure"; `exam_entry_screen.dart:402-404` "A refused or unavailable permission never blocks a save"; `settings_screen.dart:568-570`). No silent-swallow residue.
- **The `✓` glyphs** in `settings_screen.dart:184,356` and `profile_screen.dart:183` are row values (a settings row's answer), i.e. content, not decorative comment art. The ✓ in `app_haptics.dart:18,62` quotes a toast string ("exam saved ✓"). Emoji-range grep otherwise clean.
- **`## ` headers inside doc comments** (`day_picker.dart`, `lock_screen.dart`, `subjects_screen.dart`, `curriculum_templates.dart`, `app_colors.dart`, …) are structured argument sections, each carrying substantive content — not README paste. Likewise the long-dash dividers in `app_spacing.dart:185-189` and `analytics_screen_test.dart:257-265` introduce real sections with content between the rails.
- **Leftover-marker grep is clean**: zero TODO/FIXME/HACK/XXX/WIP in lib/test/tool; zero "for now"; the only "placeholder/stub" hits are legitimate test-double vocabulary (`not stubbed` in fakes) and `backup_gate.dart:208-209` explaining the stubbing contract for tests.
- **No generic filler names**: no `data`/`temp`/`foo`/`flag`/`handleThing` locals in hand-written code (`firestore_backup_repository.dart:97` `final data = snap.data()` is the idiomatic narrow use, immediately type-checked and discarded; `widget_raster.dart:141` likewise). No orphan private symbols: a cross-tree reference count over every `_private` declaration in `lib/` found zero single-use orphans.
- **No duplicated imports** in any scoped file. Magic prefs keys are constants at their feature (`_kLocaleKey` app_providers.dart:201, `kHapticsEnabledKey` app_providers.dart:319, `_kLastOpenDayKey` dashboard_screen.dart:53); the raw literals in tests (`widget_test.dart:62`, `dashboard_p3_test.dart:40`) exist because the prod constants are library-private — unavoidable, and each test-local constant is documented.
- **Naming conventions hold across eras of the code**: providers end in `Provider` (`snapshotProvider`, `reviewQueueProvider`), data classes in `Repository` behind domain interfaces, widgets plain nouns, motion helpers named for effect (`PopIn`, `RiseIn`, `CompletionDisc`). `fetch/get/xProvider`-style drift: none found.
- **Error-handling idiom is uniform**: transport boundaries translate to domain failures (`BackupException`, `AuthException`) at exactly one layer; UI writes go through `runWrite`; Crashlytics `recordError` appears at the three boundaries where loss is possible (`recordExam`, backup upload/download guard). The differing catch shapes (`on Object catch`, `on AuthException`, `catch (_)`) track real semantic differences, not era drift.
- **Quote style**: single quotes for all string literals throughout (double quotes appear only inside prose comments quoting words — correct English usage). Const usage is dense and consistent; the analyzer surfaced no const-related lints beyond environment noise.
- **`dart analyze` noise to ignore in this environment**: the bulk `override_on_non_overriding_member` warnings, the `InvalidType`-subtype catch warnings (`firebase_auth_repository.dart:119,231`, `firestore_backup_repository.dart:234`), and the `dead_code` hits at `firestore_backup_repository.dart:101,118` and `widget_raster.dart:133` are artifacts of running without resolved Flutter/Firebase types. Manual reads confirm the flagged code is correct (dynamic Firestore data narrowing at 101/118 is genuinely reachable defensive typing; `_collectBlocks`' else-branch is the recursion). The two test-side `dead_code` hits (`dashboard_p3_test.dart:221`, `shell_first_frame_test.dart:113`) are final `return true;` continuations inside `visitAncestorElements` callbacks — reachable by contract.
- **Skipped test with a reason** (`analytics_screen_test.dart:255`, `skip: true); // P2 follow-up: endless frame loop in this harness`) is a documented deferral with the cause named inline, not a silent disable.
- **`tool/check_invariants.sh`** is exemplary authored tooling: every check cites the incident that motivated it (debug-signed APKs ×2, versionCode 2001, the CRLF unzip parsing bug, the Firestore `size()` field-count trap).

## Summary

| Severity | Count |
|----------|-------|
| P0 | 0 |
| P1 | 0 |
| P2 | 5 |

This codebase does not read as slop. Every category the sweep targets — tutorial comments, contradiction, filler names, dead branches, swallowed errors, emoji/divider art, leftover markers, commented-out code, dual idioms, generic docstrings, import duplication, orphan helpers, print residue — came back empty or resolved to documented intent on read. The five findings above are seams (one misattached doc block, one duplicated sentence, one unformatted paste, one unedited scaffold file, three finished one-shot scripts), all cheap to repair, none hiding a bug.
