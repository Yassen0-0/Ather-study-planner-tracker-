# 04-performance.md — صياد الأداء

قرأت المكدس كله من `main.dart` حتى آخر شاشة، وتتبّعت سلسلة الضغطة الواحدة من الـcheckbox حتى الفريم.
**صفر أرقام مخترعة**: كل إيجاد تحته وصفة قياس، والاستنتاج الكمي الوحيد المسموح به هنا هو حساب تعقيد
(O(...)) مشتق من الكود نفسه، وثوابت مقروءة من الملفات (16ms، sigma 24، 150ms).

---

## جولة 2 — تصحيحات بعد قراءة كود الحزمة نفسه (pub cache، riverpod/flutter_riverpod 3.4.2)

### ج2-أ) ادعاء «autoDispose افتراضيًا» في جدول §1: **غلط** — وهذا أهم تصحيح في التقرير

كتبتُ أن Riverpod 3 يصفّي عائلات summary عند unmount «فلا تراكم غير محدود كما في 2.x». هذا خطأ
لهذا المشروع تحديدًا، وسلسلة الدليل من الكود المثبَّت فعليًا:

1. العائلات الأربع معرّفة يدويًا بلا `.autoDispose`: `subjectSummaryProvider` و
   `chapterSummaryProvider` و`lessonSummaryProvider` و`chapterOfLessonProvider`
   (`summary_providers.dart:70-110`).
2. الافتراضي في الـAPI اليدوي لـ3.4.2 هو keepAlive: `super.isAutoDispose = false`
   (`riverpod-3.4.2/lib/src/providers/provider.dart:24`، وكذلك `stream_provider.dart:96,213`)،
   وباني `.family` نفسه افتراضه false (`lib/src/builder.dart:430`). الـautoDispose يبقى opt-in:
   `Provider.autoDispose.family<...>` (`builder.dart:472-490`).
3. الإزالة عند فقدان المستمعين مشروطة صراحةً: `mayNeedDispose()` لا يجدول dispose إلا
   `if (provider.isAutoDispose)` (`lib/src/core/element.dart:1223-1231`)، ولا يوجد أي
   eviction/LRU لدليل العائلة في الحاوية — العنصر لا يُزال إلا بـinvalidate/remove يدوي أو بموت
   الحاوية.

**النتيجة المصححة**: كل درس/باب/مادة زاره الطالب في الجلسة يترك عنصرًا + ملخصًا مخزنًا حيًّا حتى موت
العملية، و`chapterOfLessonProvider(lessonId)` يجرّ معه قيد `chapterSummaryProvider(chapterId)`
متسلسلًا. وللأمانة في تقدير الخطورة: التراكم **ذاكرة فقط لا حسابًا** — العنصر غير المسموع إليه
يصير inactive فتتوقف سلسلة إعادة الحساب عنده وتؤجل حتى الاستماع القادم (`onCancel` يوقف اشتراك
الـstream الأساسي، `element.dart:187-199`). أي تسريب بطيء غير محدود الحد، أثقل مما كتبت، لكنه ليس
انفجار CPU.

**الإصلاح**: كلمة واحدة لكل عائلة — `Provider.autoDispose.family<...>` للعائلات الأربع. الثمن
المقبول: فقدان memoization بين الزيارات (إعادة حساب O(درس/باب/مادة) عند كل فتح شاشة، رخيصة نسبةً
لما تعيد الشاشات أصلًا). البديل إن أردنا الكاش: إبقاؤها keepAlive عمدًا مع invalidate عند إغلاق
الروت — قرار صريح بدل السلوك الصامت الحالي.

### ج2-ب) نطاق pause-under-TickerMode أدق مما كتبته — والادعاء الأصلي يصمد جوهريًا

من `flutter_riverpod-3.4.2/lib/src/core/consumer.dart`:

- ما يتوقف: **اشتراكات `ref.watch` على مستوى الويدجت فقط**. `_updateTickerMode()` يدور على
  `_dependencies` وحدها (`:420-432`)، والاشتراك الجديد يمر بـ`_applyTickerMode` (`:494`).
- ما لا يتوقف: `ref.listen` داخل build يذهب إلى `_listeners` (`:551`) ولا يلمسه TickerMode إطلاقًا
  — الـcallbacks تستمر والويدجت مخفي. وكذلك `listenManual` (`_manualListeners`, `:579-613`).
