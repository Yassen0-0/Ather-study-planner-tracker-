# 03-architecture.md — المعماري

> قرأت الكود كأني ورثته والمطلوب مني إضافة ميزة كبيرة الشهر الجاي. هذا المكان الذي كنت سأتألم فيه، وبنية الهدف، وأقصر طريق إليها. كل ادعاء بـ file:line — افتحه قبل أن تصدقني.

---

## 0) الخريطة التي ورثتها (سطرين)

الطبقات نظيفة الاتجاه: `presentation → domain ← data`، ولا يوجد أي `import 'package:flutter'` تحت `lib/domain/` (grep مؤكد). المصدر الواحد للحقيقة هو `StudySnapshot` يُبث من `_combineLatest6` فوق ستة جداول كاملة (`lib/data/repositories/drift_study_repository.dart:31-39`)، وكل شاشة تقرأ ملخصات محسوبة مسبقًا (`lib/domain/services/summaries.dart:146`). هذا قرار جيد وموثّق جيدًا — مشكلتي ليست مع الشكل بل مع **ثلاثة مواقع يبدأ فيها البيت بالانحناء**.

---

## 1) الإيجادات — حيث ستتألم

### A1. صيغة الإتقان مكتوبة في مسارين متوازيين، والنسخة التي تختبرها ليست النسخة التي تشتغل

- `MasteryCalculator.lessonMastery` (`lib/domain/services/mastery_calculator.dart:33-48`) و`MasteryCalculator.lessonMasteries` (`:56-77`): **نفس صيغة 70/30 مكتوبة حرفيًا مرتين** — الوزنان مضمنان inline في `:47` وفي `:73-74`. التعليق على `:50-55` يعرف السبب (تجنب النسخ والفرز) لكنه لا يمنع الانفراق، بل يجعله محتملًا: أي تعديل مستقبلي على الصيغة ("وزن آخر امتحانين") يجب أن يمس الموقعين معًا.
- نفس الثنائية تتكرر أعلى الهرم: مسار بطيء `chapterMasteryOf`/`subjectMasteryOf`/`overallMastery` (`mastery_calculator.dart:90-128`) ومسار سريع داخل `Summaries.chapter/subject/dashboard` يعيد نفس التجميعات inline (`lib/domain/services/summaries.dart:189-191`, `:246-248`, `:309-311`)، والتعادل بينهما محفوظ بالتعليقات ("Identical by definition", `summaries.dart:198-201`) وليس بالكود.
- **الأدهى:** `overallMastery` (`mastery_calculator.dart:121-128`) **ميت في الإنتاج** — grep كامل: لا يستدعيه إلا الاختبار (`test/domain/mastery_calculator_test.dart:186,193-194`). الداشبورد يعرض الرقم من الحقل المحسوب inline في `summaries.dart:309-311` (`dashboard.overallMastery` يُقرأ في `lib/presentation/dashboard/dashboard_screen.dart:231,254,277` و`lib/presentation/share/mastery_card.dart:233`). أي أن الاختبارات تتحقق من دالة لا يشغّل أحد، بينما الدالة الشغيلة بلا اختبار مباشر.
- يوجد اختبار عقد **واحد** يطابق المسارين عند مستوى الدرس فقط (`test/domain/mastery_calculator_test.dart:460-472`). لا شيء يطابق مستوى الباب/المادة/الكلي.

**لماذا ستتألم:** أول طلب "عدّل الصيغة" أو "أضف امتحان نهائي بوزن مختلف" سيضرب 5 مواقع، واثنان منها بلا اختبار يحرسهما.

### A2. خدمات التصدير تسكن domain وتكسر نقاوتها — وتحمل `DateTime.now()`

- `lib/domain/services/pdf_export_service.dart:4-7`: يستورد `path_provider` و`pdf` و`share_plus` — platform channels داخل الطبقة "النقية".
- `lib/domain/services/data_export_service.dart:4-5`: يستورد `path_provider` و`share_plus`.
- هذان الملفان يكتبان ملفات ويفتحان share sheet — عمل بنية تحتية I/O، لا حساب domain. التناقض موثق داخل الكود نفسه: `summaries.dart:14-15` يفتخر بأن domain "no Flutter, no database"، و`insights_generator.dart:12-13` بأنه "has no localisation" — وهذان الملفان لا يستوفيان روح القاعدة.
- أسوأ: `data_export_service.dart:68` يستدعي `DateTime.now()` مباشرة لبناء اسم الملف — **انتهاك وحيد لقاعدة Clock القابلة للحقن** التي يعلن عنها `study_repository.dart:61-66` ("like every other timestamp the app writes"). اختبار يثبّت الزمن لن يستطيع التحكم في اسم ملف التصدير.

