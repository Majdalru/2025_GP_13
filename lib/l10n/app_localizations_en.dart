// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Caregiver';

  @override
  String get login => 'Log in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get caregiver => 'Caregiver';

  @override
  String get elderly => 'Elderly';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get shortPassword => 'Min 6 characters';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get next => 'Next';

  @override
  String get dontHaveAccount => 'Don’t have an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get signInFailed => 'Sign-in failed';

  @override
  String get signInGenericError =>
      'Unable to sign in. Please check your email, password, or account type.';

  @override
  String get invalidEmailAuth => 'Invalid email address.';

  @override
  String get tooManyRequestsAuth =>
      'Too many attempts. Please try again later.';

  @override
  String get accountDisabledAuth => 'This account has been disabled.';

  @override
  String get networkErrorAuth =>
      'Network error. Check your internet connection.';

  @override
  String get ok => 'OK';

  @override
  String get noProfileSelected =>
      'No elderly profile selected.\n\nPlease link a profile using the drawer menu.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get browse => 'Browse';

  @override
  String get home => 'Home';

  @override
  String get medicationHistory => 'Medication History';

  @override
  String get clearAllHistory => 'Clear All History?';

  @override
  String get confirmClearHistory =>
      'This will permanently remove all medication history records.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearAll => 'Clear All';

  @override
  String get historyClearedToast => 'History cleared';

  @override
  String get clearAllHistoryMenu => 'Clear All History';

  @override
  String get noMedicationHistory => 'No medication history';

  @override
  String get noMedicationHistoryDesc =>
      'Deleted and expired medications\nwill appear here';

  @override
  String get removeFromHistory => 'Remove from History?';

  @override
  String confirmRemoveFromHistory(String medName) {
    return 'Remove \"$medName\" from history?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get recoverMedication => 'Recover Medication?';

  @override
  String confirmRecoverMedication(String medName) {
    return 'Add \"$medName\" back to your active medications?';
  }

  @override
  String get recover => 'Recover';

  @override
  String recoveredSuccessfully(String medName) {
    return '\"$medName\" recovered successfully';
  }

  @override
  String get failedToRecover => 'Failed to recover medication';

  @override
  String get expired => 'Expired';

  @override
  String get deleted => 'Deleted';

  @override
  String get unknownDate => 'Unknown date';

  @override
  String get frequency => 'Frequency';

  @override
  String get dose => 'Dose';

  @override
  String get days => 'Days';

  @override
  String get times => 'Times';

  @override
  String get endDate => 'End Date';

  @override
  String get notes => 'Notes';

  @override
  String get recoverMedicationButton => 'Recover Medication';

  @override
  String actionOnDate(String action, String date) {
    return '$action on $date';
  }

  @override
  String get guest => 'Guest';

  @override
  String get caregiverRole => 'Caregiver';

  @override
  String get elderlyRole => 'Elderly';

  @override
  String get settings => 'Settings';

  @override
  String get linkedProfiles => 'Linked Profiles';

  @override
  String get link => 'Link';

  @override
  String get noProfilesLinkedYet => 'No profiles linked yet.';

  @override
  String get logOut => 'Log out';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get doYouReallyWantToLogOut => 'Do you really want to log out?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get unlink => 'Unlink';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String confirmDeleteProfile(String profileName) {
    return 'Do you want to Delete $profileName from your account?';
  }

  @override
  String get errorNotLoggedIn => 'Error: You are not logged in.';

  @override
  String profileUnlinked(String profileName) {
    return 'Profile $profileName unlinked';
  }

  @override
  String errorUnlinkingProfile(String error) {
    return 'Error unlinking profile: $error';
  }

  @override
  String get editInfo => 'Edit Info';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get selectGender => 'Select gender';

  @override
  String get mobile => 'Mobile (05XXXXXXXX)';

  @override
  String get requiredError => 'Required';

  @override
  String get mustStartWith05 => 'Must start with 05';

  @override
  String get mustBe10Digits => 'Must be 10 digits';

  @override
  String get mobileInUse => 'Mobile in use';

  @override
  String get mobileInUseMsg => 'This mobile number is already in use.';

  @override
  String get informationUpdated => 'Information updated';

  @override
  String errorUpdatingInfo(String error) {
    return 'Error updating info: $error';
  }

  @override
  String get profileLinked => 'Profile linked!';

  @override
  String get profileLinkedMsg =>
      'Profile linked successfully. You can now manage this elderly user from your dashboard.';

  @override
  String get linkElderlyViaCode => 'Link Elderly via Code';

  @override
  String get enter6Characters => 'Enter 6 characters';

  @override
  String get invalidOrExpiredCode => 'Invalid or expired code.';

  @override
  String get invalidCodeData => 'Invalid code data.';

  @override
  String get codeHasExpired => 'Code has expired.';

  @override
  String anErrorOccurred(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get summary => 'Summary';

  @override
  String errorLoading(String error) {
    return 'Error: $error';
  }

  @override
  String get noMedicationsFound => 'No medications found';

  @override
  String onTimeLateMissed(int onTime, int late, int missed) {
    return 'On time: $onTime   Late: $late   Missed: $missed';
  }

  @override
  String get noDosesForThisMonthYet => 'No doses for this month yet';

  @override
  String get medicationsForThisElderly => 'Medications for this elderly';

  @override
  String get byDay => 'By day';

  @override
  String get byMedication => 'By medication';

  @override
  String scheduledTime(String time) {
    return 'Scheduled $time';
  }

  @override
  String takenTime(String time) {
    return ' • Taken $time';
  }

  @override
  String get missedOverdue => ' • Missed (>10m overdue)';

  @override
  String get takenLateStatus => ' • Taken late';

  @override
  String get noLogsForThisDay => 'No logs for this day';

  @override
  String get selectDayToViewDetails => 'Select a day to view details';

  @override
  String get reminder => 'Reminder!';

  @override
  String elderlyMissedDoses(String name, int count) {
    return '$name has missed $count missed dose(s)!';
  }

  @override
  String youMissedDoses(int count) {
    return 'You have $count missed medication(s)!';
  }

  @override
  String get upcoming => 'Upcoming';

  @override
  String get nextUp => 'Next Up';

  @override
  String get laterToday => 'Later Today';

  @override
  String get taken => 'Taken';

  @override
  String get missedTitle => 'Missed';

  @override
  String get medicationTakenOnTime => 'The medication was taken on time ✓';

  @override
  String get medicationTakenLate => 'The medication was taken late';

  @override
  String undoSuccessful(String medName) {
    return 'Undo successful for $medName. Notifications rescheduled.';
  }

  @override
  String get noMedicationsInCategory =>
      'No medications in this category today.';

  @override
  String get takenOnTime => 'Taken on time';

  @override
  String get takenLate => 'Taken late';

  @override
  String get missed => 'Missed';

  @override
  String get pastDue => 'Past due';

  @override
  String get dueNow => 'Due now';

  @override
  String get at => 'at';

  @override
  String get markAsTakenLate => 'Mark as Taken Late';

  @override
  String get markAsTaken => 'Mark as Taken';

  @override
  String get undo => 'Undo';

  @override
  String get favorites => 'Favorites';

  @override
  String get medications => 'Medications';

  @override
  String get addNewMedication => 'Add New Medication';

  @override
  String errorDeletingMedication(String error) {
    return 'Error deleting medication: $error';
  }

  @override
  String get errorLoadingMedications => 'Error loading medications.';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String errorLoadingVideo(String error) {
    return 'Error loading video: $error';
  }

  @override
  String errorLoadingAudio(String error) {
    return 'Error loading audio: $error';
  }

  @override
  String get media => 'Media';

  @override
  String get searchFavorites => 'Search favorites...';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get voiceCommandFailed => 'Voice command failed, please try again.';

  @override
  String get health => 'Health';

  @override
  String get story => 'Story';

  @override
  String get quran => 'Quran';

  @override
  String get searchForAudio => 'Search for audio...';

  @override
  String get addedToFavorites => 'Added to Favorites successfully';

  @override
  String get removedFromFavorites => 'Removed from Favorites';

  @override
  String get noValidYoutubeUrl => 'No valid YouTube URL provided.';

  @override
  String get emergencyAlert => 'Emergency alert';

  @override
  String todayLabel(Object date) {
    return 'Today • $date';
  }

  @override
  String get goToMedications => 'Go to Medications';

  @override
  String get noUpcomingMeds => 'No upcoming meds';

  @override
  String get monthlyOverview => 'Monthly Overview';

  @override
  String viewingDailyMeds(Object name) {
    return 'You are viewing $name\'s daily meds.';
  }

  @override
  String get onTimeStatus => 'On time';

  @override
  String get missedStatus => 'Missed';

  @override
  String get howToReadPieChart => 'How to read this pie chart?';

  @override
  String get pieChartHelpBody =>
      '• Each slice = group of doses this month\n• Green: doses taken on time\n• Yellow: doses taken late\n• Red: doses that were missed completely\n\nThe size of each slice shows its percentage from ALL doses.';

  @override
  String get howToReadBarChart => 'How to read this daily bar chart?';

  @override
  String get barChartHelpBody =>
      '• Each bar = one day of this month\n• Bar height = total number of doses that day\n• Green part = doses taken on time\n• Yellow part = doses taken late\n• Red part = missed doses\n\nThis helps you see which days had more missed or late doses.';

  @override
  String get howToReadWeeklyTrend => 'How to read weekly trend?';

  @override
  String get weeklyTrendHelpBody =>
      '• Each card = one week in this month\n• It shows how many doses were on time, late, or missed\n• The percentage on the right is overall adherence for that week.\n\nGreen weeks = very good adherence, red weeks = need attention.';

  @override
  String get gotIt => 'Got it';

  @override
  String summaryForMed(Object medName) {
    return 'Summary • $medName';
  }

  @override
  String get noDosesThisMonth => 'No doses for this month yet.';

  @override
  String get statusPie => 'Status pie';

  @override
  String get dailyBar => 'Daily bar';

  @override
  String get weeklyTrend => 'Weekly trend';

  @override
  String get monthlyAdherence => 'Monthly adherence';

  @override
  String get doseStatusThisMonth => 'Dose status (this month)';

  @override
  String get dailyDosesByStatus => 'Daily doses by status (stacked bar)';

  @override
  String get noDailyData => 'No daily data available for this month.';

  @override
  String get noDataWeeklyTrend => 'No data available for weekly trend.';

  @override
  String get notEnoughDataWeekly => 'Not enough data for weekly trend.';

  @override
  String get weeklyAdherenceTrend => 'Weekly adherence trend';

  @override
  String weekNumber(Object week) {
    return 'Week $week';
  }

  @override
  String dayLabel(Object day) {
    return 'Day: $day';
  }

  @override
  String daysRangeLabel(Object startDay, Object endDay) {
    return 'Days: $startDay–$endDay';
  }

  @override
  String get greatAdherence => 'Great adherence 👏';

  @override
  String get moderateAdherence => 'Moderate adherence – can be improved 🙂';

  @override
  String get lowAdherence => 'Low adherence – needs attention ⚠️';

  @override
  String get medicationDeletedSuccessfully => 'Medication deleted successfully';

  @override
  String get medsFor => 'Meds for';

  @override
  String get medicationList => 'Medication List';

  @override
  String get todaysMeds => 'Today\'s Meds';

  @override
  String get medList => 'Med list';

  @override
  String get confirmDeletion => 'Confirm Deletion';

  @override
  String get areYouSureToDelete => 'Are you sure you want to delete';

  @override
  String get rescan => 'Rescan';

  @override
  String get scanFailed => 'Scan failed';

  @override
  String get editMedication => 'Edit Medication';

  @override
  String get step1MedicineName => 'Step 1: Medicine Name';

  @override
  String get whatMedicationDoYouNeedToTake =>
      'What medication do you need to take?';

  @override
  String get medicineName => 'Medicine Name';

  @override
  String get manageMedicationList => 'Manage medication list';

  @override
  String get manageAccess => 'Manage access';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get shareWithElderly => 'Share with Elderly';

  @override
  String get shareLifeUpdates => 'Share your life updates with your loved';

  @override
  String get pleaseSelectElderlyProfileFirst =>
      'Please select an elderly profile from the drawer menu first.';

  @override
  String get pleaseSelectElderlyProfile =>
      'Please select an elderly profile first.';

  @override
  String get elderlyInfo => 'Elderly Info';

  @override
  String get userFallback => 'User';

  @override
  String get na => 'N/A';

  @override
  String get newCaregiverLinked =>
      'A new caregiver has been linked to your profile.';

  @override
  String get caregiverUnlinked =>
      'A caregiver has been unlinked from your profile.';

  @override
  String errorLoadingProfile(String error) {
    return 'Error loading profile: $error';
  }

  @override
  String get informationUpdatedSuccessfully =>
      'Information updated successfully';

  @override
  String get voiceOpeningMedications => 'Opening your medications page.';

  @override
  String get voiceAccountNotFound =>
      'I could not find your account. Please log in again.';

  @override
  String get voiceAddMedication =>
      'Okay, I will help you add a new medication.';

  @override
  String get voiceEditMedication =>
      'Okay, let us edit one of your medications.';

  @override
  String get voiceDeleteMedication =>
      'Okay, let us choose which medication to delete.';

  @override
  String get voiceOpeningMedia => 'Opening your media page.';

  @override
  String get voiceAlreadyHome => 'You are already on the home page.';

  @override
  String get voiceSosPreamble =>
      'Emergency mode. Here we will trigger the SOS flow.';

  @override
  String get emergencyTitle => 'Emergency';

  @override
  String get emergencyFlowDesc =>
      'Here we will trigger the SOS flow (calling caregiver, sending alert, etc.).';

  @override
  String get voiceSettingsNotReady =>
      'Settings page is not ready yet. In the future, I will open it for you from here.';

  @override
  String helloUser(String name) {
    return 'Hello $name';
  }

  @override
  String get sos => 'SOS';

  @override
  String get errorNotLoggedIn2 => 'Error: Not logged in.';

  @override
  String get everyDay => 'Every day';

  @override
  String get mustBeLoggedInToSave => 'You must be logged in to save.';

  @override
  String errorUpdatingMedication(String error) {
    return 'Error updating medication: $error';
  }

  @override
  String errorSavingMedication(String error) {
    return 'Error saving medication: $error';
  }

  @override
  String get change => 'Change';

  @override
  String get addAnotherTime => 'Add another time';

  @override
  String get clearAllTimes => 'Clear All Times';

  @override
  String get pleaseSelectAllRequiredTimes =>
      'Please select all required times.';

  @override
  String get egPanadol => 'e.g. Panadol';

  @override
  String get optionalInstructions => 'Optional instructions...';

  @override
  String timeNumber(int index) {
    return 'Time $index';
  }

  @override
  String get location => 'Location';

  @override
  String get liveLocation => 'Live location & last seen';

  @override
  String get save => 'Save';

  @override
  String get caregivers => 'Caregivers';

  @override
  String get generateCode => 'Generate Code';

  @override
  String errorGeneratingCode(String error) {
    return 'Error generating code: $error';
  }

  @override
  String get youNeedToBeLoggedIn => 'You need to be logged in.';
}