- وما لا يتوقف أبدًا: اشتراكات provider↔provider في نواة riverpod — خارج Flutter كليًا.
  `BackupSyncNotifier` يستخدم `Ref.listen` داخل `Notifier.build` (`backup_providers.dart:76-77`)
  فلا يعرفه TickerMode أصلًا. أما `ReviewScheduler` فـ`ref.listen` عنده WidgetRef.listen داخل
  build ويدجت (`notification_providers.dart:185-192`) — لو حُفي لاستمر، لكنه مركَّب قرب الجذر
  (`:51`)، فصفّه في الجدول «نشط دائمًا» صحيح والسبب مزدوج لا واحد.
- الأثر النهائي يصمد: حين تتوقف كل المستمعين النشطين لمزوّد يصير العنصر inactive فيوقف `onCancel()`
  اشتراك الـstream الأساسي نفسه (`element.dart:187-199`) — فالتبويبات المخفية توقفت عن الحساب فعلًا
  حتى وهي keepAlive، والحالة باقية في الذاكرة، والمتغيّر الفائت يُردّ عند الاستئناف كما في تصحيح 1.
  الفرق الوحيد عن صياغتي الأولى: الآلية تعمل عبر inactivity متسلسلة، لا عبر dispose تلقائي.

### ج2-ج) تكلفة reschedule عند تغيّر البصمة — الحساب

الحارس موجود: تطابق البصمة يعيد مبكرًا بصفر IPC (`review_notification_service.dart:314`). المكلف
هو المسار المتغيّر فقط: `cancelAll()` واحدة (`:321`) ثم `zonedSchedule` **بانتظار متسلسل** لكل
تذكير (`:327-350`) — تذكيران كحد أقصى لكل درس، بسقف صلب `kMaxScheduledAlarms = 400` منبهًا
(`:173`). فطالب بـ200 درس كلها داخل النافذة = حتى 401 نداء platform متتاليًا على الخيط الرئيسي في
تمريرة واحدة، كل نداء تسجيل AlarmManager جهة النظام. تعليق الكود نفسه يعترف بالثمن (`:279-283`).

مضخّمان يجعلان المسار المتغيّر أكثر تكرارًا مما يبدو:

1. `_applied` في الذاكرة فقط (`:155`) — **كل تشغيل بارد جديد يدفع تمريرة إعادة بناء كاملة** لأن
   null ≠ أي بصمة.
2. `planReminders` يرشّح بالوقت الحالي (`:210`, `:225`) — أي تذكير تجاوز لحظته منذ آخر تمريرة يخرج
   من الخطة فتتغير البصمة، فتمريرة resume تدفع البناء الكامل حتى بلا أي كتابة من الطالب.

التخفيف المقترح (بالترتيب):

1. خزّن البصمة المطبقة في SharedPreferences (محملة أصلًا في `main.dart:19`) — يقتل المضخّم 1.
2. فرّق بدل الإعادة الكاملة: قارن الخطة الجديدة بالمطبقة لكل id واستخدم `cancel(id)` /
   `zonedSchedule` للمتغيّر فقط — تعديل درس واحد يصبح نداءين بدل 401.
3. صغّر السقف الزمني: تعليق الكود ذاته (`:169-172`) يحتج بأن البعيد لا يكلّف شيئًا لأن التمريرة
   تعاد عند كل resume — سقف «الأقربون فقط» يقصّ أسوأ حالة تناسبيًا بلا خسارة وظيفة.
4. قسّم الحلقة دفعات مع yield بينها كي لا تتركز معالجة رسائل الـchannel في فريم resume الواحد.

وللدقة: انتظار نداءات platform channel لا يسد الخيط الرئيسي حسابيًا؛ الكلفة زمن مضاف + معالجة
رسائل على الخيط الرئيسي + تسجيلات جهة النظام. القياس: profile mode، `Timeline.startSync` حول
`_sync()`، fixture بـ200 درس، وقارن resume ببصمة متغيرة مقابل ثابتة.

### ج2-د) startup: ترتيب حجم الانتظارات بالاستدلال (لا قياس)

