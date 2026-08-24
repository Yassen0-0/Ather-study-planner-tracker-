# 00-context.md — سياق الاستكشاف (يقرأه كل وكيل قبل أي شيء)

كتبه قائد الفريق بعد قراءة شخصية للكود، واتحدث بعد جلسة تحقق ثانية. الهدف: توفر عليك ساعات تعريف، **لكن لا تثق بي** — كل ادعاء هنا له `file:line`، افتحه وتحقق قبل البناء عليه.
علامة ✅ = اتأكدت منه بنفسي. علامة ❓ = بذرة تحقق لسه محتاجة فتح.

---

## 1) المكدس والخريطة

- Flutter / Dart SDK `^3.12.2` — `pubspec.yaml` version **1.8.0+14** ✅ (`pubspec.yaml:5`)، اسم الحزمة `ather`.
- Clean Architecture ثلاث طبقات: `presentation → domain ← data`.
- State: `flutter_riverpod` 3.x بمزوّدات مكتوبة يدويًا (ممنوع codegen — تعارض analyzer مع drift_dev).
- Persistence: drift فوق SQLite، ملف القاعدة اسمه `sahm` (إبقاء الاسم قرار مقصود). `schemaVersion = 3` ✅ (`lib/data/db/app_database.dart:53`). v3 أضاف `subjects.name/archivedAt/deletedAt` ⇒ يوجد الآن `subjects_screen.dart` و`recycle_bin_screen.dart` وسلة حذف كاملة.
- التنقل: go_router `StatefulShellRoute` بأربعة فروع `/ · /review · /analytics · /tasks` + settings فوق الروت الجذري (`lib/app/router.dart:188-341`). معالج الامتحان روت ملء شاشة على root navigator بدون tab bar (`router.dart:239-251`).
- **مفيش "+" في شريط التبويب** — اتشال في التحديث البصري (`app_shell.dart:20-30`) ✅.
- الوقت: `Clock` قابل للحقن؛ `nowProvider` يبث مرة عند منتصف الليل + عند resume لو اليوم اتغير (`app_providers.dart:79-137`). كان بينبث كل 60 ثانية قديمًا.
- الإتقان: صيغة 70/30 (`mastery_calculator.dart:33-48`)، حزم <50/<70/<90 (`mastery.dart:21-26`)، عتبة إتقان الباب 70 (`mastery.dart:30`)، دورة مراجعة 30 يومًا بالأيام التقويمية لا الساعات المنقضية (`review_cycle_service.dart:49-96`)، إنذار مبكر يوم -3، ذكراء الساعة 18:00 (`review_cycle_service.dart:119-174`).
- الواجبات لا تدخل الإتقان أبدًا؛ رسالة جاهزية فقط عند <60% (`mastery.dart:39`).
- الخدمات: Firebase Auth، نسخ احتياطي Firestore مستند واحد gzip مع debounce، Crashlytics داخل مخاطر الكتابة الحرجة (`recordExam`, migration)، App Check مفعّل غير مُلزِم مؤقتًا (`main.dart:71-95`)، write_guard يحوّل أي كتابة فاشلة لتوست بدل صمت (`presentation/common/write_guard.dart`).
- التذكيرات: مجدولة عند النظام (`zonedSchedule`)، تخطيطها pure وقابل للاختبار (`planReminders`)، سقف 400 منبه، fingerprint يمنع إعادة الحجز عديمة الفائدة (`data/notifications/review_notification_service.dart`).
- الاختبارات: 37 ملف اختبار تحت `test/`. **لا تشغّل flutter test/build أنت** — القائد يتولى التحقق؛ اقرأ الكود واستنتج.

## 2) أسبوع طالب متخيَّل — متتبَّع في الكود