**لماذا ستتألم:** كل ميزة "خروج بيانات" قادمة (PDF بخطة مراجعة، CSV، نسخة مجدولة) ستُقلِّد أقرب مثال موجود — وهو مثال مخالف. والجزء الوحيد من `DataExportService` القادر على الفشل فعليًا — `share()` (`data_export_service.dart:66-89`) — بلا أي تغطية اختبارية. *(تصحيح جولة 2: العبارة الأولى لهذه الجملة كانت تقول إن اختبارات التصدير "تختبر I/O حقيقيًا" — خطأ، انظر §جولة 2/ر2.)*

### A3. snapshotProvider: القرار الصحيح بثلاث نقاط كسر معلومة مسبقًا

التكلفة: أي كتابة في أي جدول تعيد بناء **كل** الكيانات من الصفر (mappers `drift_study_repository.dart:674-733`) + الفرز + الفهرسة، ثم تُبطل كل provider المشتقة (`dashboardProvider` `summary_providers.dart:63-68`، `reviewQueueProvider` `app_providers.dart:164-169`، `insightsProvider` `:171-176`). نافذة التجميع 16ms (`drift_study_repository.dart:748`) تبتلع bursts داخل transaction واحدة فقط — **نقرة checkbox = كتابة مستقلة = إعادة بناء كاملة** (`updateChecklist` `drift_study_repository.dart:364-377`، مستدعاة من `lesson_screen.dart:312-320`). تعليق `notification_providers.dart:63-68` يعترف بالمشكلة نفسها ويحلها debounce للإشعارات فقط.

نقاط الكسر الثلاث (بالترتيب الذي ستصله):

1. **الجدول السابع.** `_combineLatest6` مكتوب بستة بارامترات مصمتة الأنواع (`drift_study_repository.dart:750-758`). أي ميزة من قائمتك (خطط مراجعة، وحدات فرعية، وضع مدرسة) تحتاج جدولًا جديدًا ⇒ تكتب `_combineLatest7` أو تعمّمه ⇒ وتضيف حقلًا لـ`StudySnapshot` ⇒ وتمدد `StudyBackup` و`restore` (`:549-651`) ⇒ وschemaVersion 4 مع migration test. الممر ضيق ومعروف — المشكلة أنه **غير مكتوب في مكان واحد كمسار إلزامي**، فأول ميزة سيمر منها قد ينسى حلقة (عادة الـbackup round-trip).
2. **ميزة عالية التردد.** مؤقت جلسة دراسة أو تتبع تركيز يكتب كل ثانية ⇒ يضرب هذا المسار 60×/دقيقة. الـdocstring (`study_snapshot.dart:16-19`) يبرز "few hundred lessons, few thousand exams" — سنة ثانوية كاملة بامتحانات مراجعة أسبوعية تقترب من الحد.
3. **الاستثناءات من النقاء تتراكم عند الحواف.** `buildReviewQueue` يلفّ `snapshot.chapters` بلا فلترة (`review_cycle_service.dart:225`) و`_addWeakestChapter` كذلك (`insights_generator.dart:143`) بينما `upcomingReviewCount` (`:207`) و`activeLessons` (`study_snapshot.dart:105-115`) مفلترة — درس تحت مادة محذوفة يدخل مركز المراجعة وتنبيهه ملغى. هذه ليست bug معزولة؛ هي **عقود القرار**: "snapshot يحوي الكل، والفلترة مسؤولية القارئ" بلا آلية تفرضها، فكل مستهلك جديد يقرر بنفسه (ويخطئ بنصف الاحتمال).

**أقصر طريق (ليس الآن، لكن اكتبه):** قبل أول ميزة كبيرة — اختبار تحمل يقيس زمن بناء snapshot و`Summaries.dashboard` عند 600 درس/3000 امتحان، ليكون القرار مقيسًا لا موروثًا. وعند الجدول السابق: عمّم الـoperator إلى `List<Stream>` مرة واحدة.

### A4. تعريف "متقن" سياسة منتج تسكن في provider عرض

`homeStatsProvider` يعرّف الدرس المتقن بـ`hasExam && !needsReview && mastery >= 90` (`lib/presentation/providers/summary_providers.dart:48`) — شرط مركّب من ثلاثة مفاهيم domain، مكتوب في طبقة presentation. بالتوازي: `Chapter.isMastered` = `masteredAt != null` (زر "أتقنت الباب"، قد يقع عند 71%)، و`MasteryBand` >= 90 = "متفوق" (`mastery.dart:16-17`). ثلاثة معانٍ لجوار "متقن" في ثلاثة أدوار. الشاشة التالية التي تحتاج العدد (تقرير مشاركة؟ وضع مدرسة؟) ستنسخ الشرط من الـprovider أو تخترعه ثالثًا.

