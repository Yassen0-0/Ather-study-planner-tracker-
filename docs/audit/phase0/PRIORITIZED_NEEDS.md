# Phase 0 — Prioritized Needs List (merged)

Merged from: product-evaluator, ux-evaluator, qa-evaluator, competitor-evaluator
(see sibling reports in this folder for full evidence). Base: `ai-audit/2026-08-25` @ `547c059`.
Dedup rules applied: same root cause merged across reports; strongest severity kept;
owner/device actions distinguished from code changes.

## Legend
- **P0** blocks shipping or destroys user trust/data. **P1** major friction or silent failure. **P2** polish/opportunity.
- [CODE] fixable by an implementer agent · [OWNER] needs a human/device decision · [DOC] documentation reconciliation

## The list

| # | Sev | Type | Need | Root evidence |
|---|-----|------|------|---------------|
| N1 | P0 | [CODE] | Guard Firebase absence so a failed `initializeApp` doesn't crash the first frame (Windows DOA; also means broken boot = zero telemetry) | `auth_providers.dart:13-15`, `app.dart:24-28`, `firebase_options.dart:41-45` |
| N2 | P0 | [OWNER] | Ship a distribution channel: run the already-written site deploy + copy APK (`BACKLOG.md:9-29`); decide Play timing | private repo, undeployed site, no listing |
| N3 | P0 | [OWNER] | Product decision: mandatory login gate contradicts offline-first thesis — design local-first mode with sign-in raised only for backup | `router.dart:164-169` vs `PROJECT.md` §1/§3.17 |
| N4 | P1 | [CODE] | Stop empty-record upload overwriting cloud backup after a failed offline auto-restore (persist last-successful-download marker; refuse upload while local empty + newer cloud doc existed) | `backup_providers.dart:124-141`, `backup_gate.dart:212-224` |
| N5 | P1 | [CODE] | ReviewScheduler must await `snapshotProvider.future` — every cold start briefly cancels ALL reminders against the loading fallback | `notification_providers.dart:114-133`, contrast `backup_providers.dart:104-121` |
| N6 | P1 | [CODE] | Log inside ReviewScheduler's silent catch — recurrence of the §3.15a "reminders quietly dead" class | `notification_providers.dart:164-167` |
| N7 | P1 | [CODE] | Reads have no error surface: stream errors collapse to `StudySnapshot.empty()` → loading/false-success screens; add error state + settle-gated empty states | `app_providers.dart:154-156`; dashboard/review empty states |
| N8 | P1 | [CODE] | Tasks add writes to a sticky selected day (yesterday after reopen) with no day cue on the button; re-seed past-day selection on day change and/or label target day | `task_providers.dart:32-42`, `tasks_screen.dart:44-59` |
| N9 | P1 | [CODE] | Wizard step 3: blank correct-count silently records all-wrong; block Next with banner | `exam_entry_screen.dart` step 3 validation |
| N10 | P1 | [CODE] | Cut activation tax: lesson-level template bundles / bulk lesson add (templates stop at chapters today); extend first-run card to name the ladder | `curriculum_templates.dart:33-45`, `dashboard_screen.dart:286-315` |
| N11 | P1 | [OWNER] | Prove reminder delivery across reboot on one device (boot receiver declared, never exercised) | `PROJECT.md:1159-1161` |
| N12 | P1 | [OWNER] | Verify Arabic chapter-report PDF on device; hide row if shaping fails | `PLAN.md:217-220` |
| N13 | P1 | [DOC] | Reconcile PROJECT.md with shipped reality (free subjects vs §1, §5 table, §3.28 third entry door, release lines) | subjects_screen vs `PROJECT.md:67-68,618-620,842-878` |
| N14 | P1 | [CODE] | Surface auto-restore failure instead of `on BackupException {}` (SyncStatus.failed + log) | `backup_gate.dart:220-223` |
| N15 | P1 | [CODE] | Load-test the 900 KiB backup ceiling with a synthetic 2-year record; design refusal UX if it fails | `PROJECT.md:1650-1653`, §3.26 |
| N16 | P2 | [CODE] | NumberField: paste `2.5`/Arabic decimal strips separator → 25; reject or normalize consciously; accept Arabic-Indic digits everywhere consistently | `ather_controls.dart:393-444` |
| N17 | P2 | [CODE] | Reject invisible-char-only names (ZWSP/RLM/tatweel pass `trim().isNotEmpty`) | `prompts.dart:60-70` |
| N18 | P2 | [CODE] | Notification tap on deleted lesson lands on blank scaffold; shared "not found" body for null summaries (lesson/chapter/subject) | `lesson_screen.dart:95-100`, `router.dart:353-355` |
| N19 | P2 | [CODE] | Timezone: resolve IANA id properly + refresh `setLocalLocation` on resume; offset-only guess drifts reminder hours abroad | `review_notification_service.dart:86-91,450-463` |
| N20 | P2 | [CODE] | `permanentlyLockedOut` shows generic refusal copy; add lockout line; clear `exam_draft_*` keys on account wipe | `lock_screen.dart:119-141`, `exam_entry_screen.dart:119-209` |
| N21 | P2 | [CODE] | Analytics: curriculum-with-zero-exams shows dash cards; needs one actionable empty-state | `analytics_screen.dart:148-156` |
| N22 | P2 | [CODE] | Review tab badge paints weak/declining in alarm red; reserve red for overdue | `app_shell.dart:52-54,511` |
| N23 | P2 | [CODE] | Extend recycle-bin protection (or warning copy) to chapter/lesson deletion | `BACKLOG.md:41-48` |
| N24 | P2 | [OWNER] | Resolve Windows claim: build once or strike §2 claim | `PROJECT.md:117,1115-1126` |
| N25 | P2 | [OWNER] | Profile motion/scroll on mid-range Android; record numbers in §9 | `PROJECT.md:1265-1270` |

## Roadmap opportunities (competitor-derived, post-v1)

Ordered by leverage for the mastery thesis; content banks/leaderboards/streaks explicitly rejected as scope creep:

1. Ship curriculum templates fully incl. lessons (overlaps N10) — activation cliff is THE gap vs Anki-class tools.
2. Surface decay countdown outside the app: reboot-proof reminders (N11) + home-screen widget.
3. Fast exam-entry flow — entry speed is the product's currency; every second counts.
4. Past-paper library so a "real exam" is always available to enter.
5. Adaptive per-lesson review intervals (Anki-style) behind the Review Center.
6. Parent-facing read-only share/export (reach the payer without accounts).
7. Teacher/tutor distribution kit (QR poster + WhatsApp assets).

## What everything downstream serves

Phase 1 audits verify/deepen N1–N25 (especially the [CODE] items); Phase 2 turns verified findings into an ordered execution plan; Phases 3–5 execute and prove it.