- **الأحد:** أول فتح. redirect يقرأ الجلسة المخبأة متزامنًا (`router.dart:164-170`) — الدخول فوري حتى أوفلاين. داشبورد فارغ ⇒ `_FirstRunCard` يحل محل كروت الملخص (`dashboard_screen.dart:85-91,189`) وأربع مواد مزروعة. يضيف بابًا عبر `createChapter` (`drift_study_repository.dart:183-197`) أو قالب منهج كامل عبر `addChapters` بمطابقة أسماء عربية متسامحة (ة/ه، همزات، تشكيل) `_matchKey` (`drift_study_repository.dart:224-289`).
- **الاثنين:** يشطب خطوات الدراسة الخمس الثابتة (`updateChecklist`, :364-377) ويسجل واجبًا (`recordHomework`, :528-544) ⇒ إن كانت نسبته <60% تظهر "ذاكر أكتر" (`summaries.dart:40-43`). لا أثر للواجب في أي رقم إتقان — بحكم تصميمي.
- **الثلاثاء:** يمتحن 60%. المعالج أربع خطوات (`exam_entry_screen.dart:77,387-391`)، النسبة تُشتق من مجموعات الأسئلة داخل نفس الـtransaction ولا تُقبل من المتصل (`drift_study_repository.dart:398-408`)، ويُعاد ختم `lastReviewedAt` ومحو `lastNotifiedAt` وتعليم `didExam` تلقائيًا (:437-445). امتحان واحد ⇒ إتقان 60% بالظبط (`mastery_calculator.dart:39`). ساعة المراجعة بدأت.
- **الأربعاء:** لا يفتح التطبيق. لا شيء يحدث إطلاقًا: لا streaks ولا مفهوم "رجع بعد غياب" في الكود كله. التذكيرات محجوزة مسبقًا عند النظام.
- **الخميس:** يرجع. `nowProvider` يبث عند resume لأن اليوم تغير (`app_providers.dart:108-117`). نفس الرقم، نفس كارت "التالي" (`navigation_providers.dart:31-73`). لا اعتراف بالفجوة ولا "منور نورت".
- **اليوم 30:** الدرس overdue (`needsReview`, `review_cycle_service.dart:93-96`)، الباب كله أحمر بقاعدة "درس واحد يكفي" (:180-186)، الذكراء تصيب 18:00. مركز المراجعة يعرضه أولًا (`buildReviewQueue` :219-270)، والصف يفتح المعالج بعلامة `isReviewExam` مشتقة تلقائيًا (`exam_entry_screen.dart:247`).

## 3) بذور تحقق — نتائج القائد، ليست نهائية