**أقصر طريق:** انقل العدّ إلى `DashboardSummary` (أو `HomeStats` داخل summaries.dart) كحقل محسوب باسم صريح (`currentlyMasteredLessons`)، واجعل الـprovider قراءة فقط. سطران يتحركان، والسياسة تعود لبيتها.

### A5. شاشة التحليلات تحسب خارج نظام الـproviders

`analytics_screen.dart:46-48` يستدعي `MasteryTrends.forAllSubjects(snapshot)` **داخل build مباشرة** — بلا provider ولا memoization. `subjectMasteryAsOf` (`insights_generator.dart:243-274`) تكلفة O(منهج كامل) لكل نقطة، × حتى 12 نقطة (`maxPoints` `:335`) × 4 مواد — ويعاد كلها عند كل `setState` لتغيير فلتر المادة (`analytics_screen.dart:107`). نفس الحسبة تعاد في `insightsProvider` (`app_providers.dart:171-176`) لمادة "الأفضل تحسنًا" (`insights_generator.dart:117`). البيانات تاريخية بحتة (لا تعتمد على `now`) — مثالية لـprovider يعتمد على `snapshotValueProvider` فقط.

**أقصر طريق:** `trajectoriesProvider = Provider(...)` سطر واحد في `app_providers.dart`، واستبدل الاستدعاء في الشاشة. يمنع التكرار عبر rebuilds ويرفع الحساب من widget إلى الطبقة المتفق عليها.

### A6. الكود الميت بتعليقات حية = فخ للوريث

- `quickExamTargetProvider` (`navigation_providers.dart:81-102`): grep لكامل `lib/` — **التعريف فقط، صفر call sites**. حاشيته (`:75-80`) تتحدث عن "the tab bar's black +" الذي أُزيل (`app_shell.dart:20-22` تؤكد الإزالة)، وكذلك تعليق `Routes.exam` (`router.dart:49-52`). ميت منذ التحديث البصري ويحمل تعليمات تشغيل لزر لم يعد موجودًا.
- `task_providers.dart:28-30` يعلّل اختيار `read` بأن `nowValueProvider` "re-emits every minute" — بينما هو يبث عند منتصف الليل + resume منذ إصلاح الساعة (`app_providers.dart:43-73`). القرار نفسه ما زال صحيحًا (watch هنا سيجرّ الطالب ليومه المعروض عند منتصف الليل) لكن سببه الموثق كاذب — ومن يثق بالتعليق سيبني عليه.

**أقصر طريق:** احذف `quickExamTargetProvider` وصحح التعليقين (`router.dart:49-52`، `task_providers.dart:28-30`). عشر دقائق، صفر مخاطرة.

### A7. l10n: ملتزم فعليًا — الاستثناء حرف واحد

القلق في `00-context.md` §4 كان في محله لكن الجواب مطمئن: sealed Insight classes تُرندر عبر ARB بالكامل (`analytics_screen.dart:170-192` — switch على الأنواع الأربعة إلى `l.insight*`)، ونصوص الإشعارات تدخل كcallbacks من الطبقة المحلية (`notification_providers.dart:143-150`). grep العربي في strings داخل اقتباسات عبر `presentation/` لم يُخرج إلا `'؟'` كأول حرف احتياطي في ثلاثة مواقع (`settings_screen.dart:282`, `profile_screen.dart:209`, `subject_presentation.dart:44`) — مقبول عمليًا، لكنه إن تكاثر فمفتاح ARB مشترك (`commonInitial`) أرخص من ثلاث نسخ. العربي الآخر كله: تعليقات، وقوالب منهج (`curriculum_templates.dart:53-76` — بيانات مقصودة، لا UI).

### A8. الاختبارات: أقوى مما ظن سياق الاستكشاف — لكن فيها فجوتان حقيقيتان

الموجود (فحصت عناوينها جميعًا): recycle bin (3 اختبارات سلوكية في `test/widget/recycle_bin_test.dart`)، export JSON (6 في `test/domain/data_export_test.dart` تشمل round-trip وversion marker وتصادم الأسماء)، PDF + raster (في `test/domain/pdf_export_test.dart`)، restore ids وfail-mid-way (`test/data/backup_restore_test.dart`)، deleteExam بشتى الحالات (`test/data/drift_study_repository_test.dart` group deleteExam)، وtrajectory/velocity كاملة (`test/domain/insights_generator_test.dart`).

