// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مقدم الرعاية';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get caregiver => 'مقدم رعاية';

  @override
  String get elderly => 'كبير سن';

  @override
  String get requiredField => 'مطلوب';

  @override
  String get invalidEmail => 'أدخل بريد إلكتروني صالح';

  @override
  String get shortPassword => '٦ أحرف على الأقل';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get next => 'التالي';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get signInFailed => 'فشل تسجيل الدخول';

  @override
  String get signInGenericError =>
      'تعذر تسجيل الدخول. يرجى التحقق من البريد الإلكتروني أو كلمة المرور أو نوع الحساب.';

  @override
  String get invalidEmailAuth => 'عنوان بريد إلكتروني غير صالح.';

  @override
  String get tooManyRequestsAuth =>
      'محاولات كثيرة. يرجى المحاولة مرة أخرى لاحقًا.';

  @override
  String get accountDisabledAuth => 'تم تعطيل هذا الحساب.';

  @override
  String get networkErrorAuth => 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت.';

  @override
  String get ok => 'موافق';

  @override
  String get noProfileSelected =>
      'لم يتم تحديد أي ملف شخصي لكبار السن.\n\nيرجى ربط ملف شخصي باستخدام القائمة الجانبية.';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get browse => 'تصفح';

  @override
  String get home => 'الرئيسية';

  @override
  String get medicationHistory => 'سجل الأدوية';

  @override
  String get clearAllHistory => 'مسح كل السجل؟';

  @override
  String get confirmClearHistory =>
      'سيؤدي هذا إلى إزالة جميع سجلات الأدوية بشكل دائم.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get historyClearedToast => 'تم مسح السجل';

  @override
  String get clearAllHistoryMenu => 'مسح كل السجل';

  @override
  String get noMedicationHistory => 'لا يوجد سجل أدوية';

  @override
  String get noMedicationHistoryDesc => 'ستظهر الأدوية المحذوفة والمنتهية\nهنا';

  @override
  String get removeFromHistory => 'إزالة من السجل؟';

  @override
  String confirmRemoveFromHistory(String medName) {
    return 'هل تريد إزالة \"$medName\" من السجل؟';
  }

  @override
  String get remove => 'إزالة';

  @override
  String get recoverMedication => 'استعادة الدواء؟';

  @override
  String confirmRecoverMedication(String medName) {
    return 'هل تريد إعادة \"$medName\" إلى الأدوية النشطة؟';
  }

  @override
  String get recover => 'استعادة';

  @override
  String recoveredSuccessfully(String medName) {
    return 'تم استرجاع \"$medName\" بنجاح';
  }

  @override
  String get failedToRecover => 'فشل في استعادة الدواء';

  @override
  String get expired => 'منتهي';

  @override
  String get deleted => 'محذوف';

  @override
  String get unknownDate => 'تاريخ غير معروف';

  @override
  String get frequency => 'التكرار';

  @override
  String get dose => 'الجرعة';

  @override
  String get days => 'الأيام';

  @override
  String get times => 'الأوقات';

  @override
  String get endDate => 'تاريخ الانتهاء';

  @override
  String get notes => 'ملاحظات';

  @override
  String get recoverMedicationButton => 'استرجاع الدواء';

  @override
  String actionOnDate(String action, String date) {
    return '$action في $date';
  }

  @override
  String get guest => 'زائر';

  @override
  String get caregiverRole => 'مقدم رعاية';

  @override
  String get elderlyRole => 'كبير سن';

  @override
  String get settings => 'الإعدادات';

  @override
  String get linkedProfiles => 'حسابات مرتبطة';

  @override
  String get link => 'ربط';

  @override
  String get noProfilesLinkedYet => 'لا توجد حسابات مرتبطة بعد.';

  @override
  String get logOut => 'تسجيل خروج';

  @override
  String get areYouSure => 'هل أنت متأكد؟';

  @override
  String get doYouReallyWantToLogOut => 'هل تريد حقاً تسجيل الخروج؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get unlink => 'إلغاء الربط';

  @override
  String get deleteProfile => 'حذف الحساب';

  @override
  String confirmDeleteProfile(String profileName) {
    return 'هل تريد حذف $profileName من حسابك؟';
  }

  @override
  String get errorNotLoggedIn => 'خطأ: لم تقم بتسجيل الدخول.';

  @override
  String profileUnlinked(String profileName) {
    return 'تم إلغاء ربط حساب $profileName';
  }

  @override
  String errorUnlinkingProfile(String error) {
    return 'خطأ في إلغاء ربط الحساب: $error';
  }

  @override
  String get editInfo => 'تعديل المعلومات';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get gender => 'الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get selectGender => 'اختر الجنس';

  @override
  String get mobile => 'رقم الجوال (05XXXXXXXX)';

  @override
  String get requiredError => 'مطلوب';

  @override
  String get mustStartWith05 => 'يجب أن يبدأ بـ 05';

  @override
  String get mustBe10Digits => 'يجب أن يكون 10 أرقام';

  @override
  String get mobileInUse => 'الجوال مستخدم';

  @override
  String get mobileInUseMsg => 'رقم الجوال هذا مستخدم بالفعل.';

  @override
  String get informationUpdated => 'تم تحديث المعلومات';

  @override
  String errorUpdatingInfo(String error) {
    return 'خطأ في تحديث المعلومات: $error';
  }

  @override
  String get profileLinked => 'تم ربط الحساب!';

  @override
  String get profileLinkedMsg =>
      'تم ربط الحساب بنجاح. يمكنك الآن إدارة هذا المستخدم من لوحة التحكم الخاصة بك.';

  @override
  String get linkElderlyViaCode => 'ربط كبير سن عبر الرمز';

  @override
  String get enter6Characters => 'أدخل 6 حروف/أرقام';

  @override
  String get invalidOrExpiredCode => 'الرمز غير صالح أو منتهي الصلاحية.';

  @override
  String get invalidCodeData => 'بيانات الرمز غير صالحة.';

  @override
  String get codeHasExpired => 'انتهت صلاحية الرمز.';

  @override
  String anErrorOccurred(String error) {
    return 'حدث خطأ: $error';
  }

  @override
  String get summary => 'الملخص';

  @override
  String errorLoading(String error) {
    return 'خطأ: $error';
  }

  @override
  String get noMedicationsFound => 'لا توجد أدوية';

  @override
  String onTimeLateMissed(int onTime, int late, int missed) {
    return 'في الوقت: $onTime   متأخر: $late   مفوت: $missed';
  }

  @override
  String get noDosesForThisMonthYet => 'لا توجد جرعات لهذا الشهر بعد';

  @override
  String get medicationsForThisElderly => 'أدوية كبير السن هذا';

  @override
  String get byDay => 'حسب اليوم';

  @override
  String get byMedication => 'حسب الدواء';

  @override
  String scheduledTime(String time) {
    return 'مجدول $time';
  }

  @override
  String takenTime(String time) {
    return ' • تم أخذه $time';
  }

  @override
  String get missedOverdue => ' • مفوت (>10 دقائق تأخير)';

  @override
  String get takenLateStatus => ' • تم أخذه متأخراً';

  @override
  String get noLogsForThisDay => 'لا توجد سجلات لهذا اليوم';

  @override
  String get selectDayToViewDetails => 'اختر يوماً لعرض التفاصيل';

  @override
  String get reminder => 'تذكير!';

  @override
  String elderlyMissedDoses(String name, int count) {
    return 'فوت $name عدد $count من الجرعات!';
  }

  @override
  String youMissedDoses(int count) {
    return 'لقد فوتت $count من الأدوية!';
  }

  @override
  String get upcoming => 'القادمة';

  @override
  String get nextUp => 'التالي';

  @override
  String get laterToday => 'في وقت لاحق اليوم';

  @override
  String get taken => 'تم أخذها';

  @override
  String get missedTitle => 'مفوتة';

  @override
  String get medicationTakenOnTime => 'تم أخذ الدواء في وقته ✓';

  @override
  String get medicationTakenLate => 'تم أخذ الدواء متأخراً';

  @override
  String undoSuccessful(String medName) {
    return 'تم التراجع بنجاح لـ $medName. تم إعادة جدولة التنبيهات.';
  }

  @override
  String get noMedicationsInCategory => 'لا توجد أدوية في هذه الفئة اليوم.';

  @override
  String get takenOnTime => 'تم أخذه في وقته';

  @override
  String get takenLate => 'تم أخذه متأخراً';

  @override
  String get missed => 'مفوت';

  @override
  String get pastDue => 'متأخر';

  @override
  String get dueNow => 'مستحق الآن';

  @override
  String get at => 'في';

  @override
  String get markAsTakenLate => 'تحديد كمأخوذ متأخراً';

  @override
  String get markAsTaken => 'تحديد كمأخوذ';

  @override
  String get undo => 'تراجع';

  @override
  String get favorites => 'المفضلة';

  @override
  String get medications => 'الأدوية';

  @override
  String get addNewMedication => 'إضافة دواء جديد';

  @override
  String errorDeletingMedication(String error) {
    return 'خطأ في حذف الدواء: $error';
  }

  @override
  String get errorLoadingMedications => 'خطأ في تحميل الأدوية.';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String errorLoadingVideo(String error) {
    return 'خطأ في تحميل الفيديو: $error';
  }

  @override
  String errorLoadingAudio(String error) {
    return 'خطأ في تحميل الصوت: $error';
  }

  @override
  String get media => 'الوسائط';

  @override
  String get searchFavorites => 'البحث في المفضلة...';

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج';

  @override
  String get voiceCommandFailed => 'فشل الأمر الصوتي، يرجى المحاولة مرة أخرى.';

  @override
  String get health => 'الصحة';

  @override
  String get story => 'قصة';

  @override
  String get quran => 'قرآن';

  @override
  String get searchForAudio => 'البحث عن مقطع صوتي...';

  @override
  String get addedToFavorites => 'تمت الإضافة إلى المفضلة بنجاح';

  @override
  String get removedFromFavorites => 'تمت الإزالة من المفضلة';

  @override
  String get noValidYoutubeUrl => 'لا يوجد رابط يوتيوب صالح.';

  @override
  String get emergencyAlert => 'تنبيه طوارئ';

  @override
  String todayLabel(Object date) {
    return 'اليوم • $date';
  }

  @override
  String get goToMedications => 'الذهاب إلى الأدوية';

  @override
  String get noUpcomingMeds => 'لا توجد أدوية قادمة';

  @override
  String get monthlyOverview => 'نظرة عامة شهرية';

  @override
  String viewingDailyMeds(Object name) {
    return 'أنت تعرض الأدوية اليومية لـ $name.';
  }

  @override
  String get onTimeStatus => 'في الوقت';

  @override
  String get missedStatus => 'مفوت';

  @override
  String get howToReadPieChart => 'كيف تقرأ هذا المخطط الدائري؟';

  @override
  String get pieChartHelpBody =>
      '• كل شريحة = مجموعة من الجرعات هذا الشهر\n• الأخضر: الجرعات التي أخذت في الوقت\n• الأصفر: الجرعات التي أخذت متأخرة\n• الأحمر: الجرعات المفوتة تماماً\n\nحجم كل شريحة يوضح نسبتها من جميع الجرعات.';

  @override
  String get howToReadBarChart => 'كيف تقرأ هذا المخطط العمودي اليومي؟';

  @override
  String get barChartHelpBody =>
      '• كل عمود = يوم واحد من هذا الشهر\n• ارتفاع العمود = إجمالي عدد الجرعات في ذلك اليوم\n• الجزء الأخضر = الجرعات التي أخذت في الوقت\n• الجزء الأصفر = الجرعات التي أخذت متأخرة\n• الجزء الأحمر = الجرعات المفوتة\n\nهذا يساعدك في رؤية الأيام التي كانت فيها جرعات مفوتة أو متأخرة أكثر.';

  @override
  String get howToReadWeeklyTrend => 'كيف تقرأ الاتجاه الأسبوعي؟';

  @override
  String get weeklyTrendHelpBody =>
      '• كل بطاقة = أسبوع واحد في هذا الشهر\n• توضح كم جرعة كانت في الوقت، أو متأخرة، أو مفوتة\n• النسبة المئوية على اليمين هي الالتزام العام لذلك الأسبوع.\n\nالأسابيع الخضراء = التزام جيد جداً، الأسابيع الحمراء = تحتاج إلى انتباه.';

  @override
  String get gotIt => 'فهمت';

  @override
  String summaryForMed(Object medName) {
    return 'الملخص • $medName';
  }

  @override
  String get noDosesThisMonth => 'لا توجد جرعات لهذا الشهر بعد.';

  @override
  String get statusPie => 'حالة دائرية';

  @override
  String get dailyBar => 'أعمدة يومية';

  @override
  String get weeklyTrend => 'اتجاه أسبوعي';

  @override
  String get monthlyAdherence => 'الالتزام الشهري';

  @override
  String get doseStatusThisMonth => 'حالة الجرعات (هذا الشهر)';

  @override
  String get dailyDosesByStatus => 'الجرعات اليومية حسب الحالة (أعمدة متراكمة)';

  @override
  String get noDailyData => 'لا توجد بيانات يومية متاحة لهذا الشهر.';

  @override
  String get noDataWeeklyTrend => 'لا توجد بيانات متاحة للاتجاه الأسبوعي.';

  @override
  String get notEnoughDataWeekly => 'بيانات غير كافية للاتجاه الأسبوعي.';

  @override
  String get weeklyAdherenceTrend => 'اتجاه الالتزام الأسبوعي';

  @override
  String weekNumber(Object week) {
    return 'الأسبوع $week';
  }

  @override
  String dayLabel(Object day) {
    return 'يوم: $day';
  }

  @override
  String daysRangeLabel(Object startDay, Object endDay) {
    return 'أيام: $startDay–$endDay';
  }

  @override
  String get greatAdherence => 'التزام ممتاز 👏';

  @override
  String get moderateAdherence => 'التزام متوسط – يمكن تحسينه 🙂';

  @override
  String get lowAdherence => 'التزام منخفض – يحتاج إلى انتباه ⚠️';

  @override
  String get medicationDeletedSuccessfully => 'تم حذف الدواء بنجاح';

  @override
  String get medsFor => 'أدوية';

  @override
  String get medicationList => 'قائمة الأدوية';

  @override
  String get todaysMeds => 'أدوية اليوم';

  @override
  String get medList => 'قائمة الأدوية';

  @override
  String get confirmDeletion => 'تأكيد الحذف';

  @override
  String get areYouSureToDelete => 'هل أنت متأكد أنك تريد حذف';

  @override
  String get rescan => 'إعادة المسح';

  @override
  String get scanFailed => 'فشل المسح';

  @override
  String get editMedication => 'تعديل الدواء';

  @override
  String get step1MedicineName => 'الخطوة ١: اسم الدواء';

  @override
  String get whatMedicationDoYouNeedToTake =>
      'ما هو الدواء الذي تحتاج إلى تناوله؟';

  @override
  String get medicineName => 'اسم الدواء';
}
