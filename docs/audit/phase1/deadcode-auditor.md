# Dead Code Audit

Phase 1, read-only. Scope: `lib/ test/ tool/ windows/ android/ assets/ pubspec.yaml`, plus
root-level artifacts. Every deletion candidate below carries the exact searches run and their
hit counts. Generated code (`*.g.dart`, `lib/core/l10n/generated/`, `.dart_tool/`, `build/`) was
excluded from reference counts; hand-written code only.

Method summary:

- **File closure**: built the import graph from entrypoints (`lib/main.dart`) plus every
  `test/**` and `tool/**` file that imports `package:ather/...`. Result: **all 112 dart files
  under `lib/` are reachable. Zero orphan files.**
- **Symbol sweep**: extracted 454 top-level declarations (types/functions/getters/vars) across
  109 hand-written lib files and word-boundary-grepped each across `lib/ test/ tool/ windows/
  android/`. Two genuine orphans survived (below); everything else had an external reference.
- **Member sweep**: extracted 605 class members from repositories/services/theme/layout files;
  filtered to members with zero references outside their defining file, then manually verified
  each survivor. Most were private-and-internally-used (false positives, listed at the end).
- **Analyzer caveat**: this machine has Flutter 3.47.1 / intl ^0.20.3 while `pubspec.yaml` pins
  intl 0.20.2 (CI builds with 3.44.6), so `flutter pub get` fails here and `dart analyze` ran
  against a stale `.dart_tool/package_config.json`, producing ~12,973 version-skew warnings.
  Its `dead_code` hits in `firestore_backup_repository.dart:101,118`, `widget_raster.dart:133`,
  `dashboard_p3_test.dart:221`, `shell_first_frame_test.dart:113` are type-resolution artifacts
  of that skew, **not** reliable findings — noted, not actioned. The greps below are the proofs.

---

## Deletion candidates

### P1 — misleading (stale configs/scripts that could be executed or trusted)

#### 1. `.auto-claude-status` — stale "work in progress" flag (TRACKED in git)
- **Proof of staleness**: file says `"active": true`, `"spec": "001-crash-reporting-integration"`,
  `"state": "building"`, 9/10 subtasks, timestamped `2026-08-18T11:06:25`. Crashlytics shipped —
  `RELEASE_NOTES.md` covers 1.8.0+16 and `main.dart:172 _initializeCrashlytics()` is live.
  Searches: crashlytics integration exists in `lib/main.dart` (hits: `_initializeCrashlytics`
  defined :172, called :42); nothing reads `.auto-claude-status` anywhere:
  `grep -rn "auto-claude-status" lib test tool .github windows android` → **0 hits**.
- **Risk**: any agent or human reading the root sees "a build is in progress, 9/10 done" from
  eight days before the current release. It lies about repository state.
- **Grouping**: commit A ("remove stale Windows-era agent state files").
- **Severity**: P1.

#### 2. `wt-session-a/`, `wt-session-b/` — dead worktree copies of the whole project (~stale trees)
- **What the searches show**:
  - Their `.git` files: `cat wt-session-a/.git wt-session-b/.git` → `gitdir: C:/ather/.git/worktrees/wt-session-{a,b}` — Windows paths, **broken on this Linux checkout**.
  - `git worktree list` lists both as **prunable**.
  - Branch content: `git log --oneline main..exec/session-a` → **empty**; `main..exec/session-b` → **empty**; merge-base = `7cae5ab` "Plan the verified backlog into two independent sessions". They contain **zero unique commits**.
  - Prior audit already dated them: `.audit/08-wildcard.md:115` — "`wt-session-a`/`wt-session-b` at `7cae5ab` (`1.7.0+13`) — older than main"; `animation/11_ceo_review_report.md:18` flags them (F-02) as causing real tooling problems.
  - Ignored twice over: `.gitignore:102-103` and excluded from analysis in `analysis_options.yaml` (`wt-session-a/**`, `wt-session-b/**`).
- **Why P1 not P2**: CLAUDE.md Rule 2 *requires* agents to inspect sibling worktrees before building ("assume it is newer than yours"). These look exactly like what Rule 2 warns about but are provably older than main; keeping them forces every future session to re-litigate that.
- **Removal procedure**: `git worktree prune` (clears the C:/ather registrations), then `git branch -D exec/session-a exec/session-b` (no unique commits lost), then delete the directories.
- **Grouping**: commit A.
- **Severity**: P1.