الغائب:

1. **restore مع مادة في سلة المحذوفات:** `restore` يعيد كتابة `subjects` شاملة صفوف `deletedAt` (`drift_study_repository.dart:566-581`). لا اختبار واحد يسأل: هل تنجو المادة المحذوفة من استعادة نسخة احتياطية، أم تستعيد كصف سليم؟ (`backup_restore_test.dart` يختبر added/archived/v1 — لا deletedAt). إن كانت غير مقصودة فهي ثغرة بيانات؛ وإن كانت مقصودة فلا اختبار يحرسها.
2. **deleteExam × checklist:** `deleteExam` يصلح الساعة (`:457-523`) لكنه لا يمس `didExam` — حذف آخر امتحان يترك checklist مكتوبًا "امتحنت". لا اختبار سلوكي يوثق القرار (هل هو مقصود؟). الفرق عن حالة `lessonsAwaitingNotification` المحذوفة موثقة (`review_cycle_service.dart:315-327`): هناك اقتُرح الحذف، وهنا القرار الصامت بلا وثيقة ولا اختبار.
3. (ثانوية) لا cross-check بين المسارين البطيء/السريع أعلى من مستوى الدرس (تكملة A1)، ولا اختبار تحمل للـsnapshot (A3).

### A9. أين تقع الميزات إذا طُلبت غدًا — جرد البيانات الفعلي

| طلب | البيانات موجودة؟ | أين يسكن | ما ينقص |
|---|---|---|---|
| جدول زمني للمراجعات / خطة تلقائية | ✅ `exams.createdAt` (`tables.dart:126`)، `lastReviewedAt` (`:77`) | حسابه pure في `ReviewCycleService` + provider فوق snapshot — **لا يحتاج schema** لو كان مشتقًا | لو احتاجت "خطة" حالة محفوظة (موعد مخطط، تأجيل) ⇒ جدول جديد ⇒ ممر A3 كاملًا |
| إحصائيات يومية | جزئيًا: امتحانات/واجبات/مهام لها `createdAt`/`day` (`tables.dart:106,126,141,152`) | مشتقة من snapshot بلا schema | **خطوات الدراسة بلا أي تاريخ**: خمسة booleans مسطحة (`tables.dart:85-93`) تُكتَب overwrite في `updateChecklist` (`drift_study_repository.dart:368-376`)؛ و`task.done` بلا `completedAt` (`tables.dart:145`). "ماذاذاكر يوم الثلاثاء؟" عن الخطوات **غير قابل للاشتقاق — البيانات غير موجودة أصلًا** |
| مواد فرعية/وحدات | ❌ الهرمية صلبة `Subject→Chapter→Lesson` (`tables.dart:51-94`) | — | إضافة مستوى = أثقل migration في القائمة (FK، شاشات، فهارس snapshot، backup). البديل الأرخص: حقل `groupId` nullable على chapters بدل جدول جديد |
| استهداف درجات نهائي / وزن امتحان نهائي | ✅ الامتحانات محفوظة بمجموعاتها | `MasteryCalculator` — لكن انظر A1: الصيغة في مسارين | أي تغيير وزن يضرب 5 مواقع (A1) قبل أن يضرب UI |

**القرار المعماري المطلوب قبل الشهر الجاي:** إذا كانت "إحصائيات يومية" أو أي سجل نشاط واردة فعلًا، فالقرار ليس "أين الشاشة" بل **هل نضيف جدول أحداث append-only الآن** — لأن كل يوم تأخير بعده هو تاريخ لا يمكن استرجاعه من booleans تُكتَب فوق بعضها. هذا هو الوجود الوحيد في القائمة الذي **يكلف أكثر بانتظاره**.

---

## 2) بنية الهدف

لا تغيير في الشكل — الشكل سليم. التغيير في **ثلاث قوانين** تجعل الممر الضيق آمنًا:

1. **domain نقية فعليًا:** الكيانات + الحساب + السياسة. لا plugin، لا I/O، لا `DateTime.now()` — Clock فقط. خدمات الخروج (export/pdf/share) تسكن `lib/data/`.
2. **الصيغة بمكان واحد:** `lessonMasteries` تستدعي نواة مشتركة تقرأها `lessonMastery` بعد فرزها (أو تُحذف `overallMastery` الميتة ويُعتمد رقم `Summaries.dashboard` رسميًا مع اختبار عقد يطابق المسارين عند المستويات الأربعة).
3. **مسار الجدول الجديد إلزامي ومكتوب:** `tables.dart → schemaVersion+N → migration + test → StudyBackup round-trip → StudySnapshot field → combineLatest(N)` — قائمة تحقق في CLAUDE.md أو PROJECT.md، لا في رأس قائد الفريق.