1. ✅ **قائمة المراجعة تمشي على المواد المؤرشفة والمحذوفة:** `buildReviewQueue` يلفّ على `snapshot.chapters` بلا فلترة (`review_cycle_service.dart:225`)، وكذلك `_addWeakestChapter` (`insights_generator.dart:143`) — بينما `upcomingReviewCount` (:207) و`_addStalestLesson` (:182) والتنبيهات (`review_notification_service.dart:197`) تستخدم `activeLessons`. درس تحت مادة محذوفة يدخل مركز المراجعة لكن تنبيهه اتلغى — التناقض قائم في الكود الحالي.
2. ✅ **تعريفان لـ"متقن":** إحصائية الداشبورد تعد الدرس متقنًا لو `hasExam && !needsReview && mastery >= 90` (`summary_providers.dart:48`)، بينما `Chapter.isMastered` = ضغط زر "أتقنت الباب" (`masteredAt != null`) وقد يقع عند 71%. طالب أتمّ بابًا رسميًا لن تُعد دروسه "متقنة"، ودروس 90% بلا ضغط تُعد متقنة.
3. ✅ **مزوّد ميت:** `quickExamTargetProvider` (`navigation_providers.dart:81-102`) بلا أي call site (grep: التعريف فقط). تعليقه (:75-80) وتعليق `router.dart:49-52` يتحدثان عن "+" المحذوف. تعليق راكض آخر بنفس الملف: `SelectedTaskDayNotifier` يقول إن `nowValueProvider` "يبث كل دقيقة" (`task_providers.dart:28-30`) وهو بثّ منتصف الليل الآن.
4. ✅ **overall مكرر في بيتين:** `MasteryCalculator.overallMastery` (`mastery_calculator.dart:121-128`) و`Summaries.dashboard` يعيدان نفس المتوسط (`summaries.dart:309-311`).
5. ✅ **حارس الـinsight يبلع قصة حقيقية:** `_addImprovement` يتخطى مادة `before <= 0` (`insights_generator.dart:120`) — مادة امتحاناتها الأولى كلها داخل النافذة لن تحصل على insight تحسن أبدًا مهما قفزت.
6. ✅ **لحظة 60% بلا متابعة:** امتحان أول 60% ليس overdue ولا lowMastery (<50) ولا declining (امتحان واحد) ⇒ لا يظهر في أي مكان 30 يومًا. أضعف لحظة في حلقة المنتج.
7. ❓ **markChapterMastered يعيد ختم `lastReviewedAt` لكل دروس الباب** بما فيها غير الممتحن أصلًا (`drift_study_repository.dart:308-327`) — والباب يظل `isMastered` حتى لو أُضيف له درس جديد غير ممتحن بعدها (`chapter.isMastered` يقرأ `masteredAt` فقط). تحقق من التفاعل.
8. ❓ **deleteExam لا يمس `didExam`:** حذف آخر امتحان يصلح الساعة (`:458-523`) لكن checklist يظل مكتوبًا "امتحنت". تحقق من الأثر على الطالب.
9. ❓ **خطوة 4 في المعالج تقرأ snapshot مرة واحدة** (`ref.read` في `exam_entry_screen.dart:486`) وتصنع امتحانًا افتراضيًا بـid -1 — لو امتحان حقيقي بنفس المللي ثانية فالترتيب `compareExamsNewestFirst` يكسر التعادل بالنزول في id ⇒ الافتراضي يُعد الأقدم. عرض فقط، لكن تحقق.
10. ❓ **restore() يعيد كتابة `subjects` بالكامل** شاملة صفوف `deletedAt` (`drift_study_repository.dart:556-581`) — هل سلة المحذوفات تنجو من استعادة نسخة؟ مقصود أم ثغرة؟
11. ❓ **مهام اليوم والمفاتيح الزمنية:** `tasksForSelectedDayProvider` يقارن `task.day == day` مباشرة (`task_providers.dart:44-50`)، ومفتاح اليوم منتصف الليل محلي (`tables.dart:139-141`) — ما مصير مهمة 23:59 عبر منتصف الليل/DST؟
12. ❓ **backup_gate.dart وauth**: تدفق تبديل الحساب ومسح الجهاز (`kLastAccountUidKey`) — اقرأهما وقيّم الحواف.

## 4) أسئلة مفتوحة لا أعرف إجابتها

- الشاشات الجديدة (export/share/recycle-bin/profile): نصوص hardcoded خارج ARB؟ RTL مكسور في مكان ما؟
- شاشة التحليلات: هل `subjectMasteryAsOf` يُعاد حسابه لكل نقطة في كل build دون تخزين؟
- Windows desktop لم يُختبر قط — هل يكسره شيء حديث؟
- كم اختبارًا يغطي المسارات الجديدة (سلة/تصدير/مشاركة) فعلًا؟
- ما الذي يبتلعه `runWrite` بصمت مقابل ما يسجله Crashlytics؟

## 5) قواعد البيت (تذكير)

- **كل ادعاء بملف وسطر.** رقم سطر مزيف يُسقط التقرير كله.
- **العادي فشل.** لو المعلومة صح عن أي تطبيق، احذفها.
- لا تعدّل أي كود تحت `lib/`. ملفك أنت فقط تحت `.audit/`.
- اقرأ `PROJECT.md` للسياق التصميمي (وهو مصدر الحقيقة) — لكن **الكود يغلب المستند** عند التعارض، وسجّل التعارض.