#### 3. `tool/add_p5_arb.py`, `tool/add_p5_rich_arb.py`, `tool/fix_p3_arb.py` — spent one-shot migration scripts
- **Proof their work is done** (each script appends keys to both ARB files):
  - `fix_p3_arb.py` keys, e.g. `examVerdictWeak` → present at `lib/core/l10n/app_ar.arb:661` with exactly the value the script restores.
  - `add_p5_arb.py` keys, e.g. `examEveButton` → present in `app_ar.arb` (`grep -c "examEveButton\|reviewBodyDeclining" app_ar.arb` → 3 matches incl. batch marker).
  - `add_p5_rich_arb.py` keys, e.g. `reviewBodyDeclining` → present in `app_ar.arb`.
  - Each header self-identifies as one-shot: "refuses to run twice on the same tree" / "One-shot repair".
  - Nothing references them: `grep -rn "add_p5\|fix_p3" lib test tool .github RELEASING.md CLAUDE.md` → **0 hits outside the scripts themselves**.
- **Risk**: sitting in `tool/` beside `check_invariants.sh`, they read like part of the release pipeline. Re-running is designed to no-op, but a future agent "fixing l10n" may treat them as current process instead of archaeology.
- **Grouping**: commit B ("remove spent l10n migration scripts"). Recoverable from git history if ever needed again.
- **Severity**: P1.

#### 4. `public/index.html` — landing page advertises version 1.7.0
- **Proof**: `grep -n "1\.7\.0" public/index.html` → lines 110 and 167 ("الإصدار 1.7.0" / "Version 1.7.0"). Shipped line is 1.8.0 (`pubspec.yaml:5` → `version: 1.8.0+16`; `dist/` holds the 1.8.0 build-15 APK; `public/ather-latest.apk` dated later the same day). `firebase.json` hosting block serves `public/` — this text is site-facing.
- **Also**: `sha256sum public/ather-latest.apk dist/Ather-1.8.0-build15.apk` → different hashes (`ad842e46…` vs `d6772ab7…`), so the published "latest" APK is not the newest staged one either. Which one *should* be published is a release decision, not mine to make — but page text and artifact disagreeing with `pubspec` is a fact.
- **Risk**: students download while the page understates the version by two minor releases.
- **Grouping**: commit C ("site copy: version bump") — needs the release owner to confirm which APK is canonical first.
- **Severity**: P1.

### P2 — dead code and cruft