---

## 3) أقصر طريق — خطوات صغيرة، التطبيق شغال بعد كل واحدة

| # | الخطوة | الملفات | الحجم | تخفض ألم |
|---|---|---|---|---|
| S1 | احذف `quickExamTargetProvider` وصحح تعليقي `router.dart:49-52` و`task_providers.dart:28-30` | `navigation_providers.dart`, `router.dart`, `task_providers.dart` | S | A6 |
| S2 | انقل `pdf_export_service.dart` + `data_export_service.dart` إلى `lib/data/export/` وحدّث imports ومسارات الاختبار (move ميكانيكي، لا تغيير منطق) | الملفان + `export_providers.dart` + اختبارهما | S–M | A2 |
| S3 | مرّر `Clock` إلى `DataExportService.share` واستخدمه في `buildFilename` بدل `DateTime.now()` | `data_export_service.dart:68` | S | A2 |
| S4 | استخرج نواة الصيغة المشتركة: `lessonMasteries` تستدعي `_masteryFromSorted(exams)` التي تستدعيها `lessonMastery` بعد الفرز؛ الثوابت `kRecentWeight/kHistoryWeight` بدل inline | `mastery_calculator.dart:33-77` | S | A1 |
| S5 | اختبار عقد: المسار السريع == البطيء عند مستويات chapter/subject/overall (نمط `mastery_calculator_test.dart:460-472` معممًا)؛ واحذف أو وظّف `overallMastery` الميتة | `mastery_calculator_test.dart` | S | A1 |
| S6 | `trajectoriesProvider` في `app_providers.dart` واستبدل استدعاء build في شاشة التحليلات | `app_providers.dart`, `analytics_screen.dart:46-48` | S | A5 |
| S7 | انقل تعريف "متقن" من `homeStatsProvider` إلى `DashboardSummary` | `summaries.dart`, `summary_providers.dart:34-61` | S | A4 |
| S8 | اختبار restore مع مادة `deletedAt` + اختبار deleteExam×didExam — ليقررا السلوك ويوثقاه | `backup_restore_test.dart`, `drift_study_repository_test.dart` | M | A8 |
| S9 | اختبار تحمل snapshot/dashboard عند 600 درس/3000 امتحان — يقيس قرار A3 قبل أول ميزة كبيرة | test جديد | M | A3 |
| S10 | *(عند أول جدول سابع فقط)* عمّم `_combineLatest6` إلى قائمة streams + وثّق مسار الجدول الجديد كقائمة تحقق | `drift_study_repository.dart:736-832` | M | A3 |

كل خطوة مستقلة، لا تعتمد على أخريات إلا S4→S5 وS2→S3. لا شيء فيها "إعادة هيكلة عامة".

---

## أهم 3

1. **الصيغة في مسارين متوازيين بلا عقد يربطهما — والنسخة المختبَرة (`overallMastery`) ميتة في الإنتاج بينما الشغيلة بلا اختبار مباشر.** أول تعديل على الصيغة سينفرك بصمت. (A1)
2. **خدمات التصدير في domain تكسر نقاوتها وتحمل `DateTime.now()` الوحيد في البيت** — وهي النموذج الذي ستقلده كل ميزة خروج بيانات قادمة. انقلها وانقض العادة قبل أن تنتشر. (A2)
3. **أي ميزة كبيرة قادمة تمر من ممر ضيق واحد غير موثق: جدول جديد ⇒ `_combineLatest6` مصمت العدد + StudySnapshot + StudyBackup + migration.** وثّق المسار الآن، وقرر مصير "سجل نشاط يومي" قبل أن يستمر فقدان تاريخ الخطوات (booleans بلا تواريخ) يومًا أطول — هذا الوحيد الذي يكلف أكثر بانتظاره. (A3 + A9)

---

# جولة 2

> ثلاث مهام: حسم A9/A3 بتكلفة صريحة، وتدقيق ادعاءين اختباريين من الجولة الأولى، وقرر معماري لطبقة share/raster أمام فكرة #14. نفس القاعدة: كل ادعاء بـ file:line.

---

## ر1. توصية A9/A3 النهائية — جدول `study_events` بالتكلفة الكاملة

### السكيما الأصغرية (شكل المستخدم حرفيًا: id/type/refId/at/payload)

