# 11 — تقرير الريفيو التنفيذي (CEO Review) — 2026-08-23

> شركة مراجعة مستقلة · مراجعة كاملة لتطبيق أثر على الفرع `wip/current-session`
> (HEAD `76f4a5e` — "WIP: P4 visual system + P5 radar/certificate/exam-eve").
>
> **قاعدة الشركة:** صفر تعديلات على كود التقرير المراجَع. هذا الملف هو المخرج الوحيد.
> المراجع بالإنجليزية بصيغة `file:line`، والشرح بالعربية.

---

## 1) حالة الشجرة قبل البدء

- الـworktrees كلها نظيفة تحت `lib/` — لا يوجد شغل غير ملتزم في أي منها
  (فُحصت `wt-session-a`، `wt-session-b`، وكل `.claude/worktrees/*`).
- فرعا الجلسات `exec/session-a` و`exec/session-b` عند `7cae5ab` وهو **سلف** لـHEAD
  (`git merge-base --is-ancestor` = true) — أي أن الشجرة الرئيسية هي الأحدث ولا يوجد
  base أقدم مقلق (Rule 2 مستوفاة).
- ملاحظة مهمة: نسخ العمل القديمة داخل `wt-session-a/b` تسبب مشكلة أدوات حقيقية — انظر F-02.

---

## 2) الملخص التنفيذي (30 ثانية)

التطبيق في أفضل حالة مراجعتِه حتى الآن: **483 اختبارًا ناجحًا و1 متخطى**، و`flutter analyze`
نظيف تمامًا على كود المستودع نفسه (صفر issues في `lib/` و`test/`). لم يجد فريق المسح
أي خطأ منطقي في قلب المنتج: معادلة الإتقان، ساعة الـ30 يومًا، الهجرات، الحذف مع إعادة
حساب الساعة، مزامنة الـbackup، بوابة تبديل الحسابات، والصلاحيات — كلها مطابقة لـPROJECT.md.

المخاطرة الوحيدة ذات الوزن (P1) **ليست في الكود بل في عملية الإصدار**: الشجرة تحمل
schema v4 جديد بينما `versionCode` ما زال `1.8.0+14` — وهو نفس الرقم الذي **شُحن فعلًا**
مع schema v3. أي APK يخرج من هذه الشجرة دون رفع الرقم سيُرفض التثبيت فوقه على هواتف
الطلبة، وهو بالضبط الضرر الذي كُتب CLAUDE.md Rule 1 لمنعه.

| المحور | الدرجة 0–10 | أخطر ملاحظة |
|---|---|---|
| Bugs منطقية | **9** | لا أخطاء منطقية مكتشفة في المسارات الحرجة؛ WIP الأخير (radar/certificate/exam-eve) نظيف |
| الأمان | **9** | App Check مُشحّن بلا enforcement (مقصود وموثق main.dart:97-106) — البديل الوحيد الممكن |
| الأداء | **9** | لا شيء جديد؛ coalescing وdebounce وفingerprints كلها موجودة ومقيسة |
| الاختبارات والتغطية | **8** | اختبار واحد متخطى دائمًا للشاشة التحليلية (F-03) |
| UX والحركة | **9** | لا ملاحظات جوهرية؛ قرارات RTL مثبتة عمدًا وموثقة |
| تطابق الوثائق مع الكود | **8** | RELEASE_NOTES.md متأخر عن آخر إصدار مقتطع فعليًا (F-05) |

---

## 3) النتائج مرتبة P0 → P3

### لا يوجد P0

لم يمر أي finding بمعيار «كسر مؤكد لبيانات طالب أو أمانها» بعد مناقشة المؤيد/المعارض.

### P1 — مهم