التسلسل قبل `runApp`: prefs (`main.dart:19`) ← `Firebase.initializeApp` (`:29-31`) ←
`_activateAppCheck` (`:32`) ← `_initializeCrashlytics` (`:33`).

- SharedPreferences: قراءة ملف صغير عبر platform channel — من رتبة مللي ثوانيات دافئة، وعشرات
  عليها باردة. انتظار مبرر (وميض اللغة `:16-18`).
- `Firebase.initializeApp`: تهيئة محلية بلا شبكة (التعليق `:21-23` ينصّ على ذلك) — من رتبة عشرات
  المللي ثوانيات عادةً. انتظار مبرر (جلسة offline للراوتر).
- `_activateAppCheck`: **المجهول الوحيد** — Play Integrity يعتمد شبكةً وخدمات Play، وقد يكون الأغلى
  والأكثر تقلبًا في السلسلة. لا أخمّن رقمه؛ أكتفي بأنه المرشح الأول للنقل بعد أول فريم: enforcement
  مطفأ وفشله مقصود غير مؤثر (`:67-70`)، فنقله لا يغيّر سلوك اليوم إطلاقًا.
- Crashlytics: إسناد حقل متزامن في release (`:119`) ولا شيء في debug (`:115`) — مهمل.

كيف يُقاس ويُفسَّر: `adb shell am start -W com.ather.app/.MainActivity` (وسّط TotalTime على عدة
بدءات باردة) + سطر Displayed في logcat + `flutter run --profile --trace-startup` ثم اقرأ الفجوة
قبل runApp في DevTools؛ غلّف كل await مؤقتًا بـ`Timeline.startSync` لتوزيع النصيب. قاعدة التفسير:
كل ما قبل runApp يؤجل أول فريم 1:1، ومقارنة وضع الطيران/online تعزل نصيب App Check الشبكي المتقلب.

---

## 0) تصحيحان لفرضيتي المهمة — الكود أثبتهما قبل أي حكم

### تصحيح 1: الفروع المخفية **لا** تُعاد بناؤها عند كل كتابة… لكن الثمن لا يختفي، يتأجل

فرضية المهمة كانت أن `BranchCrossFade` يُبقي كل الفروع mounted تحت الـblur فتدفع ثمن كل كتابة.
هذا نصف صحيح:

- flutter_riverpod **3.4.2** يوقف (pause) اشتراكات أي `ConsumerWidget` واقع تحت `TickerMode(enabled: false)`
  — مصدر الحقيقة: `flutter_riverpod-3.4.2/lib/src/core/consumer.dart:75-76` و`:405-428`
  (`TickerMode.getNotifier(context)` ثم `sub.pause()`).
- و`BranchCrossFade` يلفّ كل فرع مخفي بـ`TickerMode(enabled: i == currentIndex)`
  (`app_shell.dart:245-247`).

فالداشبورد ومركز المراجعة والتحليلات المخفية **لا تعيد البناء ولا تعيد الحساب** عند كتابة تحدث وأنت
على تبويب آخر. الرسم (paint) متخطى أصلًا لأن `AnimatedOpacity(0)` يقصّره، والبناء محسوب.

**لكن** — والهنا الإيجاد — العمل المؤجل يُردّ دفعة واحدة على **فريم تبديل التبويب نفسه**: لحظة
`goBranch` يستأنف الفرع اشتراكاته، يجد الاعتمادات تغيّرت، فيعيد الحساب ويعيد البناء في نفس الفريم الذي
فيه crossfade بمدة `AppMotion.nav` (150ms، `app_spacing.dart`) وفوقه `BackdropFilter` يعيد ترشيح ما
تحته. تبديل التبويبات هو أغلى عملية روتينية في التطبيق الآن، وليست الكتابة وحدها.

### تصحيح 2: SQL يعمل في isolate خلفي، لكن بناء الـsnapshot يعمل على UI isolate

`driftDatabase(name: 'sahm')` (`app_database.dart:34`) يفتح الاتصال عبر
`NativeDatabase.createBackgroundConnection` (`drift_flutter-0.3.1/lib/src/native.dart:131`) — الاستعلام
والـrow-mapping لصفوف drift في isolate خلفي ✓. لكن الصفوف تُشحن عبر حدود الـisolate إلى UI isolate،
وهناك بالضبط يعمل `_buildSnapshot` (`drift_study_repository.dart:63-106`): تحويل كل صفوف الجداول الستة
إلى كيانات domain، تجميع الخرائط، وفرز الأبواب والدروس وقوائم الامتحانات — **على الخيط الرئيسي، عند كل
انبعاث**. وكذلك مُنشئ `StudySnapshot` نفسه (`study_snapshot.dart:27-37`) يعيد groupBy وفرز كل قائمة
امتحانات لكل درس.

