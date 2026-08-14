import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'أثر'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'إنت مش بتخلص الدروس… إنت بتتقنها'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navReview.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get navReview;

  /// No description provided for @navProgress.
  ///
  /// In ar, this message translates to:
  /// **'تقدمك'**
  String get navProgress;

  /// No description provided for @navTasks.
  ///
  /// In ar, this message translates to:
  /// **'مهامك'**
  String get navTasks;

  /// No description provided for @subjectBiology.
  ///
  /// In ar, this message translates to:
  /// **'أحياء'**
  String get subjectBiology;

  /// No description provided for @subjectPhysics.
  ///
  /// In ar, this message translates to:
  /// **'فيزياء'**
  String get subjectPhysics;

  /// No description provided for @subjectChemistry.
  ///
  /// In ar, this message translates to:
  /// **'كيمياء'**
  String get subjectChemistry;

  /// No description provided for @subjectEnglish.
  ///
  /// In ar, this message translates to:
  /// **'إنجليزي'**
  String get subjectEnglish;

  /// No description provided for @weekdaySaturday.
  ///
  /// In ar, this message translates to:
  /// **'س'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In ar, this message translates to:
  /// **'ح'**
  String get weekdaySunday;

  /// No description provided for @weekdayMonday.
  ///
  /// In ar, this message translates to:
  /// **'ن'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In ar, this message translates to:
  /// **'ث'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In ar, this message translates to:
  /// **'ر'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In ar, this message translates to:
  /// **'خ'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In ar, this message translates to:
  /// **'ج'**
  String get weekdayFriday;

  /// No description provided for @dashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'النهارده'**
  String get dashboardTitle;

  /// No description provided for @overallMastery.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان العام'**
  String get overallMastery;

  /// No description provided for @statLessonsRemaining.
  ///
  /// In ar, this message translates to:
  /// **'دروس فاضلة'**
  String get statLessonsRemaining;

  /// No description provided for @statNeedsReview.
  ///
  /// In ar, this message translates to:
  /// **'محتاج مراجعة'**
  String get statNeedsReview;

  /// No description provided for @statMastered.
  ///
  /// In ar, this message translates to:
  /// **'متقن'**
  String get statMastered;

  /// No description provided for @sectionSubjects.
  ///
  /// In ar, this message translates to:
  /// **'المواد'**
  String get sectionSubjects;

  /// No description provided for @firstRunTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من هنا'**
  String get firstRunTitle;

  /// No description provided for @firstRunBody.
  ///
  /// In ar, this message translates to:
  /// **'افتح مادة، ضيف فيها باب، وبعدين درس. الإتقان بيتحسب من امتحاناتك الحقيقية بس — مش من إنك خلصت الدرس.'**
  String get firstRunBody;

  /// No description provided for @firstRunAction.
  ///
  /// In ar, this message translates to:
  /// **'افتح أول مادة'**
  String get firstRunAction;

  /// No description provided for @sectionNext.
  ///
  /// In ar, this message translates to:
  /// **'اللي بعده'**
  String get sectionNext;

  /// No description provided for @actionExam.
  ///
  /// In ar, this message translates to:
  /// **'امتحن'**
  String get actionExam;

  /// No description provided for @notStartedYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه مبدأتش'**
  String get notStartedYet;

  /// No description provided for @subjectHasOverdueLesson.
  ///
  /// In ar, this message translates to:
  /// **'فات ميعاد مراجعة درس'**
  String get subjectHasOverdueLesson;

  /// No description provided for @lessonCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{درس واحد} =2{درسين} few{{count} دروس} many{{count} درس} other{{count} درس}}'**
  String lessonCount(int count);

  /// No description provided for @chapterCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{باب واحد} =2{بابين} few{{count} أبواب} many{{count} باب} other{{count} باب}}'**
  String chapterCount(int count);

  /// No description provided for @chaptersMasteredOf.
  ///
  /// In ar, this message translates to:
  /// **'{mastered} من {total} باب اتقنتها'**
  String chaptersMasteredOf(String mastered, String total);

  /// No description provided for @chaptersOfShort.
  ///
  /// In ar, this message translates to:
  /// **'{mastered} من {total} باب'**
  String chaptersOfShort(String mastered, String total);

  /// No description provided for @lessonsExaminedOf.
  ///
  /// In ar, this message translates to:
  /// **'{examined} من {total} درس متمتحن'**
  String lessonsExaminedOf(String examined, String total);

  /// No description provided for @lessonsOnTimeOf.
  ///
  /// In ar, this message translates to:
  /// **'{onTime} من {total} درس في وقتها'**
  String lessonsOnTimeOf(String onTime, String total);

  /// No description provided for @sectionChapters.
  ///
  /// In ar, this message translates to:
  /// **'الأبواب'**
  String get sectionChapters;

  /// No description provided for @sectionLessons.
  ///
  /// In ar, this message translates to:
  /// **'الدروس'**
  String get sectionLessons;

  /// No description provided for @addChapter.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة باب'**
  String get addChapter;

  /// No description provided for @addLesson.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة درس'**
  String get addLesson;

  /// No description provided for @noChaptersYet.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أبواب لسه'**
  String get noChaptersYet;

  /// No description provided for @noLessonsYet.
  ///
  /// In ar, this message translates to:
  /// **'مفيش دروس لسه'**
  String get noLessonsYet;

  /// No description provided for @chapterName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الباب'**
  String get chapterName;

  /// No description provided for @lessonName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الدرس'**
  String get lessonName;

  /// No description provided for @chapterNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: الباب الأول — الخلية'**
  String get chapterNameHint;

  /// No description provided for @lessonNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: تركيب الغشاء البلازمي'**
  String get lessonNameHint;

  /// No description provided for @renameChapter.
  ///
  /// In ar, this message translates to:
  /// **'تعديل اسم الباب'**
  String get renameChapter;

  /// No description provided for @renameLesson.
  ///
  /// In ar, this message translates to:
  /// **'تعديل اسم الدرس'**
  String get renameLesson;

  /// No description provided for @deleteChapter.
  ///
  /// In ar, this message translates to:
  /// **'حذف الباب'**
  String get deleteChapter;

  /// No description provided for @deleteLesson.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدرس'**
  String get deleteLesson;

  /// No description provided for @deleteChapterConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هيتحذف الباب وكل الدروس والامتحانات اللي جواه. مش هينفع ترجع فيها.'**
  String get deleteChapterConfirm;

  /// No description provided for @deleteLessonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هيتحذف الدرس وكل امتحاناته. مش هينفع ترجع فيها.'**
  String get deleteLessonConfirm;

  /// No description provided for @averageExamScore.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الامتحانات'**
  String get averageExamScore;

  /// No description provided for @chapterNeedsReview.
  ///
  /// In ar, this message translates to:
  /// **'محتاج مراجعة'**
  String get chapterNeedsReview;

  /// No description provided for @chapterMasteredAt.
  ///
  /// In ar, this message translates to:
  /// **'اتقنته في {date}'**
  String chapterMasteredAt(String date);

  /// No description provided for @masterChapter.
  ///
  /// In ar, this message translates to:
  /// **'أتقنت الباب'**
  String get masterChapter;

  /// No description provided for @viewChapterReport.
  ///
  /// In ar, this message translates to:
  /// **'شوف تقرير الباب'**
  String get viewChapterReport;

  /// No description provided for @notReadyGate.
  ///
  /// In ar, this message translates to:
  /// **'لسه مش جاهز — اعرف ليه'**
  String get notReadyGate;

  /// No description provided for @notReadyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لسه مش جاهز'**
  String get notReadyTitle;

  /// No description provided for @notReadyBody.
  ///
  /// In ar, this message translates to:
  /// **'عشان تتقن الباب لازم كل الدروس تتمتحن والإتقان يوصل {threshold} على الأقل.'**
  String notReadyBody(String threshold);

  /// No description provided for @noExamShort.
  ///
  /// In ar, this message translates to:
  /// **'مفيش امتحان'**
  String get noExamShort;

  /// No description provided for @lessonNoExamYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش امتحان'**
  String get lessonNoExamYet;

  /// No description provided for @dueInDays.
  ///
  /// In ar, this message translates to:
  /// **'باقي {days} يوم'**
  String dueInDays(String days);

  /// No description provided for @dueInDaysLong.
  ///
  /// In ar, this message translates to:
  /// **'باقي {days} يوم على المراجعة'**
  String dueInDaysLong(String days);

  /// No description provided for @overdueByDays.
  ///
  /// In ar, this message translates to:
  /// **'متأخر {days} يوم'**
  String overdueByDays(String days);

  /// No description provided for @masteryCaptionWithExams.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان محسوب من آخر امتحان {last} ومتوسط اللي قبله {rest}'**
  String masteryCaptionWithExams(String last, String rest);

  /// No description provided for @masteryCaptionNoExams.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان بيتحسب من الامتحانات بس — سجّل أول امتحان عشان تبدأ'**
  String get masteryCaptionNoExams;

  /// No description provided for @checklistTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوات المذاكرة'**
  String get checklistTitle;

  /// No description provided for @checklistWatched.
  ///
  /// In ar, this message translates to:
  /// **'شاهدت الدرس'**
  String get checklistWatched;

  /// No description provided for @checklistReadNotes.
  ///
  /// In ar, this message translates to:
  /// **'قريت الملازم'**
  String get checklistReadNotes;

  /// No description provided for @checklistDidHomework.
  ///
  /// In ar, this message translates to:
  /// **'حليت الواجب'**
  String get checklistDidHomework;

  /// No description provided for @checklistDidExam.
  ///
  /// In ar, this message translates to:
  /// **'حليت الامتحان'**
  String get checklistDidExam;

  /// No description provided for @checklistReviewedNotes.
  ///
  /// In ar, this message translates to:
  /// **'راجعت الملازم'**
  String get checklistReviewedNotes;

  /// No description provided for @homeworkTitle.
  ///
  /// In ar, this message translates to:
  /// **'الواجب'**
  String get homeworkTitle;

  /// No description provided for @homeworkAdd.
  ///
  /// In ar, this message translates to:
  /// **'سجل درجة واجب'**
  String get homeworkAdd;

  /// No description provided for @homeworkScore.
  ///
  /// In ar, this message translates to:
  /// **'الدرجة'**
  String get homeworkScore;

  /// No description provided for @homeworkMax.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get homeworkMax;

  /// No description provided for @homeworkNotReady.
  ///
  /// In ar, this message translates to:
  /// **'لسه محتاج تذاكر أكتر قبل ما تدخل الامتحان'**
  String get homeworkNotReady;

  /// No description provided for @homeworkReady.
  ///
  /// In ar, this message translates to:
  /// **'تمام، جاهز تدخل الامتحان'**
  String get homeworkReady;

  /// No description provided for @homeworkNone.
  ///
  /// In ar, this message translates to:
  /// **'مفيش واجبات متسجلة'**
  String get homeworkNone;

  /// No description provided for @homeworkNote.
  ///
  /// In ar, this message translates to:
  /// **'الواجب مش بيدخل في حساب الإتقان — ده مؤشر استعداد بس'**
  String get homeworkNote;

  /// No description provided for @homeworkInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الدرجة لازم تكون من صفر لـ «من»، و«من» أكبر من صفر'**
  String get homeworkInvalid;

  /// No description provided for @examHistory.
  ///
  /// In ar, this message translates to:
  /// **'الامتحانات السابقة'**
  String get examHistory;

  /// No description provided for @examNoHistory.
  ///
  /// In ar, this message translates to:
  /// **'مفيش امتحانات لسه'**
  String get examNoHistory;

  /// No description provided for @examReviewBadge.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get examReviewBadge;

  /// No description provided for @examHistoryHint.
  ///
  /// In ar, this message translates to:
  /// **'دوس على امتحان عشان تشيله لو اتسجل غلط'**
  String get examHistoryHint;

  /// No description provided for @examDelete.
  ///
  /// In ar, this message translates to:
  /// **'شيل الامتحان'**
  String get examDelete;

  /// No description provided for @examDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هيتشال الامتحان من السجل وإتقان الدرس هيتحسب من غيره. مش هينفع ترجع فيها.'**
  String get examDeleteConfirm;

  /// No description provided for @toastExamDeleted.
  ///
  /// In ar, this message translates to:
  /// **'اتشال الامتحان — الإتقان اتحسب من الأول'**
  String get toastExamDeleted;

  /// No description provided for @examStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الامتحان'**
  String get examStart;

  /// No description provided for @examRecordResult.
  ///
  /// In ar, this message translates to:
  /// **'سجل نتيجة امتحان'**
  String get examRecordResult;

  /// No description provided for @examRecordReview.
  ///
  /// In ar, this message translates to:
  /// **'سجل امتحان المراجعة'**
  String get examRecordReview;

  /// No description provided for @examStep1Title.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأسئلة الكلي'**
  String get examStep1Title;

  /// No description provided for @examStep1Hint.
  ///
  /// In ar, this message translates to:
  /// **'الامتحان فيه كام سؤال؟'**
  String get examStep1Hint;

  /// No description provided for @examStep2Title.
  ///
  /// In ar, this message translates to:
  /// **'درجات الأسئلة'**
  String get examStep2Title;

  /// No description provided for @examStep2Hint.
  ///
  /// In ar, this message translates to:
  /// **'اقسم الأسئلة: كام سؤال بكام درجة'**
  String get examStep2Hint;

  /// No description provided for @examStep3Title.
  ///
  /// In ar, this message translates to:
  /// **'إجاباتك الصح'**
  String get examStep3Title;

  /// No description provided for @examStep3Hint.
  ///
  /// In ar, this message translates to:
  /// **'كام سؤال جاوبته صح في كل مجموعة'**
  String get examStep3Hint;

  /// No description provided for @examStep4Title.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get examStep4Title;

  /// No description provided for @examGroupQuestions.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأسئلة'**
  String get examGroupQuestions;

  /// No description provided for @examGroupPoints.
  ///
  /// In ar, this message translates to:
  /// **'درجة السؤال'**
  String get examGroupPoints;

  /// No description provided for @examAddGroup.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة مجموعة'**
  String get examAddGroup;

  /// No description provided for @examRemoveGroup.
  ///
  /// In ar, this message translates to:
  /// **'شيل المجموعة'**
  String get examRemoveGroup;

  /// No description provided for @examGroupLabel.
  ///
  /// In ar, this message translates to:
  /// **'{count} أسئلة × {points} درجة'**
  String examGroupLabel(String count, String points);

  /// No description provided for @examPointsLine.
  ///
  /// In ar, this message translates to:
  /// **'{points} درجة'**
  String examPointsLine(String points);

  /// No description provided for @examMasteryBefore.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان قبل'**
  String get examMasteryBefore;

  /// No description provided for @examMasteryAfter.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان بعد'**
  String get examMasteryAfter;

  /// No description provided for @examSave.
  ///
  /// In ar, this message translates to:
  /// **'احفظ النتيجة'**
  String get examSave;

  /// No description provided for @examSaveReview.
  ///
  /// In ar, this message translates to:
  /// **'احفظ امتحان المراجعة'**
  String get examSaveReview;

  /// No description provided for @examSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نحفظ الامتحان. أرقامك لسه موجودة — جرّب تاني.'**
  String get examSaveFailed;

  /// No description provided for @examDiscardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسيب الامتحان؟'**
  String get examDiscardTitle;

  /// No description provided for @examDiscardBody.
  ///
  /// In ar, this message translates to:
  /// **'اللي كتبته هيروح. مش هينفع ترجع فيها.'**
  String get examDiscardBody;

  /// No description provided for @examDiscardLeave.
  ///
  /// In ar, this message translates to:
  /// **'سيبه'**
  String get examDiscardLeave;

  /// No description provided for @examDiscardStay.
  ///
  /// In ar, this message translates to:
  /// **'كمّل'**
  String get examDiscardStay;

  /// No description provided for @examErrorNeedAtLeastOneQuestion.
  ///
  /// In ar, this message translates to:
  /// **'لازم سؤال واحد على الأقل'**
  String get examErrorNeedAtLeastOneQuestion;

  /// No description provided for @examErrorGroupInvalid.
  ///
  /// In ar, this message translates to:
  /// **'كل مجموعة لازم يكون فيها عدد أسئلة ودرجة أكبر من صفر'**
  String get examErrorGroupInvalid;

  /// No description provided for @examErrorSumMismatch.
  ///
  /// In ar, this message translates to:
  /// **'مجموع الأسئلة ({assigned}) لازم يساوي العدد الكلي ({total})'**
  String examErrorSumMismatch(String assigned, String total);

  /// No description provided for @examErrorCorrectExceeds.
  ///
  /// In ar, this message translates to:
  /// **'عدد الصح مينفعش يزيد عن عدد الأسئلة'**
  String get examErrorCorrectExceeds;

  /// No description provided for @toastExamSaved.
  ///
  /// In ar, this message translates to:
  /// **'اتسجّل الامتحان — عداد المراجعة بدأ من جديد'**
  String get toastExamSaved;

  /// No description provided for @toastHomeworkSaved.
  ///
  /// In ar, this message translates to:
  /// **'اتسجّلت درجة الواجب'**
  String get toastHomeworkSaved;

  /// No description provided for @reviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'محتاج مراجعة'**
  String get reviewTitle;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حاجة محتاجة مراجعة'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'كل دروسك في وقتها. استمر.'**
  String get reviewEmptyBody;

  /// No description provided for @reviewReasonWeak.
  ///
  /// In ar, this message translates to:
  /// **'مستوى ضعيف'**
  String get reviewReasonWeak;

  /// No description provided for @reviewReasonDeclining.
  ///
  /// In ar, this message translates to:
  /// **'مستواك بينزل'**
  String get reviewReasonDeclining;

  /// No description provided for @reviewNotificationTitle.
  ///
  /// In ar, this message translates to:
  /// **'وقت المراجعة'**
  String get reviewNotificationTitle;

  /// No description provided for @reviewNotificationBody.
  ///
  /// In ar, this message translates to:
  /// **'وقت مراجعة درس {lesson} في {chapter}'**
  String reviewNotificationBody(String lesson, String chapter);

  /// No description provided for @analyticsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقدمك'**
  String get analyticsTitle;

  /// No description provided for @analyticsInsights.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get analyticsInsights;

  /// No description provided for @analyticsAllSubjects.
  ///
  /// In ar, this message translates to:
  /// **'كل المواد'**
  String get analyticsAllSubjects;

  /// No description provided for @analyticsAlwaysAllSubjects.
  ///
  /// In ar, this message translates to:
  /// **'الكارت ده بيقارن المواد الأربعة دايماً'**
  String get analyticsAlwaysAllSubjects;

  /// No description provided for @analyticsMasteryBySubject.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان حسب المادة'**
  String get analyticsMasteryBySubject;

  /// No description provided for @analyticsMasteryByChapter.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان حسب الباب'**
  String get analyticsMasteryByChapter;

  /// No description provided for @analyticsWeakestLessons.
  ///
  /// In ar, this message translates to:
  /// **'أضعف الدروس'**
  String get analyticsWeakestLessons;

  /// No description provided for @analyticsReviewDiscipline.
  ///
  /// In ar, this message translates to:
  /// **'الالتزام بالمراجعة'**
  String get analyticsReviewDiscipline;

  /// No description provided for @analyticsNotEnoughData.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش بيانات كفاية'**
  String get analyticsNotEnoughData;

  /// No description provided for @insightStrongestSubject.
  ///
  /// In ar, this message translates to:
  /// **'{subject} أقوى مادة عندك دلوقتي — {value}'**
  String insightStrongestSubject(String subject, String value);

  /// No description provided for @insightChapterWeak.
  ///
  /// In ar, this message translates to:
  /// **'«{chapter}» لسه ضعيف — {value}'**
  String insightChapterWeak(String chapter, String value);

  /// No description provided for @insightLessonNotReviewed.
  ///
  /// In ar, this message translates to:
  /// **'مراجعتش «{lesson}» من {days} يوم'**
  String insightLessonNotReviewed(String lesson, String days);

  /// No description provided for @insightSubjectImproved.
  ///
  /// In ar, this message translates to:
  /// **'{subject} اتحسنت {delta} الشهر ده'**
  String insightSubjectImproved(String subject, String delta);

  /// No description provided for @chapterReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقرير الباب'**
  String get chapterReportTitle;

  /// No description provided for @trendUp.
  ///
  /// In ar, this message translates to:
  /// **'اتحسنت من {from} لـ {to}'**
  String trendUp(String from, String to);

  /// No description provided for @trendDown.
  ///
  /// In ar, this message translates to:
  /// **'نزلت من {from} لـ {to}'**
  String trendDown(String from, String to);

  /// No description provided for @trendFlat.
  ///
  /// In ar, this message translates to:
  /// **'محتاج امتحانات أكتر عشان نقيس التقدم'**
  String get trendFlat;

  /// No description provided for @weakestLessonBadge.
  ///
  /// In ar, this message translates to:
  /// **'أضعف درس'**
  String get weakestLessonBadge;

  /// No description provided for @celebrationTitle.
  ///
  /// In ar, this message translates to:
  /// **'أتقنت الباب!'**
  String get celebrationTitle;

  /// No description provided for @celebrationBody.
  ///
  /// In ar, this message translates to:
  /// **'شغل محترم. كمّل على كده.'**
  String get celebrationBody;

  /// No description provided for @celebrationHint.
  ///
  /// In ar, this message translates to:
  /// **'دوس في أي حتة تكمّل'**
  String get celebrationHint;

  /// No description provided for @authSignInTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authSignInTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب جديد'**
  String get authRegisterTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك مرة واحدة بس — بعد كده التطبيق هيشتغل من غير نت'**
  String get authSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In ar, this message translates to:
  /// **'الباسورد'**
  String get authPassword;

  /// No description provided for @authEmailHint.
  ///
  /// In ar, this message translates to:
  /// **'you@example.com'**
  String get authEmailHint;

  /// No description provided for @authSignIn.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get authSignIn;

  /// No description provided for @authRegister.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get authRegister;

  /// No description provided for @authGoogle.
  ///
  /// In ar, this message translates to:
  /// **'كمّل بحساب Google'**
  String get authGoogle;

  /// No description provided for @authToRegister.
  ///
  /// In ar, this message translates to:
  /// **'لسه مش عامل حساب؟ اعمل واحد'**
  String get authToRegister;

  /// No description provided for @authToSignIn.
  ///
  /// In ar, this message translates to:
  /// **'عندك حساب؟ سجّل دخول'**
  String get authToSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الباسورد؟'**
  String get authForgotPassword;

  /// No description provided for @authResetSent.
  ///
  /// In ar, this message translates to:
  /// **'بعتنالك رابط على الإيميل تغيّر بيه الباسورد'**
  String get authResetSent;

  /// No description provided for @authErrorEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل مش مظبوط'**
  String get authErrorEmailInvalid;

  /// No description provided for @authErrorPasswordShort.
  ///
  /// In ar, this message translates to:
  /// **'الباسورد لازم 6 حروف على الأقل'**
  String get authErrorPasswordShort;

  /// No description provided for @authErrorWrongCredentials.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل أو الباسورد غلط'**
  String get authErrorWrongCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل ده مستخدم قبل كده'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorNoNetwork.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت. تسجيل الدخول أول مرة بس محتاج نت — بعد كده التطبيق بيشتغل أوفلاين.'**
  String get authErrorNoNetwork;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كتير. استنى شوية وجرّب تاني'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نكمّل. جرّب تاني'**
  String get authErrorGeneric;

  /// No description provided for @authSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هتحتاج نت عشان تسجّل دخول تاني. بياناتك محفوظة على الجهاز ومش هتتمسح.'**
  String get authSignOutConfirm;

  /// No description provided for @authAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get authAccount;

  /// No description provided for @lockUnlock.
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get lockUnlock;

  /// No description provided for @lockReason.
  ///
  /// In ar, this message translates to:
  /// **'افتح Ather'**
  String get lockReason;

  /// No description provided for @lockRefused.
  ///
  /// In ar, this message translates to:
  /// **'مفتحش — جرّب تاني'**
  String get lockRefused;

  /// No description provided for @lockLockedOut.
  ///
  /// In ar, this message translates to:
  /// **'حاولت كتير. استنى شوية وجرّب تاني، أو افتح بكود القفل بتاع التليفون.'**
  String get lockLockedOut;

  /// No description provided for @lockSetting.
  ///
  /// In ar, this message translates to:
  /// **'قفل بالبصمة'**
  String get lockSetting;

  /// No description provided for @lockSettingBody.
  ///
  /// In ar, this message translates to:
  /// **'اطلب بصمة كل ما تفتح التطبيق'**
  String get lockSettingBody;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsTheme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ar, this message translates to:
  /// **'النظام'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeBody.
  ///
  /// In ar, this message translates to:
  /// **'اختار مظهر التطبيق، أو سيبه يمشي مع إعدادات الموبايل'**
  String get settingsThemeBody;

  /// No description provided for @settingsNotifications.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات المراجعة'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsBody.
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني لما يجي وقت مراجعة درس'**
  String get settingsNotificationsBody;

  /// No description provided for @settingsNotificationsBlocked.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات مقفولة من إعدادات التليفون. افتحها من هناك عشان التذكير يوصلك.'**
  String get settingsNotificationsBlocked;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get settingsAbout;

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية'**
  String get backupTitle;

  /// No description provided for @backupBody.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك بتتحفظ على حسابك، فلو غيّرت التليفون تلاقيها زي ما هي.'**
  String get backupBody;

  /// No description provided for @backupNever.
  ///
  /// In ar, this message translates to:
  /// **'لسه متحفظتش'**
  String get backupNever;

  /// No description provided for @backupSavedAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر حفظ: {date}'**
  String backupSavedAt(String date);

  /// No description provided for @backupSaving.
  ///
  /// In ar, this message translates to:
  /// **'بيحفظ…'**
  String get backupSaving;

  /// No description provided for @backupSaveNow.
  ///
  /// In ar, this message translates to:
  /// **'احفظ دلوقتي'**
  String get backupSaveNow;

  /// No description provided for @backupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجع النسخة السحابية'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'اللي على التليفون ده هيتمسح ويتحط مكانه اللي في النسخة السحابية.'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreDone.
  ///
  /// In ar, this message translates to:
  /// **'رجّعنا بياناتك'**
  String get backupRestoreDone;

  /// No description provided for @backupRestoreEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نسخة سحابية لسه'**
  String get backupRestoreEmpty;

  /// No description provided for @backupErrorOffline.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نت — هيتحفظ أول ما النت يرجع'**
  String get backupErrorOffline;

  /// No description provided for @backupErrorPermission.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحيات مظبوطتش على السيرفر'**
  String get backupErrorPermission;

  /// No description provided for @backupErrorTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك أكبر من إن نحفظها مرة واحدة'**
  String get backupErrorTooLarge;

  /// No description provided for @backupErrorUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية مش مقروءة'**
  String get backupErrorUnreadable;

  /// No description provided for @backupErrorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ مظبطش'**
  String get backupErrorUnknown;

  /// No description provided for @tasksTitle.
  ///
  /// In ar, this message translates to:
  /// **'مهام النهارده'**
  String get tasksTitle;

  /// No description provided for @tasksDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} خلصتهم'**
  String tasksDoneOf(String done, String total);

  /// No description provided for @addTask.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة مهمة'**
  String get addTask;

  /// No description provided for @addTaskTitle.
  ///
  /// In ar, this message translates to:
  /// **'مهمة جديدة'**
  String get addTaskTitle;

  /// No description provided for @taskNameHint.
  ///
  /// In ar, this message translates to:
  /// **'هتعمل إيه النهارده؟'**
  String get taskNameHint;

  /// No description provided for @renameTask.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المهمة'**
  String get renameTask;

  /// No description provided for @deleteTask.
  ///
  /// In ar, this message translates to:
  /// **'حذف المهمة'**
  String get deleteTask;

  /// No description provided for @deleteTaskConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هتتشال من مهام اليوم ده خالص.'**
  String get deleteTaskConfirm;

  /// No description provided for @noTasksYet.
  ///
  /// In ar, this message translates to:
  /// **'مفيش مهام لليوم ده'**
  String get noTasksYet;

  /// No description provided for @tasksEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اللي ناوي تعمله، وشيله لما تخلصه.'**
  String get tasksEmptyBody;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In ar, this message translates to:
  /// **'في حاجة مامشتش صح. جرّب تاني.'**
  String get commonSomethingWentWrong;

  /// No description provided for @nameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الأول'**
  String get nameRequired;

  /// No description provided for @authShowPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة السر'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة السر'**
  String get authHidePassword;

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get commonDelete;

  /// No description provided for @commonNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get commonBack;

  /// No description provided for @commonEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