#### 5. `ExamDraftGroup` typedef — zero users
- `lib/domain/services/review_cycle_service.dart:380`: `typedef ExamDraftGroup = DraftQuestionGroup;`
- Proof: `grep -rn --include=*.dart -w ExamDraftGroup lib test tool` → **exactly 1 hit: its own declaration line**. Callers use `DraftQuestionGroup` directly (e.g. `drift_study_repository.dart:448`), so the "re-export" re-exports to nobody.
- Risk: none. Grouping: commit D ("drop dead review-cycle symbols", together with #6).
- Severity: P2.

#### 6. `ReviewStateX.isOverdueAt` extension method — zero call sites
- `lib/domain/services/review_cycle_service.dart:373-376`: `extension ReviewStateX on Lesson { bool isOverdueAt(DateTime now) => … }`.
- Proof: `grep -rn --include=*.dart -w isOverdueAt lib test tool` → **1 hit (declaration)**; `-w ReviewStateX` → **1 hit (declaration)**; `-w isOverdueAt|ExamDraftGroup|ReviewStateX` across `test tool` → **0**. Doc comment claims exam entry uses it; `grep -n "isOverdueAt\|needsReview" lib/presentation/exam_entry/exam_entry_screen.dart` shows exam entry goes through `ReviewCycleService.needsReview` instead.
- Irony worth recording: the same class body (lines 357–368) documents the removal of the previously-dead `lessonsAwaitingNotification` "which kept a full set of passing tests the whole time" — two more of the same species grew right underneath that epitaph.
- Grouping: commit D. Severity: P2.

#### 7. ARB key `subjectTemplateNote` — generated getter never called
- Declarations: `lib/core/l10n/app_ar.arb:658`, `lib/core/l10n/app_en.arb:447`; generated getter `lib/core/l10n/generated/app_localizations*.dart` (regenerated, not hand-edited).
- Proof: regex search `\bsubjectTemplateNote\b` over `lib test tool` excluding `/generated/` → **0 hits**. Introduced by `git log -S subjectTemplateNote` → `2e19fc8 "[B4] Optional pre-loaded chapter templates"` and never gained a caller: `subjects_screen.dart` uses `l.subjectTemplateAdd` (:179) and `l.subjectTemplateCount` (:180), never the note.
- Action: remove both ARB entries, regen. Grouping: commit E ("l10n hygiene"). Severity: P2.

#### 8. `.auto-claude-security.json`, `.claude_settings.json` — Windows-era agent configs (TRACKED)
- Proof: `cat` shows `"project_dir": "C:\\ather"` and permission entries `Read(C:\ather/**)`, `Shell(C:\Program Files\Git\bin\bash.exe:*)`, `apksigner.bat` — paths that do not exist on this Linux checkout. Referenced by no build/test/CI step: `grep -rn "claude_settings\|auto-claude-security" lib test tool .github` → **0 hits**. `git ls-files` confirms both tracked.
- Risk: low (inert data), but they document a machine layout that no longer exists and invite agents to restore it. Grouping: commit A. Severity: P2 (P1 only in combination with #1, which is why they ship together).

#### 9. `.claude/worktrees/*` (7 copies, ~7.1 GB) and `.claude/worktasks/release-apk` (~870 MB) — stale Windows-era tree dumps
- Proof: every `.git` inside points to `gitdir: C:/ather/.git/worktrees/<name>` (checked all 7); `git worktree list` marks all **prunable**; sizes via `du -sh`: 3.1G, 928M, 3.2M, 3.0M, 94M, 791M, 2.3G + 870M task dir. Branches involved (`ather-build`, `release-apk`, etc.) exist in refs; the directories themselves are plain copies.
- Note: these are NOT covered by the root `.gitignore` `build/` rule and are currently eating ~8 GB next to the live tree. Grouping: standalone cleanup commit + `git worktree prune`. Severity: P2 (disk/confusion hazard, no runtime effect since analysis_options excludes only some paths — actually it excludes `.claude/worktrees/**/`).

#### 10. `tool/render/**/*.png` including `tool/render/failures/` — untracked golden-test outputs
- Proof: `git ls-files tool/render` → only the three `*_test.dart` files; every PNG (render/, render-dark/, motion/, failures/) is **untracked** local output. `failures/` holds diff images for a `10-settings` golden mismatch from some past run — keeping failure diffs forever makes the tree look like goldens are currently failing.
- Regenerable by running the render tests with `--update-goldens`. Grouping: commit F ("clean render artifacts") or leave-if-owner-wants-filmstrips; at minimum delete `failures/`. Severity: P2.

#### 11. `dist/README.md` — describes the wrong build as "the build to hand out"
- Proof: README headline "Ather 1.8.0+14 — the build to hand out", "versionCode rises with every build (14 as of 1.8.0+14)". Directory contents: `Ather-1.3.1-build8`, `Ather-1.6.0-build11`, `Ather-1.8.0-build15`; `pubspec.yaml` now at `1.8.0+16`. `dist/` itself is gitignored (`.gitignore:69`) but `RELEASING.md:173` references `dist/_quarantine-do-not-distribute/` as historical evidence — keep the folder, fix or date-stamp the README.
- Severity: P2 (local-only, but it is the doc a human grabs when handing out an APK).

#### 12. `sahm.iml`, `.idea/` — IDE leftovers under the project's old name
- Proof: `PROJECT.md:1909` records the original scaffold was `flutter create` named `sahm`; `sahm.iml` sits at root while the app/module is `ather`. `git ls-files | grep iml` → **untracked** (`.gitignore` covers `*.iml`, `.idea/`). Purely local IntelliJ state. Deleting `sahm.iml` cannot affect anything tracked. Severity: P2, grouping: commit G.

#### 13. Empty duplicate audit dirs: `docs/audit/phase-0/`, `docs/audit/phase-1/`, `docs/audit/phase-2/`
- Proof: all three are empty (`find … -type f` → none), created 2026-08-25 00:09, while the populated trees are `docs/audit/phase0/` and `docs/audit/phase1/` (this report lives there). Git does not track empty dirs — they are local scaffolding noise duplicating the real names one hyphen away. Severity: P2, trivial. (Do not confuse: reports go in `phase1/`, no hyphen.)

### Explicitly checked and NOT dead (so nobody re-flags them)

- **Dependencies**: every declared dep import-searched — flutter_riverpod 60, drift 31, drift_flutter 1, go_router 25, flutter_local_notifications 4, timezone 3, intl 3, shared_preferences 29, path_provider 3, share_plus 3, pdf 5, crypto 2 (justified in pubspec:53–57), firebase_core 2, firebase_auth 3, google_sign_in 1, local_auth 5, cloud_firestore 2, firebase_app_check 1, firebase_crashlytics 5. Dev deps: build_runner/drift_dev/flutter_lints are build-time by nature; local_auth_platform_interface, fake_cloud_firestore, firebase_auth_mocks each imported by tests. **Zero unused dependencies.**
- **Assets**: `assets/fonts/ReadexPro.ttf` declared (pubspec:112) and loaded via `AppTypography`; `assets/branding/*.svg` deliberately unpacked — see Alive-but-looks-dead. Android res: `splash_glyph` consumed by `drawable*/launch_background.xml`, launch backgrounds by `styles.xml`/manifest, mipmaps by manifest. No orphans.
- **Routes**: all 18 `Routes.*` members have ≥1 call site (per-member counts run; smallest non-zero: `chapterReport: 2`).
- **Prefs keys**: all 11 keys have both reader and writer (table grepped from `getString/setString/getBool/setBool/remove` sites).
- **Notification payload**: written as `'${reminder.lessonId}'` (`review_notification_service.dart:420`) and parsed at `:106–108`. Consistent.
- **ARB keys**: 347 of 348 used; only #7 above is orphaned.
- **Platform gates**: `Platform.isAndroid` early-returns guard genuinely Android-only features (secure window, notifications); `firebase_options.dart` platform switch is standard generated coverage; `app_shell.dart:176` mobile-check is behavioral, not vestigial. Locals ship exactly ar+en matching the two ARB files. No flag with a lone setter found (`kDebugMode` uses are provider selection, standard).
- **Tests**: every `test/support/*` helper imported somewhere (fake_notifications and year_fixture each by exactly 1 test — thin but used); all `package:ather/…` imports in tests/tool resolve; no symbol surfaced that exists only inside a test file.
- **Commented-out code**: none >2 lines anywhere in `lib/`. The one candidate (`drift_task_repository.dart:23`) is prose. The only removed-code record is the intentional narrative comment at `review_cycle_service.dart:357–368`.

---

## Investigate-and-report

### `wt-session-a/`, `wt-session-b/`
Full project-tree copies from the era when this repo lived at `C:\ather` on Windows. They are
registered git worktrees of branches `exec/session-a` / `exec/session-b`, both parked at `7cae5ab`
(v1.7.0+13, 2026-08-18). On this machine their gitdir pointers are dangling, `git worktree list`
reports both prunable, neither branch holds a commit main lacks, and both prior audits
(`.audit/08-wildcard.md:115`, `animation/11_ceo_review_report.md` F-02) already classified them
as stale-and-harmful. **Verdict: deletable — prune worktrees, delete the two branches, rm the
dirs (candidate #2).**

### `.commandcode/`
CommandCodeBot agent permissions (`settings.json` allows `flutter:*`, `git:*`, `findstr:*`,
`apksigner.bat`, a `C:\Users\kk783\…` path) plus an empty `taste/` dir. All-Windows paths,
gitignored (`.gitignore:87`), referenced by nothing. **Verdict: inert local tool config from the
old machine; safe to delete locally; not tracked, so no commit involved.**

### `dist/`
Release-APK staging: three shipped APKs (1.3.1-b8, 1.6.0-b11, 1.8.0-b15), the
`_quarantine-do-not-distribute/` set of debug-signed 1.0.0 builds kept as evidence (explicitly
referenced by `RELEASING.md:173`), and a README that is one-to-two releases behind (#11).
**Verdict: not dead — it is the distribution archive and quarantine evidence. Keep the APKs;
refresh the README's version claim.**

### `animation/`
Motion-design dossier (01_meetings → 11_ceo_review, PROMPT_COMPANY, demo HTML, screen specs).
It is load-bearing **as documentation**: five lib files cite it by path in doc comments
(`ather_brand.dart:179,298`, `app_haptics.dart:12`, `springs.dart:7`, `day_picker.dart:86`),
and MOTION_BRIEF/PROJECT.md lean on the same IDs. **Verdict: alive — protected design source;
deleting it would sever the spec links the code quotes.**

### `.auto-claude-*` / `.claude_settings.json`
Covered as candidates #1/#8: tracked, Windows-pathed, status file actively lying about a finished
feature being mid-flight. **Verdict: delete (commit A).**

---

## Alive-but-looks-dead — do not delete

| Item | Where | Why it looks dead | Why it isn't |
|---|---|---|---|
| Branding SVGs | `assets/branding/glyph-mastery.svg`, `icon-mastery-dark.svg`, `icon-mastery-light.svg` | Deliberately absent from pubspec assets (comment pubspec:95–103) so zero runtime refs | Authored identity / source of truth for the CustomPainter geometry (`ather_brand.dart`); exported to Android bitmaps by `tool/branding/export_branding_test.dart` |
| `lastNotifiedAt` column & field | `tables.dart:81`, `lesson.dart:76`, carried through backup (`study_backup.dart:177,356`) | Written and migrated but never read for decisions — the poll-based reminder design died | Documented deliberate keep (`review_cycle_service.dart:357–368`): dropping it costs a curriculum migration to reclaim 8 bytes/row; backups preserve it for round-tripping |
| Render harnesses | `tool/render/ather_render_test.dart`, `ather_dark_render_test.dart`, `motion_filmstrip_test.dart` | Not wired into CI; produce PNGs nobody ships | Golden/filmstrip generators behind the committed design evidence; referenced by the motion workflow docs |
| Branding export test | `tool/branding/export_branding_test.dart` | Lives under `tool/`, writes files, "test" that isn't in the suite's assertions | The generator for every Android launcher bitmap; pubspec comment names it as the export path |
| Windows runner | `windows/**` | App is Android-first; `secure_window.dart` and notifications bail out off-Android | Documented dev-run target (`PROJECT.md:1090,1117`); standard Flutter desktop scaffold |
| `firebase_options.dart` non-Android cases | `case TargetPlatform.iOS/macOS/windows/linux`, `if (kIsWeb)` | Unreachable for the shipped Android APK | Standard generated Firebase bootstrap; harmless defensive coverage |
| Internal-use symbols my member sweep flagged | e.g. `_map`, `_doc`, `_plugin`, `_applied` (repos/services); `regular` (`app_typography.dart:51`, used :367); `velocityWindowPoints` (`insights_generator.dart:568`, used :642) | Zero references *outside* their own file | All referenced inside their file — private helpers doing their job |
| `PdfExportException` / `PdfExportFailure` | `pdf_export_service.dart:11–19, 90–101` | Thrown and caught only within one file | That is the contract: internal throw → wrap → rethrow; caller surfaces via its own error path (`chapter_report_screen.dart:89ff`) |

---

### Proposed deletion-commit grouping

- **Commit A** — "Remove stale Windows-era agent state": `.auto-claude-status`,
  `.auto-claude-security.json`, `.claude_settings.json` (#1, #8).
- **Commit B** — "Remove spent l10n migration scripts": `tool/add_p5_arb.py`,
  `tool/add_p5_rich_arb.py`, `tool/fix_p3_arb.py` (#3).
- **Commit C** — Site/version truth (needs owner input on canonical APK): `public/index.html`
  version lines, `dist/README.md` refresh (#4, #11).
- **Commit D** — "Drop dead review-cycle symbols": `ExamDraftGroup`, `ReviewStateX.isOverdueAt` (#5, #6).
- **Commit E** — l10n hygiene: remove `subjectTemplateNote` from both ARBs + regen (#7).
- **Commit G** — `sahm.iml` removal if ever adopted into tracking hygiene (#12); empty
  `docs/audit/phase-{0,1,2}` dirs are untracked rmdir (#13).
- **Non-commits**: wt-session/prune + `.claude/worktrees` purge (#2, #9) and `tool/render` PNG
  cleanup (#10) are filesystem/git-metadata operations; only the `.gitignore`/analysis_options
  mentions need touching in a commit, and both already cover the dirs.

Total deletion candidates: **13** (4 × P1, 9 × P2). Investigate-and-report verdicts: 4 areas.
Alive-but-looks-dead protections recorded: 8 entries.