---

## 1) خريطة "مين بيستمع لإيه" (grep كامل لـref.watch)

| المستمع | يستمع إلى | حالته وهو مخفي |
|---|---|---|
| `AppShell` | `dashboardProvider.select(overdueCount)` (`app_shell.dart:47-49`) | **نشط دائمًا** — فوق كل TickerMode |
| `DashboardScreen` | dashboard + homeStats + nextTarget (`dashboard_screen.dart:46-49`) | متوقف عند إخفاء الفرع |
| `ReviewCenterScreen` | reviewQueue + snapshot (`review_center_screen.dart:37-38`) | متوقف عند الإخفاء |
| `AnalyticsScreen` | dashboard + insights + snapshot + **trajectories داخل build** (`analytics_screen.dart:44-48`) | متوقف عند الإخفاء |
| `TasksScreen` | مهام (stream منفصل) + nowValue (`tasks_screen.dart:126-129`) | معزول عن كتابات الدراسة تقريبًا |
| شاشات الدرس/الباب/المادة/المعالج | عائلات summary (`summary_providers.dart:70-110`) | نشطة ما دام الروت ظاهرًا؛ **[صُحّح في جولة 2-أ]** عائلات يدوية بلا `.autoDispose` ⇒ keepAlive في 3.x كما في 2.x — كل معرّف زُور يبقى مخزنًا حتى خروج التطبيق (تراكم ذاكرة لا حساب) |
| `ReviewScheduler` | `ref.listen(snapshotProvider)` (`notification_providers.dart:185`) | نشط دائمًا، debounce 5s (:68) |
| `BackupSyncNotifier` | `ref.listen(snapshotProvider)` (`backup_providers.dart:76-77`) | نشط دائمًا، debounce 20s (:68)، gzip خارج isolate (`firestore_backup_repository.dart:221-222`) |

**النتيجة الحرجة من الجدول**: `AppShell` وحده يُبقي `dashboardProvider` حيًا مدى حياة التطبيق. الـ`select`
يمنع *إعادة بناء الويدجت* عند تغيّر أي رقم غير الشارة، لكنه لا يمنع *إعادة حساب* المزوّد نفسه —
`Summaries.dashboard` لكامل المنهج تُحسب عند كل كتابة، وأنت واقف على تبويب المهام.

---

## 2) trace ضغطة checkbox واحدة (tick واحد في شاشة درس)

1. `updateChecklist` يكتب صفًا في `lessons` (`drift_study_repository.dart:364-377`).
2. استعلام `lessons.watch()` يعيد تنفيذ SELECT في isolate الخلفي ويشحن كل صفوف الدروس للـUI isolate.
3. `_combineLatest6` يؤجّل 16ms (`kSnapshotCoalesceWindow`, `drift_study_repository.dart:748`) —
   النافذة مضبوطة ومختبَرة، تبتلع انبعاثات transaction واحدة ✓.
4. `publish()` ينادي `_buildSnapshot` **على UI isolate**: إعادة تحويل كل صفوف الجداول الستة إلى كيانات
   جديدة + فرز الأبواب والدروس + فرز قائمة امتحانات كل درس (`drift_study_repository.dart:71-105`,
   `study_snapshot.dart:27-37`). التعقيد O(كل الصفوف في القاعدة) تخصيصات ذاكرة، ليس O(التغيير).
5. `snapshotValueProvider` يتغير ⇒ `dashboardProvider` يعيد `Summaries.dashboard` لكامل المنهج
   (حيّ بسبب AppShell، أعلاه) ⇒ `homeStatsProvider` و`nextTargetProvider` لو الداشبورد ظاهر.
6. الشاشة الظاهرة تعيد البناء؛ `AnimatedPercentage` و`MasteryBar` يعيدان tween القيمة
   (`animated_percentage.dart:39-48`, `mastery_bar.dart:45-55`) — مقصود وجميل، لكنه يحتاج فريمات سليمة.