#### F-01 · إعادة استخدام `versionCode` شُحن سابقًا مع schema أقدم — خطر قفل الترقية
- **المكان:** `pubspec.yaml:5` (`version: 1.8.0+14`) مقابل `lib/data/db/app_database.dart:52` (`schemaVersion => 4`).
- **الدليل:**
  - commit `8ca5793` ("Cut 1.8.0+14") قُطّع **قبل** دخول schema v4، ورسالته تؤكد تسليم build برقم 14.
  - التعليق نفسه في `app_database.dart:41-45` يقول حرفيًا: *"version 3 has now shipped (1.8.0+14)"*.
  - schema v4 دخل لاحقًا في commit `f3fbf10` دون رفع `+N` بعده حتى الآن (طبيعي لـWIP، لكن الخطورة قائمة).
  - `tool/check_invariants.sh` يفحص "versionCode has not gone backwards" فقط — رقم **متساوٍ** لا يوقظه السكربت.
- **سيناريو الكسر:** يبنى APK من هذه الشجرة ويُسلَّم لأي طالب دون bump → Android يرفض
  التثبيت لأن `versionCode` ليس أعلى من المثبّت → الرسالة العملية للطالب تصبح
  «احذف القديم» → ضياع كل امتحاناته. هذا هو الضرر النصي الأول في CLAUDE.md Rule 1،
  وقد وقع مرتين من قبل بأشكال أخرى.
- **الإصلاح (سطران):** قبل أن يخرج أي build من المستودع: ارفع إلى `1.8.0+15` (وأعِد
  `appVersion` اليدوي في `settings_screen.dart` ليواكب — الـinvariant يطلب تطابقهما).
  شرطي: الخطر لا يتحقق إلا عند التسليم دون رفع.

### P2 — محسّن

#### F-02 · `flutter analyze` من جذر المستودع يُظهر 6 أخطاء من worktrees متداخلة قديمة
- **المكان:** `wt-session-a/test/support/fake_auth.dart:12` و`:67`،
  `wt-session-a/test/support/fake_notifications.dart:42`، ونظائرها في `wt-session-b`.
- **الدليل (تشغيل فعلي 2026-08-23):**
  ```
  error - Missing concrete implementations of 'AuthRepository.reloadAccount'
          and 'AuthRepository.sendEmailVerification' - wt-session-a\test\support\fake_auth.dart:12
  error - 'FakeAuthRepository.register' ... isn't a valid override ... :67
  error - 'FakeNotificationService.reschedule' ... isn't a valid override ... fake_notifications.dart:42
  ```
  السبب: `analysis_options.yaml` لا يستثني مجلدات الـworktrees المتداخلة، فيحلّل
  ملفاتها القديمة ضد **`lib/` الحالي** (الذي تطوّر: `register` أصبح يعيد `Future<bool>`،
  وأُضيف `buildEarlyBody` لتوقيع `reschedule`).
- **سيناريو الكسر:** أي مطوّر/وكيل يشغّل `flutter analyze` محليًا يرى شجرة «حمراء»
  وكأن كوده مكسور؛ الوقت يضيع في تشخيص أخطاء ليست له. CI غير متأثر (checkout نضيف
  بلا هذه المجلدات)، وهذا ما جعلها P2 وليس P1.
- **الإصلاح:** أضف إلى `analysis_options.yaml`:
  ```yaml
  analyzer:
    exclude:
      - wt-session-*/**
      - .claude/worktrees/**
      - .auto-claude/**
  ```
  أو نظّف الـworktrees المنتهية (`git worktree remove` / `prune`).

### P3 — ملحوظات

#### F-03 · اختبار متخطى دائمًا يترك شاشة Analytics بلا تغطية widget حية
- **المكان:** `test/widget/analytics_screen_test.dart:159` (`skip: true` — التعليق:
  "P2 follow-up: endless frame loop in this harness").
- **الدليل:** نتيجة `flutter test`: `+483 ~1` (اختبار واحد متخطى، وهو هذا).
- **سيناريو الكسر:** تراجع بصري أو كسر في الشاشة التحليلية (الرادار/ال trajectories
  الجديدة في هذا الـWIP) لن يمره أي اختبار آلي.
- **الإصلاح:** عزّل سبب حلقة الفريمات في الهارنس (غالبًا ticker/timer غير ملغى) وأعد
  تشغيله؛ أو استبدله بـgolden render عبر `tool/render/`.

