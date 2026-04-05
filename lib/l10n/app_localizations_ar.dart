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
  String get caregiver => 'مقدم الرعاية';

  @override
  String get elderly => 'كبير سن';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get next => 'التالي';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get signUp => 'تسجيل';

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
  String errorLoadingVideo(String error) {
    return 'خطأ في تحميل الفيديو: $error';
  }

  @override
  String errorLoadingAudio(String error) {
    return 'خطأ في تحميل الصوت: $error';
  }

  @override
  String get searchFavorites => 'البحث في المفضلة...';

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج';

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

  @override
  String get manageMedicationList => 'إدارة قائمة الأدوية';

  @override
  String get manageAccess => 'إدارة الوصول';

  @override
  String get verificationCode => 'رمز التحقق';

  @override
  String get shareWithElderly => 'مشاركة مع كبير السن';

  @override
  String get shareLifeUpdates => 'شارك تحديثات حياتك مع من تحب';

  @override
  String get pleaseSelectElderlyProfileFirst =>
      'يرجى تحديد ملف شخصي لكبير السن من القائمة الجانبية أولاً.';

  @override
  String get pleaseSelectElderlyProfile =>
      'يرجى تحديد ملف شخصي لكبير السن أولاً.';

  @override
  String get elderlyInfo => 'معلومات كبير السن';

  @override
  String get userFallback => 'مستخدم';

  @override
  String get na => 'غير متوفر';

  @override
  String get newCaregiverLinked => 'تم ربط مقدم رعاية جديد بحسابك.';

  @override
  String get caregiverUnlinked => 'تم إلغاء ربط مقدم رعاية من حسابك.';

  @override
  String errorLoadingProfile(String error) {
    return 'خطأ في تحميل الحساب: $error';
  }

  @override
  String get informationUpdatedSuccessfully => 'تم تحديث المعلومات بنجاح';

  @override
  String get voiceOpeningMedications => 'جاري فتح صفحة الأدوية الخاصة بك.';

  @override
  String get voiceAccountNotFound =>
      'لم أتمكن من العثور على حسابك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get voiceAddMedication => 'حسنًا، سأساعدك في إضافة دواء جديد.';

  @override
  String get voiceEditMedication => 'حسنًا، لنقم بتعديل أحد أدويتك.';

  @override
  String get voiceDeleteMedication => 'حسنًا، لنختر الدواء الذي تريد حذفه.';

  @override
  String get voiceOpeningMedia => 'جاري فتح صفحة الوسائط الخاصة بك.';

  @override
  String get voiceAlreadyHome => 'أنت بالفعل في الصفحة الرئيسية.';

  @override
  String get voiceSosPreamble => 'وضع الطوارئ. هنا سنقوم بتفعيل خطوات الطوارئ.';

  @override
  String get emergencyTitle => 'طوارئ';

  @override
  String get emergencyFlowDesc =>
      'هنا سنقوم بتفعيل خطوات الطوارئ (الاتصال بمقدم الرعاية، إرسال تنبيه، إلخ).';

  @override
  String get voiceSettingsNotReady =>
      'صفحة الإعدادات غير جاهزة بعد. في المستقبل، سأفتحها لك من هنا.';

  @override
  String helloUser(String name) {
    return 'مرحباً $name';
  }

  @override
  String get sos => 'طوارئ';

  @override
  String get errorNotLoggedIn2 => 'خطأ: لم تقم بتسجيل الدخول.';

  @override
  String get everyDay => 'كل يوم';

  @override
  String get mustBeLoggedInToSave => 'يجب تسجيل الدخول للحفظ.';

  @override
  String errorUpdatingMedication(String error) {
    return 'خطأ في تحديث الدواء: $error';
  }

  @override
  String errorSavingMedication(String error) {
    return 'خطأ في حفظ الدواء: $error';
  }

  @override
  String get change => 'تغيير';

  @override
  String get addAnotherTime => 'إضافة وقت آخر';

  @override
  String get clearAllTimes => 'مسح كل الأوقات';

  @override
  String get pleaseSelectAllRequiredTimes =>
      'يرجى تحديد كافة الأوقات المطلوبة.';

  @override
  String get egPanadol => 'مثال: بنادول';

  @override
  String get optionalInstructions => 'تعليمات اختيارية...';

  @override
  String timeNumber(int index) {
    return 'الوقت $index';
  }

  @override
  String get location => 'الموقع';

  @override
  String get liveLocation => 'الموقع المباشر وآخر ظهور';

  @override
  String get save => 'حفظ';

  @override
  String get caregivers => 'مقدمي الرعاية';

  @override
  String get generateCode => 'إنشاء رمز';

  @override
  String errorGeneratingCode(String error) {
    return 'خطأ في إنشاء الرمز: $error';
  }

  @override
  String get youNeedToBeLoggedIn => 'يجب تسجيل الدخول أولاً.';

  @override
  String get emailAlreadyInUse => 'البريد الإلكتروني مستخدم بالفعل';

  @override
  String get phoneAlreadyUsed => 'رقم الهاتف مستخدم بالفعل';

  @override
  String get accountCreatedSuccess => 'تم إنشاء الحساب بنجاح ✅';

  @override
  String get invalidEmailAddress => 'عنوان البريد الإلكتروني غير صالح.';

  @override
  String get weakPassword => 'كلمة المرور ضعيفة.';

  @override
  String errorPrefix(String error) {
    return 'تفاصيل الخطأ: $error';
  }

  @override
  String get caregiverSignUp => 'تسجيل مقدم الرعاية';

  @override
  String get requiredField => 'مطلوب';

  @override
  String get enterValidEmail => 'أدخل بريد إلكتروني صالح';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'الاسم الأخير';

  @override
  String get gender => 'الجنس';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get enterValidSaudiNumber => 'أدخل رقم سعودي صحيح (05XXXXXXXX)';

  @override
  String get min6Chars => 'على الأقل 6 أحرف';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمات المرور غير متطابقة';

  @override
  String get elderlySignUp => 'تسجيل كبير السن';

  @override
  String get invalidEmail => 'بريد إلكتروني غير صالح.';

  @override
  String get networkError => 'خطأ في الشبكة. تحقق من الاتصال.';

  @override
  String stepXofY(int step, int total) {
    return 'خطوة $step من $total';
  }

  @override
  String get back => 'رجوع';

  @override
  String get accountEmail => 'البريد الإلكتروني للحساب';

  @override
  String get personalInfo => 'المعلومات الشخصية';

  @override
  String get contactInfo => 'معلومات الاتصال';

  @override
  String get phoneStartWith05 => 'يجب أن يبدأ رقم الهاتف بـ 05';

  @override
  String get accountSecurity => 'أمان الحساب';

  @override
  String get confirm => 'تأكيد';

  @override
  String get emailSent => 'تم إرسال البريد الإلكتروني';

  @override
  String get passwordResetLinkSent =>
      'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.';

  @override
  String get error => 'خطأ';

  @override
  String get somethingWentWrong => 'حدث خطأ ما.';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get willSendPasswordResetLink =>
      'سنرسل رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.';

  @override
  String get emailAddress => 'عنوان البريد الإلكتروني';

  @override
  String get pleaseEnterYourEmail => 'الرجاء إدخال بريدك الإلكتروني';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get lastUpdate => 'آخر تحديث';

  @override
  String get refreshLocation => 'تحديث الموقع';

  @override
  String get videoSharedSuccessfully => 'تمت مشاركة الفيديو بنجاح!';

  @override
  String get failedToUploadVideo => 'فشل تحميل الفيديو';

  @override
  String errorSharingVideo(String error) {
    return 'خطأ في مشاركة الفيديو: $error';
  }

  @override
  String errorStartingRecording(String error) {
    return 'خطأ في بدء التسجيل: $error';
  }

  @override
  String errorStoppingRecording(String error) {
    return 'خطأ في إيقاف التسجيل: $error';
  }

  @override
  String get voiceMessageSharedSuccessfully =>
      'تمت مشاركة الرسالة الصوتية بنجاح!';

  @override
  String errorSharingVoice(String error) {
    return 'خطأ في مشاركة الصوت: $error';
  }

  @override
  String nameThisType(String type) {
    return 'قم بتسمية هذا الـ $type';
  }

  @override
  String get enterTitleOptional => 'أدخل عنوانًا (اختياري)';

  @override
  String get shareVideo => 'مشاركة فيديو';

  @override
  String get pickFromGallery => 'اختيار من المعرض';

  @override
  String get recording => 'جاري التسجيل...';

  @override
  String get voiceMessage => 'رسالة صوتية';

  @override
  String get tapToStop => 'انقر للإيقاف';

  @override
  String get tapToRecord => 'انقر للتسجيل';

  @override
  String get recentlyShared => 'تمت مشاركته مؤخرًا';

  @override
  String get uploading => 'جاري الرفع...';

  @override
  String get noItemsSharedYet => 'لا توجد عناصر مشتركة بعد.';

  @override
  String get media => 'الوسائط';

  @override
  String get story => 'قصص';

  @override
  String get quran => 'قرآن';

  @override
  String get health => 'الصحة';

  @override
  String get favorites => 'المفضلة';

  @override
  String get voiceCommandFailed => 'فشل الأمر الصوتي. حاول مرة أخرى.';

  @override
  String get alreadyOnMediaPage => 'أنت بالفعل في صفحة الوسائط.';

  @override
  String get goingBackToHome => 'العودة إلى الصفحة الرئيسية.';

  @override
  String get manageMedicationsInstruction =>
      'لإدارة أدويتك، يرجى العودة إلى الصفحة الرئيسية وفتح قسم الأدوية.';

  @override
  String get startingSosFlow => 'سنبدأ هنا بتدفق الطوارئ SOS.';

  @override
  String get settingsNotAvailableHere =>
      'الإعدادات غير متوفرة من صفحة الوسائط بعد.';

  @override
  String get mediaCategoryPrompt =>
      'أنت في صفحة الوسائط. من أي فئة تريدني أن أشغل شيئًا؟ اختر صحة، قرآن، قصص، مقدم الرعاية أو المفضلة.';

  @override
  String get stoppingVoiceAssistant => 'حسنا، سأتوقف الآن.';

  @override
  String get didNotCatchThat => 'عذراً، لم أفهم ذلك.';

  @override
  String get categoryNotUnderstood =>
      'عذراً، لم أفهم الفئة. يرجى المحاولة مرة أخرى.';

  @override
  String specificOrRandomPrompt(String matchedCategory) {
    return 'حسنا، $matchedCategory. هل ترغب في تشغيل شيء محدد أم عشوائي؟';
  }

  @override
  String get sayAudioOrVideoName =>
      'الرجاء قول اسم المقطع الصوتي أو الفيديو الذي تريده.';

  @override
  String get didNotHearTitle => 'لم أسمع عنواناً.';

  @override
  String playingRandomFromCategory(String matchedCategory) {
    return 'حسنا، أقوم بتشغيل شيء عشوائي من $matchedCategory.';
  }

  @override
  String get mustBeLoggedInForFavorites =>
      'يجب تسجيل الدخول للوصول إلى المفضلة.';

  @override
  String noAudioFoundForCategory(String category) {
    return 'لم يتم العثور على مقاطع صوتية لـ $category.';
  }

  @override
  String playingItem(String title) {
    return 'تشغيل $title';
  }

  @override
  String couldNotFindAudioNamed(String searchTitle, String category) {
    return 'لم أتمكن من العثور على أي مقطع باسم $searchTitle في $category.';
  }

  @override
  String get somethingWentWrongWhileSearching => 'حدث خطأ أثناء البحث.';

  @override
  String get all => 'الكل';

  @override
  String get audio => 'صوت';

  @override
  String get video => 'فيديو';

  @override
  String get familyMedia => 'وسائط العائلة';

  @override
  String get pleaseLogInFirst => 'الرجاء تسجيل الدخول أولاً.';

  @override
  String get noMediaSharedYet => 'لا توجد وسائط مشتركة بعد.';

  @override
  String get noMediaInThisFilter => 'لا توجد وسائط في هذا الفلتر.';

  @override
  String get deleteMediaTitle => 'حذف الوسائط؟';

  @override
  String get confirmDeleteSpecificMedia =>
      'هل أنت متأكد من رغبتك في حذف هذه الوسائط المحددة؟';

  @override
  String get mediaDeletedSuccessfully => 'تم حذف الوسائط بنجاح';

  @override
  String errorDeletingMedia(String error) {
    return 'خطأ في حذف الوسائط: $error';
  }

  @override
  String get share => 'مشاركة';

  @override
  String get delete => 'حذف';

  @override
  String get deleteItem => 'حذف العنصر؟';

  @override
  String get areYouSureDeleteSharedItem =>
      'هل أنت متأكد أنك تريد حذف هذا العنصر المشترك؟';

  @override
  String get itemDeletedSuccessfully => 'تم حذف العنصر بنجاح';

  @override
  String errorDeletingItem(String error) {
    return 'خطأ في حذف العنصر: $error';
  }

  @override
  String get comingSoon => 'قريباً';

  @override
  String get shortPassword => 'الأدنى 6 أحرف';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get stepDurationTitle => 'الخطوة ٢: المدة';

  @override
  String get stepDurationSub => 'ما هي مدة تناول هذا الدواء؟';

  @override
  String get stepDaysTitle => 'الخطوة ٣: الأيام';

  @override
  String get stepDaysSub => 'في أي أيام يجب تناول هذا الدواء؟';

  @override
  String get stepFreqTitle => 'الخطوة ٤: التكرار';

  @override
  String get stepFreqSub => 'اختر عدد مرات تناول هذا الدواء';

  @override
  String get stepDoseTitle => 'الخطوة ٥: الجرعة';

  @override
  String get stepDoseSub => 'ما هو شكل وجرعة هذا الدواء؟';

  @override
  String get stepTimesTitle => 'الخطوة ٦: الأوقات';

  @override
  String get stepTimesSub => 'متى يجب تناول هذا الدواء؟';

  @override
  String get stepNotesTitle => 'الخطوة ٧: ملاحظات';

  @override
  String get stepNotesSub => 'هل توجد تعليمات خاصة؟ (اختياري)';

  @override
  String get stepSummaryTitle => 'الخطوة ٨: الملخص';

  @override
  String get stepSummarySub => 'يرجى مراجعة المعلومات قبل الحفظ.';

  @override
  String get medFormTitle => 'شكل الدواء';

  @override
  String get strengthDoseTitle => 'الجرعة / التركيز';

  @override
  String get formCapsule => 'كبسولة';

  @override
  String get formSyrup => 'شراب';

  @override
  String get formCream => 'كريم / مرهم';

  @override
  String get formEyeDrops => 'قطرة عين';

  @override
  String get formEarDrops => 'قطرة أذن';

  @override
  String get formNasal => 'بخاخ أنف';

  @override
  String get formInjection => 'حقنة';

  @override
  String get formOther => 'أخرى';

  @override
  String get durOngoing => 'مستمر (بدون تاريخ انتهاء)';

  @override
  String get durPickCustom => 'اختيار تاريخ انتهاء محدد';

  @override
  String get freqOnce => 'مرة واحدة يومياً';

  @override
  String get freqTwice => 'مرتين يومياً';

  @override
  String get freqThree => '٣ مرات يومياً';

  @override
  String get freqFour => '٤ مرات يومياً';

  @override
  String get freqCustom => 'مخصص';

  @override
  String get scanPreview => 'معاينة المسح';

  @override
  String get scanPrescription => 'مسح الوصفة الطبية';

  @override
  String get scanning => 'جاري المسح...';

  @override
  String get rescanBtn => 'إعادة المسح';

  @override
  String get applyBtn => 'تطبيق';

  @override
  String get fillAllFieldsBtn => 'أكمل جميع الحقول';

  @override
  String get saveChangesBtn => 'حفظ التغييرات';

  @override
  String get addMedBtn => 'إضافة دواء';

  @override
  String get medAddedSuccess => 'تم إضافة الدواء بنجاح';

  @override
  String get medUpdatedSuccess => 'تم تحديث الدواء بنجاح';

  @override
  String get summaryMedName => 'اسم الدواء';

  @override
  String get summaryDose => 'الجرعة';

  @override
  String get summaryDuration => 'المدة';

  @override
  String get summaryFrequency => 'التكرار';

  @override
  String get summaryDays => 'الأيام';

  @override
  String get summaryTimes => 'الأوقات';

  @override
  String get summaryNotes => 'ملاحظات';

  @override
  String get durDays => 'أيام';

  @override
  String get durWeeks => 'أسابيع';

  @override
  String get durMonths => 'أشهر';

  @override
  String durEndsOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get durOngoingShort => 'مستمر';

  @override
  String get durCustomShort => 'مخصص';

  @override
  String durCustomSelected(String date) {
    return 'مخصص: $date';
  }

  @override
  String get orDivider => 'أو';

  @override
  String get scanNotLabelWarning =>
      'هذه الصورة لا تبدو كبطاقة دواء. يرجى التقاط صورة واضحة لملصق الوصفة أو علبة الدواء.';

  @override
  String get scanCouldNotDetect => 'لم يتم اكتشاف:';

  @override
  String get scanFillManually =>
      'يرجى ملء الحقول يدوياً أدناه، أو التقاط صورة أوضح.';

  @override
  String get scanAllDetected =>
      'تم اكتشاف جميع الحقول بنجاح! يرجى التحقق قبل التطبيق.';

  @override
  String get scanMedNameHint => 'مثال: حمض الفيوسيديك';

  @override
  String scanDaysLimitedHintDays(int count) {
    return 'يتم عرض الأيام ضمن مدة $count يوم فقط';
  }

  @override
  String get scanDaysLimitedHintCustom =>
      'يتم عرض الأيام ضمن المدة المخصصة فقط';

  @override
  String get daySunday => 'الأحد';

  @override
  String get dayMonday => 'الاثنين';

  @override
  String get dayTuesday => 'الثلاثاء';

  @override
  String get dayWednesday => 'الأربعاء';

  @override
  String get dayThursday => 'الخميس';

  @override
  String get dayFriday => 'الجمعة';

  @override
  String get daySaturday => 'السبت';

  @override
  String get stepDaysScheduleLabel => 'الجدول اليومي';

  @override
  String stepDaysEveryDayCount(int count) {
    return 'كل يوم ($count أيام)';
  }

  @override
  String get stepDaysAvailable => 'الأيام المتاحة';

  @override
  String get stepDaysSpecific => 'أيام محددة';

  @override
  String stepDaysBasedOnDuration(int count) {
    return 'بناءً على مدة $count يوم، الأيام التالية فقط متاحة.';
  }

  @override
  String get stepDaysBasedOnEndDate =>
      'بناءً على تاريخ الانتهاء المحدد، الأيام التالية فقط متاحة.';

  @override
  String get selectATime => 'اختر وقتاً';

  @override
  String get summaryNotSpecified => 'غير محدد';

  @override
  String summaryDurationDaysUntil(int days, String date) {
    return '$days يوم (حتى $date)';
  }

  @override
  String summaryDurationUntil(String date) {
    return 'حتى $date';
  }
}