7. `ReviewScheduler` يسمع الانبعاث ⇒ debounce 5s ⇒ `cancelAll()` + نداء platform لكل درس.
8. `BackupSyncNotifier` يسمع ⇒ debounce 20s ⇒ gzip خارج isolate + رفع Firestore.

**ما سيحسه الإنسان**: الخطوات 4–6 تتنافس مع أنيميشن التكة نفسها (`CompletionDisc` flood 340ms،
`icon_motion.dart:239-317`) التي تشتغل بالضبط بعد الضغطة. لو تجاوزت الميزانية، الطالب يرى تلعثمًا في
الحركة الوحيدة التي تعترف بلمسته. والأهم: **التكلفة تنمو مع حجم السجل** — طالب سنة كاملة (فرضية المهمة:
~1000+ امتحان بمجموعاتها + مئات الدروس) يدفع خطوة 4 عن كل ضغطة، وفي آخر العام تكون أثقل من أول العام
بالضرورة. هذا تراجع تدريجي لا يشبه bug: التطبيق "يبطؤ مع الوقت" بلا سبب ظاهر للطالب.

**كيف تقيسه**:
- زرع بيانات بحجم سنة عبر مسار `restore()` الموجود (`drift_study_repository.dart:549-651`) من fixture اختبار.
- `flutter run --profile` + DevTools Performance: سجّل أطول فريم build خلال 10 ضغطات checkbox متتالية،
  عند حجم بيانات صغير مقابل مزروع كبير. الفرق هو رقم P1.
- مؤقتًا (لا commit): `Timeline.startSync('buildSnapshot')` حول جسم `_buildSnapshot` واقرأ التتبع.

**الإصلاح المقترح** (اثنان مستقلان):
1. **افصل الشارة عن الملخص الكامل**: `AppShell` يحتاج `overdueCount` فقط. اعمل
   `overdueCountProvider = Provider<int>` يمشي مباشرة على `snapshotValueProvider` بحلقة O(lessons)
   (`app_shell.dart:47-49` يستبدل select بدازه). بهذا يموت آخر مستمع دائم لـ`dashboardProvider`،
   وصار حساب المنهج الكامل يحدث فقط والداشبورد ظاهرة فعلًا. تغيير ~15 سطرًا.
2. **أنزل بناء الـsnapshot عن الخيط الرئيسي**: إما `Isolate.run` حول التحويل داخل `_combineLatest6`،
   أو اجعل الـstream يشحن صفوفًا خامًا ويبني الكيانات في الخلفية. أكبر، لكنه الوحيد الذي يوقف نمو
   الخطوة 4 مع السنة.

---

## 3) الإيجادات مرتبة بالمحسوس

### P1 — كل كتابة تعيد بناء المنهج كله على الخيط الرئيسي، حتى وأنت على تبويب المهام
هو trace القسم 2 بأكمله. الجذر مزدوج: `_buildSnapshot` على UI isolate (`drift_study_repository.dart:63-106`)
+ `dashboardProvider` حي للأبد بسبب select الشارة (`app_shell.dart:47-49`). **الأكثر تحسيسًا في التقرير كله**،
لأنه يتضاعف مع عمر السجل ولا يظهر إلا على جهاز الطالب الفعلي.

### P2 — مسار التحليلات يُحسب داخل `build()`: ~48 مسحة كاملة للمادة + نسخة وفرز لكل درس لكل نقطة
- `analytics_screen.dart:46-48`: `MasteryTrends.forAllSubjects(snapshot)` **inline في build**، بينما
  كل شيء مثله في التطبيق مزوّد (`insightsProvider` فوقه بسطرين).
- التكلفة: `forAllSubjects` (`insights_generator.dart:342-347`) ← لكل مادة ≤12 نقطة (`maxPoints=12`,
  `insights_generator.dart:335`) ← كل نقطة تنادي `subjectMasteryAsOf` (`:243-274`) التي تمشي
  أبوابًا←دروسًا←`examsFor(lesson).where(...).toList()` + `lessonMastery` بنسخة وفرز دفاعي **لكل درس
  لكل نقطة**. لأربع مواد: ~48 مسحة كاملة للمادة في كل build.
