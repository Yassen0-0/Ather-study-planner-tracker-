# 08-wildcard.md — الويلدكارد

ما تبعنيش scope. مشيت وراء تعارض واحد لاحظته في أول ساعة: **هذا المستودع يملك عقدًا مكتوبًا مع نفسه — "كل وثيقة تصف الكود يجب أن تبقى صادقة" (public/README.md:70-94 حرفيًا "Keeping it honest") — وأحدث كود كسر هذا العقد في أكثر من مكان، ولا أحد سجّل ذلك.** بقية التقرير إما امتداد لهذا الخيط أو حوافّ خطيرة اكتشفتها في مسارات الأمان والاستعادة.

ممنوعاتي محترمة: لا 70/30، لا قائمة المراجعة/المؤرشف، لا quickExamTargetProvider، لا "متقن"، لا snapshotProvider.

---

## W1 — سياسة الخصوصية والصفحة المباشرة وتقرير الأمان يعدون "لا تسجيل أعطال"… والتطبيق يشغّل Crashlytics منذ 2026-08-18

**أخطر ما وجدته، وهو تعارض موثّق بتواريخ git لا برأي.**

الكود:
- `lib/main.dart:113-119` — `_initializeCrashlytics` يشغّل `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError` في **release فقط**.
- `lib/data/repositories/drift_study_repository.dart:449-453` — `recordExam` يرفع non-fatal إلى Crashlytics.
- `lib/data/db/app_database.dart:82-85` — فشل الـmigration يُرفع.
- `lib/data/backup/firestore_backup_repository.dart:149,235,243,247` — كل فشل نقل نسخة احتياطية يُرفع.

الوثائق التي أصبحت تكذب:
- `public/privacy.html:112` (عربي): «**لا تسجيل أعطال** يرسل بيانات إلى الخارج.»
- `public/privacy.html:248` (إنجليزي): "**No crash reporting** that sends data off the device."
- `public/privacy.html:261-265` — قسم "Where it is stored" يحصر المعالجين في Firebase Auth + Firestore فقط؛ Crashlytics خدمة ثالثة غير معلنة.
- `public/index.html:153`: "No ads, no tracking, no analytics…" — الوعد الرابع من وعود الصفحة الأربعة.
- `docs/reviews/security-audit-2026-08-15.md:316` — "VERIFIED-8 — No trackers. No ads, analytics, or crash-reporting SDK. **Materially simplifies Families Policy compliance**"، و`:397-421` مسودة إجابات Data safety مبنية على "Crash logs / diagnostics — no Crashlytics".

