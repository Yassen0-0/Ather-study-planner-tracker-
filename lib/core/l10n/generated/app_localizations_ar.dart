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
  String get appTagline => 'أنت لا تُنهي الدروس، بل تُتقنها';

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
  String get weekdaySaturday => 'سبت';

  @override
  String get weekdaySunday => 'أحد';

  @override
  String get weekdayMonday => 'اثنين';

  @override
  String get weekdayTuesday => 'ثلاثاء';

  @override
  String get weekdayWednesday => 'أربعاء';

  @override
  String get weekdayThursday => 'خميس';

  @override
  String get weekdayFriday => 'جمعة';

  @override
  String get todayLabel => 'اليوم';

  @override
  String get dashboardTitle => 'اليوم';

  @override
  String get overallMastery => 'الإتقان العام';

  @override
  String get statLessonsRemaining => 'دروس متراكمة';

  @override
  String get statNeedsReview => 'يحتاج مراجعة';

  @override
  String get statMastered => 'متفوق';

  @override
  String get sectionSubjects => 'المواد';

  @override
  String get firstRunTitle => 'ابدأ من هنا';

  @override
  String get firstRunBody =>
      'الإتقان يُحسب من امتحاناتك وحدها، لا من إنهاء الدرس.';

  @override
  String get firstRunAction => 'افتح أول مادة';

  @override
  String get sectionNext => 'التالي';

  @override
  String get actionExam => 'امتحن';

  @override
  String get notStartedYet => 'لم تبدأ بعد';

  @override
  String get subjectHasOverdueLesson => 'تأخّرت مراجعة درس';

  @override
  String lessonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درس',
      many: '$count درساً',
      few: '$count دروس',
      two: 'درسان',
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
      many: '$count باباً',
      few: '$count أبواب',
      two: 'بابان',
      one: 'باب واحد',
    );
    return '$_temp0';
  }

  @override
  String chaptersMasteredOf(String mastered, String total) {
    return 'أتقنت $mastered من $total باب';
  }

  @override
  String chaptersOfShort(String mastered, String total) {
    return '$mastered من $total باب';
  }

  @override
  String lessonsExaminedOf(String examined, String total) {
    return '$examined من $total درس بامتحان';
  }

  @override
  String lessonsOnTimeOf(String onTime, String total) {
    return '$onTime من $total درس في موعده';
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
  String get noChaptersYet => 'لا توجد أبواب بعد';

  @override
  String get noLessonsYet => 'لا توجد دروس بعد';

  @override
  String get chapterName => 'اسم الباب';

  @override
  String get lessonName => 'اسم الدرس';

  @override
  String get chapterNameHint => 'مثال: الباب الأول — الخلية';

  @override
  String get lessonNameHint => 'مثال: تركيب الغشاء البلازمي';

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
      'سيُحذف الباب وكل الدروس والامتحانات التي بداخله. لا يمكن التراجع.';

  @override
  String get deleteLessonConfirm =>
      'سيُحذف الدرس وكل امتحاناته. لا يمكن التراجع.';

  @override
  String get averageExamScore => 'متوسط الامتحانات';

  @override
  String get chapterNeedsReview => 'يحتاج مراجعة';

  @override
  String chapterMasteredAt(String date) {
    return 'أتقنته في $date';
  }

  @override
  String chapterClosureDated(String date) {
    return 'أُغلِق $date';
  }

  @override
  String get masterChapter => 'أتقنت الباب';

  @override
  String get viewChapterReport => 'تقرير الباب';

  @override
  String get notReadyGate => 'لم يكتمل بعد — اعرف السبب';

  @override
  String get notReadyTitle => 'لم يكتمل بعد';

  @override
  String notReadyBody(String threshold) {
    return 'لإتقان الباب يجب أن يكون لكل درس امتحان، وأن يبلغ الإتقان $threshold على الأقل.';
  }

  @override
  String get noExamShort => 'لا امتحان';

  @override
  String get lessonNoExamYet => 'لا يوجد امتحان بعد';

  @override
  String dueInDays(String days) {
    return 'بقي $days يوم';
  }

  @override
  String dueInDaysLong(String days) {
    return 'بقي $days يوم على المراجعة';
  }

  @override
  String overdueByDays(String days) {
    return 'متأخّر $days يوم';
  }

  @override
  String masteryCaptionWithExams(String last, String rest) {
    return 'الإتقان محسوب من آخر امتحان $last ومتوسط ما قبله $rest';
  }

  @override
  String get masteryCaptionNoExams =>
      'الإتقان يُحسب من الامتحانات وحدها — سجّل أول امتحان';

  @override
  String get checklistTitle => 'خطوات المذاكرة';

  @override
  String get checklistWatched => 'شاهدت الدرس';

  @override
  String get checklistReadNotes => 'قرأت الملازم';

  @override
  String get checklistDidHomework => 'حللت الواجب';

  @override
  String get checklistDidExam => 'حللت الامتحان';

  @override
  String get checklistReviewedNotes => 'راجعت الملازم';

  @override
  String get homeworkTitle => 'الواجب';

  @override
  String get homeworkAdd => 'سجّل درجة واجب';

  @override
  String get homeworkScore => 'الدرجة';

  @override
  String get homeworkMax => 'من';

  @override
  String get homeworkNotReady => 'تحتاج مذاكرة أكثر قبل دخول الامتحان';

  @override
  String get homeworkReady => 'جاهز لدخول الامتحان';

  @override
  String get homeworkNone => 'لا واجبات مسجّلة';

  @override
  String get homeworkNote =>
      'الواجب لا يدخل في حساب الإتقان — هو مؤشر استعداد فقط';

  @override
  String get homeworkInvalid => 'الدرجة بين صفر و«من»، و«من» أكبر من صفر';

  @override
  String get examHistory => 'الامتحانات السابقة';

  @override
  String get examNoHistory => 'لا امتحانات بعد';

  @override
  String get examReviewBadge => 'مراجعة';

  @override
  String get examDelete => 'حذف الامتحان';

  @override
  String get examDeleteConfirm =>
      'سيُحذف الامتحان من السجل ويُعاد حساب إتقان الدرس بدونه. لا يمكن التراجع.';

  @override
  String get toastExamDeleted => 'حُذف الامتحان — أُعيد حساب الإتقان';

  @override
  String get examStart => 'ابدأ الامتحان';

  @override
  String get examRecordResult => 'سجّل نتيجة امتحان';

  @override
  String get examRecordReview => 'سجّل امتحان المراجعة';

  @override
  String get examStep1Title => 'عدد الأسئلة الكلي';

  @override
  String get examStep1Hint => 'كم سؤالاً في الامتحان؟';

  @override
  String get examStep2Title => 'درجات الأسئلة';

  @override
  String get examStep2Hint => 'وزّع الأسئلة: كم سؤالاً بكم درجة';

  @override
  String get examStep3Title => 'إجاباتك الصحيحة';

  @override
  String get examStep3Hint => 'كم سؤالاً أجبته صحيحاً في كل مجموعة';

  @override
  String get examStep4Title => 'النتيجة';

  @override
  String get examGroupQuestions => 'عدد الأسئلة';

  @override
  String get examGroupPoints => 'درجة السؤال';

  @override
  String get examAddGroup => '+ إضافة مجموعة';

  @override
  String get examRemoveGroup => 'حذف المجموعة';

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
      'تعذّر حفظ الامتحان. أرقامك لم تَضِع — حاول مرة أخرى.';

  @override
  String get examDiscardTitle => 'تترك الامتحان؟';

  @override
  String get examDiscardBody => 'ما كتبته سيضيع. لا يمكن التراجع.';

  @override
  String get examDiscardLeave => 'اترك';

  @override
  String get examDiscardStay => 'أكمل';

  @override
  String get examErrorNeedAtLeastOneQuestion => 'سؤال واحد على الأقل';

  @override
  String get examErrorGroupInvalid =>
      'كل مجموعة تحتاج عدد أسئلة ودرجة أكبر من صفر';

  @override
  String examErrorSumMismatch(String assigned, String total) {
    return 'مجموع الأسئلة ($assigned) يجب أن يساوي العدد الكلي ($total)';
  }

  @override
  String get examErrorCorrectExceeds =>
      'عدد الإجابات الصحيحة لا يتجاوز عدد الأسئلة';

  @override
  String get toastExamSaved => 'حُفظ الامتحان — بدأ عدّاد المراجعة من جديد';

  @override
  String get toastHomeworkSaved => 'حُفظت درجة الواجب';

  @override
  String get reviewTitle => 'يحتاج مراجعة';

  @override
  String get reviewEmptyTitle => 'لا شيء يحتاج مراجعة';

  @override
  String get reviewEmptyBody => 'كل دروسك في موعدها.';

  @override
  String get reviewReasonWeak => 'مستوى ضعيف';

  @override
  String get reviewReasonDeclining => 'مستواك ينخفض';

  @override
  String get reviewNotificationTitle => 'وقت المراجعة';

  @override
  String reviewNotificationBody(String lesson, String chapter) {
    return 'حان وقت مراجعة درس $lesson في $chapter';
  }

  @override
  String get analyticsTitle => 'تقدمك';

  @override
  String get analyticsInsights => 'ملاحظات';

  @override
  String get analyticsAllSubjects => 'كل المواد';

  @override
  String get analyticsMasteryBySubject => 'الإتقان حسب المادة';

  @override
  String get analyticsMasteryByChapter => 'الإتقان حسب الباب';

  @override
  String get analyticsWeakestLessons => 'أضعف الدروس';

  @override
  String get analyticsReviewDiscipline => 'الالتزام بالمراجعة';

  @override
  String get analyticsNotEnoughData => 'لا توجد بيانات كافية بعد';

  @override
  String insightStrongestSubject(String subject, String value) {
    return '$subject أقوى موادك الآن — $value';
  }

  @override
  String insightChapterWeak(String chapter, String value) {
    return '«$chapter» ما زال ضعيفاً — $value';
  }

  @override
  String insightLessonNotReviewed(String lesson, String days) {
    return 'لم تراجع «$lesson» منذ $days يوم';
  }

  @override
  String insightSubjectImproved(String subject, String delta) {
    return '$subject تحسّنت $delta هذا الشهر';
  }

  @override
  String get chapterReportTitle => 'تقرير الباب';

  @override
  String trendUp(String from, String to) {
    return 'ارتفعت من $from إلى $to';
  }

  @override
  String trendDown(String from, String to) {
    return 'انخفضت من $from إلى $to';
  }

  @override
  String get trendFlat => 'تحتاج امتحانات أكثر لقياس التقدّم';

  @override
  String get trendSteady => 'ثابتة — النصفان على المستوى نفسه';

  @override
  String get chapterReportMasteryLabel => 'الإتقان';

  @override
  String get weakestLessonBadge => 'أضعف درس';

  @override
  String get celebrationTitle => 'أتقنت الباب!';

  @override
  String get celebrationBody => 'عمل ممتاز. واصِل.';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authRegisterTitle => 'حساب جديد';

  @override
  String get authSubtitle => 'تسجيل دخول واحد، ثم يعمل التطبيق دون اتصال';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة السر';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authSignIn => 'دخول';

  @override
  String get authRegister => 'إنشاء حساب';

  @override
  String get authGoogle => 'المتابعة بحساب Google';

  @override
  String get authToRegister => 'لا حساب لديك؟ أنشئ واحداً';

  @override
  String get authToSignIn => 'لديك حساب؟ سجّل الدخول';

  @override
  String get authForgotPassword => 'نسيت كلمة السر؟';

  @override
  String get authResetSent => 'أرسلنا رابطاً إلى بريدك لتغيير كلمة السر';

  @override
  String get authErrorEmailInvalid => 'البريد الإلكتروني غير صحيح';

  @override
  String get authErrorPasswordShort => 'كلمة السر ٨ أحرف على الأقل';

  @override
  String get authErrorWrongCredentials =>
      'البريد الإلكتروني أو كلمة السر غير صحيحة';

  @override
  String get authErrorEmailInUse => 'هذا البريد مستخدم بالفعل';

  @override
  String get authErrorNoNetwork =>
      'لا يوجد اتصال. تسجيل الدخول أول مرة فقط يحتاج اتصالاً — بعدها يعمل التطبيق دون إنترنت.';

  @override
  String get authErrorTooManyAttempts =>
      'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى';

  @override
  String get authErrorGeneric => 'تعذّر إتمام العملية. حاول مرة أخرى';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignOutConfirm =>
      'ستحتاج اتصالاً لتسجيل الدخول مرة أخرى. بياناتك محفوظة على الجهاز ولن تُحذف.';

  @override
  String get authAccount => 'الحساب';

  @override
  String get authDeleteAccount => 'حذف الحساب';

  @override
  String get authDeleteAccountConfirm =>
      'سيُحذف حسابك ونسختك السحابية وكل شيء على الجهاز نهائياً. لا يمكن التراجع.';

  @override
  String get authDeleteAccountOfflineWarning =>
      'ما لم يُرفع إلى السحابة بعد سيضيع مع الحذف.';

  @override
  String get authDeleteAccountReauthTitle => 'أكّد أنه حسابك';

  @override
  String get authDeleteAccountReauthBody => 'اكتب كلمة سر حسابك لإتمام الحذف.';

  @override
  String get authDeleteAccountReauthAction => 'احذف الحساب';

  @override
  String get authDeleteAccountFailed => 'لم يُحذف الحساب. حاول مرة أخرى.';

  @override
  String get accountSwitchWipeTitle => 'حساب مختلف';

  @override
  String get accountSwitchWipeMessage =>
      'البيانات المحفوظة على هذا الجهاز تخص حسابًا آخر. للمتابعة بهذا الحساب ستُمسح كل بيانات الجهاز: المواد والأبواب والامتحانات والمهام. لا يمكن التراجع.';

  @override
  String get accountSwitchWipeConfirm => 'امسح بيانات الجهاز';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get privacyTitle => 'خصوصيتك';

  @override
  String get privacyIntro =>
      'هذا التطبيق يجمع أقل قدر ممكن من البيانات. ما يلي وصف لما يحدث فعلاً، لا وعود عامة.';

  @override
  String get privacyLocalTitle => 'بيانات دراستك';

  @override
  String get privacyLocalBody =>
      'موادك وأبوابك ودروسك وامتحاناتك ومهامك محفوظة على هاتفك، في قاعدة بيانات محلية. الإتقان يُحسب على جهازك. واسمك وسنتك الدراسية في «ملفك» محفوظان على هذا الجهاز وحده ولا يُرفعان إلى أي خادم.';

  @override
  String get privacyAccountTitle => 'بيانات الحساب';

  @override
  String get privacyAccountBody =>
      'للنسخة السحابية نطلب بريداً إلكترونياً وكلمة سر (أو حساب Google)، وتُحفظ لدى Firebase Auth من Google. بريدك هو كل ما نعرفه عنك على الخادم — لا اسم ولا عمر ولا أي بيانات أخرى.';

  @override
  String get privacyCloudTitle => 'النسخة السحابية';

  @override
  String get privacyCloudBody =>
      'إن أنشأت حساباً، تُرفع نسخة من بيانات دراستك مشفّرة أثناء النقل وتُحفظ على خوادم Google (Firebase Firestore) باسم حسابك. لا يصل إليها أحد سواك — ولا نحن.';

  @override
  String get privacyDeleteTitle => 'حذف بياناتك';

  @override
  String get privacyDeleteBody =>
      'في أسفل صفحة الإعدادات زر «حذف الحساب». عند الضغط عليه: تُمحى بياناتك على الهاتف، وتُمحى النسخة السحابية، ويُزال الحساب نفسه من Firebase. نهائياً.';

  @override
  String get privacyNoCollectTitle => 'ما لا نفعله';

  @override
  String get privacyNoCollectBody =>
      'لا إعلانات. لا تتبّع. لا بيع للبيانات. لا تحليلات ولا تقارير أخطاء لجهة خارجية.';

  @override
  String get lockUnlock => 'افتح';

  @override
  String get lockReason => 'افتح أثر';

  @override
  String get lockRefused => 'لم يُفتح. حاول مرة أخرى.';

  @override
  String get lockLockedOut =>
      'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى، أو استخدم رمز قفل هاتفك.';

  @override
  String get lockSetting => 'قفل بالبصمة';

  @override
  String get hapticsSetting => 'الاهتزاز';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get profileTitle => 'ملفك';

  @override
  String get profileName => 'الاسم';

  @override
  String get profileNameHint => 'اكتب اسمك';

  @override
  String get profileNameUnset => 'لم تكتبه بعد';

  @override
  String get profileYear => 'السنة الدراسية';

  @override
  String get profileYearUnset => 'لم تحددها';

  @override
  String get profileYearFirst => 'الأول الثانوي';

  @override
  String get profileYearSecond => 'الثاني الثانوي';

  @override
  String get profileYearThird => 'الثالث الثانوي';

  @override
  String get profileLocalNote =>
      'هذه البيانات محفوظة على هذا الجهاز وحده، ولا تُرفع إلى أي خادم.';

  @override
  String profileGreeting(String name) {
    return 'أهلاً، $name';
  }

  @override
  String get subjectsArchived => 'مواد مؤرشفة';

  @override
  String get subjectsArchivedNote =>
      'المادة المؤرشفة لا تظهر ولا تدخل في حساب الإتقان ولا تُرسل تنبيهاتها، وأبوابها وامتحاناتها محفوظة كما هي.';

  @override
  String get subjectArchive => 'أرشفة المادة';

  @override
  String get subjectUnarchive => 'إخراج من الأرشيف';

  @override
  String get binTitle => 'سلة المحذوفات';

  @override
  String get binEmpty => 'السلة فارغة';

  @override
  String get binRestore => 'استرجاع';

  @override
  String get binPurge => 'حذف نهائي';

  @override
  String get binEmptyAll => 'إفراغ السلة';

  @override
  String binDeletedAt(String date) {
    return 'حُذفت في $date';
  }

  @override
  String get binNote =>
      'المواد هنا محفوظة بالكامل بأبوابها وامتحاناتها، ولا تُحذف من نفسها أبداً. الحذف النهائي وحده هو الذي يمحوها.';

  @override
  String binPurgeConfirm(String subject, String chapters, String exams) {
    return 'سيُمحى «$subject» ومعه $chapters و$exams. لا يمكن التراجع.';
  }

  @override
  String get binEmptyAllConfirm =>
      'سيُمحى كل ما في السلة ومعه أبوابه وامتحاناته. لا يمكن التراجع.';

  @override
  String examCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count امتحان',
      many: '$count امتحاناً',
      few: '$count امتحانات',
      two: 'امتحانان',
      one: 'امتحان واحد',
    );
    return '$_temp0';
  }

  @override
  String get subjectsTitle => 'المواد';

  @override
  String subjectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مادة',
      many: '$count مادة',
      few: '$count مواد',
      two: 'مادتان',
      one: 'مادة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get subjectAdd => '+ إضافة مادة';

  @override
  String get subjectNameHint => 'مثال: رياضيات';

  @override
  String get subjectRename => 'تعديل الاسم';

  @override
  String get subjectDelete => 'حذف المادة';

  @override
  String get settingsPreferences => 'التفضيلات';

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
  String get settingsNotifications => 'إشعارات المراجعة';

  @override
  String get settingsNotificationsBlocked =>
      'الإشعارات مغلقة من إعدادات الهاتف. افتحها من هناك ليصلك التذكير.';

  @override
  String get settingsAboutSection => 'عن أثر';

  @override
  String get settingsAbout => 'عن التطبيق';

  @override
  String settingsVersionFormat(String version) {
    return 'الإصدار $version';
  }

  @override
  String get backupTitle => 'النسخة السحابية';

  @override
  String get backupNever => 'لم تُحفظ بعد';

  @override
  String backupSavedAt(String date) {
    return 'آخر حفظ: $date';
  }

  @override
  String get backupSaving => 'جارٍ الحفظ…';

  @override
  String get backupSaveNow => 'احفظ الآن';

  @override
  String get backupRestore => 'استرجاع النسخة السحابية';

  @override
  String get backupRestoreConfirm =>
      'سيُمحى ما على هذا الهاتف ويحل محله ما في النسخة السحابية.';

  @override
  String get backupRestoreDone => 'استُرجعت بياناتك';

  @override
  String get backupRestoreEmpty => 'لا توجد نسخة سحابية بعد';

  @override
  String get backupErrorOffline => 'لا يوجد اتصال — سيُحفظ فور عودة الشبكة';

  @override
  String get backupErrorPermission => 'صلاحيات الخادم غير مضبوطة';

  @override
  String get backupErrorTooLarge => 'بياناتك أكبر من أن تُحفظ دفعة واحدة';

  @override
  String get backupErrorUnreadable => 'النسخة السحابية غير مقروءة';

  @override
  String get backupErrorUnknown => 'لم ينجح الحفظ';

  @override
  String get tasksTitle => 'مهام اليوم';

  @override
  String tasksDoneOf(String done, String total) {
    return 'أنجزت $done من $total';
  }

  @override
  String get addTask => '+ إضافة مهمة';

  @override
  String get addTaskTitle => 'مهمة جديدة';

  @override
  String get taskNameHint => 'ماذا ستفعل اليوم؟';

  @override
  String get renameTask => 'تعديل المهمة';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String get deleteTaskConfirm => 'ستُحذف من مهام هذا اليوم نهائياً.';

  @override
  String get noTasksYet => 'لا مهام لهذا اليوم';

  @override
  String get tasksQueueClearedTitle => 'خلص الطابور';

  @override
  String get tasksQueueClearedBody => 'ما بقي شيء مخطط لهذا اليوم.';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonSomethingWentWrong => 'تعذّر إتمام العملية. حاول مرة أخرى.';

  @override
  String get nameRequired => 'اكتب اسماً أولاً';

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

  @override
  String get exportTitle => 'تصدير بياناتك';

  @override
  String get exportBody =>
      'احصل على نسخة من كل ما سجّلته: المواد والأبواب والدروس والامتحانات ودرجات الإتقان، في ملف JSON واحد تقدر تفتحه وتقرأه بنفسك.';

  @override
  String get exportAction => 'صدّر وشارك الملف';

  @override
  String get exportWhereNote =>
      'الملف يتفتح في نافذة المشاركة، تختار منها تحفظه فين — درايف أو واتساب أو الملفات. أثر لا يحتفظ بنسخة.';

  @override
  String get exportErrorFile =>
      'تعذّر تجهيز الملف. راجع المساحة الفاضية على الجهاز.';

  @override
  String get exportErrorShare => 'تعذّر فتح نافذة المشاركة';

  @override
  String get chapterReportExport => 'صدّر التقرير PDF';

  @override
  String get chapterReportExportDone => 'اتجهّز التقرير';

  @override
  String get chapterReportExportError => 'تعذّر تجهيز ملف PDF';

  @override
  String get shareCardAction => 'شارك تقدّمك';

  @override
  String get shareCardTitle => 'إتقاني في أثر';

  @override
  String get shareCardOverall => 'الإتقان العام';

  @override
  String shareCardLessonsAbove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درساً أثبتَها فوق حد الإتقان',
      many: '$count درساً أثبتَها فوق حد الإتقان',
      few: '$count دروس أثبتَها فوق حد الإتقان',
      two: 'درسان أثبتَهما فوق حد الإتقان',
      one: 'درس واحد أثبتَه فوق حد الإتقان',
      zero: 'لا توجد دروس أثبتَها فوق حد الإتقان بعد',
    );
    return '$_temp0';
  }

  @override
  String get shareCardError => 'تعذّر تجهيز صورة التقدّم';

  @override
  String reviewNotificationEarlyBody(String lesson, String chapter) {
    return 'اقترب موعد مراجعة درس $lesson في $chapter';
  }

  @override
  String get analyticsTrajectory => 'مسار درجاتك';

  @override
  String analyticsVelocity(String value) {
    return '$value نقطة لكل دورة مراجعة';
  }

  @override
  String get analyticsVelocityFlat => 'ثابت، بلا تغيّر';

  @override
  String get authVerificationSent => 'بعتنالك رابط تأكيد على بريدك';

  @override
  String get authEmailUnverified => 'لم يتم تأكيده';

  @override
  String get authResendVerification => 'إعادة إرسال رابط التأكيد';

  @override
  String get authVerificationTooSoon =>
      'بعتنا رابط للتو. استنى شوية وحاول تاني.';

  @override
  String get authVerificationNote =>
      'تأكيد بريدك يخليك تقدر تسترجع حسابك لو نسيت كلمة السر. التطبيق شغال عادي من غيره.';

  @override
  String get subjectTemplateAdd => 'أضف أبواب المنهج';

  @override
  String subjectTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count باباً',
      few: '$count أبواب',
      two: 'بابين',
      one: 'باباً واحداً',
    );
    return '$_temp0';
  }

  @override
  String subjectTemplateAdded(String count) {
    return 'تمت إضافة $count';
  }

  @override
  String get subjectTemplateNothingNew => 'كل أبواب المنهج موجودة عندك بالفعل';

  @override
  String get subjectTemplateNote =>
      'أبواب المنهج المعتادة، تقدر تعدّلها أو تحذفها زي أي باب كتبته بنفسك. مش هيتغيّر أو يتحذف أي باب عندك.';

  @override
  String get authVerificationNotSent =>
      'اتعمل حسابك. رابط التأكيد ما اتبعتش — تقدر تبعته من صفحة ملفك.';

  @override
  String get examVerdictWeak =>
      'درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبلها.';

  @override
  String get examVerdictPassed => 'عدّيت، مش متقن — امتحان تاني هو اللي يرفعه.';

  @override
  String examNeedToCross(String percentage) {
    return 'عشان تعدّي الحد: جيب $percentage في اللي جاي.';
  }

  @override
  String comebackLine(String days, String count) {
    return 'رجعت بعد $days يوم — $count درس عبر معاده.';
  }

  @override
  String lastHomeworkDated(String date) {
    return 'آخر واجب ($date)';
  }

  @override
  String get checklistAllDone => 'ذاكرتها كلها — فاضل إنك تثبتها بامتحان.';

  @override
  String tasksDayDone(String done, String total) {
    return 'أنجزت $done من $total — يومك خلص.';
  }

  @override
  String reviewWaitingHeader(String count) {
    return 'دروس المراجعة المستنياك: $count';
  }

  @override
  String insightDiscipline(String onTime, String examined) {
    return 'التزمت $onTime من $examined مراجعة في معادها.';
  }

  @override
  String purgeCountsLine(
    String subjects,
    String chapters,
    String lessons,
    String exams,
  ) {
    return '$subjects مادة · $chapters باب · $lessons درس · $exams امتحان';
  }

  @override
  String restoreCopyCounts(String chapters, String exams) {
    return 'النسخة السحابية: $chapters باب، $exams امتحان';
  }

  @override
  String get examEveButton => 'ليلة الامتحان';

  @override
  String get examEveTitle => 'ليلة الامتحان';

  @override
  String get examEveBody => 'دروس المادة مرتبة حسب أولوية إثباتها الليلة.';

  @override
  String get examEveTierUnsettled => 'غير مُثبت — بلا امتحان';

  @override
  String get examEveTierWeakest => 'الأضعف إتقانًا';

  @override
  String get examEveTierNearestDue => 'الأقرب سقوطًا';

  @override
  String reviewBodyDeclining(String lesson) {
    return 'آخر امتحان في $lesson نازل — راجعه قبل ما يوقع.';
  }

  @override
  String reviewBodyWeak(String lesson) {
    return '$lesson لسه ضعيف — ثبّته بامتحان.';
  }
}