- متى يتكرر: كل ضغطة فلتر (`setState` في `analytics_screen.dart:107`)، كل عودة للتبويب، كل تغيير ثيم/لغة،
  وكل كتابة ما دام التبويب ظاهرًا.
- **الإحساس**: بطء ملحوظ في ضغطات الفلاتر وفي أول فريم لفتح "تقدمك" لطالب له تاريخ — ويزداد مع البيانات.
- **القياس**: نفس سيناريو P1؛ قارن زمن فريم أول دخول للتبويب وضغطة فلتر بين snapshot فارغ ومزروع.
  أو غلّف `forAllSubjects` بـ`Timeline.startSync` مؤقتًا.
- **الإصلاح**: انقل الحساب إلى Provider (نمط `insightsProvider` تمامًا) بحيث يُحسب مرة لكل snapshot لا مرة
  لكل build×فلترة، ومرّر خريطة `lessonMasteries` إليه كما تفعل `Summaries`.

### P3 — تكديس العمل المؤجل على فريم تبديل التبويب (وجه التصحيح 1)
- بسبب pause/resume (تصحيح 1 أعلاه)، كل حسابات التبويب الغائب تُردّ له لحظة `goBranch`:
  دخول "تقدمك" = insights + trajectories + بناء الشاشة كلها، في نفس فريم الـcrossfade وفوق إعادة ترشيح
  الـblur. `TickerMode off` كفيل بإيقاف العمل الخفي — لكنه **يجمّعه على نقطة الانتقال**.
- **الإحساس**: "ثقل" تبديل التبويبات مع تقدم الاستخدام، خاصة إلى التحليلات.
- **القياس**: في profile mode، زرع بيانات، زيارة التبويبات الأربعة، ثم تسجيل فريمات `goBranch` في
  timeline (DevTools يسمّيها frame events) — قارن أول فريم بعد كل تبديل بين بيانات فارغة ومزروعة.
- **الإصلاح**: إصلاح P2 يقلّص أسوأ حالة؛ وبعد ذلك إن بقي إحساس، سخّن المشتقات الثقيلة وقت فراغ
  (`SchedulerBinding.scheduleTask` بـpriority منخفض) بدل لحظة اللمسة.

### P4 — الـblur (sigma 24) يعاد تنفيذه طوال أي تمرير تحت الشريط
- `BackdropFilter` واحد فقط ✓ (`app_shell.dart:183-190`)، sigma ثابت غير متحرك ✓ (`glassSigma = 24`,
  `app_spacing.dart:247`). لكن `extendBody: true` (`app_shell.dart:57`) و`AtherScreen` يعيد ارتفاع
  الشريط كهامش سفلي عمدًا (`ather_scaffold.dart:128-134,159-167`) — أي أن **كل scroll في كل شاشة**
  يحرّك محتوى تحت مرشّح gaussian 24، والمرشّح يعاد رسمه مع كل فريم يتغير فيه ما تحته. على Impeller
  مقبول؛ على أجهزة رخيصة تسقط لمسار GL fallback هذه هي مصدر تلعثم التمرير الكلاسيكي.
- **الإحساس**: تمرير غير سلس على الهواتف الرخيصة تحديدًا — جمهور المشروع بالضبط.
- **القياس**: A/B مجاني موجود في الكود أصلًا: مسار `canBlur == false` (`app_shell.dart:163-176`)
  يُستخدم على desktop. شغّل نفس المشهد (داشبورد بعناصر تكفي للتمرير) على أندرويد رخيص وعلى Windows
  وسجّل raster/UI thread في timeline، ثم قرر.
- **الإصلاح**: بوابة مستوى الجهاز لنفس مسار `DecoratedBox` الموجود (بدون لمسة تصميم جديدة)، أو خفض
  sigma — قرار تصميمي يعود لـPROJECT.md §3.19. لا أحذف الزجاج؛ أقيسه أولًا.

### P5 — بدء التشغيل: ثلاث انتظارات متسلسلة قبل أول فريم
- `main.dart:19` ينتظر `SharedPreferences.getInstance()`، ثم `:29-33` ينتظر
  `Firebase.initializeApp` ← `_activateAppCheck()` ← `_initializeCrashlytics()` **بالتسلسل** قبل
  `runApp` (`:38`).
