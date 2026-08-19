// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Ather';

  @override
  String get appTagline => 'You don\'t finish lessons… you master them';

  @override
  String get navHome => 'Today';

  @override
  String get navReview => 'Review';

  @override
  String get navProgress => 'Progress';

  @override
  String get navTasks => 'Tasks';

  @override
  String get subjectBiology => 'Biology';

  @override
  String get subjectPhysics => 'Physics';

  @override
  String get subjectChemistry => 'Chemistry';

  @override
  String get subjectEnglish => 'English';

  @override
  String get weekdaySaturday => 'Sat';

  @override
  String get weekdaySunday => 'Sun';

  @override
  String get weekdayMonday => 'Mon';

  @override
  String get weekdayTuesday => 'Tue';

  @override
  String get weekdayWednesday => 'Wed';

  @override
  String get weekdayThursday => 'Thu';

  @override
  String get weekdayFriday => 'Fri';

  @override
  String get todayLabel => 'Today';

  @override
  String get dashboardTitle => 'Today';

  @override
  String get overallMastery => 'Overall mastery';

  @override
  String get statLessonsRemaining => 'Lessons left';

  @override
  String get statNeedsReview => 'Needs review';

  @override
  String get statMastered => 'Mastered';

  @override
  String get sectionSubjects => 'Subjects';

  @override
  String get firstRunTitle => 'Start here';

  @override
  String get firstRunBody =>
      'Mastery comes from your exams alone, not from finishing a lesson.';

  @override
  String get firstRunAction => 'Open your first subject';

  @override
  String get sectionNext => 'Up next';

  @override
  String get actionExam => 'Log exam';

  @override
  String get notStartedYet => 'Not started yet';

  @override
  String get subjectHasOverdueLesson => 'A lesson is past its review date';

  @override
  String lessonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String chaptersMasteredOf(String mastered, String total) {
    return '$mastered of $total chapters mastered';
  }

  @override
  String chaptersOfShort(String mastered, String total) {
    return '$mastered of $total chapters';
  }

  @override
  String lessonsExaminedOf(String examined, String total) {
    return '$examined of $total lessons examined';
  }

  @override
  String lessonsOnTimeOf(String onTime, String total) {
    return '$onTime of $total lessons on time';
  }

  @override
  String get sectionChapters => 'Chapters';

  @override
  String get sectionLessons => 'Lessons';

  @override
  String get addChapter => '+ Add chapter';

  @override
  String get addLesson => '+ Add lesson';

  @override
  String get noChaptersYet => 'No chapters yet';

  @override
  String get noLessonsYet => 'No lessons yet';

  @override
  String get chapterName => 'Chapter name';

  @override
  String get lessonName => 'Lesson name';

  @override
  String get chapterNameHint => 'e.g. Chapter 1 — The Cell';

  @override
  String get lessonNameHint => 'e.g. Plasma membrane structure';

  @override
  String get renameChapter => 'Rename chapter';

  @override
  String get renameLesson => 'Rename lesson';

  @override
  String get deleteChapter => 'Delete chapter';

  @override
  String get deleteLesson => 'Delete lesson';

  @override
  String get deleteChapterConfirm =>
      'This deletes the chapter with every lesson and exam inside it. It cannot be undone.';

  @override
  String get deleteLessonConfirm =>
      'This deletes the lesson and all of its exams. It cannot be undone.';

  @override
  String get averageExamScore => 'Exam average';

  @override
  String get chapterNeedsReview => 'Needs review';

  @override
  String chapterMasteredAt(String date) {
    return 'Mastered on $date';
  }

  @override
  String get masterChapter => 'I mastered this chapter';

  @override
  String get viewChapterReport => 'See chapter report';

  @override
  String get notReadyGate => 'Not ready yet — find out why';

  @override
  String get notReadyTitle => 'Not ready yet';

  @override
  String notReadyBody(String threshold) {
    return 'To master a chapter every lesson needs an exam and mastery has to reach at least $threshold.';
  }

  @override
  String get noExamShort => 'No exam';

  @override
  String get lessonNoExamYet => 'No exam yet';

  @override
  String dueInDays(String days) {
    return '$days days left';
  }

  @override
  String dueInDaysLong(String days) {
    return '$days days until review';
  }

  @override
  String overdueByDays(String days) {
    return '$days days overdue';
  }

  @override
  String masteryCaptionWithExams(String last, String rest) {
    return 'Mastery is the last exam $last plus the average of the earlier ones $rest';
  }

  @override
  String get masteryCaptionNoExams =>
      'Mastery comes from exams only — log your first exam to start';

  @override
  String get checklistTitle => 'Study steps';

  @override
  String get checklistWatched => 'Watched the lesson';

  @override
  String get checklistReadNotes => 'Read the notes';

  @override
  String get checklistDidHomework => 'Did the homework';

  @override
  String get checklistDidExam => 'Sat the exam';

  @override
  String get checklistReviewedNotes => 'Reviewed the notes';

  @override
  String get homeworkTitle => 'Homework';

  @override
  String get homeworkAdd => 'Log a homework score';

  @override
  String get homeworkScore => 'Score';

  @override
  String get homeworkMax => 'out of';

  @override
  String get homeworkNotReady => 'You need more study before sitting the exam';

  @override
  String get homeworkReady => 'Good — you\'re ready for the exam';

  @override
  String get homeworkNone => 'No homework logged';

  @override
  String get homeworkNote =>
      'Homework never counts toward mastery — it is a readiness signal only';

  @override
  String get homeworkInvalid =>
      'The score must be between zero and the total, and the total above zero';

  @override
  String get examHistory => 'Past exams';

  @override
  String get examNoHistory => 'No exams yet';

  @override
  String get examReviewBadge => 'Review';

  @override
  String get examDelete => 'Remove exam';

  @override
  String get examDeleteConfirm =>
      'This exam will be removed from the record and the lesson\'s mastery recalculated without it. This can\'t be undone.';

  @override
  String get toastExamDeleted => 'Exam removed — mastery recalculated';

  @override
  String get examStart => 'Start the exam';

  @override
  String get examRecordResult => 'Log an exam result';

  @override
  String get examRecordReview => 'Log the review exam';

  @override
  String get examStep1Title => 'Total questions';

  @override
  String get examStep1Hint => 'How many questions were on the exam?';

  @override
  String get examStep2Title => 'Question marks';

  @override
  String get examStep2Hint => 'Split the questions: how many at how many marks';

  @override
  String get examStep3Title => 'Your correct answers';

  @override
  String get examStep3Hint => 'How many did you get right in each group';

  @override
  String get examStep4Title => 'Result';

  @override
  String get examGroupQuestions => 'Questions';

  @override
  String get examGroupPoints => 'Marks each';

  @override
  String get examAddGroup => '+ Add group';

  @override
  String get examRemoveGroup => 'Remove group';

  @override
  String examGroupLabel(String count, String points) {
    return '$count questions × $points marks';
  }

  @override
  String examPointsLine(String points) {
    return '$points marks';
  }

  @override
  String get examMasteryBefore => 'Mastery before';

  @override
  String get examMasteryAfter => 'Mastery after';

  @override
  String get examSave => 'Save result';

  @override
  String get examSaveReview => 'Save review exam';

  @override
  String get examSaveFailed =>
      'We couldn\'t save this exam. Your numbers are still here — try again.';

  @override
  String get examDiscardTitle => 'Leave this exam?';

  @override
  String get examDiscardBody =>
      'What you\'ve entered will be lost. This can\'t be undone.';

  @override
  String get examDiscardLeave => 'Leave';

  @override
  String get examDiscardStay => 'Keep going';

  @override
  String get examErrorNeedAtLeastOneQuestion =>
      'At least one question is required';

  @override
  String get examErrorGroupInvalid =>
      'Every group needs a question count and a mark above zero';

  @override
  String examErrorSumMismatch(String assigned, String total) {
    return 'The group total ($assigned) must equal the overall total ($total)';
  }

  @override
  String get examErrorCorrectExceeds =>
      'Correct answers cannot exceed the number of questions';

  @override
  String get toastExamSaved => 'Exam saved — the review clock restarts now';

  @override
  String get toastHomeworkSaved => 'Homework score saved';

  @override
  String get reviewTitle => 'Needs review';

  @override
  String get reviewEmptyTitle => 'Nothing needs review';

  @override
  String get reviewEmptyBody => 'Every lesson is on time. Keep going.';

  @override
  String get reviewReasonWeak => 'Weak score';

  @override
  String get reviewReasonDeclining => 'Your score is dropping';

  @override
  String get reviewNotificationTitle => 'Time to review';

  @override
  String reviewNotificationBody(String lesson, String chapter) {
    return 'Time to review $lesson in $chapter';
  }

  @override
  String get analyticsTitle => 'Progress';

  @override
  String get analyticsInsights => 'Notes';

  @override
  String get analyticsAllSubjects => 'All subjects';

  @override
  String get analyticsMasteryBySubject => 'Mastery by subject';

  @override
  String get analyticsMasteryByChapter => 'Mastery by chapter';

  @override
  String get analyticsWeakestLessons => 'Weakest lessons';

  @override
  String get analyticsReviewDiscipline => 'Review discipline';

  @override
  String get analyticsNotEnoughData => 'Not enough data yet';

  @override
  String insightStrongestSubject(String subject, String value) {
    return '$subject is your strongest subject right now — $value';
  }

  @override
  String insightChapterWeak(String chapter, String value) {
    return '\"$chapter\" is still weak — $value';
  }

  @override
  String insightLessonNotReviewed(String lesson, String days) {
    return 'You haven\'t reviewed \"$lesson\" in $days days';
  }

  @override
  String insightSubjectImproved(String subject, String delta) {
    return '$subject is up $delta this month';
  }

  @override
  String get chapterReportTitle => 'Chapter report';

  @override
  String trendUp(String from, String to) {
    return 'Up from $from to $to';
  }

  @override
  String trendDown(String from, String to) {
    return 'Down from $from to $to';
  }

  @override
  String get trendFlat => 'More exams are needed to measure progress';

  @override
  String get weakestLessonBadge => 'Weakest lesson';

  @override
  String get celebrationTitle => 'Chapter mastered!';

  @override
  String get celebrationBody => 'Solid work. Keep it up.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authRegisterTitle => 'New account';

  @override
  String get authSubtitle =>
      'Sign in once, then the app works with no connection';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authRegister => 'Create account';

  @override
  String get authGoogle => 'Continue with Google';

  @override
  String get authToRegister => 'No account yet? Create one';

  @override
  String get authToSignIn => 'Already have an account? Sign in';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authResetSent => 'We sent you a link to reset your password';

  @override
  String get authErrorEmailInvalid => 'That email is not valid';

  @override
  String get authErrorPasswordShort =>
      'The password needs at least 8 characters';

  @override
  String get authErrorWrongCredentials => 'Wrong email or password';

  @override
  String get authErrorEmailInUse => 'That email is already registered';

  @override
  String get authErrorNoNetwork =>
      'No connection. Only the first sign-in needs the network — after that the app works offline.';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Wait a moment and try again';

  @override
  String get authErrorGeneric => 'That did not go through. Try again';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutConfirm =>
      'You will need a connection to sign in again. Your data stays on this device and is not deleted.';

  @override
  String get authAccount => 'Account';

  @override
  String get authDeleteAccount => 'Delete account';

  @override
  String get authDeleteAccountConfirm =>
      'Your account, your cloud copy and everything on this device will be permanently deleted. This cannot be undone.';

  @override
  String get authDeleteAccountOfflineWarning =>
      'Anything that has not reached the cloud yet will be lost with the deletion.';

  @override
  String get authDeleteAccountReauthTitle => 'Confirm it is your account';

  @override
  String get authDeleteAccountReauthBody =>
      'Type your password to finish deleting the account.';

  @override
  String get authDeleteAccountReauthAction => 'Delete account';

  @override
  String get authDeleteAccountFailed =>
      'The account was not deleted. Try again.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get privacyTitle => 'Your privacy';

  @override
  String get privacyIntro =>
      'This app collects as little as possible. Everything below describes what actually happens — not generic promises.';

  @override
  String get privacyLocalTitle => 'Your study data';

  @override
  String get privacyLocalBody =>
      'Your subjects, chapters, lessons, exams and tasks are stored on your phone, in a local database. Mastery is computed on your device. Your name and school year from the profile are kept on this device only and are never uploaded.';

  @override
  String get privacyAccountTitle => 'Account data';

  @override
  String get privacyAccountBody =>
      'For the cloud backup we ask for an email and password (or a Google account). They are stored by Google Firebase Auth. Your email is everything we know about you on the server — no name, no age, no other personal data.';

  @override
  String get privacyCloudTitle => 'The cloud backup';

  @override
  String get privacyCloudBody =>
      'If you create an account, a copy of your study data, encrypted in transit, is stored on Google servers (Firebase Firestore) under your account. Nobody but you can reach it — including us.';

  @override
  String get privacyDeleteTitle => 'Deleting your data';

  @override
  String get privacyDeleteBody =>
      'At the very bottom of Settings there is a Delete account button. When you tap it: the data on your phone is erased, the cloud copy is erased, and the account itself is removed from Firebase. Permanently.';

  @override
  String get privacyNoCollectTitle => 'What we never do';

  @override
  String get privacyNoCollectBody =>
      'No ads. No tracking. No selling data. No third-party analytics or crash reporting. The app works offline most of the time anyway.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockReason => 'Unlock Ather';

  @override
  String get lockRefused => 'That didn\'t unlock — try again';

  @override
  String get lockLockedOut =>
      'Too many attempts. Wait a moment and try again, or use your phone\'s passcode.';

  @override
  String get lockSetting => 'Fingerprint lock';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profileTitle => 'Your profile';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameHint => 'Type your name';

  @override
  String get profileNameUnset => 'Not set';

  @override
  String get profileYear => 'School year';

  @override
  String get profileYearUnset => 'Not set';

  @override
  String get profileYearFirst => 'Year 1';

  @override
  String get profileYearSecond => 'Year 2';

  @override
  String get profileYearThird => 'Year 3';

  @override
  String get profileLocalNote =>
      'This is kept on this device only and is never uploaded to any server.';

  @override
  String profileGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get subjectsArchived => 'Archived subjects';

  @override
  String get subjectsArchivedNote =>
      'An archived subject is not shown, does not count toward mastery, and sends no reminders. Its chapters and exams are kept exactly as they were.';

  @override
  String get subjectArchive => 'Archive subject';

  @override
  String get subjectUnarchive => 'Unarchive';

  @override
  String get binTitle => 'Recycle bin';

  @override
  String get binEmpty => 'The bin is empty';

  @override
  String get binRestore => 'Restore';

  @override
  String get binPurge => 'Delete permanently';

  @override
  String get binEmptyAll => 'Empty the bin';

  @override
  String binDeletedAt(String date) {
    return 'Deleted $date';
  }

  @override
  String get binNote =>
      'Subjects here are kept whole, with their chapters and exams, and are never removed on their own. Only a permanent delete erases them.';

  @override
  String binPurgeConfirm(String subject, String chapters, String exams) {
    return 'This erases \"$subject\" along with $chapters and $exams. It cannot be undone.';
  }

  @override
  String get binEmptyAllConfirm =>
      'This erases everything in the bin along with its chapters and exams. It cannot be undone.';

  @override
  String examCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exams',
      one: '1 exam',
    );
    return '$_temp0';
  }

  @override
  String get subjectsTitle => 'Subjects';

  @override
  String subjectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subjects',
      one: '1 subject',
    );
    return '$_temp0';
  }

  @override
  String get subjectAdd => '+ Add subject';

  @override
  String get subjectNameHint => 'e.g. Maths';

  @override
  String get subjectRename => 'Rename';

  @override
  String get subjectDelete => 'Delete subject';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsNotifications => 'Review reminders';

  @override
  String get settingsNotificationsBlocked =>
      'Notifications are turned off in your phone\'s settings. Turn them on there to get reminders.';

  @override
  String get settingsAboutSection => 'About Ather';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersionFormat(String version) {
    return 'Version $version';
  }

  @override
  String get backupTitle => 'Cloud backup';

  @override
  String get backupNever => 'Not saved yet';

  @override
  String backupSavedAt(String date) {
    return 'Last saved: $date';
  }

  @override
  String get backupSaving => 'Saving…';

  @override
  String get backupSaveNow => 'Save now';

  @override
  String get backupRestore => 'Restore from cloud';

  @override
  String get backupRestoreConfirm =>
      'Everything on this phone will be replaced by the cloud copy.';

  @override
  String get backupRestoreDone => 'Your data is back';

  @override
  String get backupRestoreEmpty => 'No cloud backup yet';

  @override
  String get backupErrorOffline =>
      'No connection — it will save when you\'re back online';

  @override
  String get backupErrorPermission => 'The server permissions aren\'t set up';

  @override
  String get backupErrorTooLarge => 'Your data is too large to save in one go';

  @override
  String get backupErrorUnreadable => 'The cloud copy can\'t be read';

  @override
  String get backupErrorUnknown => 'Saving didn\'t work';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get tasksTitle => 'Today\'s tasks';

  @override
  String tasksDoneOf(String done, String total) {
    return '$done of $total done';
  }

  @override
  String get addTask => '+ Add task';

  @override
  String get addTaskTitle => 'New task';

  @override
  String get taskNameHint => 'What are you doing today?';

  @override
  String get renameTask => 'Edit task';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get deleteTaskConfirm => 'It will be removed from this day for good.';

  @override
  String get noTasksYet => 'No tasks for this day';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSomethingWentWrong => 'Something didn\'t work. Try again.';

  @override
  String get nameRequired => 'Type a name first';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';
}