```dart
/// سجل نشاط append-only. لا يُحدَّث ولا يُحذف إلا بحذف ما يشير إليه
/// (restore/clear). ليس جزءًا من StudySnapshot — انظر «الأثر الثالث» أدناه.
@DataClassName('StudyEventRow')
class StudyEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'checklist_step' | 'task_done' — نوعان فقط في هذه النسخة.
  TextColumn get type => text().withLength(min: 1, max: 24)();

  /// lessonId أو taskId. nullable احتياطًا لأنواع مستقبلية بلا مرجع صف واحد.
  IntColumn get refId => integer().nullable()();

  /// JSON صغير: {"step":"didExam","to":true}. نص مقصودًا لا أعمدة —
  /// الأنواع ستتكاثر وأي عمود جديد هو migration كامل.
  TextColumn get payload => text().nullable()();

  DateTimeColumn get at => dateTime()();
}
```

فهرس وحيد تستحق ثمنه: `@TableIndex(name: 'idx_study_events_at', columns: {#at})` — كل سؤال مخطط له ("ماذا ذاكر يوم الثلاثاء؟") مسح مدى زمني، والجدول سيكبر خطيًا بلا سقف.

### التكلفة الصريحة، بندًا بندًا

1. **الجدول:** `tables.dart` ~20 سطرًا كما فوق.
2. **Migration:** `schemaVersion` من 3 إلى 4 (`app_database.dart:53`)، وسطر واحد في `onUpgrade` على نمط التراكم القائم `if (from < 4) await m.createTable(studyEvents);` (`app_database.dart:68-80`). اختباره بنفس منهج `test/data/task_migration_test.dart:27-50`: بناء صورة v3 حقيقية ثم إعادة الفتح عند v4. تعليق `app_database.dart:40-46` يقول إن v3 لم تُشحن بعد — لا يهم هنا: الصيغة التراكمية تغطي الحالتين بنفس السطر.
3. **StudyBackup round-trip:** `formatVersion` من 3 إلى 4 (`study_backup.dart:51`). حقل `final List<StudyEvent> events;` مع كتلة toJson/fromJson (~25 سطرًا). **النمط جاهز حرفيًا:** `fromSnapshot` يأخذ tasks باراميترًا منفصلًا عن snapshot لنفس السبب تمامًا (`study_backup.dart:71-83`) — events تأخذ مقعدها الثاني. موضعا التجميع يتحدثان: `export_providers.dart:65` و`backup_providers.dart:147`. وفي `restore` داخل نفس الـtransaction: `await _db.delete(_db.studyEvents).go();` + insertAll (`drift_study_repository.dart:553-649`). أثر جانبي مقصود: نسخة v4 تُرفض على build قديم رفضًا صريحًا لا نصف قراءة — هذا اتجاه الأمان المعلن (`study_backup.dart:34-51,179-184`). عدم حملها يعني أن استعادة على هاتف جديد تمحو التاريخ الذي بُني الجدول من أجله — فيُلغى جدولٌ بلا backup معناه.
4. **الكاتبَان فقط — وهنا التكلفة الخفية:** الامتحانات والواجبات و`masteredAt` مستبعدة لأنها تحمل تواريخها أصلًا (`tables.dart:126,106,60`). يبقى المكتوبان بلا تاريخ: `updateChecklist` (`drift_study_repository.dart:364-377`) و`setTaskDone` (`drift_task_repository.dart:69-73`) — وكلاهما **بلا باراميتر زمن اليوم**، بينما أسلوب البيت يتطلب `required DateTime at` (`recordExam :396`، `createChapter :187`). إذن: إضافة `at` لتوقيعيهما، وتمريرها من `lesson_screen.dart:316` ومن `tasks_screen.dart:175` عبر Clock. ولوج انتقالات فقط (false→true والعكس) لا كل كتابة: المستودع يقرأ الصف قبل التحديث ويكتب الفرق — قراءة واحدة إضافية لكل tick.
5. **أثر snapshot/combineLatest: صفر، بالتصميم.** لا يدخل `_combineLatest6` (`drift_study_repository.dart:31-39`) ولا `StudySnapshot`. **وهذا هو القرار الحامل في التوصية:** إدخاله يجعل كل tick checkbox يعيد تجسيد التاريخ كله المتنامي ضمن إعادة البناء الكاملة — أي تسريع نقطة الكسر الثانية في A3 بمقدار نمو التاريخ نفسه. القراءة حين يحتاجها قارئ: استعلامات مدى على `at` عبر method مخصصة في repository، تجميع pure في domain service، provider فوقه — لا عبر `snapshotValueProvider`.

### هل يحل المشكلتين معًا؟