- أول انتظارين لهما مبرران موثقان في الكود نفسه (وميض اللغة `:16-18`؛ جلسة offline للراوتر `:21-27`).
  لكن **تفعيل App Check (Play Integrity)** لا شرط له أول فريم: الفرض غير مفعّل وفشله مقصود غير مؤثر
  اليوم (`main.dart:57-70` نصّه حرفيًا "a failed activation costs nothing at all"). وهو الثالث في
  السلسلة، فأي تأخير منه يضاف كاملًا على الشاشة البيضاء.
- **الإحساس**: شاشة بيضاء/سوداء أطول عند كل فتح بارد — والطالب يفتح التطبيق عدة مرات يوميًا.
- **القياس**: `adb shell am start -W com.ather.app/.MainActivity` (TotalTime) + `logcat` سطر Displayed +
  `flutter run --profile --trace-startup`. قِس قبل/بعد نقل AppCheck — لا تعتمد على تخميني لحجمه.
- **الإصلاح**: أبقِ prefs وFirebase.initializeApp منتظرَين (مبرراتهما حقيقية)، وانقل `_activateAppCheck()`
  إلى بعد أول فريم (`addPostFrameCallback` أو `unawaited` بعد `runApp`). Crashlytics hook رخيص ومتزامن،
  مكانه صح.

### P6 — فرز دفاعي متكرر رغم أن الـsnapshot يضمن الترتيب (مضاعِف شبه مجاني)
- `lessonMastery` تنسخ وترتب دفاعيًا (`mastery_calculator.dart:33-48`)، بينما الـsnapshot يفرز قوائم
  الامتحانات في مُنشئه مرة واحدة (`study_snapshot.dart:31-37`)، ولنفس الغرض توجد `lessonMasteries`
  بلا نسخ (`mastery_calculator.dart:50-77`) — تعليق الملف نفسه يشرح الفرق.
- المسارات التي ما زالت على النسخة الثقيلة رغم الضمان: `buildReviewQueue` لكل درس
  (`review_cycle_service.dart:228`)، `chapterBlockers` (`:284`)، `canMasterChapter` ←
  `chapterMasteryOf` (`:307-313` ← `mastery_calculator.dart:90-95`)، وinsights
  (`insights_generator.dart:123,150,206`).
- وحدها ليست محسوسة؛ لكنها تتضاعف داخل P1/P2/P3 عند كل انبعاث. **الإصلاح شبه مجاني**: مرّر خريطة
  `lessonMasteries` أو اعتمد الترتيب المضمون في هذه المواضع.

### P7 — insights تعيد مسحات متعددة لنفس الـsnapshot بلا خريطة مشتركة
- `_addImprovement`: `subjectMasteryAsOf` لكل مادة (`insights_generator.dart:117`) **+**
  `subjectMasteryOf` (`:123`)؛ `_addStrongestSubject`: `subjectMasteryOf` من جديد (`:206`)؛
  `_addWeakestChapter`: `chapterMasteryOf` لكل باب (`:150`). كل واحدة منها مشي كامل
  أبوابًا←دروسًا←امتحانات بنسخ وفرز. `Summaries.dashboard` حلّت هذه المشكلة لنفسها بخريطة
  `masteries` الممرَّرة (`summaries.dart:158-176,260-263`) — insights لم تأخذ نصيبها.
- تُحسب فقط والتحليلات mounted (Riverpod 3 يوقفها وإلا)، لكنها تضاف فوق P2 في نفس الشاشة ونفس اللحظة.
- **الإصلاح**: احسب `subjectMasteryOf` مرة واحدة لكل مادة في `generate` ومرّره، واستخدم خريطة
  `lessonMasteries` داخل `subjectMasteryAsOf` بدل `lessonMastery` لكل درس.

### P8 — بناء صفوف القوائم eager داخل `AtherScreen` (قِس قبل أن تلمس)
- `ListView(children:)` (`ather_scaffold.dart:159-167`): التحميل الكسلي للعناصر **مقاس وموثق** في تعليق
  الملف نفسه (`:136-158`، مع اختبار `layout_matrix_test.dart`) — 400 صف تبني 8 عناصر فقط. الباقي
  المعترف به: قائمة `children:` نفسها تُبنى eager قبل الوصول للويدجت، فكل rebuild يبني كل ويدجت الصفوف
  (وليس mount). المؤلف كتب حرفيًا أنها "worth measuring on a device first".
