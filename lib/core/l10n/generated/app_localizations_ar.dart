// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'أثر';

  @override
  String get appTagline => 'إنت مش بتخلص الدروس… إنت بتتقنها';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navReview => 'مراجعة';

  @override
  String get navProgress => 'تقدمك';

  @override
  String get navTasks => 'مهامك';

  @override
  String get subjectBiology => 'أحياء';

  @override
  String get subjectPhysics => 'فيزياء';

  @override
  String get subjectChemistry => 'كيمياء';

  @override
  String get subjectEnglish => 'إنجليزي';

  @override
  String get weekdaySaturday => 'س';

  @override
  String get weekdaySunday => 'ح';

  @override
  String get weekdayMonday => 'ن';

  @override
  String get weekdayTuesday => 'ث';

  @override
  String get weekdayWednesday => 'ر';

  @override
  String get weekdayThursday => 'خ';

  @override
  String get weekdayFriday => 'ج';

  @override
  String get dashboardTitle => 'النهارده';

  @override
  String get overallMastery => 'الإتقان العام';

  @override
  String get statLessonsRemaining => 'دروس فاضلة';

  @override
  String get statNeedsReview => 'محتاج مراجعة';

  @override
  String get statMastered => 'متقن';

  @override
  String get sectionSubjects => 'المواد';

  @override
  String get firstRunTitle => 'ابدأ من هنا';

  @override
  String get firstRunBody =>
      'افتح مادة، ضيف فيها باب، وبعدين درس. الإتقان بيتحسب من امتحاناتك الحقيقية بس — مش من إنك خلصت الدرس.';

  @override
  String get firstRunAction => 'افتح أول مادة';

  @override
  String get sectionNext => 'اللي بعده';

  @override
  String get actionExam => 'امتحن';

  @override
  String get notStartedYet => 'لسه مبدأتش';

  @override
  String get subjectHasOverdueLesson => 'فات ميعاد مراجعة درس';

  @override
  String lessonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درس',
      many: '$count درس',
      few: '$count دروس',
      two: 'درسين',
      one: 'درس واحد',
    );
    return '$_temp0';
  }

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count باب',
      many: '$count باب',
      few: '$count أبواب',
      two: 'بابين',
      one: 'باب واحد',
    );
    return '$_temp0';
  }

  @override
  String chaptersMasteredOf(String mastered, String total) {
    return '$mastered من $total باب اتقنتها';
  }

  @override
  String chaptersOfShort(String mastered, String total) {
    return '$mastered من $total باب';
  }

  @override
  String lessonsExaminedOf(String examined, String total) {
    return '$examined من $total درس متمتحن';
  }

  @override
  String lessonsOnTimeOf(String onTime, String total) {
    return '$onTime من $total درس في وقتها';
  }

  @override
  String get sectionChapters => 'الأبواب';

  @override
  String get sectionLessons => 'الدروس';

  @override
  String get addChapter => '+ إضافة باب';

  @override
  String get addLesson => '+ إضافة درس';

  @override
  String get noChaptersYet => 'مفيش أبواب لسه';

  @override
  String get noLessonsYet => 'مفيش دروس لسه';

  @override
  String get chapterName => 'اسم الباب';

  @override
  String get lessonName => 'اسم الدرس';

  @override
  String get chapterNameHint => 'مثلاً: الباب الأول — الخلية';

  @override
  String get lessonNameHint => 'مثلاً: تركيب الغشاء البلازمي';

  @override
  String get renameChapter => 'تعديل اسم الباب';

  @override
  String get renameLesson => 'تعديل اسم الدرس';

  @override
  String get deleteChapter => 'حذف الباب';

  @override
  String get deleteLesson => 'حذف الدرس';

  @override
  String get deleteChapterConfirm =>
      'هيتحذف الباب وكل الدروس والامتحانات اللي جواه. مش هينفع ترجع فيها.';

  @override
  String get deleteLessonConfirm =>
      'هيتحذف الدرس وكل امتحاناته. مش هينفع ترجع فيها.';

  @override
  String get averageExamScore => 'متوسط الامتحانات';

  @override
  String get chapterNeedsReview => 'محتاج مراجعة';

  @override
  String chapterMasteredAt(String date) {
    return 'اتقنته في $date';
  }

  @override
  String get masterChapter => 'أتقنت الباب';

  @override
  String get viewChapterReport => 'شوف تقرير الباب';

  @override
  String get notReadyGate => 'لسه مش جاهز — اعرف ليه';

  @override
  String get notReadyTitle => 'لسه مش جاهز';

  @override
  String notReadyBody(String threshold) {
    return 'عشان تتقن الباب لازم كل الدروس تتمتحن والإتقان يوصل $threshold على الأقل.';
  }

  @override
  String get noExamShort => 'مفيش امتحان';

  @override
  String get lessonNoExamYet => 'لسه مفيش امتحان';

  @override
  String dueInDays(String days) {
    return 'باقي $days يوم';
  }

  @override
  String dueInDaysLong(String days) {
    return 'باقي $days يوم على المراجعة';
  }

  @override
  String overdueByDays(String days) {
    return 'متأخر $days يوم';
  }

  @override
  String masteryCaptionWithExams(String last, String rest) {
    return 'الإتقان محسوب من آخر امتحان $last ومتوسط اللي قبله $rest';
  }

  @override
  String get masteryCaptionNoExams =>
      'الإتقان بيتحسب من الامتحانات بس — سجّل أول امتحان عشان تبدأ';

  @override
  String get checklistTitle => 'خطوات المذاكرة';

  @override
  String get checklistWatched => 'شاهدت الدرس';

  @override
  String get checklistReadNotes => 'قريت الملازم';

  @override
  String get checklistDidHomework => 'حليت الواجب';

  @override
  String get checklistDidExam => 'حليت الامتحان';

  @override
  String get checklistReviewedNotes => 'راجعت الملازم';

  @override
  String get homeworkTitle => 'الواجب';

  @override
  String get homeworkAdd => 'سجل درجة واجب';

  @override
  String get homeworkScore => 'الدرجة';

  @override
  String get homeworkMax => 'من';

  @override
  String get homeworkNotReady => 'لسه محتاج تذاكر أكتر قبل ما تدخل الامتحان';

  @override
  String get homeworkReady => 'تمام، جاهز تدخل الامتحان';

  @override
  String get homeworkNone => 'مفيش واجبات متسجلة';

  @override
  String get homeworkNote =>
      'الواجب مش بيدخل في حساب الإتقان — ده مؤشر استعداد بس';

  @override
  String get homeworkInvalid =>
      'الدرجة لازم تكون من صفر لـ «من»، و«من» أكبر من صفر';

  @override
  String get examHistory => 'الامتحانات السابقة';

  @override
  String get examNoHistory => 'مفيش امتحانات لسه';

  @override
  String get examReviewBadge => 'مراجعة';

  @override
  String get examHistoryHint => 'دوس على امتحان عشان تشيله لو اتسجل غلط';

  @override
  String get examDelete => 'شيل الامتحان';

  @override
  String get examDeleteConfirm =>
      'هيتشال الامتحان من السجل وإتقان الدرس هيتحسب من غيره. مش هينفع ترجع فيها.';

  @override
  String get toastExamDeleted => 'اتشال الامتحان — الإتقان اتحسب من الأول';

  @override
  String get examStart => 'ابدأ الامتحان';

  @override
  String get examRecordResult => 'سجل نتيجة امتحان';

  @override
  String get examRecordReview => 'سجل امتحان المراجعة';

  @override
  String get examStep1Title => 'عدد الأسئلة الكلي';

  @override
  String get examStep1Hint => 'الامتحان فيه كام سؤال؟';

  @override
  String get examStep2Title => 'درجات الأسئلة';

  @override
  String get examStep2Hint => 'اقسم الأسئلة: كام سؤال بكام درجة';

  @override
  String get examStep3Title => 'إجاباتك الصح';

  @override
  String get examStep3Hint => 'كام سؤال جاوبته صح في كل مجموعة';

  @override
  String get examStep4Title => 'النتيجة';

  @override
  String get examGroupQuestions => 'عدد الأسئلة';

  @override
  String get examGroupPoints => 'درجة السؤال';

  @override
  String get examAddGroup => '+ إضافة مجموعة';

  @override
  String get examRemoveGroup => 'شيل المجموعة';

  @override
  String examGroupLabel(String count, String points) {
    return '$count أسئلة × $points درجة';
  }

  @override
  String examPointsLine(String points) {
    return '$points درجة';
  }

  @override
  String get examMasteryBefore => 'الإتقان قبل';

  @override
  String get examMasteryAfter => 'الإتقان بعد';

  @override
  String get examSave => 'احفظ النتيجة';

  @override
  String get examSaveReview => 'احفظ امتحان المراجعة';

  @override
  String get examSaveFailed =>
      'مقدرناش نحفظ الامتحان. أرقامك لسه موجودة — جرّب تاني.';

  @override
  String get examDiscardTitle => 'تسيب الامتحان؟';

  @override
  String get examDiscardBody => 'اللي كتبته هيروح. مش هينفع ترجع فيها.';

  @override
  String get examDiscardLeave => 'سيبه';

  @override
  String get examDiscardStay => 'كمّل';

  @override
  String get examErrorNeedAtLeastOneQuestion => 'لازم سؤال واحد على الأقل';

  @override
  String get examErrorGroupInvalid =>
      'كل مجموعة لازم يكون فيها عدد أسئلة ودرجة أكبر من صفر';

  @override
  String examErrorSumMismatch(String assigned, String total) {
    return 'مجموع الأسئلة ($assigned) لازم يساوي العدد الكلي ($total)';
  }

  @override
  String get examErrorCorrectExceeds => 'عدد الصح مينفعش يزيد عن عدد الأسئلة';

  @override
  String get toastExamSaved => 'اتسجّل الامتحان — عداد المراجعة بدأ من جديد';

  @override
  String get toastHomeworkSaved => 'اتسجّلت درجة الواجب';

  @override
  String get reviewTitle => 'محتاج مراجعة';

  @override
  String get reviewEmptyTitle => 'مفيش حاجة محتاجة مراجعة';

  @override
  String get reviewEmptyBody => 'كل دروسك في وقتها. استمر.';

  @override
  String get reviewReasonWeak => 'مستوى ضعيف';

  @override
  String get reviewReasonDeclining => 'مستواك بينزل';

  @override
  String get reviewNotificationTitle => 'وقت المراجعة';

  @override
  String reviewNotificationBody(String lesson, String chapter) {
    return 'وقت مراجعة درس $lesson في $chapter';
  }

  @override
  String get analyticsTitle => 'تقدمك';

  @override
  String get analyticsInsights => 'ملاحظات';

  @override
  String get analyticsAllSubjects => 'كل المواد';

  @override
  String get analyticsAlwaysAllSubjects =>
      'الكارت ده بيقارن المواد الأربعة دايماً';

  @override
  String get analyticsMasteryBySubject => 'الإتقان حسب المادة';

  @override
  String get analyticsMasteryByChapter => 'الإتقان حسب الباب';

  @override
  String get analyticsWeakestLessons => 'أضعف الدروس';

  @override
  String get analyticsReviewDiscipline => 'الالتزام بالمراجعة';

  @override
  String get analyticsNotEnoughData => 'لسه مفيش بيانات كفاية';

  @override
  String insightStrongestSubject(String subject, String value) {
    return '$subject أقوى مادة عندك دلوقتي — $value';
  }

  @override
  String insightChapterWeak(String chapter, String value) {
    return '«$chapter» لسه ضعيف — $value';
  }

  @override
  String insightLessonNotReviewed(String lesson, String days) {
    return 'مراجعتش «$lesson» من $days يوم';
  }

  @override
  String insightSubjectImproved(String subject, String delta) {
    return '$subject اتحسنت $delta الشهر ده';
  }

  @override
  String get chapterReportTitle => 'تقرير الباب';

  @override
  String trendUp(String from, String to) {
    return 'اتحسنت من $from لـ $to';
  }

  @override
  String trendDown(String from, String to) {
    return 'نزلت من $from لـ $to';
  }

  @override
  String get trendFlat => 'محتاج امتحانات أكتر عشان نقيس التقدم';

  @override
  String get weakestLessonBadge => 'أضعف درس';

  @override
  String get celebrationTitle => 'أتقنت الباب!';

  @override
  String get celebrationBody => 'شغل محترم. كمّل على كده.';

  @override
  String get celebrationHint => 'دوس في أي حتة تكمّل';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authRegisterTitle => 'حساب جديد';

  @override
  String get authSubtitle =>
      'سجّل دخولك مرة واحدة بس — بعد كده التطبيق هيشتغل من غير نت';

  @override
  String get authEmail => 'الإيميل';

  @override
  String get authPassword => 'الباسورد';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authSignIn => 'دخول';

  @override
  String get authRegister => 'إنشاء حساب';

  @override
  String get authGoogle => 'كمّل بحساب Google';

  @override
  String get authToRegister => 'لسه مش عامل حساب؟ اعمل واحد';

  @override
  String get authToSignIn => 'عندك حساب؟ سجّل دخول';

  @override
  String get authForgotPassword => 'نسيت الباسورد؟';

  @override
  String get authResetSent => 'بعتنالك رابط على الإيميل تغيّر بيه الباسورد';

  @override
  String get authErrorEmailInvalid => 'الإيميل مش مظبوط';

  @override
  String get authErrorPasswordShort => 'الباسورد لازم 6 حروف على الأقل';

  @override
  String get authErrorWrongCredentials => 'الإيميل أو الباسورد غلط';

  @override
  String get authErrorEmailInUse => 'الإيميل ده مستخدم قبل كده';

  @override
  String get authErrorNoNetwork =>
      'مفيش اتصال بالنت. تسجيل الدخول أول مرة بس محتاج نت — بعد كده التطبيق بيشتغل أوفلاين.';

  @override
  String get authErrorTooManyAttempts => 'محاولات كتير. استنى شوية وجرّب تاني';

  @override
  String get authErrorGeneric => 'مقدرناش نكمّل. جرّب تاني';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignOutConfirm =>
      'هتحتاج نت عشان تسجّل دخول تاني. بياناتك محفوظة على الجهاز ومش هتتمسح.';

  @override
  String get authAccount => 'الحساب';

  @override
  String get lockUnlock => 'افتح';

  @override
  String get lockReason => 'افتح Ather';

  @override
  String get lockRefused => 'مفتحش — جرّب تاني';

  @override
  String get lockLockedOut =>
      'حاولت كتير. استنى شوية وجرّب تاني، أو افتح بكود القفل بتاع التليفون.';

  @override
  String get lockSetting => 'قفل بالبصمة';

  @override
  String get lockSettingBody => 'اطلب بصمة كل ما تفتح التطبيق';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsThemeBody =>
      'اختار مظهر التطبيق، أو سيبه يمشي مع إعدادات الموبايل';

  @override
  String get settingsNotifications => 'إشعارات المراجعة';

  @override
  String get settingsNotificationsBody => 'ذكّرني لما يجي وقت مراجعة درس';

  @override
  String get settingsNotificationsBlocked =>
      'التنبيهات مقفولة من إعدادات التليفون. افتحها من هناك عشان التذكير يوصلك.';

  @override
  String get settingsAbout => 'عن التطبيق';

  @override
  String get backupTitle => 'النسخة السحابية';

  @override
  String get backupBody =>
      'بياناتك بتتحفظ على حسابك، فلو غيّرت التليفون تلاقيها زي ما هي.';

  @override
  String get backupNever => 'لسه متحفظتش';

  @override
  String backupSavedAt(String date) {
    return 'آخر حفظ: $date';
  }

  @override
  String get backupSaving => 'بيحفظ…';

  @override
  String get backupSaveNow => 'احفظ دلوقتي';

  @override
  String get backupRestore => 'استرجع النسخة السحابية';

  @override
  String get backupRestoreConfirm =>
      'اللي على التليفون ده هيتمسح ويتحط مكانه اللي في النسخة السحابية.';

  @override
  String get backupRestoreDone => 'رجّعنا بياناتك';

  @override
  String get backupRestoreEmpty => 'مفيش نسخة سحابية لسه';

  @override
  String get backupErrorOffline => 'مفيش نت — هيتحفظ أول ما النت يرجع';

  @override
  String get backupErrorPermission => 'الصلاحيات مظبوطتش على السيرفر';

  @override
  String get backupErrorTooLarge => 'بياناتك أكبر من إن نحفظها مرة واحدة';

  @override
  String get backupErrorUnreadable => 'النسخة السحابية مش مقروءة';

  @override
  String get backupErrorUnknown => 'الحفظ مظبطش';

  @override
  String get tasksTitle => 'مهام النهارده';

  @override
  String tasksDoneOf(String done, String total) {
    return '$done من $total خلصتهم';
  }

  @override
  String get addTask => '+ إضافة مهمة';

  @override
  String get addTaskTitle => 'مهمة جديدة';

  @override
  String get taskNameHint => 'هتعمل إيه النهارده؟';

  @override
  String get renameTask => 'تعديل المهمة';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String get deleteTaskConfirm => 'هتتشال من مهام اليوم ده خالص.';

  @override
  String get noTasksYet => 'مفيش مهام لليوم ده';

  @override
  String get tasksEmptyBody => 'اكتب اللي ناوي تعمله، وشيله لما تخلصه.';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonSomethingWentWrong => 'في حاجة مامشتش صح. جرّب تاني.';

  @override
  String get nameRequired => 'اكتب اسم الأول';

  @override
  String get authShowPassword => 'إظهار كلمة السر';

  @override
  String get authHidePassword => 'إخفاء كلمة السر';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonClose => 'إغلاق';
}