نعم، وبالتعريف: checklist-history = انتقالات الخطوات الخمس مؤرخة (`tables.dart:85-93` booleans تُكتب فوق بعضها في `drift_study_repository.dart:368-376`)؛ task-completion-date = انتقالات done/undone مؤرخة (`tables.dart:145` done أعمى). ولا يمس الصيغة ولا mastery إطلاقًا — لا تفاعل مع A1.

### القرار: **الآن — نسخة "الالتقاط فقط"**

التجارة في سطرين: تكلفة اليوم **ثابتة وصغيرة** (migration إضافي من أرخص عائلاته — createTable على نمط مُختبَر، وبنية backup جاهزة تستقبل حقلًا ثانيًا)، بينما تكلفة الانتظار **تراكمية بلا سقف** — كل يوم تشغيل بطلانه يُمحى نهائيًا من سجل كل طالب شغّال، والميزة نفسها ستُبنى لاحقًا بالتكلفة ذاتها زائد ثقب التاريخ. قفل النطاق شرط قرار "الآن": جدول + migration/اختبار + حمل في backup + الكاتبَان المؤرخان — **لا UI، لا قرّاء، لا دخول snapshot**. وإلا تحوّل "الآن" إلى ممر الجدول السابع الذي حذّر منه A3. البيان الوحيد الذي يقلب القرار ليس "مؤجل" بل **"ملغى"**: لو أقسم مالك المنتج أن إحصائيات النشاط/الخطوات لن تُبنى في عمر التطبيق، يُحذف البند بكلفته صفرًا — التأجيل المجرد هو الخيار الوحيد الذي خسر فيه الطرفان.

---

## ر2. تدقيق ادعاءَي الاختبارات (A8(1) وA2)

### `test/data/backup_restore_test.dart` — الادعاء **صحيح**

ستة اختبارات معدودة بالاسم: ids محفوظة (`:118`)، استبدال لا دمج (`:139`)، subjects المضافة تُحمل (`:150`)، نسخة v1 لا تمس المزروعة (`:162`)، فشل منتصف الطريق يترك القاعدة سليمة (`:182`)، نسخة فارغة تفرّغ السجل (`:232`). **ولا واحد منها يبني Subject بـ`deletedAt` ويتابع مصيره عبر restore** — رغم أن المسار يحمله في موضعين: `drift_study_repository.dart:578` و`study_backup.dart:98,196`. فجوة A8(1) قائمة كما وُصفت؛ S8 يبقى كما هو. والسؤال الذي يجب أن يجيب عنه الاختبار الأول: هل المادة المحذوفة تنجو من الاستعادة أم تُستعاد صفًّا سليمًا — سلوك اليوم غير موثق بأي اختبار.

### `test/domain/data_export_test.dart` — ادعائي **كان خطأً، وصُحح في متن A2**

الجولة الأولى قالت إنه "يختبر I/O حقيقيًا تحت مسمى domain". فتحتُه الآن: **لا I/O حقيقي ولا path_provider mocking إطلاقًا** — الملف يعلن امتناعه عمدًا في docstring صريح (`:13-19`: "the file layer is two path_provider calls and a share sheet, and neither exists in a unit test"). الاختبارات الستة (`:103-159`) تغطي `encode()` و`buildFilename()` فقط — دالتان نقيتان: round-trip عبر `jsonDecode`+`fromJson` (`:100-101`)، تصدير فارغ، version marker، الإزاحة للقراءة البشرية، الطابع الزمني، تصادم الأسماء.

التصحيح لا يبرئ A2 بل يعيد توجيه اللوم بدقة: الجزء المختبَر هو الجزء الذي لا يكاد يخطئ، والجزء القادر على الفشل فعليًا — `share()` بكل ما فيه من `getTemporaryDirectory` و`Share.shareXFiles` ومعالجة `ShareResultStatus.unavailable` (`data_export_service.dart:66-89`) — **بلا سطر اختبار واحد**. درس منهجي يسجَّل هنا: ادعاء "الاختبارات تختبر X" يُفتح له الملف قبل أن يُبنى عليه قسم.

---

## ر3. طبقة share/raster ومصير شهادة الباب (#14)

### أين ينتمي كلٌّ منهما