#### F-04 · تحديد المنطقة الزمنية بالإزاحة وحدها قد يختار القاهرة لجهاز خارج مصر
- **المكان:** `lib/data/notifications/review_notification_service.dart:413-426`.
- **الدليل:** أي جهازoffsetه `+02:00` أو `+03:00` (سواء مصر أو موسكو أو الرياض أو
  أثينا صيفًا) يحصل على `Africa/Cairo`.
- **سيناريو الكسر:** طالب يسافر (أو جهاز بمنطقة ثابتة +3) قد يرى التذكير يهبط في ساعة
  مختلفة عن 18:00 المحلية حول انتقالات DST. الأثر محدود أصلًا لأن الجدولة
  `inexactAllowWhileIdle` (±1 ساعة تسليمًا) — لذلك هي ملحوظة وسؤال تحقق لا أكثر:
  هل السوق المصري وحده مقصود؟ إن نعم، القرار سليم كما هو.
- **الإصلاح:** على Windows/Android 26+ يمكن قراءة `TimeZone.name` الحقيقي بدل تخمين
  الإزاحة؛ أو اتركها مع تعليق يصرّح بالحد.

#### F-05 · `RELEASE_NOTES.md` متأخر عن إصدار قُطّع فعلًا
- **المكان:** `RELEASE_NOTES.md:1` (آخر مدخل "1.7.0+12, 2026-08-17") مقابل commit
  `8ca5793` الذي قصّ `1.8.0+14` بتاريخ 2026-08-19، و`pubspec.yaml:5`.
- **سيناريو الكسر:** توثيق التسليم لا يطابق ما وصل الهواتف — أول ما يقرأه وكيل قادم
  هو إصدار قديم بإصدارين (وهذا نوع الانحراف الذي حذرت منه PROJECT.md §"stale text").
- **الإصلاح:** أضف مدخل `1.8.0+14` (JSON export، checksum للنسخة السحابية، مزامنة
  الحالة الفارغة، Crashlytics) قبل قصّ الإصدار التالي.

---

## 4) قرارات محمية (وُجد من يقترح تغييرها — وهي مقصودة وموثقة)

1. **ترتيب الرادار مثبت RTL دائمًا** (`review_center_screen.dart:220-223`) — حتى في
   الوضع الإنجليزي يبقى اليوم الأقرب على اليمين. التعليق يصرّح أنها مثبتة عمدًا
   ("pinned here rather than inherited"). لا تلمسها.
2. **خطة ليلة الامتحان تُحسب لحظة الفتح بـ`ref.read`** (`exam_eve_sheet.dart:30-34`)
   — مقصودة: الورقة تُغلق قبل أي تنقل، والشيت عرض نقي قابل للاختبار بلا providers.
3. **كتابة uid بعد الـwipe لا قبله** (`backup_gate.dart:100-102`) — حماية من انقطاع
   منتصف المسح. أي إعادة ترتيب لهذين السطرين تفتح نافذة رفع بيانات طالب لملف طالب آخر.
4. **بصمة جدولة الإشعارات تُمسح قبل اللمس وليس بعده** (`review_notification_service.dart:352-353`)
   — اتجاه الفشل الآمن. لا "حسّنوها" بتأجيل المسح.
5. **`needsReview` مشتقة لا مخزنة**، و**نقطة حالة الدرس الثابتة** (`lastReviewedAt`
   يُعاد حسابه في نفس transaction عند `deleteExam` — `drift_study_repository.dart:520-592`)
   — قرار موثق في PROJECT.md §3.31.
6. **App Check بلا enforcement اليوم** (`main.dart:97-106`) — الترتيب ship→wait→enforce
   هو الوحيد الذي لا يقفل الطلبة على 1.2.0/1.3.1.
7. **الإغلاق الزجاجي للتاب بار حدودها الأربع** (BackdropFilter واحد، clip إلزامي،
   sigma غير متحرك، gate بالنظام لا بالحركة) — PROJECT.md §3.19.

---

## 5) أسئلة تستحق تحقيق (لا تُعد bugs — احتمالات بلا دليل كافٍ بعد)

