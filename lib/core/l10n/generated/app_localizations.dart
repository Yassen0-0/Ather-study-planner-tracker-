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
  /// **'أنت لا تُنهي الدروس، بل تُتقنها'**
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

  /// Short weekday name in the day picker, beside the date: 'سبت 14'. These were single letters (س ح ن ر خ ج) while the week strip showed all seven days at once and had ~41px per cell to do it in. The picker shows three to five days and gives each one a pill, so there is room for a name a student does not have to decode.
  ///
  /// In ar, this message translates to:
  /// **'سبت'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In ar, this message translates to:
  /// **'أحد'**
  String get weekdaySunday;

  /// No description provided for @weekdayMonday.
  ///
  /// In ar, this message translates to:
  /// **'اثنين'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثاء'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In ar, this message translates to:
  /// **'أربعاء'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In ar, this message translates to:
  /// **'خميس'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In ar, this message translates to:
  /// **'جمعة'**
  String get weekdayFriday;

  /// What today's cell says in the day picker, in place of its weekday and date. Today always carries it, selected or not: it is the one fixed landmark in a row whose other cells change every time the student moves a day.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get todayLabel;

  /// No description provided for @dashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dashboardTitle;

  /// No description provided for @overallMastery.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان العام'**
  String get overallMastery;

  /// Was «دروس متبقّية» ('Lessons left'). Owner decision 2026-08-23: the backlog stat reads «دروس متراكمة» -- 'lessons owed', not a neutral countdown -- and borrows the wrong/red alarm on purpose so the student clears the debt early.
  ///
  /// In ar, this message translates to:
  /// **'دروس متراكمة'**
  String get statLessonsRemaining;

  /// No description provided for @statNeedsReview.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج مراجعة'**
  String get statNeedsReview;

  /// The third stat counts lessons that are «متفوق»: examined, not overdue, and at or above 90. Ather names three states and never one word for all of them: «أثبت» (examined, fresh, ≥70), «متفوق» (examined, fresh, ≥90), and «باب مُغلق» (a dated closure event whose evidence still stands).
  ///
  /// In ar, this message translates to:
  /// **'متفوق'**
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

  /// Halved deliberately. The walkthrough half -- open a subject, add a chapter, then a lesson -- told a student to do the only thing the empty screen allows. What survives is the product's one claim, which a student genuinely cannot guess from the interface.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان يُحسب من امتحاناتك وحدها، لا من إنهاء الدرس.'**
  String get firstRunBody;

  /// No description provided for @firstRunAction.
  ///
  /// In ar, this message translates to:
  /// **'افتح أول مادة'**
  String get firstRunAction;

  /// No description provided for @sectionNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get sectionNext;

  /// No description provided for @actionExam.
  ///
  /// In ar, this message translates to:
  /// **'امتحن'**
  String get actionExam;

  /// No description provided for @notStartedYet.
  ///
  /// In ar, this message translates to:
  /// **'لم تبدأ بعد'**
  String get notStartedYet;

  /// No description provided for @subjectHasOverdueLesson.
  ///
  /// In ar, this message translates to:
  /// **'تأخّرت مراجعة درس'**
  String get subjectHasOverdueLesson;

  /// No description provided for @lessonCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{درس واحد} =2{درسان} few{{count} دروس} many{{count} درساً} other{{count} درس}}'**
  String lessonCount(int count);

  /// No description provided for @chapterCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{باب واحد} =2{بابان} few{{count} أبواب} many{{count} باباً} other{{count} باب}}'**
  String chapterCount(int count);

  /// No description provided for @chaptersMasteredOf.
  ///
  /// In ar, this message translates to:
  /// **'أتقنت {mastered} من {total} باب'**
  String chaptersMasteredOf(String mastered, String total);

  /// No description provided for @chaptersOfShort.
  ///
  /// In ar, this message translates to:
  /// **'{mastered} من {total} باب'**
  String chaptersOfShort(String mastered, String total);

  /// No description provided for @lessonsExaminedOf.
  ///
  /// In ar, this message translates to:
  /// **'{examined} من {total} درس بامتحان'**
  String lessonsExaminedOf(String examined, String total);

  /// No description provided for @lessonsOnTimeOf.
  ///
  /// In ar, this message translates to:
  /// **'{onTime} من {total} درس في موعده'**
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
  /// **'لا توجد أبواب بعد'**
  String get noChaptersYet;

  /// No description provided for @noLessonsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دروس بعد'**
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
  /// **'مثال: الباب الأول — الخلية'**
  String get chapterNameHint;

  /// No description provided for @lessonNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تركيب الغشاء البلازمي'**
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
  /// **'سيُحذف الباب وكل الدروس والامتحانات التي بداخله. لا يمكن التراجع.'**
  String get deleteChapterConfirm;

  /// No description provided for @deleteLessonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف الدرس وكل امتحاناته. لا يمكن التراجع.'**
  String get deleteLessonConfirm;

  /// No description provided for @averageExamScore.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الامتحانات'**
  String get averageExamScore;

  /// No description provided for @chapterNeedsReview.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج مراجعة'**
  String get chapterNeedsReview;

  /// Shown in green only while the closure's evidence still stands (every lesson examined, chapter mean at or above 70 today).
  ///
  /// In ar, this message translates to:
  /// **'أتقنته في {date}'**
  String chapterMasteredAt(String date);

  /// Neutral line shown when the chapter carries a closure date whose evidence has since broken — the date stays, the green tick does not.
  ///
  /// In ar, this message translates to:
  /// **'أُغلِق {date}'**
  String chapterClosureDated(String date);

  /// No description provided for @masterChapter.
  ///
  /// In ar, this message translates to:
  /// **'أتقنت الباب'**
  String get masterChapter;

  /// No description provided for @viewChapterReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير الباب'**
  String get viewChapterReport;

  /// No description provided for @notReadyGate.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل بعد — اعرف السبب'**
  String get notReadyGate;

  /// No description provided for @notReadyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل بعد'**
  String get notReadyTitle;

  /// No description provided for @notReadyBody.
  ///
  /// In ar, this message translates to:
  /// **'لإتقان الباب يجب أن يكون لكل درس امتحان، وأن يبلغ الإتقان {threshold} على الأقل.'**
  String notReadyBody(String threshold);

  /// No description provided for @noExamShort.
  ///
  /// In ar, this message translates to:
  /// **'لا امتحان'**
  String get noExamShort;

  /// No description provided for @lessonNoExamYet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد امتحان بعد'**
  String get lessonNoExamYet;

  /// No description provided for @dueInDays.
  ///
  /// In ar, this message translates to:
  /// **'بقي {days} يوم'**
  String dueInDays(String days);

  /// No description provided for @dueInDaysLong.
  ///
  /// In ar, this message translates to:
  /// **'بقي {days} يوم على المراجعة'**
  String dueInDaysLong(String days);

  /// No description provided for @overdueByDays.
  ///
  /// In ar, this message translates to:
  /// **'متأخّر {days} يوم'**
  String overdueByDays(String days);

  /// No description provided for @masteryCaptionWithExams.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان محسوب من آخر امتحان {last} ومتوسط ما قبله {rest}'**
  String masteryCaptionWithExams(String last, String rest);

  /// No description provided for @masteryCaptionNoExams.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان يُحسب من الامتحانات وحدها — سجّل أول امتحان'**
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
  /// **'قرأت الملازم'**
  String get checklistReadNotes;

  /// No description provided for @checklistDidHomework.
  ///
  /// In ar, this message translates to:
  /// **'حللت الواجب'**
  String get checklistDidHomework;

  /// No description provided for @checklistDidExam.
  ///
  /// In ar, this message translates to:
  /// **'حللت الامتحان'**
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
  /// **'سجّل درجة واجب'**
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
  /// **'تحتاج مذاكرة أكثر قبل دخول الامتحان'**
  String get homeworkNotReady;

  /// No description provided for @homeworkReady.
  ///
  /// In ar, this message translates to:
  /// **'جاهز لدخول الامتحان'**
  String get homeworkReady;

  /// No description provided for @homeworkNone.
  ///
  /// In ar, this message translates to:
  /// **'لا واجبات مسجّلة'**
  String get homeworkNone;

  /// No description provided for @homeworkNote.
  ///
  /// In ar, this message translates to:
  /// **'الواجب لا يدخل في حساب الإتقان — هو مؤشر استعداد فقط'**
  String get homeworkNote;

  /// No description provided for @homeworkInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الدرجة بين صفر و«من»، و«من» أكبر من صفر'**
  String get homeworkInvalid;

  /// No description provided for @examHistory.
  ///
  /// In ar, this message translates to:
  /// **'الامتحانات السابقة'**
  String get examHistory;

  /// No description provided for @examNoHistory.
  ///
  /// In ar, this message translates to:
  /// **'لا امتحانات بعد'**
  String get examNoHistory;

  /// No description provided for @examReviewBadge.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get examReviewBadge;

  /// No description provided for @examDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف الامتحان'**
  String get examDelete;

  /// No description provided for @examDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف الامتحان من السجل ويُعاد حساب إتقان الدرس بدونه. لا يمكن التراجع.'**
  String get examDeleteConfirm;

  /// No description provided for @toastExamDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الامتحان — أُعيد حساب الإتقان'**
  String get toastExamDeleted;

  /// No description provided for @examStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الامتحان'**
  String get examStart;

  /// No description provided for @examRecordResult.
  ///
  /// In ar, this message translates to:
  /// **'سجّل نتيجة امتحان'**
  String get examRecordResult;

  /// No description provided for @examRecordReview.
  ///
  /// In ar, this message translates to:
  /// **'سجّل امتحان المراجعة'**
  String get examRecordReview;

  /// No description provided for @examStep1Title.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأسئلة الكلي'**
  String get examStep1Title;

  /// No description provided for @examStep1Hint.
  ///
  /// In ar, this message translates to:
  /// **'كم سؤالاً في الامتحان؟'**
  String get examStep1Hint;

  /// No description provided for @examStep2Title.
  ///
  /// In ar, this message translates to:
  /// **'درجات الأسئلة'**
  String get examStep2Title;

  /// No description provided for @examStep2Hint.
  ///
  /// In ar, this message translates to:
  /// **'وزّع الأسئلة: كم سؤالاً بكم درجة'**
  String get examStep2Hint;

  /// No description provided for @examStep3Title.
  ///
  /// In ar, this message translates to:
  /// **'إجاباتك الصحيحة'**
  String get examStep3Title;

  /// No description provided for @examStep3Hint.
  ///
  /// In ar, this message translates to:
  /// **'كم سؤالاً أجبته صحيحاً في كل مجموعة'**
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
  /// **'حذف المجموعة'**
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
  /// **'تعذّر حفظ الامتحان. أرقامك لم تَضِع — حاول مرة أخرى.'**
  String get examSaveFailed;

  /// No description provided for @examDiscardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تترك الامتحان؟'**
  String get examDiscardTitle;

  /// No description provided for @examDiscardBody.
  ///
  /// In ar, this message translates to:
  /// **'ما كتبته سيضيع. لا يمكن التراجع.'**
  String get examDiscardBody;

  /// No description provided for @examDiscardLeave.
  ///
  /// In ar, this message translates to:
  /// **'اترك'**
  String get examDiscardLeave;

  /// No description provided for @examDiscardStay.
  ///
  /// In ar, this message translates to:
  /// **'أكمل'**
  String get examDiscardStay;

  /// No description provided for @examErrorNeedAtLeastOneQuestion.
  ///
  /// In ar, this message translates to:
  /// **'سؤال واحد على الأقل'**
  String get examErrorNeedAtLeastOneQuestion;

  /// No description provided for @examErrorGroupInvalid.
  ///
  /// In ar, this message translates to:
  /// **'كل مجموعة تحتاج عدد أسئلة ودرجة أكبر من صفر'**
  String get examErrorGroupInvalid;

  /// No description provided for @examErrorSumMismatch.
  ///
  /// In ar, this message translates to:
  /// **'مجموع الأسئلة ({assigned}) يجب أن يساوي العدد الكلي ({total})'**
  String examErrorSumMismatch(String assigned, String total);

  /// No description provided for @examErrorCorrectExceeds.
  ///
  /// In ar, this message translates to:
  /// **'عدد الإجابات الصحيحة لا يتجاوز عدد الأسئلة'**
  String get examErrorCorrectExceeds;

  /// No description provided for @toastExamSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ الامتحان — بدأ عدّاد المراجعة من جديد'**
  String get toastExamSaved;

  /// No description provided for @toastHomeworkSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت درجة الواجب'**
  String get toastHomeworkSaved;

  /// No description provided for @reviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج مراجعة'**
  String get reviewTitle;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء يحتاج مراجعة'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'كل دروسك في موعدها.'**
  String get reviewEmptyBody;

  /// No description provided for @reviewReasonWeak.
  ///
  /// In ar, this message translates to:
  /// **'مستوى ضعيف'**
  String get reviewReasonWeak;

  /// No description provided for @reviewReasonDeclining.
  ///
  /// In ar, this message translates to:
  /// **'مستواك ينخفض'**
  String get reviewReasonDeclining;

  /// No description provided for @reviewNotificationTitle.
  ///
  /// In ar, this message translates to:
  /// **'وقت المراجعة'**
  String get reviewNotificationTitle;

  /// No description provided for @reviewNotificationBody.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت مراجعة درس {lesson} في {chapter}'**
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
  /// **'لا توجد بيانات كافية بعد'**
  String get analyticsNotEnoughData;

  /// No description provided for @insightStrongestSubject.
  ///
  /// In ar, this message translates to:
  /// **'{subject} أقوى موادك الآن — {value}'**
  String insightStrongestSubject(String subject, String value);

  /// No description provided for @insightChapterWeak.
  ///
  /// In ar, this message translates to:
  /// **'«{chapter}» ما زال ضعيفاً — {value}'**
  String insightChapterWeak(String chapter, String value);

  /// No description provided for @insightLessonNotReviewed.
  ///
  /// In ar, this message translates to:
  /// **'لم تراجع «{lesson}» منذ {days} يوم'**
  String insightLessonNotReviewed(String lesson, String days);

  /// No description provided for @insightSubjectImproved.
  ///
  /// In ar, this message translates to:
  /// **'{subject} تحسّنت {delta} هذا الشهر'**
  String insightSubjectImproved(String subject, String delta);

  /// No description provided for @chapterReportTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقرير الباب'**
  String get chapterReportTitle;

  /// No description provided for @trendUp.
  ///
  /// In ar, this message translates to:
  /// **'ارتفعت من {from} إلى {to}'**
  String trendUp(String from, String to);

  /// No description provided for @trendDown.
  ///
  /// In ar, this message translates to:
  /// **'انخفضت من {from} إلى {to}'**
  String trendDown(String from, String to);

  /// No description provided for @trendFlat.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج امتحانات أكثر لقياس التقدّم'**
  String get trendFlat;

  /// No description provided for @trendSteady.
  ///
  /// In ar, this message translates to:
  /// **'ثابتة — النصفان على المستوى نفسه'**
  String get trendSteady;

  /// No description provided for @chapterReportMasteryLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان'**
  String get chapterReportMasteryLabel;

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
  /// **'عمل ممتاز. واصِل.'**
  String get celebrationBody;

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
  /// **'تسجيل دخول واحد، ثم يعمل التطبيق دون اتصال'**
  String get authSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر'**
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
  /// **'المتابعة بحساب Google'**
  String get authGoogle;

  /// No description provided for @authToRegister.
  ///
  /// In ar, this message translates to:
  /// **'لا حساب لديك؟ أنشئ واحداً'**
  String get authToRegister;

  /// No description provided for @authToSignIn.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟ سجّل الدخول'**
  String get authToSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة السر؟'**
  String get authForgotPassword;

  /// No description provided for @authResetSent.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رابطاً إلى بريدك لتغيير كلمة السر'**
  String get authResetSent;

  /// No description provided for @authErrorEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صحيح'**
  String get authErrorEmailInvalid;

  /// No description provided for @authErrorPasswordShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر ٨ أحرف على الأقل'**
  String get authErrorPasswordShort;

  /// No description provided for @authErrorWrongCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة السر غير صحيحة'**
  String get authErrorWrongCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مستخدم بالفعل'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorNoNetwork.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال. تسجيل الدخول أول مرة فقط يحتاج اتصالاً — بعدها يعمل التطبيق دون إنترنت.'**
  String get authErrorNoNetwork;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام العملية. حاول مرة أخرى'**
  String get authErrorGeneric;

  /// No description provided for @authSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج اتصالاً لتسجيل الدخول مرة أخرى. بياناتك محفوظة على الجهاز ولن تُحذف.'**
  String get authSignOutConfirm;

  /// No description provided for @authAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get authAccount;

  /// No description provided for @authDeleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get authDeleteAccount;

  /// No description provided for @authDeleteAccountConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف حسابك ونسختك السحابية وكل شيء على الجهاز نهائياً. لا يمكن التراجع.'**
  String get authDeleteAccountConfirm;

  /// No description provided for @authDeleteAccountOfflineWarning.
  ///
  /// In ar, this message translates to:
  /// **'ما لم يُرفع إلى السحابة بعد سيضيع مع الحذف.'**
  String get authDeleteAccountOfflineWarning;

  /// No description provided for @authDeleteAccountReauthTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكّد أنه حسابك'**
  String get authDeleteAccountReauthTitle;

  /// No description provided for @authDeleteAccountReauthBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب كلمة سر حسابك لإتمام الحذف.'**
  String get authDeleteAccountReauthBody;

  /// No description provided for @authDeleteAccountReauthAction.
  ///
  /// In ar, this message translates to:
  /// **'احذف الحساب'**
  String get authDeleteAccountReauthAction;

  /// No description provided for @authDeleteAccountFailed.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحذف الحساب. حاول مرة أخرى.'**
  String get authDeleteAccountFailed;

  /// No description provided for @accountSwitchWipeTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب مختلف'**
  String get accountSwitchWipeTitle;

  /// No description provided for @accountSwitchWipeMessage.
  ///
  /// In ar, this message translates to:
  /// **'البيانات المحفوظة على هذا الجهاز تخص حسابًا آخر. للمتابعة بهذا الحساب ستُمسح كل بيانات الجهاز: المواد والأبواب والامتحانات والمهام. لا يمكن التراجع.'**
  String get accountSwitchWipeMessage;

  /// No description provided for @accountSwitchWipeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'امسح بيانات الجهاز'**
  String get accountSwitchWipeConfirm;

  /// No description provided for @settingsPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get settingsPrivacy;

  /// No description provided for @privacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'خصوصيتك'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In ar, this message translates to:
  /// **'هذا التطبيق يجمع أقل قدر ممكن من البيانات. ما يلي وصف لما يحدث فعلاً، لا وعود عامة.'**
  String get privacyIntro;

  /// No description provided for @privacyLocalTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات دراستك'**
  String get privacyLocalTitle;

  /// No description provided for @privacyLocalBody.
  ///
  /// In ar, this message translates to:
  /// **'موادك وأبوابك ودروسك وامتحاناتك ومهامك محفوظة على هاتفك، في قاعدة بيانات محلية. الإتقان يُحسب على جهازك. واسمك وسنتك الدراسية في «ملفك» محفوظان على هذا الجهاز وحده ولا يُرفعان إلى أي خادم.'**
  String get privacyLocalBody;

  /// No description provided for @privacyAccountTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الحساب'**
  String get privacyAccountTitle;

  /// No description provided for @privacyAccountBody.
  ///
  /// In ar, this message translates to:
  /// **'للنسخة السحابية نطلب بريداً إلكترونياً وكلمة سر (أو حساب Google)، وتُحفظ لدى Firebase Auth من Google. بريدك هو كل ما نعرفه عنك على الخادم — لا اسم ولا عمر ولا أي بيانات أخرى.'**
  String get privacyAccountBody;

  /// No description provided for @privacyCloudTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية'**
  String get privacyCloudTitle;

  /// No description provided for @privacyCloudBody.
  ///
  /// In ar, this message translates to:
  /// **'إن أنشأت حساباً، تُرفع نسخة من بيانات دراستك مشفّرة أثناء النقل وتُحفظ على خوادم Google (Firebase Firestore) باسم حسابك. لا يصل إليها أحد سواك — ولا نحن.'**
  String get privacyCloudBody;

  /// No description provided for @privacyDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف بياناتك'**
  String get privacyDeleteTitle;

  /// No description provided for @privacyDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'في أسفل صفحة الإعدادات زر «حذف الحساب». عند الضغط عليه: تُمحى بياناتك على الهاتف، وتُمحى النسخة السحابية، ويُزال الحساب نفسه من Firebase. نهائياً.'**
  String get privacyDeleteBody;

  /// No description provided for @privacyNoCollectTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما لا نفعله'**
  String get privacyNoCollectTitle;

  /// No description provided for @privacyNoCollectBody.
  ///
  /// In ar, this message translates to:
  /// **'لا إعلانات. لا تتبّع. لا بيع للبيانات. لا تحليلات ولا تقارير أخطاء لجهة خارجية.'**
  String get privacyNoCollectBody;

  /// No description provided for @lockUnlock.
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get lockUnlock;

  /// No description provided for @lockReason.
  ///
  /// In ar, this message translates to:
  /// **'افتح أثر'**
  String get lockReason;

  /// No description provided for @lockRefused.
  ///
  /// In ar, this message translates to:
  /// **'لم يُفتح. حاول مرة أخرى.'**
  String get lockRefused;

  /// No description provided for @lockLockedOut.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى، أو استخدم رمز قفل هاتفك.'**
  String get lockLockedOut;

  /// No description provided for @lockSetting.
  ///
  /// In ar, this message translates to:
  /// **'قفل بالبصمة'**
  String get lockSetting;
  String get lockMethodsTitle;
  String get lockMethodBiometric;
  String get lockMethodPassword;
  String get lockMethodBoth;
  String get setPasswordTitle;
  String get newPasswordLabel;
  String get confirmNewPasswordLabel;
  String get currentPasswordLabel;
  String get passwordMismatch;
  String get passwordTooShort;
  String get wrongPassword;
  String get unlockWithPassword;

  /// No description provided for @hapticsSetting.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز'**
  String get hapticsSetting;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملفك'**
  String get profileTitle;

  /// No description provided for @profileName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get profileName;

  /// No description provided for @profileNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك'**
  String get profileNameHint;

  /// No description provided for @profileNameUnset.
  ///
  /// In ar, this message translates to:
  /// **'لم تكتبه بعد'**
  String get profileNameUnset;

  /// No description provided for @profileYear.
  ///
  /// In ar, this message translates to:
  /// **'السنة الدراسية'**
  String get profileYear;

  /// No description provided for @profileYearUnset.
  ///
  /// In ar, this message translates to:
  /// **'لم تحددها'**
  String get profileYearUnset;

  /// No description provided for @profileYearFirst.
  ///
  /// In ar, this message translates to:
  /// **'الأول الثانوي'**
  String get profileYearFirst;

  /// No description provided for @profileYearSecond.
  ///
  /// In ar, this message translates to:
  /// **'الثاني الثانوي'**
  String get profileYearSecond;

  /// No description provided for @profileYearThird.
  ///
  /// In ar, this message translates to:
  /// **'الثالث الثانوي'**
  String get profileYearThird;

  /// No description provided for @profileLocalNote.
  ///
  /// In ar, this message translates to:
  /// **'هذه البيانات محفوظة على هذا الجهاز وحده، ولا تُرفع إلى أي خادم.'**
  String get profileLocalNote;

  /// No description provided for @profileGreeting.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً، {name}'**
  String profileGreeting(String name);

  /// No description provided for @subjectsArchived.
  ///
  /// In ar, this message translates to:
  /// **'مواد مؤرشفة'**
  String get subjectsArchived;

  /// No description provided for @subjectsArchivedNote.
  ///
  /// In ar, this message translates to:
  /// **'المادة المؤرشفة لا تظهر ولا تدخل في حساب الإتقان ولا تُرسل تنبيهاتها، وأبوابها وامتحاناتها محفوظة كما هي.'**
  String get subjectsArchivedNote;

  /// No description provided for @subjectArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة المادة'**
  String get subjectArchive;

  /// No description provided for @subjectUnarchive.
  ///
  /// In ar, this message translates to:
  /// **'إخراج من الأرشيف'**
  String get subjectUnarchive;

  /// No description provided for @binTitle.
  ///
  /// In ar, this message translates to:
  /// **'سلة المحذوفات'**
  String get binTitle;

  /// No description provided for @binEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get binEmpty;

  /// No description provided for @binRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع'**
  String get binRestore;

  /// No description provided for @binPurge.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get binPurge;

  /// No description provided for @binEmptyAll.
  ///
  /// In ar, this message translates to:
  /// **'إفراغ السلة'**
  String get binEmptyAll;

  /// No description provided for @binDeletedAt.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت في {date}'**
  String binDeletedAt(String date);

  /// No description provided for @binNote.
  ///
  /// In ar, this message translates to:
  /// **'المواد هنا محفوظة بالكامل بأبوابها وامتحاناتها، ولا تُحذف من نفسها أبداً. الحذف النهائي وحده هو الذي يمحوها.'**
  String get binNote;

  /// No description provided for @binPurgeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُمحى «{subject}» ومعه {chapters} و{exams}. لا يمكن التراجع.'**
  String binPurgeConfirm(String subject, String chapters, String exams);

  /// No description provided for @binEmptyAllConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُمحى كل ما في السلة ومعه أبوابه وامتحاناته. لا يمكن التراجع.'**
  String get binEmptyAllConfirm;

  /// No description provided for @examCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{امتحان واحد} =2{امتحانان} few{{count} امتحانات} many{{count} امتحاناً} other{{count} امتحان}}'**
  String examCountLabel(int count);

  /// No description provided for @subjectsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المواد'**
  String get subjectsTitle;

  /// No description provided for @subjectCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مادة واحدة} =2{مادتان} few{{count} مواد} many{{count} مادة} other{{count} مادة}}'**
  String subjectCountLabel(int count);

  /// No description provided for @subjectAdd.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة مادة'**
  String get subjectAdd;

  /// No description provided for @subjectNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: رياضيات'**
  String get subjectNameHint;

  /// No description provided for @subjectRename.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاسم'**
  String get subjectRename;

  /// No description provided for @subjectDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف المادة'**
  String get subjectDelete;

  /// No description provided for @settingsPreferences.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get settingsPreferences;

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

  /// No description provided for @settingsNotifications.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات المراجعة'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsBlocked.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات مغلقة من إعدادات الهاتف. افتحها من هناك ليصلك التذكير.'**
  String get settingsNotificationsBlocked;

  /// No description provided for @settingsAboutSection.
  ///
  /// In ar, this message translates to:
  /// **'عن أثر'**
  String get settingsAboutSection;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get settingsAbout;

  /// No description provided for @settingsVersionFormat.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String settingsVersionFormat(String version);

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية'**
  String get backupTitle;

  /// No description provided for @backupNever.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفظ بعد'**
  String get backupNever;

  /// No description provided for @backupSavedAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر حفظ: {date}'**
  String backupSavedAt(String date);

  /// No description provided for @backupSaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get backupSaving;

  /// No description provided for @backupSaveNow.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الآن'**
  String get backupSaveNow;

  /// No description provided for @backupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع النسخة السحابية'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُمحى ما على هذا الهاتف ويحل محله ما في النسخة السحابية.'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreDone.
  ///
  /// In ar, this message translates to:
  /// **'استُرجعت بياناتك'**
  String get backupRestoreDone;

  /// No description provided for @backupRestoreEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخة سحابية بعد'**
  String get backupRestoreEmpty;

  /// No description provided for @backupErrorOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — سيُحفظ فور عودة الشبكة'**
  String get backupErrorOffline;

  /// No description provided for @backupErrorPermission.
  ///
  /// In ar, this message translates to:
  /// **'صلاحيات الخادم غير مضبوطة'**
  String get backupErrorPermission;

  /// No description provided for @backupErrorTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك أكبر من أن تُحفظ دفعة واحدة'**
  String get backupErrorTooLarge;

  /// No description provided for @backupErrorUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية غير مقروءة'**
  String get backupErrorUnreadable;

  /// No description provided for @backupErrorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'لم ينجح الحفظ'**
  String get backupErrorUnknown;

  /// The tasks screen's title while today is the selected day. The day picker sitting under it says 'اليوم' for today's cell, so the title names what the list is rather than repeating the day.
  ///
  /// In ar, this message translates to:
  /// **'مهام اليوم'**
  String get tasksTitle;

  /// No description provided for @tasksDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت {done} من {total}'**
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
  /// **'ماذا ستفعل اليوم؟'**
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
  /// **'ستُحذف من مهام هذا اليوم نهائياً.'**
  String get deleteTaskConfirm;

  /// No description provided for @noTasksYet.
  ///
  /// In ar, this message translates to:
  /// **'لا مهام لهذا اليوم'**
  String get noTasksYet;

  /// No description provided for @tasksQueueClearedTitle.
  ///
  /// In ar, this message translates to:
  /// **'خلص الطابور'**
  String get tasksQueueClearedTitle;

  /// No description provided for @tasksQueueClearedBody.
  ///
  /// In ar, this message translates to:
  /// **'ما بقي شيء مخطط لهذا اليوم.'**
  String get tasksQueueClearedBody;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام العملية. حاول مرة أخرى.'**
  String get commonSomethingWentWrong;

  /// No description provided for @nameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسماً أولاً'**
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

  /// === Batch A1: data export, chapter report PDF, share card. Appended block, append-only, do not reorder. ===
  ///
  /// In ar, this message translates to:
  /// **'تصدير بياناتك'**
  String get exportTitle;

  /// No description provided for @exportBody.
  ///
  /// In ar, this message translates to:
  /// **'احصل على نسخة من كل ما سجّلته: المواد والأبواب والدروس والامتحانات ودرجات الإتقان، في ملف JSON واحد تقدر تفتحه وتقرأه بنفسك.'**
  String get exportBody;

  /// No description provided for @exportAction.
  ///
  /// In ar, this message translates to:
  /// **'صدّر وشارك الملف'**
  String get exportAction;

  /// No description provided for @exportWhereNote.
  ///
  /// In ar, this message translates to:
  /// **'الملف يتفتح في نافذة المشاركة، تختار منها تحفظه فين — درايف أو واتساب أو الملفات. أثر لا يحتفظ بنسخة.'**
  String get exportWhereNote;

  /// No description provided for @exportErrorFile.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز الملف. راجع المساحة الفاضية على الجهاز.'**
  String get exportErrorFile;

  /// No description provided for @exportErrorShare.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح نافذة المشاركة'**
  String get exportErrorShare;

  /// No description provided for @chapterReportExport.
  ///
  /// In ar, this message translates to:
  /// **'صدّر التقرير PDF'**
  String get chapterReportExport;

  /// No description provided for @chapterReportExportDone.
  ///
  /// In ar, this message translates to:
  /// **'اتجهّز التقرير'**
  String get chapterReportExportDone;

  /// No description provided for @chapterReportExportError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز ملف PDF'**
  String get chapterReportExportError;

  /// No description provided for @shareCardAction.
  ///
  /// In ar, this message translates to:
  /// **'شارك تقدّمك'**
  String get shareCardAction;

  /// No description provided for @shareCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'إتقاني في أثر'**
  String get shareCardTitle;

  /// No description provided for @shareCardOverall.
  ///
  /// In ar, this message translates to:
  /// **'الإتقان العام'**
  String get shareCardOverall;

  /// Counts «أثبت» lessons only: an exam behind the lesson, the evidence still fresh (not overdue), at or above 70. The old wording said «متقنة» and counted stale scores.
  ///
  /// In ar, this message translates to:
  /// **'{count,plural, =0{لا توجد دروس أثبتَها فوق حد الإتقان بعد} =1{درس واحد أثبتَه فوق حد الإتقان} =2{درسان أثبتَهما فوق حد الإتقان} few{{count} دروس أثبتَها فوق حد الإتقان} many{{count} درساً أثبتَها فوق حد الإتقان} other{{count} درساً أثبتَها فوق حد الإتقان}}'**
  String shareCardLessonsAbove(int count);

  /// No description provided for @shareCardError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز صورة التقدّم'**
  String get shareCardError;

  /// No description provided for @reviewNotificationEarlyBody.
  ///
  /// In ar, this message translates to:
  /// **'اقترب موعد مراجعة درس {lesson} في {chapter}'**
  String reviewNotificationEarlyBody(String lesson, String chapter);

  /// No description provided for @analyticsTrajectory.
  ///
  /// In ar, this message translates to:
  /// **'مسار درجاتك'**
  String get analyticsTrajectory;

  /// No description provided for @analyticsVelocity.
  ///
  /// In ar, this message translates to:
  /// **'{value} نقطة لكل دورة مراجعة'**
  String analyticsVelocity(String value);

  /// No description provided for @analyticsVelocityFlat.
  ///
  /// In ar, this message translates to:
  /// **'ثابت، بلا تغيّر'**
  String get analyticsVelocityFlat;

  /// No description provided for @authVerificationSent.
  ///
  /// In ar, this message translates to:
  /// **'بعتنالك رابط تأكيد على بريدك'**
  String get authVerificationSent;

  /// No description provided for @authEmailUnverified.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيده'**
  String get authEmailUnverified;

  /// No description provided for @authResendVerification.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال رابط التأكيد'**
  String get authResendVerification;

  /// No description provided for @authVerificationTooSoon.
  ///
  /// In ar, this message translates to:
  /// **'بعتنا رابط للتو. استنى شوية وحاول تاني.'**
  String get authVerificationTooSoon;

  /// No description provided for @authVerificationNote.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد بريدك يخليك تقدر تسترجع حسابك لو نسيت كلمة السر. التطبيق شغال عادي من غيره.'**
  String get authVerificationNote;

  /// No description provided for @subjectTemplateAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف أبواب المنهج'**
  String get subjectTemplateAdd;

  /// No description provided for @subjectTemplateCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{باباً واحداً} =2{بابين} few{{count} أبواب} other{{count} باباً}}'**
  String subjectTemplateCount(int count);

  /// No description provided for @subjectTemplateAdded.
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة {count}'**
  String subjectTemplateAdded(String count);

  /// No description provided for @subjectTemplateNothingNew.
  ///
  /// In ar, this message translates to:
  /// **'كل أبواب المنهج موجودة عندك بالفعل'**
  String get subjectTemplateNothingNew;

  /// No description provided for @subjectTemplateNote.
  ///
  /// In ar, this message translates to:
  /// **'أبواب المنهج المعتادة، تقدر تعدّلها أو تحذفها زي أي باب كتبته بنفسك. مش هيتغيّر أو يتحذف أي باب عندك.'**
  String get subjectTemplateNote;

  /// No description provided for @authVerificationNotSent.
  ///
  /// In ar, this message translates to:
  /// **'اتعمل حسابك. رابط التأكيد ما اتبعتش — تقدر تبعته من صفحة ملفك.'**
  String get authVerificationNotSent;

  /// No description provided for @examVerdictWeak.
  ///
  /// In ar, this message translates to:
  /// **'درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبلها.'**
  String get examVerdictWeak;

  /// No description provided for @examVerdictPassed.
  ///
  /// In ar, this message translates to:
  /// **'عدّيت، مش متقن — امتحان تاني هو اللي يرفعه.'**
  String get examVerdictPassed;

  /// No description provided for @examNeedToCross.
  ///
  /// In ar, this message translates to:
  /// **'عشان تعدّي الحد: جيب {percentage} في اللي جاي.'**
  String examNeedToCross(String percentage);

  /// No description provided for @comebackLine.
  ///
  /// In ar, this message translates to:
  /// **'رجعت بعد {days} يوم — {count} درس عبر معاده.'**
  String comebackLine(String days, String count);

  /// No description provided for @lastHomeworkDated.
  ///
  /// In ar, this message translates to:
  /// **'آخر واجب ({date})'**
  String lastHomeworkDated(String date);

  /// No description provided for @checklistAllDone.
  ///
  /// In ar, this message translates to:
  /// **'ذاكرتها كلها — فاضل إنك تثبتها بامتحان.'**
  String get checklistAllDone;

  /// No description provided for @tasksDayDone.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت {done} من {total} — يومك خلص.'**
  String tasksDayDone(String done, String total);

  /// No description provided for @reviewWaitingHeader.
  ///
  /// In ar, this message translates to:
  /// **'دروس المراجعة المستنياك: {count}'**
  String reviewWaitingHeader(String count);

  /// No description provided for @insightDiscipline.
  ///
  /// In ar, this message translates to:
  /// **'التزمت {onTime} من {examined} مراجعة في معادها.'**
  String insightDiscipline(String onTime, String examined);

  /// No description provided for @purgeCountsLine.
  ///
  /// In ar, this message translates to:
  /// **'{subjects} مادة · {chapters} باب · {lessons} درس · {exams} امتحان'**
  String purgeCountsLine(
    String subjects,
    String chapters,
    String lessons,
    String exams,
  );

  /// No description provided for @restoreCopyCounts.
  ///
  /// In ar, this message translates to:
  /// **'النسخة السحابية: {chapters} باب، {exams} امتحان'**
  String restoreCopyCounts(String chapters, String exams);

  /// No description provided for @examEveButton.
  ///
  /// In ar, this message translates to:
  /// **'ليلة الامتحان'**
  String get examEveButton;

  /// No description provided for @examEveTitle.
  ///
  /// In ar, this message translates to:
  /// **'ليلة الامتحان'**
  String get examEveTitle;

  /// No description provided for @examEveBody.
  ///
  /// In ar, this message translates to:
  /// **'دروس المادة مرتبة حسب أولوية إثباتها الليلة.'**
  String get examEveBody;

  /// No description provided for @examEveTierUnsettled.
  ///
  /// In ar, this message translates to:
  /// **'غير مُثبت — بلا امتحان'**
  String get examEveTierUnsettled;

  /// No description provided for @examEveTierWeakest.
  ///
  /// In ar, this message translates to:
  /// **'الأضعف إتقانًا'**
  String get examEveTierWeakest;

  /// No description provided for @examEveTierNearestDue.
  ///
  /// In ar, this message translates to:
  /// **'الأقرب سقوطًا'**
  String get examEveTierNearestDue;

  /// No description provided for @reviewBodyDeclining.
  ///
  /// In ar, this message translates to:
  /// **'آخر امتحان في {lesson} نازل — راجعه قبل ما يوقع.'**
  String reviewBodyDeclining(String lesson);

  /// No description provided for @reviewBodyWeak.
  ///
  /// In ar, this message translates to:
  /// **'{lesson} لسه ضعيف — ثبّته بامتحان.'**
  String reviewBodyWeak(String lesson);
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