التسلسل الزمني (git):
- آخر تعديل على `privacy.html` هو `ce87b92` بتاريخ **2026-08-17**.
- تهيئة Crashlytics جاءت بعدها: `8663960` بتاريخ **2026-08-18** (PR #12).

والأقسى: `public/README.md:83-85` حذّر حرفيًا — "Adding Firebase Analytics or Crashlytics — the two most natural things to reach for next — breaks this and the Data safety form together" — ثم أُضيف Crashlytics بعد ثلاثة أيام دون لمس صفحة واحدة. هذا ليس رأيًا؛ إنه خرق لوعدٍ كتبه المستودع على نفسه، وهو بالضبط نوع الادعاء الذي يمكن لمستخدم أو مراجع Play التحقق منه. أي نشر للسياسة الحالية = بيان غير صحيح أمام Families Policy.

**الإصلاح:** تحديث `privacy.html` (اللغتان) و`index.html` وإعادة صياغة إجابات Data safety قبل أي deploy قادم — أو عكس الاتجاه. الملفات الثلاثة كلها في المستودع، التعديل ساعات لا أيام.

---

## W2 — تبديل الحساب يمسح الجهاز بالكامل… بصمت، بلا تأكيد، وهي العملية الوحيدة في التطبيق التي تفعل ذلك

`lib/presentation/providers/backup_gate.dart:50-61`: عند دخول uid مختلف عن `kLastAccountUidKey` المحفوظ، يُستدعى `clear()` + `clearTasks()` فورًا — **لا حوار، لا تأكيد، لا تراجع**.

قارن هذا بكل عملية هادمة أخرى في التطبيق:
- حذف حساب كامل: تدفق مؤكد بخطوات وإعادة مصادقة (`settings_screen.dart:495-532`).
- حذف مادة: سلة محذوفات (`recycle_bin_screen.dart`).
- استعادة نسخة فوق بيانات موجودة: تأكيد صريح (`backup_providers.dart:163-169` — "every caller confirms first").
- حتى الاستعادة التلقائية نفسها مشروطة بقاعدة فارغة (`backup_gate.dart:107-133`).

المسار القابل للوقوع فعليًا لطالب مرهق: شاشة الدخول فيها زرّان بنفس الفورم — «تسجيل الدخول» و«حساب جديد» (`login_screen.dart:226-233, 263-276`). طالب كان يدخل بالإيميل وكلمة المرور طوال العام، ضغط بالخطأ على «حساب جديد» وأنشأ حسابًا جديدًا (أو دخل بحساب Google مختلف) ⇒ **مسح فوري لكامل سجلته المحلية**، ثم الاستعادة التلقائية تجد السحابة فارغة (الحساب الجديد لا يملك شيئًا) ⇒ لا شيء يعود. لا رسالة تحذير واحدة في نصوص الواجهة (`authSubtitle` = «تسجيل دخول واحد، ثم يعمل التطبيق دون اتصال» — `app_localizations_ar.dart:527`).

التعليق في `backup_gate.dart:33-49` يبرر المسح جيدًا (عزل طالبين على هاتف واحد)، والمسح مقصود وموثق — **لكن قرار "بلا تأكيد" لم يُوثق ولم يُناقش في أي مكان**، بينما أقل من ذلك بكثير يحصل على حوار. سيناريو الأخوة الشقيق (المبرر الأصلي) يتوقع قصدًا؛ سيناريو الضغط الخاطئ لا يتوقع شيئًا ويخسر كل شيء.

**الإصلاح الرخيص:** حوار واحد قبل `clear()` حين تكون القاعدة غير فارغة وحين يكون للـuid القديم بيانات — "هذا الحساب مختلف؛ بيانات الجهاز الحالية تخص حسابًا آخر وستُمسح". لا يكسر عزل الحسابات، ويحوّل أخطر لحظة في التطبيق من صامتة إلى معلنة.

---

## W3 — `runWrite` يبتلع فشل 26 موقع كتابة بلا أي تتبع… ووعد المراجعة التقنية بترقيته لم يُنفَّذ

`lib/presentation/common/write_guard.dart:36-48`: أي فشل ⇒ `debugPrint` + توست عام «حصل خطأ ما». لا Crashlytics، لا تمييز بين "القرص ممتلئ" و"قاعدة البيانات تالفة". المواقع: 26 استدعاء (`chapter_screen.dart`, `lesson_screen.dart`, `tasks_screen.dart`, `subjects_screen.dart`, `recycle_bin_screen.dart:94,186,216`…) — بما فيها **restore/destroy في سلة المحذوفات**، أي العمليات التي يمس الطالب فيها ببياناته عمدًا.

عدم التماثل هو الدليل على أن هذا سهوٌ لا اختيار:
- حفظ امتحان واحد فقط يبلّغ Crashlytics (`drift_study_repository.dart:452`، commit `8cc31de` "subtask-3-1").
- النسخ الاحتياطي يبلّغ (`firestore_backup_repository.dart` بأربعته).
- **لكن** جدول إصلاحات المراجعة التقنية نفسه قال: "promote **write_guard** and backup failures to non-fatals" (`docs/reviews/2026-08-11-technical-review.md:768`) — نُفِّذ نصفه (backup، subtask-3-2) وسقط نصفه (write_guard). لا يوجد commit لمس `write_guard.dart` منذ `4383fd6` (2026-08-10).

النتيجة العملية: وباء "قرص ممتلئ" على هواتف رخيصة — أشهر أنواع الأعطال لدى جمهور الثانوية المصرية — يراه الطلاب توستًا عامًا متكررًا، ويظهر عند المطوّر **صفرًا** في Crashlytics، لأن الكتابة الوحيدة المُبلَّغ عنها هي الامتحانات.

---

## W4 — تكامل Crashlytics نصف مكتمل: الأخطاء async غير الملتقطة لا تصل أبدًا بمكدس Dart

`lib/main.dart:113-119` يركّب `FlutterError.onError` فقط. لا وجود لأي `PlatformDispatcher.instance.onError` ولا `runZonedGuarded` في `lib/` كله (grep: صفر نتائج). أي استثناء يهرب من callback غير متزامن خارج شجرة Flutter (timers، مستقبلات riverpod، isolate callbacks) لا يمر عبر `FlutterError.onError` أصلًا.

الأهم: **مواصفة المشروع نفسها نصّت على الخطين** — `docs/reviews/2026-08-11-technical-review.md:462-464` يقترح حرفيًا `FlutterError.onError` **و** الخط الثاني داخل handler يعيد `true`. التنفيذ (PR #12) أخذ السطر الأول وترك الثاني. التعليق فوق الدالة (`main.dart:97-98`) يقول "automatic crash reporting for unhandled exceptions" — وهو ادعاء أوسع مما يفعله الكود، وهذا هو نمط W1 مصغّرًا: تعليق يعد أكثر مما يسلّم.

---

## W5 — الاستعادة تُصلح الامتحانات وتثق بالواجبات: عدم تماثل clamping في نفس الملف ونفس التهديد

`study_backup.dart` يعلن نموذج تهديد صريحًا (:302-306): "a document under a student's own uid can be written by anything holding that student's token, including a modified build of this app or a hand-crafted REST call" — ولهذا تُكلَّم كل حقول الامتحان عند `fromJson` (:209-211: `totalPossiblePoints`, `correctPoints`, `percentage`, و`correctCount` مقابل `questionCount` :232-236).

**حقول الواجب لا تُكلَّم إطلاقًا**: `study_backup.dart:279-280` — `score: h['score']! as int, maxScore: h['maxScore']! as int` خامًا. و`HomeworkEntry.percentage` (`homework_entry.dart:24`) يقسم بلا سقف: `score=9999/maxScore=10` ⇒ **99990%** تُعرض كما هي على شاشة الدرس (`lesson_screen.dart:379`)؛ `score=-5` ⇒ نسبة سالبة أبديًا < 60 ⇒ رسالة «ذاكر أكتر» لا تزول إلا بإدخال واجب جديد (`summaries.dart:40-43`).

نفس الملف، نفس التهديد المعلن، نفس اليد التي كتبت التبرير — طبّقت الحماية على الامتحان ونسيتها على الواجب. سطران من `_clampInt` يغلقانها.

---

## W6 — مفتاحا ARB ميتان من أحدث ميزتين: الانضباط الذي فرضه sweep قديم لم يصمد على الجديد

فحص آلي لكل مفاتيح `app_ar.arb`/`app_en.arb` (302 مفتاحًا، متطابقة 1:1 بين اللغتين — لا نواقص) ضد كل مصادر `lib/`:

- **`chapterReportExportDone`** («اتجهّز التقرير» / "Report ready") — موجود في `app_ar.arb` و`app_en.arb` ومولَّد في `app_localizations_ar.dart:979` / `_en.dart:974`، **بدون أي call site**. كان مفترضًا أنه توست نجاح تصدير PDF؛ النجاح اليوم بلا رسالة (`chapter_report_screen.dart:96-99` يكتفي بفتح شريط المشاركة).
- **`subjectTemplateNote`** («هذه أبواب المنهج المعتادة لهذه المادة…») — مولَّد في `_ar.dart:1068`، بلا أي call site. الملاحظة المكتوبة لتظهر تحت قوالب المواد الجاهزة (`curriculum_templates.dart`) لا تُعرض في `subjects_screen.dart`.

اللافت: commit `f78fb34` (2026-08-10) أجرى sweep حذف بالضبط هذا النوع ("Two orphan ARB keys in both locales") ووثّقه. الميزتان الأحدث (PDF export `858ed37`، templates `2e19fc8`) أعادتا إنتاج نفس الفئة خلال أيام — أي أن القاعدة "مفتاح بلا قارئ يُحذف" ليست مطبقة كعملية مستمرة.

---

## W7 — لقطات صغيرة (سجل، لا أكثر)

- **`dist/README.md:1`** ما زال يعلن "Ather 1.3.1 (build 8) — the build to hand out" مع SHA-256، بينما `dist/` يجاوره `Ather-1.6.0-build11-arm64.apk` والحالي `1.8.0+14`. مجلد توزيع يروّج لبناء عمره خمسة إصدارات — شخص يبحث عن "APK للتوزيع" سيجد التوثيق قبل الحقيقة.
- **فرع معلق بلا قرار**: `auto-claude/007-exam-calendar-scheduling` يحمل `table_calendar` + `ExamNotificationService` (commits `5f95f9b`, `df5d73b`)، غير مدموج، وPLAN.md:76 صنّف البند "DEFERRED". لا أحد حذف الفرع أو وثّق مصيره — نفس نمط "عمل جيد غير مرئي" الذي كلّف المستودع APK من قبل (CLAUDE.md Rule 2/3).
- **`BACKLOG.md:3`** يقول "Everything … is built and released as `1.7.0+12`" والحالي `1.8.0+14` — وثيقة انتظار متأخرة إصدارين، غير مؤذية لكنها من نفس عائلة "الوثيقة تتأخر عن الكود".
- **i18n نظيف** — نقطة ائتمان لا إيجاد: صفر نصوص عربية hardcoded في `presentation/`، صفر `Text('English…')`، و`iso()` مطبقة في كل مواضع الأرقام التي فحصتها (`dashboard_screen.dart:262-265`, `lesson_screen.dart:194-196`, `tasks_screen.dart:165`, `exam_entry_screen.dart:464`). منطقة ظننتها مثمرة فخرجت بيضاء.

---

## أهم 3

1. **W1 — السياسة المنشورة تنفي Crashlytics والكود يشغّله**: تعارض موثق بتاريخي git، حذّرت منه `public/README.md:83-85` حرفيًا وحدث رغم ذلك. بيان خاطئ أمام Play/Families Policy بانتظار أول deploy.
2. **W2 — تبديل الحساب يمسح الجهاز بلا تأكيد**: أخطر عملية في التطبيق هي الوحيدة غير المؤكدة، وزر «حساب جديد» المجاور لزر الدخول يجعلها قابلة للوقوع بضغطة خاطئة.
3. **W3+W4 — طبقة الإبلاغ عن الأعطال مهترئة من الجهتين**: `runWrite` يبتلع 26 موقع كتابة بلا تتبع (ووعد المراجعة التقنية بترقيته سقط)، والأخطاء async غير الملتقطة لا تصل Crashlytics أصلًا لأن الخط الثاني من تكاملها غائب.

---

# جولة 2 — 2026-08-21

تمشيط worktrees أولًا (القاعدة 2): `wt-session-a`/`wt-session-b` عند `7cae5ab` (`1.7.0+13`) — أقدم من main `530d891` (`1.8.0+14`)، ولا تغييرات غير ملتزمة تحت `lib/` في أي worktree. هذا الـcheckout هو الأحدث، والتدقيق أدناه عليه.

## R1 — `firestore.rules` قراءةً كاملةً: الحكم الصريح

**سليمة كنص. لا يوجد أي مسار قراءة أو كتابة مفتوح.** المسار الوحيد القابل للوصول من العميل هو `/users/{uid}/backup/{document=**}`، وكل فعل عليه يشترط `request.auth != null && request.auth.uid == uid` بلا استثناء واحد:

- القراءة: `firestore.rules:27`.
- الإنشاء والتحديث: `firestore.rules:48-51` — مع سقف الحجم `request.resource.data.payload.size() <= 921600` مقيسًا على الـbytes لا على عدد الحقول (فخّ `resource.size()` الموثق في `:34-41` مُصلَح فعلًا).
- الحذف مفصول عمدًا لأن `request.resource` غير موجود فيه (`firestore.rules:43-47,53`) — لو بقيت `allow write` موحدة لكان المسح السحابي مستحيلًا.
- كل ما عداه مسدود صراحةً: `match /{document=**} { allow read, write: if false }` (`firestore.rules:60-62`) — أي مجموعة مستقبلية لن ترث وصولًا بالسهو.

**علاقة App Check غير الملزم بالقواعد: لا علاقة — ولهذا فهو غير مؤذٍ هنا تحديدًا.** القواعد لا تذكر `request.app` إطلاقًا، فحالة فرض App Check لا تدخل في تقييم أي قاعدة أصلًا؛ ضمانة العزل تقوم كليًا على `request.auth.uid`. ما دام الفرض معطلًا (بحجة قاعدة التثبيت الموثقة في `main.dart:58-65`)، تبقى لبصمي API المسروق أن ينشئ حسابات ويكتب في **وثيقته هو فقط** — إساءة حصة وفوترة، لا سرية بين طالبين. هذا حرفيًا ما يقوله التعليق في `main.dart:54-56`، والكود والقواعد متطابقان على هذا التقسيم للأدوار.

حجمان يمنعان الحكم من أن يكون "ممتاز":

1. **ملف المستودع ليس التهيئة الحية.** لا شيء ينشر هذه القواعد آليًا (`firestore.rules:17-18`)، ومن المستودع وحده لا يمكن إثبات أن الكونسول مطابق. النص سليم؛ النشر غير قابل للتحقق من هنا.
2. **الضمانة غير مسيَّجة باختبار.** المراجعة التقنية طلبت "an emulator test proving uid A cannot read uid B" (`docs/reviews/2026-08-11-technical-review.md:763`) — مجلد `test/` كله (37 ملفًا) خالٍ من أي اختبار قواعد. الحكم أعلاه نتيجة قراءة بشرية، لا سياج رجوع آلي.

## R2 — W2 بعد التدقيق الأعمق: الادعاء يصمد، ويشتد

**التوقيت الدقيق: المسح لا ينتظر "فتح الشاشات" إطلاقًا — يرتفع لحظة انبعاث الحساب نفسها.** `BackupSyncGate` جالس فوق الراوتر وفوق بوابة القفل معًا (`app.dart:118-124`: `AppLockObserver > ReviewScheduler > BackupSyncGate > _LockGate`)، و`ref.listen` على `accountProvider` يسجَّل عند أول build ويظل حيًا مدى عمر التطبيق. و`accountProvider` هو stream الـ`userChanges` (`auth_providers.dart:20-22`, `firebase_auth_repository.dart:30`) — الانبعاثة ذاتها التي تحرك redirect الراوتر عبر `_AuthRefresh` (`router.dart:136-148,164-170`). أي أن المسح يجري **بالتزامن** مع الانتقال من شاشة الدخول، لا بعده؛ الطالب لا يحتاج أن يرى أي شاشة لكي تُمسح بياناته.

**زر «حساب جديد» يمر بنفس المسار حرفيًا — تأكيد بالكود لا بالاستنتاج:** `register()` تستدعي `createUserWithEmailAndPassword` التي **تسجّل الدخول فورًا** بالحساب الجديد (`firebase_auth_repository.dart:67-70`، والتعليق نفسه: "The account exists at this point") ⇒ انبعاثة `userChanges` بـuid جديد ⇒ نفس المستمع ⇒ نفس المسح. ودخول Google بحساب مختلف: نفس الشيء (`firebase_auth_repository.dart:109-111`). ثلاثة أبواب (signIn/register/Google) تصب في انبعاثة واحدة.

**السيناريو الواقعي الآن محدد بشروطه بدقة:**

- الشرط اللازم: `kLastAccountUidKey` محفوظ **ومختلف** عن الـuid الداخل (`backup_gate.dart:54`). التثبيت الأول على جهاز جديد (`previous == null`) لا يمسح شيئًا — الخطر يتطلب جهازًا عليه حساب سابق، وهو بالضبط حالة طالب العام الكامل.
- تسجيل الخروج **لا يمحو المفتاح** (فقط يعيد ضبط `_restoreChecked` — `backup_gate.dart:151-153`)، فالمفتاح ينجو عبر الخروج وهو ما يجعل الضغطة الخاطئة قاتلة: خروج ← شاشة دخول ← «حساب جديد» بالخطأ ← مسح فوري بصمت.
- مسار واقعي ثالث لم أذكره في الجولة الأولى: طالب نسي كلمة المرور، وبدل إعادة التعيين أنشأ حسابًا بإيميل ثانٍ (شائع بين الطلاب) ⇒ نفس المصير. الإيميل نفسه لا يفتح الباب (`email-already-in-use`)، لكن الإيميل الثاني يفتحه.
- **لا نجاة بقتل التطبيق**: المفتاح يُكتب *بعد* المسح عمدًا (`backup_gate.dart:58-60`)، فإذا قُتل العملية في منتصفها أعادت الإقلاع التالية المحاولة وأكملتها.
- **ما ضيّق من الضرر**: اتجاه الرفع محروس أصلًا — `flush()` يرفض الرفع ما دام المفتاح المحفوظ ≠ الحساب الحالي (`backup_providers.dart:99-102`)، فلن تُرفع بيانات الطالب القديمة إلى وثيقة الحساب الجديد. الضرر النهائي محصور ومؤكد: محليًا ممسوح، وسحابة الحساب الجديد فارغة ⇒ لا شيء يُستعاد.

الحكم: W2 كما كُتب صحيح، والتدقيق الأعمق زاده — اللحظة أخطر مما وصفتها لأنها غير مرتبطة بأي شاشة ولا بوعي المستخدم، وأبوابها ثلاثة لا بابان.

## R3 — لقطات أخيرة

- **`RELEASE_NOTES.md` تأخر إصدارين**: مؤرخ 2026-08-17 ويوثق `1.7.0+12` (`RELEASE_NOTES.md:1`)، والحالي `1.8.0+14` (`pubspec.yaml:5`). من نفس عائلة `BACKLOG.md` المتأخرة (W7). تدقيقت وعدَه الخصوصي فيها وحمل: اسم الملف الشخصي فعلاً SharedPreferences فقط (`app_providers.dart:226-252`) — الوثيقة متأخرة لكنها لا تكذب.
- **lock_screen / local_auth / secure_window: لا bypass حي وجدته.** الثغرات التاريخية مُصلحة وموثقة في مكانها: الإفلات عبر استثناء أصبح قائمة سماح من ثلاثة أكواد فقط (`lock_screen.dart:59-62`)، وزر الرجوع مبتلع أثناء القفل (`app.dart:49-70`)، و`FLAG_SECURE` منفذ نطيًا فعلًا (`MainActivity.kt:53-66`) ويُضبط قبل أول frame (`auth_providers.dart:146`). نقطتان حدّيتان بصراحة، ليستا bypass: (أ) `SecureWindow.set` يبتلع أخطاء القناة بصمت (`secure_window.dart:36-40`) — انحدار مستقبلي في الجهة النطية سيسرّب مصغرات المهام بلا أي إشارة؛ (ب) إعادة القفل على `paused` (`auth_providers.dart:156-161`) قد لا تنطلق لنسخة مرئية-غير-مركزة في split-screen — حافة نادرة، و`FLAG_SECURE` يغطي المصغرات إن كان مفعّلًا.
- **وعود docs/reviews غير المنفذة غير W3/W4:**
  - **منفذ — نقطة ائتمان**: C-1 (القواعد في المستودع + ربطها في `firebase.json:2-4`) تم؛ بند CI (`technical-review.md:766`) قام كـguardrails.yml؛ وقرار week-strip المعلّق في §14.1 من تقرير التصميم حُسم بحل ثالث لم يقترحه أحد: استبدال الشريط بـDayPicker بعدّ خلايا مقيس لا مفترض (`day_picker.dart:15-31`).
  - **ما زال مفتوحًا — الأهم**: متابعة `tooLarge` من تقرير الأمن (`security-audit-2026-08-15.md:46,217`: "raising or paging that ceiling is now load-bearing") — **معالَج جزئيًا فقط**: شاشة النسخ تعرض سبب الفشل الحي إن زارها الطالب (`backup_screen.dart:107-125`)، لكن لا سطح استباقي، وصف الإعدادات الرئيسي يعرض تاريخ آخر حفظ الذي يقرأ "سليم" (`settings_screen.dart:107`). طالب سجلّه فوق 900KiB يتوقف نسخه السحابي بصمت حتى يفتح بنفسه الشاشة الصحيحة.
  - **ما زال مفتوحًا — ثانوي**: اختبار emulator للقواعد (R1 أعلاه)؛ وانحراف تعليق `toastBottom` الذي ما زال يستشهد بـ0.72 بينما `glassTint = 0.85` (`app_spacing.dart:121` مقابل `:261` — نفس بند §14.5).
  - **غير قابل للتحقق من المستودع**: إدخال إجابات Data safety في Play Console (`security-audit-2026-08-15.md:31`) وتأكيد حذف `test@ather.app` (`:276`) — وكلاهما صار أخطر بعد W1 لأن المسودة نفسها صارت تقول إنه لا يوجد Crashlytics.