1. **هل وصل إشعار حقيقي إلى جهاز حقيقي منذ إعادة بناء مسار الإشعارات؟**
   PROJECT.md §3.15a تقول "Still unverified". الكود سليم قراءةً، لكن الادعاء الوحيد
   الذي يهم المستخدم لم يُشهد عليه بعد.
2. **سلوك `nowProvider` عند إلغاء آخر مستمع ثم إعادة الاستماع** — `onCancel` يغلق
   الـcontroller (`app_providers.dart:124-127`)؛ في الإنتاج الـproviders keep-alive
   فلا يحدث، لكنه فخ محتمل لاختبار مستقبلي. راقبها إن ظهرت "stream done" غامضة.
3. **`deleteAccount` على حساب email/password يتطلب `requires-recent-login`** —
   المسار الثاني موجود عبر `deleteAccountWithPassword`؛ لم نجد ثغرة، لكن تجربة
   المستخدم النهائية لهذا المسار (sheet إعادة كتابة الباسورد) تستخدم شاشة يدوية
   واحدة لم نشاهدها تعمل.
4. **حجم `study_events` بلا حدود زمنية** (`tables.dart:171-196`) — يُكتب ولا يُقرأ
   بعد، ويركب كل upload. بعد سنة من الاستخدام المكثف قد يقترب الـpayload من سقف
   الـ900KiB (`firestore_backup_repository.dart:75`). قرار مبكر: سياسة تقاعد/تجميع
   للأحداث قبل أن يصبح السقف حقيقة طالب.

---

## 6) ما الذي فحصته الفرق بالتوازي (منهجية مختصرة)

| الفريق | المسحة | أبرز النتائج |
|---|---|---|
| 🕵️ مسح الكود (دومين/بيانات/شاشات) | `mastery_calculator.dart`، `review_cycle_service.dart`، `exam_eve_service.dart`، `insights_generator.dart`، `drift_study_repository.dart` (1138 سطرًا)، `exam_entry_screen.dart` (wizard)، `review_center_screen.dart` | لا bugs منطقية؛ الصيغة العددية وترتيب التعادل (id tie-break) سليمة |
| 🔐 الأمان | `firebase_auth_repository.dart`، `firestore_backup_repository.dart`، `firestore.rules`، `backup_gate.dart`، `secure_window.dart`، `auth_providers.dart` | القواعد تفرض الحجم على الخادم بـ`data.payload.size()` بشكل صحيح؛ فصل delete عن create/update في القواعد صحيح؛ تسلسل wipe→uid→flush guard متين |
| ⚡ الأداء | `app_providers.dart` (midnight timer + resume)، `_combineLatest6` بنافذة 16ms، fingerprint الإشعارات، autoDispose families | لا rebuilds زيادة؛ كل نافذة انتظار موثقة بمبرر قياس |
| 🧪 الاختبارات | تشغيل فعلي: `flutter analyze` (6 أخطاء خارجية فقط — F-02)، `flutter test` (**483 نجاح، 1 تخطٍ**) | F-01/F-03 |
| 🎨 UX والحركة | wizard، review center، exam-eve، day picker، reduce-motion paths | M-01..M-23 محترمة؛ لا shake/pulse؛ العربية جمع سليم |
| 📚 التوثيق | PROJECT.md ضد الكود، RELEASE_NOTES ضد git log | F-05 فقط؛ PROJECT.md استثنائي التطابق |
| ⚔️ المناقشة | حكم على F-01..F-04 | حذف 3 مرشحات ضعيفة (منها: "onCancel يغلق controller" كـbug إنتاجي — رفضه المعارض لأن keep-alive يمنع المسار) |
| ⭐ التصنيف | P/ثقة/مجهود | انظر §3 |

**تعريف الإنجاز:**
- [x] كل الطبقات اتمسحت بفرق موازية.
- [x] كل finding عدّى مناقشة (المؤيد/المعارض) أو اتحذف بسبب موثق.
- [x] بطاقة درجات + P0→P3 + أسئلة تستحق تحقيق — في هذا الملف.
- [x] صفر تعديلات على كود التطبيق؛ هذا الملف هو التغيير الوحيد في الcommit.
