# Competitor Evaluation

Read-only audit, 2026-08-25. Scope: what comparable products offer vs. what Ather ships today
(dashboard, subjects → chapters → lessons, exam-entry wizard with question groups, review center,
analytics, daily tasks, share card, cloud backup, reminders). Sources are marked **[V]** (verified —
found via web search this session, URL cited) or **[I]** (inferred from general knowledge; treat as
directionally true, not citable).

## Competitive landscape

| Product | Platform | What it does | Relevance to Ather |
|---|---|---|---|
| منصة ثانوي (Thanawy platform app, Ahmed Basem) | Android (Play) **[V]** | Multi-teacher video explanations for the full Thanaweya curriculum, notes ("مذكرات"), external-book answer keys, daily/unit exams, student discussion page, study schedules, points leaderboard between students. 100K+ installs, ad-supported. [play.google.com](https://play.google.com/store/apps/details?id=com.ahmedbasem.thanwey&hl=ar) | Closest free Egyptian mass-market app. It is *content + community + gamification*; Ather is *measurement*. Direct substitute for attention, not for function. |
| STDY | Web/app, Egypt **[V]** | Teacher-facing platform: digital attendance, AI-generated exams, WhatsApp integration connecting teachers/students/parents; claims to save teachers money vs. offline centers. [stdy.app](https://stdy.app/index_en.html) | Shows where the money is: selling to teachers who bring their students, not to students directly. Ather's teacher-companion is explicitly deferred (PLAN.md item 17). |
| Private-teacher platforms (e.g., doroos-eg.com, Hossam Fekry chemistry platform) | Web/app, Egypt **[V]** | Per-course paid video lessons tied to a named teacher (e.g., EGP 150 per physics chapter course), online quizzes, "expected exam questions" framing. [doroos-eg.com](https://doroos-eg.com/) · [hossamfekry.com](https://www.hossamfekry.com/) | The dominant distribution channel in Thanaweya is the teacher's personal brand. None of them measure retention of mastery across the year; all sell teaching hours. |
| Nafham / Tyro | Web/app, MENA **[V]** | Free crowdsourced K-12 curriculum videos (Egypt/KSA/UAE), ~6M annual users, freemium; acquired 2021 by Tyro to combine recorded content with live 1-to-1 tutoring. [waya.media](https://waya.media/egyptian-edtech-startup-tyro-acquires-nafham) · [cbinsights.com](https://www.cbinsights.com/company/nafham) | Precedent that pure content plays consolidate into tutoring. Also evidence that "free video lessons" alone doesn't retain users without a human/tutoring hook. |
| Madrasa.org (MBRGI) | Web/app, Arab world **[V]** | ~5,000+ free Arabic-localized STEM videos, K-12, self-learning orientation. [almaktouminitiatives.org](https://www.almaktouminitiatives.org/en/what-we-do/madrasa-e-learning-platform) | Free Arabic content baseline. Confirms Ather's decision to ship zero content is a positioning choice, not an accident — nobody else does it. |
| ScanSolve | App/web, Egypt **[V]** | Past-exam papers for علمي track, step-by-step solution checking, similar-question practice before June exams. [getscansolve.com](https://www.getscansolve.com/ar/exams/thanaweya-amma) | Seasonal exam-prep demand is real and monetizable. Ather records what the student did on those papers but provides no papers itself. |
| Thanaweya AI | Web, Egypt **[V]** | Turns question-solving into a fixed schedule: when to solve, when to revise, which lessons need more practice. [thanaweya-ai.com](https://thanaweya-ai.com/thanaweya-questions) | The nearest *thesis* competitor found: planning around solving + revision targeting. But it is web, content-coupled, and has no decay mechanic or self-built curriculum. |
| AnkiDroid / Anki | Android/desktop, global **[V]** | SM-2/FSRS spaced repetition, per-card scheduling, detailed retention statistics, sync, 10M+ downloads, premade deck libraries. [github.com/ankidroid](https://github.com/ankidroid/Anki-Android) · [f-droid.org](https://f-droid.org/packages/com.ichi2.anki) | The gold standard for "review what's about to be forgotten." Ather's 30-day decay is a coarser, exam-anchored version of the same insight — a genuine differentiator in framing, weaker in mechanics (fixed interval vs. adaptive). |
| Quizlet / Brainscape / RemNote | Multi-platform **[V/I]** | Confidence-based repetition, collaborative decks, note-to-flashcard workflows; freemium subscriptions ($20–60/yr range). [spacerep.app comparison](https://spacerep.app/ankidroid-alternative) **[V]** | Show the monetization ceiling for study tools globally: subscriptions work when the tool owns the study material. Ather owns no material, so subscription-for-content won't translate. |
| Student grade trackers / TPT printables / Gradebook.app | Print & app, global **[V]** | Students already self-record test scores on paper templates and simple apps: record score, graph it, reflect monthly, set goals. [teacherspayteachers.com](https://www.teacherspayteachers.com/browse/free?search=student%20grade%20tracker) · [gradebook.app](https://www.gradebook.app/) | Validates Ather's core loop as something students demonstrably do by hand. Ather's gap vs. these is only polish and automation (they're free/one-off; Ather must justify install friction). |
| Excel/Notion trackers used by Egyptian students | Sheets **[I]** | Common pattern: one sheet per subject, columns = امتحان/درجة/التاريخ, conditional formatting for weakness. Shared via Telegram groups. | Same behavior Ather digitizes; also shows the bar for data entry is "fast enough to beat a spreadsheet." |

## What competitors do that Ather doesn't

Each item: competitor evidence → why it matters or doesn't for Ather's thesis (*mastery measured only from real exams, decays after 30 days, self-built curriculum*) → severity (opportunity cost) → risk of adding it.

### 1. Content: video lessons, notes, past papers, answer keys
**Evidence:** منصة ثانوي ships multi-teacher explanations + مذكرات + external-book answers **[V]** ([Play listing](https://play.google.com/store/apps/details?id=com.ahmedbasem.thanwey&hl=ar)); Madrasa.org 5,000 free Arabic STEM videos **[V]**; ScanSolve past papers **[V]**.
**Thesis judgment:** Doesn't matter — it's the one thing Ather deliberately refuses to own, and its honesty claim ("we don't teach, we measure") collapses if it starts teaching. Every content player above competes on content quality; none measures durable mastery.
**Severity:** P1 as opportunity cost (content is why most students install *anything*), P0 if ignored entirely at launch marketing time — the store listing must pre-answer "وين الفيديوهات؟".
**Risk of adding:** Extreme. Content production cost, copyright fights over مذكرات, and thesis dilution.

### 2. Question banks / auto-graded in-app exams
**Evidence:** منصة ثانوي daily electronic exams + unit exams **[V]**; STDY AI-generated exams **[V]**; Thanaweya AI smart question plans **[V]**.
**Thesis judgment:** Partially matters. Ather's mastery comes from *real* exams (school/paper), which is its differentiator — but a bank of official ministry past papers entered as real exams would strengthen, not dilute, the thesis (the source stays "real exam," only entry friction drops).
**Severity:** P1. The single biggest activation barrier today is: no exam happened yet → nothing to enter → empty app. Past-paper availability converts intent into first data.
**Risk of adding:** Moderate if limited to linking/importing official PDFs (ministry publishes them, moe.gov.eg **[V]**); high if it becomes generated quizzes (that's TestReady territory and breaks "real exam" wording).

### 3. Social/community: discussion pages, leaderboards
**Evidence:** منصة ثانوي discussion page + points leaderboard **[V]**; Quizlet group study **[V]**.
**Thesis judgment:** Doesn't matter for the thesis and mildly contradicts it (leaderboards reward volume of solved exams, not durable mastery). But social proof is how Egyptian study apps spread.
**Severity:** P2.
**Risk of adding:** High — moderation burden, minors' privacy (PLAN.md already flags privacy for tutor view), gamification pressure against honest self-reporting.

### 4. Parent/teacher visibility (WhatsApp-grade reporting)
**Evidence:** STDY's whole pitch is WhatsApp integration binding teacher/student/parent **[V]**; deferred in Ather (PLAN.md item 17).
**Thesis judgment:** Matters indirectly: in the Egyptian market the payer is often the parent, and the retention enforcer is the teacher. A read-only "أثر" share link/PDF for a parent is thesis-consistent (it shares measurement, not control).
**Severity:** P1.
**Risk of adding:** Moderate — privacy rules change needed; keep read-only, export-based, no accounts for the parent.

### 5. Adaptive review scheduling (per-lesson intervals instead of flat 30 days)
**Evidence:** AnkiDroid FSRS schedules each card individually by forgetting curve **[V]**; Brainscape confidence-based repetition **[V]**.
**Thesis judgment:** Matters. A lesson scored 95% and a lesson scored 55% do not deserve the same 30-day clock. Adaptive intervals would make the decay mechanic defensible pedagogically and make the Review Center smarter than a calendar.
**Severity:** P1 (quality), P2 (survival).
**Risk of adding:** Low-moderate — pure-function change to `review cycle service`, no schema change needed beyond maybe storing interval; but it complicates the beautifully simple "red after 30 days" story. Could ship as v2 behind the same UI.

### 6. Onboarding with instant value (premade curriculum)
**Evidence:** Every content app opens with ready chapters/lessons; Ather requires building curriculum by hand before any value. PLAN.md Batch B4 ("Curriculum templates") exists but isn't shipped; PLAN.md rejected interactive tutorial onboarding (dashboard_screen.dart decision).
**Thesis judgment:** Matters a lot — this is the #1 funnel risk. The official علمي علوم syllabus structure is public and stable; seeding template chapters/lessons (user-editable, keeping the "you build your curriculum" claim as "you *customize* it") removes 30+ minutes of setup without touching mastery logic.
**Severity:** P0.
**Risk of adding:** Low. Templates are just seed data; the four-subject fixity is untouched. Must avoid implying official endorsement.

### 7. Retention hooks: streaks, notifications tied to decay, seasonal campaigns
**Evidence:** منصة ثانوي daily exams habit loop + points **[V]**; AnkiDroid progress widget on home screen **[V]**; exam apps run pre-June campaign cycles (ScanSolve "راجع قبلها" framing **[V]**). Ather has local notifications (§3.15a: they existed but were silently broken until 2026‑08‑10) and a home-screen widget? — no widget exists in code.
**Thesis judgment:** The 30-day decay mechanic *is* a retention hook if surfaced aggressively: "3 دروس هتتحول أحمر الأسبوع الجاي" is a legitimate pull-back trigger that competitors can't copy honestly. Today it lives inside the app only; there's no widget, and notification reliability has one known reboot bug (§9).
**Severity:** P0. Monthly-return requirement is the product's survival math; nothing currently guarantees it.
**Risk of adding:** Low for widgets/deep-link notifications; high for streaks (moralizes studying, not mastery).

### 8. Monetization machinery (subscriptions, ad-free tier)
**Evidence:** منصة ثانوي runs ads **[V]**; doroos-eg sells courses at EGP 150 **[V]**; Nafham freemium→acquired into tutoring **[V]**; Quizlet/Brainscape subscriptions **[V]**.
**Thesis judgment:** Not yet relevant — premature before retention is proven. But note Play Store billing works poorly for many Egyptians (no widespread credit cards); competitor monetization routes around Play billing (teacher cash collection, carrier/scratch cards **[I]**).
**Severity:** P2 now, revisit at scale.
**Risk of adding:** Ads destroy trust in a measurement tool; subscriptions need content or sync value Ather doesn't sell.

### 9. Multi-device sync / device migration
**Evidence:** AnkiDroid AnkiWeb sync is table stakes in that category **[V]**; Ather has single-blob backup (§3.26), row-level sync explicitly deferred (PLAN.md item 18).
**Thesis judgment:** Marginal for thesis; matters for phone-loss events, which in a 9-month school year are common. Backup covers it adequately; restore verification exists.
**Severity:** P2.
**Risk of adding:** High engineering risk, documented in PLAN.md.

### 10. iOS presence
**Evidence:** All Egyptian consumer edtech competitors ship Android-first but the paying segment (private schools, tablets) skews iPhone **[I]**; منصة ثانوي and peers list Android + web **[V]**.
**Thesis judgment:** Irrelevant to thesis; Flutter makes it cheap eventually. Distribution reality (see below) says Android/APK culture dominates Thanaweya students **[I]**.
**Severity:** P2.
**Risk of adding:** Low code risk, Apple developer account cost + review friction.

## Ather's genuine differentiators (from code/docs)

1. **Mastery exclusively from real exams, question-group by question-group** (`exam_entries` + `exam_question_groups`, PROJECT.md §4) — no competitor found measures anything; they all *deliver* content or collect grades. This is the only product in the set whose data means "what you still know."
2. **Decay mechanic with no cheating path** — `needsReview` derived, not stored (§3.2); no "mark as reviewed" button anywhere. Competitor checklists/trackers have no concept of forgetting.
3. **Weighted last-exam formula** (last 0.7 + historical mean 0.3, §4) rewards current performance over history — mirrors FSRS philosophy but anchored to real exams rather than flashcards.
4. **Student-authored curriculum inside fixed subjects** — no other tool lets the student mirror *their* school's exact باب/درس naming, which is what makes exam entry fast mid-year.
5. **Offline-first Drift DB + optional Google account only for backup** (§3.17, §3.26) — survives Egypt's connectivity reality (~45% rural unreliable internet per market report **[V]**, researchandmarkets.com); every competitor found is online-dependent.
6. **Arabic-first RTL-native design language** (variable Readex Pro, hand-drawn icons, §7a) — competitors localize English shells; Ather is designed in Arabic.
7. **Honest anti-vanity stance**: homework never touches mastery (readiness line only), daily tasks deliberately feed nothing (§3.22) — unique and rhetorically strong ("مقياس مش ملزقة").

## Distribution & monetization notes

- **Android-first is correct.** Competitor installs cluster on Google Play **[V]**; APK-sideloading culture among Egyptian students is well established (modded/premium APK sharing) **[I]** — expect piracy of any paid tier; price accordingly or stay free.
- **The channel that matters is the teacher, not the store.** STDY sells software to teachers who distribute it to their students through WhatsApp **[V]**; doroos-eg monetizes named-teacher courses **[V]**; private tutors run Telegram/YouTube ecosystems **[I]**. Ather's cheapest growth lever is a shareable "أثر" report (already exists as `mastery_card.dart`) formatted so a teacher/parent *wants* to receive it weekly.
- **Seasonality is brutal and useful.** Everything peaks before June exams (ScanSolve markets exactly this window **[V]**; 921K students sat Thanaweya in June 2026 **[V]**, ahram.org). Ather's decay mechanic is most valuable September–March and nearly useless May–July; plan releases and campaigns on the school calendar, and expect churn after نتيجة التنسيق.
- **Monetization that fits:** free core forever (trust), paid cloud conveniences later (multi-device, longer history exports) — consistent with §3.26 mirror-backup design. Avoid ads (contradicts the measurement-tool neutrality). Teacher seat licenses (deferred item 17) are the proven Egyptian model if ever revisited.
- **Play Store listing** should adopt PLAN.md Item 14's "measurement companion" copy and explicitly say "مفيش فيديوهات — بنقيس إنت فاهم قد إيه," converting the biggest objection into the pitch.

## Prioritized Needs (top 10 ordered)

1. **Ship curriculum templates for علمي علوم** (PLAN B4) — kill the empty-app activation cliff; P0, low risk.
2. **Surface the decay countdown outside the app**: reliable notifications (fix reboot bug §9) + home-screen widget showing "X دروس هتقرب أحمر"; P0, low risk.
3. **Store listing + first-run card aligned on the measurement claim** (PLAN Item 14) — pre-answer "where are the videos?"; P0, zero code.
4. **Fast exam-entry path from a photo of the paper** (or at least a 30-second express flow for single-group exams) — data entry speed is the whole product's currency; P0, moderate risk.
5. **Official past-paper library (PDF links, ministry moe.gov.eg sources)** so students always have a "real exam" available — strengthens thesis instead of diluting it; P1, low-moderate risk.
6. **Adaptive review intervals per lesson** (score-aware decay, Anki-style) behind the existing Review Center; P1, moderate risk to the simplicity story — ship carefully.
7. **Parent-facing read-only export/share of أثر card** — leverage the payer/enforcer channel without accounts; P1, moderate privacy-design risk.
8. **Teacher-mediated distribution kit**: printable QR/poster + WhatsApp share assets for private tutors to recommend Ather alongside their lessons; P1, no product risk.
9. **Backup resilience messaging + phone-migration flow** (restore-on-new-device guided path) before scaling; P2.
10. **iOS build** once Android retention is proven; P2.

*Everything else observed in competitors — video content, question banks with auto-grading, leaderboards, chat communities, streaks, ads — is scope creep for Ather's thesis and should stay out.*
