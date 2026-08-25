# AI-Slop Phase 1 Report — Cross-Review

Phase 2 cross-review of `docs/audit/phase1/ai-slop-auditor.md`. Read-only on code; this file is
the only artifact created. Repo: branch `ai-audit/2026-08-25` @ `c9a28ec`.

Base check: the report audited `d8ff4e0`; `git diff --stat d8ff4e0..HEAD` touches only
`docs/audit/phase1/*.md`, so every citation below was verified against live, identical code.

Method: opened every cited location; ran `dart format -o show test/widget_test.dart`
(dry-run, output to /tmp — repo untouched); grepped CI workflows for a format gate; grepped
RELEASING.md/CLAUDE.md/PROJECT.md for the ARB encoding incident; spot-verified pubspec.yaml's
house voice (premise of S4).

## Summary stats

| Verdict | Count |
|---|---|
| CONFIRMED | 4 |
| DUPLICATE (deadcode-auditor.md #3) | 1 |
| STALE | 0 |
| FALSE-POSITIVE | 0 |
| **Rejected outright** | **0** |

Re-rank after verification: **0 × P1 · 4 × P2** (all effort S). The report's own severity calls
hold. No identifier renames survive anywhere in this set (rg-verified: the confirmed items are
comment relocation ×2, whitespace ×1, yaml-comment replacement ×1) — so no rename-collision risk
exists in this workstream.

Dup sweep vs `maintainability-auditor.md`: one adjacency noted under S1 below (M12 wants to move
the same two symbols during a file split). Vs `deadcode-auditor.md`: S5 is a full duplicate.

---

## Per-finding verdicts

### S1 — `_combineLatest6` doc fused onto `kSnapshotCoalesceWindow` → **CONFIRMED**

- Claim: the first four doc lines describe `_combineLatest6` but are attached to the constant
  declared above it; the function itself has no doc.
- Evidence (checked): `lib/data/repositories/drift_study_repository.dart:1042-1046` is combineLatest
  prose sitting on the constant at `:1054`; `Stream<R> _combineLatest6<...>` at `:1056` is docless.
  The constant's *correct* prose (`"How long the combined snapshot stream waits ... before
  emitting."` + blank `///` + `"One frame. Named rather than inlined because ..."`) already exists
  intact as `:1047-1053` — the defect is exactly five fused leading lines, nothing more. Cross-refs:
  constant consumed at `:1101` and in `test/data/drift_study_repository_test.dart:394`,
  `test/data/snapshot_load_test.dart:105`.
- Before→after (comment text only, zero wording changes):
  - Cut lines 1042–1046 verbatim:
    `/// Minimal combineLatest for exactly six streams.` / `///` / `/// Hand-rolled rather than
    pulling in rxdart for one operator. Emits nothing` / `/// until every source has produced a
    value, then emits on each subsequent` / `/// change -- which is what makes a snapshot
    internally consistent.`
  - Paste them directly above `Stream<R> _combineLatest6<A, B, C, D, E, F, R>(` (line 1056).
  - Constant keeps old lines 1047–1053 unchanged.
- Severity P2, effort S. N-id: NEW.
  Considered P1 ("wrong comment claims") and demoted: the misdescription sits adjacent to the
  correct description in the same block, so any reader self-corrects within seconds; no action
  based on it can go wrong. It is the top of P2.
- Overlap note: M12 (maintainability) proposes relocating both symbols to `data/db/` in a file
  split. Execute S1 first (trivial) or fold into M12's move so the doc arrives attached correctly.
- One overreach in the finding's rationale: "Everywhere else in this repository doc comments sit on
  exactly the declaration they describe" was not exhaustively verified by me — unnecessary for the
  verdict, since the local evidence is complete.

### S2 — Same fact stated twice inside `_goBranch` → **CONFIRMED**

- Claim: "already-selected tab returns to that branch's root" appears twice within twelve lines;
  second occurrence reads as a tutorial-comment restating the next line.
- Evidence (checked): `lib/presentation/shell/app_shell.dart:113` ("returns to that branch's root,
  which is navigation housekeeping ... so it stays silent") vs `:120-121` ("returns to that branch's
  root, the behaviour a bottom bar is expected to have"). rg-verified occurrence count of the
  phrase in-file: 2 → 1 after fix. The only content unique to the second copy is the marginal
  platform-convention aside; the load-bearing fact (what `initialLocation:` does here) survives at
  :113.
- Before→after: delete exactly lines 120–121 (both comment lines); keep line 122
  `initialLocation: index == navigationShell.currentIndex,`. Result:
  ```dart
  navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
  ```
- Severity P2, effort S. N-id: NEW. Comment-only deletion; unambiguous; no behavior surface.

### S3 — Unformatted pasted helper in `widget_test.dart` → **CONFIRMED**

- Claim: `openWizard` sits at group-body level while sibling `testWidgets` blocks are one level
  deeper; formatter re-nests it.
- Evidence (checked + mechanically proven): `test/widget_test.dart:257-265` at 2-space indent
  between `group(` (`:256`) and siblings at 4 spaces (`:267`). Dry-run `dart format -o show`
  diff against HEAD: the **only** hunk in the whole 419-line file is lines 257–265 shifted +2
  spaces (22 diff lines = exactly those 9 lines plus diff overhead). The report's claim that this
  is a single unrepaired seam is now formatter-proven, not just asserted.
- Before→after: run `dart format test/widget_test.dart`, or hand-indent lines 257–265 by two
  spaces (verified byte-identical outcome). Formatter dry-run output archived at review time.
- Also checked: `.github/workflows/guardrails.yml` runs `flutter analyze` + `flutter test` and no
  format gate (`rg -n format .github/workflows/` → 0 hits), confirming the report's note that
  nothing mechanical catches this class today.
- Severity P2, effort S. N-id: NEW.

### S4 — Stock `flutter create` scaffold prose in `analysis_options.yaml` → **CONFIRMED**

- Claim: generator default comment block retained verbatim around `linter:` including two
  commented-out example rules nobody uncommented.
- Evidence (checked): stock scaffold text at `analysis_options.yaml:22-31` with example rules at
  `:33-34`. (Report cited :19-33; ±2-line drift because the analyzer-exclude block above was added
  post-scaffold — same text.) Premise verified: pubspec.yaml comments (`:26-30, :42-48, :53-56,
  :64-66`) are dense house-voice decision records, so the untouched scaffold stands out as the one
  config surface with no authorial voice. Note: scaffold prose also occupies `:1-9` (header) and
  `:36-37` (footer) beyond what the report flagged — same class, include them in the same edit.
- Before→after: replace lines 22–34 with house-voice lines, e.g.
  ```yaml
  linter:
    # Stock package:flutter_lints, nothing disabled. If a rule ever fights the design,
    # fix the code -- or record here, with the reason, which rule and why.
    rules:
  ```
  Optionally also rewrite `:1-9` and `:36-37` in one sentence each (reviewer extension of scope,
  same class of residue). MUST keep `include:` (:10) and the entire `analyzer:` exclude block
  (:12-19) byte-identical — those carry behavior (worktree exclusion).
- Severity P2, effort S. N-id: NEW.

### S5 — Three spent one-shot ARB scripts in `tool/` → **DUPLICATE** (deadcode-auditor.md #3)

- Same three files, same root fact (effects landed in ARBs; headers self-identify one-shot),
  independently verified here: headers match quotes verbatim; keys present at
  `lib/core/l10n/app_ar.arb:661` (examVerdictWeak), `:750` (examEveButton), `:756-757`
  (reviewBodyDeclining).
- Disposition differs and should be merged into the deadcode workstream (its commit B): deadcode
  says delete ("recoverable from git history"); ai-slop adds — and I verified — that the
  PowerShell/console-encoding lesson exists **nowhere else** in RELEASING.md, CLAUDE.md, PROJECT.md
  or README.md (`rg -i "powershell|encoding|mangled"` → only an unrelated Expand-Archive note at
  `PROJECT.md:1876`). So if deletion wins, first relocate the two-sentence lesson to RELEASING.md;
  otherwise keep + one archival annotation. Owner call; facts not in dispute.
- Inherited severity: deadcode rates its #3 P1 (misleading-by-position next to live release tooling);
  ai-slop rated P2. For planning, defer to the deadcode workstream's grouping. Not part of this
  workstream's file set.

---

## Workstream proposal

**Name:** `de-slop-seams`

**File set (exact, all edits comment/whitespace/yaml-comment only):**
1. `lib/data/repositories/drift_study_repository.dart` — S1
2. `lib/presentation/shell/app_shell.dart` — S2
3. `test/widget_test.dart` — S3
4. `analysis_options.yaml` — S4

No rename sweeps exist; there are no other files containing any touched identifier/text beyond
these four (S1's moved text occurs once; S2's phrase count 2→1 within one file; verified above).

**Ordered fix sequence:**
1. S1 — cut/paste the five doc lines (drift_study_repository.dart:1042-1046 → above :1056).
2. S2 — delete app_shell.dart:120-121.
3. S4 — replace analysis_options.yaml:22-34 (optionally :1-9, :36-37) with house-voice lines;
   leave `include:` and `analyzer.exclude` untouched.
4. S3 last — `dart format test/widget_test.dart` (formatter dry-run already proven single-hunk).

Each step is an independent commit-sized change; land as one commit or four, none blocking.

**Optional follow-through (owner decision, outside the four files):** add
`dart format --set-exit-if-changed .` to `.github/workflows/guardrails.yml` so the S3 class stays
fixed. Changes CI behavior, hence flagged separately.

**Risks:**
- All four edits are non-executable text. Guard for review: `git diff` must show zero changed
  characters inside any executable Dart statement except the +2 indentation of
  widget_test.dart:257-265, and analysis_options.yaml's `include:`/`analyzer:` blocks must be
  byte-identical (they carry worktree-exclusion behavior).
- Renames: none proposed → zero collision risk by construction (rg counts stated per finding).
- Coordination: if maintainability M12 executes later, it inherits S1's corrected placement —
  no conflict either order.
- S5 excluded by design; its fate (delete-with-relocation vs archive-annotate) belongs to the
  deadcode workstream's commit B and an owner call.

**Verification without builds:** static reads + `dart format -o show` dry-run + rg counts, per the
no-build constraint. Standard CI (`flutter analyze` + `flutter test`) covers regression safety on
push; nothing in these edits can alter analyzed semantics.