- تهم فقط عند n كبير: باب بعشرات الدروس (`CollapsingList`)، مركز مراجعة ممتلئ. عند n صغير لا شيء.
- **القرار**: قِس أولًا (نفس أدوات P1، راقب build time لفتح باب مزروع بـ200 درس). لو ثبت الأثر، فالتحويل
  إلى builder تغيير API يعبر كل الشاشات — مشروع قائم بذاته، ليس إصلاح أداء عابر.

---

## 4) ملاحظات صغيرة (سُجلت كي لا يكتشفها أحد لاحقًا ويظنها اكتشافًا)

- `chapterOfLessonProvider` (`summary_providers.dart:102-110`) **بلا أي call site** — ميت. لا تكلفة
  أداء اليوم، لكنه كان سيحسب ملخص باب كامل مقابل breadcrumb واحد لو استُخدم.
- `settings_screen.dart:120-131` يراقب `snapshotValueProvider` ثلاث مرات في build واحد — نفس المزود =
  اشتراك واحد، غير ضار. الشاشة نفسها تعيد البناء عند كل كتابة وهي مفتوحة فقط، مقبول.
- `recycle_bin_screen.dart:113-122` (`_counts`) يمشي أبوابًا×دروسًا×امتحانات لكل صف لكل build —
  عدد المحذوفات صغير عمليًا؛ اتركه.
- `chapter_report_screen.dart:137-143` يفرز امتحانات ودروسًا في كل build — n صغيرة لكل باب؛ اتركه.
- لا gradients/shaders أخرى تستحق الكلام: `LinearGradient` واحد لتوهج حافة "اليوم" في
  `day_picker.dart:412`، وكل بقية الرسم CustomPaint صغير بـ`shouldRepaint` مضبوطة
  (`icon_motion.dart:364-369,649-651`, `analytics_screen.dart:757-759`).

## 5) ما وجدته محكمًا فعلًا — لا تهدر وقتًا هنا

- نافذة coalesce الـ16ms مضبوطة وموثقة باختبار (`drift_study_repository.dart:741-796`).
- ساعة منتصف الليل بدل polling الـ60 ثانية (`app_providers.dart:39-137`) — إصلاح أداء سابق محكم.
- debounce الإشعارات 5s والنسخ الاحتياطي 20s، وgzip عبر `Isolate.run` — كلها صح.
- كل `AnimationController` في التطبيق مصروف فعليًا ومزروع على الحالة النهائية (list_entrance/pop_in/
  icon_motion — فحصتها كلها)؛ `OverdueMark` كسول بذكاء (`icon_motion.dart:504-514`).
- `ListEntranceScope` يمنع replay الدخول عند scroll (`list_entrance.dart:18-47`).
- `AnimatedPercentage`/`MasteryBar` لا يعيدان الحركة عند ثبات القيمة.
- stagger الدخول مسقوف بـ6 (`staggerCap`, `list_entrance.dart:85`) — قائمة 40 درسًا لا تنتظر 40 تأخيرًا.

---

## أغلى 3

1. **P1 — سلسلة الكتابة**: كل ضغطة تعيد بناء snapshot كامل المنهج على الخيط الرئيسي
   (`drift_study_repository.dart:63-106`) وتحسب `Summaries.dashboard` كاملة حتى وهي مخفية
   (`app_shell.dart:47-49` يُبقي المزود حيًا) — تلعثم بعد كل لمسة، يتضاعف مع تقدم السنة.
2. **P2 — مسار التحليلات داخل build()**: `MasteryTrends.forAllSubjects` inline
   (`analytics_screen.dart:46-48`) = ~48 مسحة مادة بنسخ وفرز لكل درس لكل نقطة، تتكرر مع كل فلتر
   ودخول تبويب — انقله إلى Provider يُحسب مرة لكل snapshot.
3. **P4 — زجاج الشريط sigma 24**: `BackdropFilter` يعاد ترشيحه مع كل فريم تمرير فوق محتوى يمر تحته
   عمدًا (`app_shell.dart:57,183-190`) — jank التمرير على الهواتف الرخيصة تحديدًا؛ A/B جاهز عبر مسار
   `canBlur=false` قبل أي قرار.