- **`widget_raster.dart` = بنية تحتية عرض عامة، لا شيء خاص بالتطبيق فيها.** importsها كلها flutter/rendering وdart:ui (`:1-5`) — لا theme، لا l10n، لا branding. وهي **أصلًا قابلة لإعادة الاستخدام ومُعاد استخدامها**: مستهلكان بنفس العقد وبمعاملات مختلفة كليًا — تقرير الباب إلى PDF بعرض 520 وpixelRatio 2.5 (`chapter_report_screen.dart:65-82`) وكارت المشاركة إلى PNG بعرض 360 وpixelRatio 3 (`mastery_card.dart:250-257`). انتماؤه الطبيعي `lib/core/` (بنية تحتية rendering)، لكن النقل تجميلي — مكانه الحالي مقبول.
- **`mastery_card.dart` = ثلاثة أدوار غير متجانسة في ملف واحد:** widget عرض سليم (`MasteryCard :39-136`)؛ **سياسة عدّ domain-flavored** — `lessonsAboveThreshold` (`:195-201`) تعيد تعريف "متقن" للمرة الثانية خارج domain (توأم A4، وعتبتها `kChapterMasteryThreshold` نفسها)؛ و**تنسيق خروج بـI/O** — `shareMasteryCard` (`:209-272`) يستورد path_provider وshare_plus (`:5-6`) ويكتب ملفات ويفتح share sheet من presentation.

### هل coupling في خط RepaintBoundary→PNG يمنع #14؟

**الخط نفسه: لا.** الدليل قائم في الكود — chapter_report يمرر widget وعرضًا وسينكًا مختلفين تمامًا عبر نفس `rasterizeBlocks` (`widget_raster.dart:42`) دون لمسه. `PdfExportService` يستهلك الناتج عبر `PdfBlock(png bytes)` فقط (`pdf_export_service.dart:26-31`) — منفصل نظيف.

**ما سيُنسخ ثلاث مرات هو الغلاف حوله، وهو coupling بالتكرار لا بالتبعية:**

1. **سقالة الالتفاف** Directionality→MediaQuery(textScaler: noScaling)→DefaultTextStyle(fontFamily: 'ReadexPro')→RepaintBoundary (`mastery_card.dart:221-248`). فيها فخان مدفونان بلا حارس: قصّ مقياس النص (إطار الصورة ثابت — مقياس 2× يدفع الصفوف خارجها، `:224-226`) واسم الخط. شهادة الباب ستنسخهما أو **تنسى أحدهما** — والفشل بصري بصمت.
2. **استدعاء الراستر + encodePng + dispose الصور** (`mastery_card.dart:250-266`).
3. **ذيل الخروج**: getTemporaryDirectory → writeAsBytes → Share.shareXFiles (`:268-271`) — النمط نفسه في `data_export_service.dart:72-88` وفي مسار pdf (`chapter_report_screen.dart:95-99`).

وأضِف أن الشهادة تحتاج عدّادًا مختلفًا (عدد الامتحانات التي أثبتت الباب، لا الدروس فوق العتبة) — فما دام `lessonsAboveThreshold` يسكن ملف الكارت، ستضطر #14 إلى استيراد ملف عرض للحصول على سياسة عدد لا تخصه.

### أصغر تعديل يجعل الخط قابلًا لإعادة الاستخدام (S11)

دالة **واحدة** في `presentation/share/` (إلى جانب `widget_raster.dart`) تمتلك السلسلة كاملة:

```dart
Future<void> captureAndShare({
  required Widget child,          // المحتوى، بلا أي سقالة
  required double width,
  double pixelRatio = 3,
  required String filename,       // بدل 'ather_progress.png' المدفون (:269)
})
```

وتشمل: حل context values (colors/brand/direction/view) عند حدودها، السقالة الرباعية، rasterizeBlocks، encodePng + dispose، الملف، المشاركة. `shareMasteryCard` يتقلص إلى "ابنِ rows واستدعِ"، والشهادة (#14) تصبح ملف widget + سطر استدعاء — والفخان يُفرَضان في مكان واحد إلى الأبد. ~60 سطرًا منقولًا، صفر تغيير سلوك. الذيل (file+Share) يلتقي لاحقًا مع خدمات الخروج حين تنتقل في S2 إلى `lib/data/export/` — لكن S11 لا ينتظره.

---

## خلاصة جولة 2

| المهمة | النتيجة |
|---|---|
| جدول الأحداث | **الآن، نسخة الالتقاط فقط** — schemaVersion 4، كاتبَان مؤرخان، backup v4 يحمله، صفر عضوية في snapshot |
| تدقيق الاختبارين | backup_restore: الفجوة حقيقية كما وُصفت. data_export: ادعاءي خطأ وصُحح — لا I/O ولا mocking؛ الفجوة الفعلية `share()` بلا تغطية |
| share/raster | الخط قابل لإعادة الاستخدام أصلًا؛ الخطر في الغلاف المكرر. S11: دالة `captureAndShare` واحدة تحسم #14 قبل أن تولد |
