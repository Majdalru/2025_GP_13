import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @caregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get caregiver;

  /// No description provided for @elderly.
  ///
  /// In en, this message translates to:
  /// **'Elderly'**
  String get elderly;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don’t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get signInFailed;

  /// No description provided for @signInGenericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Please check your email, password, or account type.'**
  String get signInGenericError;

  /// No description provided for @invalidEmailAuth.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get invalidEmailAuth;

  /// No description provided for @tooManyRequestsAuth.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyRequestsAuth;

  /// No description provided for @accountDisabledAuth.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get accountDisabledAuth;

  /// No description provided for @networkErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection.'**
  String get networkErrorAuth;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noProfileSelected.
  ///
  /// In en, this message translates to:
  /// **'No elderly profile selected.\n\nPlease link a profile using the drawer menu.'**
  String get noProfileSelected;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @medicationHistory.
  ///
  /// In en, this message translates to:
  /// **'Medication History'**
  String get medicationHistory;

  /// No description provided for @clearAllHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear All History?'**
  String get clearAllHistory;

  /// No description provided for @confirmClearHistory.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove all medication history records.'**
  String get confirmClearHistory;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @historyClearedToast.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyClearedToast;

  /// No description provided for @clearAllHistoryMenu.
  ///
  /// In en, this message translates to:
  /// **'Clear All History'**
  String get clearAllHistoryMenu;

  /// No description provided for @noMedicationHistory.
  ///
  /// In en, this message translates to:
  /// **'No medication history'**
  String get noMedicationHistory;

  /// No description provided for @noMedicationHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Deleted and expired medications\nwill appear here'**
  String get noMedicationHistoryDesc;

  /// No description provided for @removeFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from History?'**
  String get removeFromHistory;

  /// No description provided for @confirmRemoveFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{medName}\" from history?'**
  String confirmRemoveFromHistory(String medName);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @recoverMedication.
  ///
  /// In en, this message translates to:
  /// **'Recover Medication?'**
  String get recoverMedication;

  /// No description provided for @confirmRecoverMedication.
  ///
  /// In en, this message translates to:
  /// **'Add \"{medName}\" back to your active medications?'**
  String confirmRecoverMedication(String medName);

  /// No description provided for @recover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get recover;

  /// No description provided for @recoveredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'\"{medName}\" recovered successfully'**
  String recoveredSuccessfully(String medName);

  /// No description provided for @failedToRecover.
  ///
  /// In en, this message translates to:
  /// **'Failed to recover medication'**
  String get failedToRecover;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get unknownDate;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @dose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get dose;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @recoverMedicationButton.
  ///
  /// In en, this message translates to:
  /// **'Recover Medication'**
  String get recoverMedicationButton;

  /// No description provided for @actionOnDate.
  ///
  /// In en, this message translates to:
  /// **'{action} on {date}'**
  String actionOnDate(String action, String date);

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @caregiverRole.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get caregiverRole;

  /// No description provided for @elderlyRole.
  ///
  /// In en, this message translates to:
  /// **'Elderly'**
  String get elderlyRole;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @linkedProfiles.
  ///
  /// In en, this message translates to:
  /// **'Linked Profiles'**
  String get linkedProfiles;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @noProfilesLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'No profiles linked yet.'**
  String get noProfilesLinkedYet;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @doYouReallyWantToLogOut.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to log out?'**
  String get doYouReallyWantToLogOut;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @confirmDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Do you want to Delete {profileName} from your account?'**
  String confirmDeleteProfile(String profileName);

  /// No description provided for @errorNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Error: You are not logged in.'**
  String get errorNotLoggedIn;

  /// No description provided for @profileUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Profile {profileName} unlinked'**
  String profileUnlinked(String profileName);

  /// No description provided for @errorUnlinkingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error unlinking profile: {error}'**
  String errorUnlinkingProfile(String error);

  /// No description provided for @editInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Info'**
  String get editInfo;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get selectGender;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile (05XXXXXXXX)'**
  String get mobile;

  /// No description provided for @requiredError.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredError;

  /// No description provided for @mustStartWith05.
  ///
  /// In en, this message translates to:
  /// **'Must start with 05'**
  String get mustStartWith05;

  /// No description provided for @mustBe10Digits.
  ///
  /// In en, this message translates to:
  /// **'Must be 10 digits'**
  String get mustBe10Digits;

  /// No description provided for @mobileInUse.
  ///
  /// In en, this message translates to:
  /// **'Mobile in use'**
  String get mobileInUse;

  /// No description provided for @mobileInUseMsg.
  ///
  /// In en, this message translates to:
  /// **'This mobile number is already in use.'**
  String get mobileInUseMsg;

  /// No description provided for @informationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Information updated'**
  String get informationUpdated;

  /// No description provided for @errorUpdatingInfo.
  ///
  /// In en, this message translates to:
  /// **'Error updating info: {error}'**
  String errorUpdatingInfo(String error);

  /// No description provided for @profileLinked.
  ///
  /// In en, this message translates to:
  /// **'Profile linked!'**
  String get profileLinked;

  /// No description provided for @profileLinkedMsg.
  ///
  /// In en, this message translates to:
  /// **'Profile linked successfully. You can now manage this elderly user from your dashboard.'**
  String get profileLinkedMsg;

  /// No description provided for @linkElderlyViaCode.
  ///
  /// In en, this message translates to:
  /// **'Link Elderly via Code'**
  String get linkElderlyViaCode;

  /// No description provided for @enter6Characters.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 characters'**
  String get enter6Characters;

  /// No description provided for @invalidOrExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code.'**
  String get invalidOrExpiredCode;

  /// No description provided for @invalidCodeData.
  ///
  /// In en, this message translates to:
  /// **'Invalid code data.'**
  String get invalidCodeData;

  /// No description provided for @codeHasExpired.
  ///
  /// In en, this message translates to:
  /// **'Code has expired.'**
  String get codeHasExpired;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String anErrorOccurred(String error);

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorLoading(String error);

  /// No description provided for @noMedicationsFound.
  ///
  /// In en, this message translates to:
  /// **'No medications found'**
  String get noMedicationsFound;

  /// No description provided for @onTimeLateMissed.
  ///
  /// In en, this message translates to:
  /// **'On time: {onTime}   Late: {late}   Missed: {missed}'**
  String onTimeLateMissed(int onTime, int late, int missed);

  /// No description provided for @noDosesForThisMonthYet.
  ///
  /// In en, this message translates to:
  /// **'No doses for this month yet'**
  String get noDosesForThisMonthYet;

  /// No description provided for @medicationsForThisElderly.
  ///
  /// In en, this message translates to:
  /// **'Medications for this elderly'**
  String get medicationsForThisElderly;

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get byDay;

  /// No description provided for @byMedication.
  ///
  /// In en, this message translates to:
  /// **'By medication'**
  String get byMedication;

  /// No description provided for @scheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {time}'**
  String scheduledTime(String time);

  /// No description provided for @takenTime.
  ///
  /// In en, this message translates to:
  /// **' • Taken {time}'**
  String takenTime(String time);

  /// No description provided for @missedOverdue.
  ///
  /// In en, this message translates to:
  /// **' • Missed (>10m overdue)'**
  String get missedOverdue;

  /// No description provided for @takenLateStatus.
  ///
  /// In en, this message translates to:
  /// **' • Taken late'**
  String get takenLateStatus;

  /// No description provided for @noLogsForThisDay.
  ///
  /// In en, this message translates to:
  /// **'No logs for this day'**
  String get noLogsForThisDay;

  /// No description provided for @selectDayToViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a day to view details'**
  String get selectDayToViewDetails;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder!'**
  String get reminder;

  /// No description provided for @elderlyMissedDoses.
  ///
  /// In en, this message translates to:
  /// **'{name} has missed {count} missed dose(s)!'**
  String elderlyMissedDoses(String name, int count);

  /// No description provided for @youMissedDoses.
  ///
  /// In en, this message translates to:
  /// **'You have {count} missed medication(s)!'**
  String youMissedDoses(int count);

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get nextUp;

  /// No description provided for @laterToday.
  ///
  /// In en, this message translates to:
  /// **'Later Today'**
  String get laterToday;

  /// No description provided for @taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken;

  /// No description provided for @missedTitle.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missedTitle;

  /// No description provided for @medicationTakenOnTime.
  ///
  /// In en, this message translates to:
  /// **'The medication was taken on time ✓'**
  String get medicationTakenOnTime;

  /// No description provided for @medicationTakenLate.
  ///
  /// In en, this message translates to:
  /// **'The medication was taken late'**
  String get medicationTakenLate;

  /// No description provided for @undoSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Undo successful for {medName}. Notifications rescheduled.'**
  String undoSuccessful(String medName);

  /// No description provided for @noMedicationsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No medications in this category today.'**
  String get noMedicationsInCategory;

  /// No description provided for @takenOnTime.
  ///
  /// In en, this message translates to:
  /// **'Taken on time'**
  String get takenOnTime;

  /// No description provided for @takenLate.
  ///
  /// In en, this message translates to:
  /// **'Taken late'**
  String get takenLate;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @pastDue.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get pastDue;

  /// No description provided for @dueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get dueNow;

  /// No description provided for @at.
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get at;

  /// No description provided for @markAsTakenLate.
  ///
  /// In en, this message translates to:
  /// **'Mark as Taken Late'**
  String get markAsTakenLate;

  /// No description provided for @markAsTaken.
  ///
  /// In en, this message translates to:
  /// **'Mark as Taken'**
  String get markAsTaken;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @medications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// No description provided for @addNewMedication.
  ///
  /// In en, this message translates to:
  /// **'Add New Medication'**
  String get addNewMedication;

  /// No description provided for @errorDeletingMedication.
  ///
  /// In en, this message translates to:
  /// **'Error deleting medication: {error}'**
  String errorDeletingMedication(String error);

  /// No description provided for @errorLoadingMedications.
  ///
  /// In en, this message translates to:
  /// **'Error loading medications.'**
  String get errorLoadingMedications;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @errorLoadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Error loading video: {error}'**
  String errorLoadingVideo(String error);

  /// No description provided for @errorLoadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Error loading audio: {error}'**
  String errorLoadingAudio(String error);

  /// No description provided for @searchFavorites.
  ///
  /// In en, this message translates to:
  /// **'Search favorites...'**
  String get searchFavorites;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @searchForAudio.
  ///
  /// In en, this message translates to:
  /// **'Search for audio...'**
  String get searchForAudio;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to Favorites successfully'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get removedFromFavorites;

  /// No description provided for @noValidYoutubeUrl.
  ///
  /// In en, this message translates to:
  /// **'No valid YouTube URL provided.'**
  String get noValidYoutubeUrl;

  /// No description provided for @emergencyAlert.
  ///
  /// In en, this message translates to:
  /// **'Emergency alert'**
  String get emergencyAlert;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today • {date}'**
  String todayLabel(Object date);

  /// No description provided for @goToMedications.
  ///
  /// In en, this message translates to:
  /// **'Go to Medications'**
  String get goToMedications;

  /// No description provided for @noUpcomingMeds.
  ///
  /// In en, this message translates to:
  /// **'No upcoming meds'**
  String get noUpcomingMeds;

  /// No description provided for @monthlyOverview.
  ///
  /// In en, this message translates to:
  /// **'Monthly Overview'**
  String get monthlyOverview;

  /// No description provided for @viewingDailyMeds.
  ///
  /// In en, this message translates to:
  /// **'You are viewing {name}\'s daily meds.'**
  String viewingDailyMeds(Object name);

  /// No description provided for @onTimeStatus.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get onTimeStatus;

  /// No description provided for @missedStatus.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missedStatus;

  /// No description provided for @howToReadPieChart.
  ///
  /// In en, this message translates to:
  /// **'How to read this pie chart?'**
  String get howToReadPieChart;

  /// No description provided for @pieChartHelpBody.
  ///
  /// In en, this message translates to:
  /// **'• Each slice = group of doses this month\n• Green: doses taken on time\n• Yellow: doses taken late\n• Red: doses that were missed completely\n\nThe size of each slice shows its percentage from ALL doses.'**
  String get pieChartHelpBody;

  /// No description provided for @howToReadBarChart.
  ///
  /// In en, this message translates to:
  /// **'How to read this daily bar chart?'**
  String get howToReadBarChart;

  /// No description provided for @barChartHelpBody.
  ///
  /// In en, this message translates to:
  /// **'• Each bar = one day of this month\n• Bar height = total number of doses that day\n• Green part = doses taken on time\n• Yellow part = doses taken late\n• Red part = missed doses\n\nThis helps you see which days had more missed or late doses.'**
  String get barChartHelpBody;

  /// No description provided for @howToReadWeeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'How to read weekly trend?'**
  String get howToReadWeeklyTrend;

  /// No description provided for @weeklyTrendHelpBody.
  ///
  /// In en, this message translates to:
  /// **'• Each card = one week in this month\n• It shows how many doses were on time, late, or missed\n• The percentage on the right is overall adherence for that week.\n\nGreen weeks = very good adherence, red weeks = need attention.'**
  String get weeklyTrendHelpBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @summaryForMed.
  ///
  /// In en, this message translates to:
  /// **'Summary • {medName}'**
  String summaryForMed(Object medName);

  /// No description provided for @noDosesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No doses for this month yet.'**
  String get noDosesThisMonth;

  /// No description provided for @statusPie.
  ///
  /// In en, this message translates to:
  /// **'Status pie'**
  String get statusPie;

  /// No description provided for @dailyBar.
  ///
  /// In en, this message translates to:
  /// **'Daily bar'**
  String get dailyBar;

  /// No description provided for @weeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly trend'**
  String get weeklyTrend;

  /// No description provided for @monthlyAdherence.
  ///
  /// In en, this message translates to:
  /// **'Monthly adherence'**
  String get monthlyAdherence;

  /// No description provided for @doseStatusThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Dose status (this month)'**
  String get doseStatusThisMonth;

  /// No description provided for @dailyDosesByStatus.
  ///
  /// In en, this message translates to:
  /// **'Daily doses by status (stacked bar)'**
  String get dailyDosesByStatus;

  /// No description provided for @noDailyData.
  ///
  /// In en, this message translates to:
  /// **'No daily data available for this month.'**
  String get noDailyData;

  /// No description provided for @noDataWeeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'No data available for weekly trend.'**
  String get noDataWeeklyTrend;

  /// No description provided for @notEnoughDataWeekly.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for weekly trend.'**
  String get notEnoughDataWeekly;

  /// No description provided for @weeklyAdherenceTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly adherence trend'**
  String get weeklyAdherenceTrend;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekNumber(Object week);

  /// No description provided for @dayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day: {day}'**
  String dayLabel(Object day);

  /// No description provided for @daysRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Days: {startDay}–{endDay}'**
  String daysRangeLabel(Object startDay, Object endDay);

  /// No description provided for @greatAdherence.
  ///
  /// In en, this message translates to:
  /// **'Great adherence 👏'**
  String get greatAdherence;

  /// No description provided for @moderateAdherence.
  ///
  /// In en, this message translates to:
  /// **'Moderate adherence – can be improved 🙂'**
  String get moderateAdherence;

  /// No description provided for @lowAdherence.
  ///
  /// In en, this message translates to:
  /// **'Low adherence – needs attention ⚠️'**
  String get lowAdherence;

  /// No description provided for @medicationDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Medication deleted successfully'**
  String get medicationDeletedSuccessfully;

  /// No description provided for @medsFor.
  ///
  /// In en, this message translates to:
  /// **'Meds for'**
  String get medsFor;

  /// No description provided for @medicationList.
  ///
  /// In en, this message translates to:
  /// **'Medication List'**
  String get medicationList;

  /// No description provided for @todaysMeds.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Meds'**
  String get todaysMeds;

  /// No description provided for @medList.
  ///
  /// In en, this message translates to:
  /// **'Med list'**
  String get medList;

  /// No description provided for @confirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletion;

  /// No description provided for @areYouSureToDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get areYouSureToDelete;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanFailed;

  /// No description provided for @editMedication.
  ///
  /// In en, this message translates to:
  /// **'Edit Medication'**
  String get editMedication;

  /// No description provided for @step1MedicineName.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Medicine Name'**
  String get step1MedicineName;

  /// No description provided for @whatMedicationDoYouNeedToTake.
  ///
  /// In en, this message translates to:
  /// **'What medication do you need to take?'**
  String get whatMedicationDoYouNeedToTake;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine Name'**
  String get medicineName;

  /// No description provided for @manageMedicationList.
  ///
  /// In en, this message translates to:
  /// **'Manage medication list'**
  String get manageMedicationList;

  /// No description provided for @manageAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage access'**
  String get manageAccess;

  /// Verification Code label
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @shareWithElderly.
  ///
  /// In en, this message translates to:
  /// **'Share with Elderly'**
  String get shareWithElderly;

  /// No description provided for @shareLifeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Share your life updates with your loved'**
  String get shareLifeUpdates;

  /// No description provided for @pleaseSelectElderlyProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select an elderly profile from the drawer menu first.'**
  String get pleaseSelectElderlyProfileFirst;

  /// No description provided for @pleaseSelectElderlyProfile.
  ///
  /// In en, this message translates to:
  /// **'Please select an elderly profile first.'**
  String get pleaseSelectElderlyProfile;

  /// No description provided for @elderlyInfo.
  ///
  /// In en, this message translates to:
  /// **'Elderly Info'**
  String get elderlyInfo;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @na.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get na;

  /// No description provided for @newCaregiverLinked.
  ///
  /// In en, this message translates to:
  /// **'A new caregiver has been linked to your profile.'**
  String get newCaregiverLinked;

  /// No description provided for @caregiverUnlinked.
  ///
  /// In en, this message translates to:
  /// **'A caregiver has been unlinked from your profile.'**
  String get caregiverUnlinked;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile: {error}'**
  String errorLoadingProfile(String error);

  /// No description provided for @informationUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Information updated successfully'**
  String get informationUpdatedSuccessfully;

  /// No description provided for @voiceOpeningMedications.
  ///
  /// In en, this message translates to:
  /// **'Opening your medications page.'**
  String get voiceOpeningMedications;

  /// No description provided for @voiceAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'I could not find your account. Please log in again.'**
  String get voiceAccountNotFound;

  /// No description provided for @voiceAddMedication.
  ///
  /// In en, this message translates to:
  /// **'Okay, I will help you add a new medication.'**
  String get voiceAddMedication;

  /// No description provided for @voiceEditMedication.
  ///
  /// In en, this message translates to:
  /// **'Okay, let us edit one of your medications.'**
  String get voiceEditMedication;

  /// No description provided for @voiceDeleteMedication.
  ///
  /// In en, this message translates to:
  /// **'Okay, let us choose which medication to delete.'**
  String get voiceDeleteMedication;

  /// No description provided for @voiceOpeningMedia.
  ///
  /// In en, this message translates to:
  /// **'Opening your media page.'**
  String get voiceOpeningMedia;

  /// No description provided for @voiceAlreadyHome.
  ///
  /// In en, this message translates to:
  /// **'You are already on the home page.'**
  String get voiceAlreadyHome;

  /// No description provided for @voiceSosPreamble.
  ///
  /// In en, this message translates to:
  /// **'Emergency mode. Here we will trigger the SOS flow.'**
  String get voiceSosPreamble;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyTitle;

  /// No description provided for @emergencyFlowDesc.
  ///
  /// In en, this message translates to:
  /// **'Here we will trigger the SOS flow (calling caregiver, sending alert, etc.).'**
  String get emergencyFlowDesc;

  /// No description provided for @voiceSettingsNotReady.
  ///
  /// In en, this message translates to:
  /// **'Settings page is not ready yet. In the future, I will open it for you from here.'**
  String get voiceSettingsNotReady;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String helloUser(Object name);

  /// No description provided for @sos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sos;

  /// No description provided for @errorNotLoggedIn2.
  ///
  /// In en, this message translates to:
  /// **'Error: Not logged in.'**
  String get errorNotLoggedIn2;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @mustBeLoggedInToSave.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to save.'**
  String get mustBeLoggedInToSave;

  /// No description provided for @errorUpdatingMedication.
  ///
  /// In en, this message translates to:
  /// **'Error updating medication: {error}'**
  String errorUpdatingMedication(String error);

  /// No description provided for @errorSavingMedication.
  ///
  /// In en, this message translates to:
  /// **'Error saving medication: {error}'**
  String errorSavingMedication(String error);

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @addAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Add another time'**
  String get addAnotherTime;

  /// No description provided for @clearAllTimes.
  ///
  /// In en, this message translates to:
  /// **'Clear All Times'**
  String get clearAllTimes;

  /// No description provided for @pleaseSelectAllRequiredTimes.
  ///
  /// In en, this message translates to:
  /// **'Please select all required times.'**
  String get pleaseSelectAllRequiredTimes;

  /// No description provided for @egPanadol.
  ///
  /// In en, this message translates to:
  /// **'e.g. Panadol'**
  String get egPanadol;

  /// No description provided for @optionalInstructions.
  ///
  /// In en, this message translates to:
  /// **'Optional instructions...'**
  String get optionalInstructions;

  /// No description provided for @timeNumber.
  ///
  /// In en, this message translates to:
  /// **'Time {index}'**
  String timeNumber(int index);

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @liveLocation.
  ///
  /// In en, this message translates to:
  /// **'Live location & last seen'**
  String get liveLocation;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @caregivers.
  ///
  /// In en, this message translates to:
  /// **'Caregivers'**
  String get caregivers;

  /// No description provided for @generateCode.
  ///
  /// In en, this message translates to:
  /// **'Generate Code'**
  String get generateCode;

  /// No description provided for @errorGeneratingCode.
  ///
  /// In en, this message translates to:
  /// **'Error generating code: {error}'**
  String errorGeneratingCode(String error);

  /// No description provided for @youNeedToBeLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You need to be logged in.'**
  String get youNeedToBeLoggedIn;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'Email already in use'**
  String get emailAlreadyInUse;

  /// No description provided for @phoneAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Phone number already used'**
  String get phoneAlreadyUsed;

  /// No description provided for @accountCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created ✅'**
  String get accountCreatedSuccess;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get invalidEmailAddress;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Weak password.'**
  String get weakPassword;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @caregiverSignUp.
  ///
  /// In en, this message translates to:
  /// **'Caregiver Sign Up'**
  String get caregiverSignUp;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @enterValidSaudiNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Saudi number (05XXXXXXXX)'**
  String get enterValidSaudiNumber;

  /// No description provided for @min6Chars.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get min6Chars;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @elderlySignUp.
  ///
  /// In en, this message translates to:
  /// **'Elderly Sign Up'**
  String get elderlySignUp;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email.'**
  String get invalidEmail;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check connection.'**
  String get networkError;

  /// No description provided for @stepXofY.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepXofY(int step, int total);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Account Email'**
  String get accountEmail;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personalInfo;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfo;

  /// No description provided for @phoneStartWith05.
  ///
  /// In en, this message translates to:
  /// **'Phone number must start with 05'**
  String get phoneStartWith05;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account Security'**
  String get accountSecurity;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent'**
  String get emailSent;

  /// No description provided for @passwordResetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'A password reset link has been sent to your email.'**
  String get passwordResetLinkSent;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @willSendPasswordResetLink.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a password reset link to your email.'**
  String get willSendPasswordResetLink;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get lastUpdate;

  /// No description provided for @refreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh location'**
  String get refreshLocation;

  /// No description provided for @videoSharedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Video shared successfully!'**
  String get videoSharedSuccessfully;

  /// No description provided for @failedToUploadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload video'**
  String get failedToUploadVideo;

  /// No description provided for @errorSharingVideo.
  ///
  /// In en, this message translates to:
  /// **'Error sharing video: {error}'**
  String errorSharingVideo(String error);

  /// No description provided for @errorStartingRecording.
  ///
  /// In en, this message translates to:
  /// **'Error starting recording: {error}'**
  String errorStartingRecording(String error);

  /// No description provided for @errorStoppingRecording.
  ///
  /// In en, this message translates to:
  /// **'Error stopping recording: {error}'**
  String errorStoppingRecording(String error);

  /// No description provided for @voiceMessageSharedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Voice message shared successfully!'**
  String get voiceMessageSharedSuccessfully;

  /// No description provided for @errorSharingVoice.
  ///
  /// In en, this message translates to:
  /// **'Error sharing voice: {error}'**
  String errorSharingVoice(String error);

  /// No description provided for @nameThisType.
  ///
  /// In en, this message translates to:
  /// **'Name this {type}'**
  String nameThisType(String type);

  /// No description provided for @enterTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter title (optional)'**
  String get enterTitleOptional;

  /// No description provided for @shareVideo.
  ///
  /// In en, this message translates to:
  /// **'Share Video'**
  String get shareVideo;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get pickFromGallery;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get voiceMessage;

  /// No description provided for @tapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to Stop'**
  String get tapToStop;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to Record'**
  String get tapToRecord;

  /// No description provided for @recentlyShared.
  ///
  /// In en, this message translates to:
  /// **'Recently Shared'**
  String get recentlyShared;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @noItemsSharedYet.
  ///
  /// In en, this message translates to:
  /// **'No items shared yet.'**
  String get noItemsSharedYet;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @quran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get quran;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @voiceCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice command failed. Please try again.'**
  String get voiceCommandFailed;

  /// No description provided for @alreadyOnMediaPage.
  ///
  /// In en, this message translates to:
  /// **'You are already on the media page.'**
  String get alreadyOnMediaPage;

  /// No description provided for @goingBackToHome.
  ///
  /// In en, this message translates to:
  /// **'Going back to the home page.'**
  String get goingBackToHome;

  /// No description provided for @manageMedicationsInstruction.
  ///
  /// In en, this message translates to:
  /// **'To manage your medications, please go back to the home page and open the medications section.'**
  String get manageMedicationsInstruction;

  /// No description provided for @startingSosFlow.
  ///
  /// In en, this message translates to:
  /// **'Here we will start the SOS emergency flow.'**
  String get startingSosFlow;

  /// No description provided for @settingsNotAvailableHere.
  ///
  /// In en, this message translates to:
  /// **'Settings are not available from the media page yet.'**
  String get settingsNotAvailableHere;

  /// No description provided for @mediaCategoryPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are on your media page. What category do you want me to play something from? Choose Health , Quraan, Story , Caregiver or favorites'**
  String get mediaCategoryPrompt;

  /// No description provided for @stoppingVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Okay, I will stop now.'**
  String get stoppingVoiceAssistant;

  /// No description provided for @didNotCatchThat.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I didn\'t catch that.'**
  String get didNotCatchThat;

  /// No description provided for @categoryNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I didn\'t understand that category. Please try again.'**
  String get categoryNotUnderstood;

  /// No description provided for @specificOrRandomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Okay, {matchedCategory}. Do you want to play something specific or random?'**
  String specificOrRandomPrompt(String matchedCategory);

  /// No description provided for @sayAudioOrVideoName.
  ///
  /// In en, this message translates to:
  /// **'Please say the name of the audio or the video that you want.'**
  String get sayAudioOrVideoName;

  /// No description provided for @didNotHearTitle.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t hear a title.'**
  String get didNotHearTitle;

  /// No description provided for @playingRandomFromCategory.
  ///
  /// In en, this message translates to:
  /// **'Okay, playing something random from {matchedCategory}.'**
  String playingRandomFromCategory(String matchedCategory);

  /// No description provided for @mustBeLoggedInForFavorites.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in for favorites.'**
  String get mustBeLoggedInForFavorites;

  /// No description provided for @noAudioFoundForCategory.
  ///
  /// In en, this message translates to:
  /// **'No audio found for {category}.'**
  String noAudioFoundForCategory(String category);

  /// No description provided for @playingItem.
  ///
  /// In en, this message translates to:
  /// **'Playing {title}'**
  String playingItem(String title);

  /// No description provided for @couldNotFindAudioNamed.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find any audio named {searchTitle} in {category}.'**
  String couldNotFindAudioNamed(String searchTitle, String category);

  /// No description provided for @somethingWentWrongWhileSearching.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while searching.'**
  String get somethingWentWrongWhileSearching;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @familyMedia.
  ///
  /// In en, this message translates to:
  /// **'Family Media'**
  String get familyMedia;

  /// No description provided for @pleaseLogInFirst.
  ///
  /// In en, this message translates to:
  /// **'Please log in first.'**
  String get pleaseLogInFirst;

  /// No description provided for @noMediaSharedYet.
  ///
  /// In en, this message translates to:
  /// **'No media shared yet.'**
  String get noMediaSharedYet;

  /// No description provided for @noMediaInThisFilter.
  ///
  /// In en, this message translates to:
  /// **'No media in this filter.'**
  String get noMediaInThisFilter;

  /// No description provided for @deleteMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Media?'**
  String get deleteMediaTitle;

  /// No description provided for @confirmDeleteSpecificMedia.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this specific media?'**
  String get confirmDeleteSpecificMedia;

  /// No description provided for @mediaDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Media deleted successfully'**
  String get mediaDeletedSuccessfully;

  /// No description provided for @errorDeletingMedia.
  ///
  /// In en, this message translates to:
  /// **'Error deleting media: {error}'**
  String errorDeletingMedia(String error);

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item?'**
  String get deleteItem;

  /// No description provided for @areYouSureDeleteSharedItem.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this shared item?'**
  String get areYouSureDeleteSharedItem;

  /// No description provided for @itemDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Item deleted successfully'**
  String get itemDeletedSuccessfully;

  /// No description provided for @errorDeletingItem.
  ///
  /// In en, this message translates to:
  /// **'Error deleting item: {error}'**
  String errorDeletingItem(String error);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @shortPassword.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get shortPassword;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @whatWouldYouLikeToShare.
  ///
  /// In en, this message translates to:
  /// **'What would you like to share today?'**
  String get whatWouldYouLikeToShare;

  /// No description provided for @chooseAMediaType.
  ///
  /// In en, this message translates to:
  /// **'Choose a media type below'**
  String get chooseAMediaType;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @late.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get late;

  /// No description provided for @onTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get onTime;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @voiceAlreadyOnHome.
  ///
  /// In en, this message translates to:
  /// **'You are already on the home page.'**
  String get voiceAlreadyOnHome;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get confirmLogout;

  /// No description provided for @medication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medication;

  /// No description provided for @noCaregiversLinked.
  ///
  /// In en, this message translates to:
  /// **'No caregivers linked'**
  String get noCaregiversLinked;

  /// No description provided for @expiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in: {time}'**
  String expiresIn(Object time);

  /// No description provided for @editInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get editInformation;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @mobileFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Mobile (05XXXXXXXX)'**
  String get mobileFormatHint;

  /// No description provided for @startWith05.
  ///
  /// In en, this message translates to:
  /// **'Start with 05'**
  String get startWith05;

  /// No description provided for @enter10Digits.
  ///
  /// In en, this message translates to:
  /// **'Enter 10 digits'**
  String get enter10Digits;

  /// No description provided for @mobileAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Mobile already used'**
  String get mobileAlreadyUsed;

  /// No description provided for @maherAlMuaiqly.
  ///
  /// In en, this message translates to:
  /// **'Maher Al-Muaiqly'**
  String get maherAlMuaiqly;

  /// No description provided for @saadAlGhamdi.
  ///
  /// In en, this message translates to:
  /// **'Saad Al-Ghamdi'**
  String get saadAlGhamdi;

  /// No description provided for @alMinshawi.
  ///
  /// In en, this message translates to:
  /// **'Al-Minshawi'**
  String get alMinshawi;

  /// No description provided for @islamicStories.
  ///
  /// In en, this message translates to:
  /// **'Islamic Stories'**
  String get islamicStories;

  /// No description provided for @worldStories.
  ///
  /// In en, this message translates to:
  /// **'World Stories'**
  String get worldStories;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @generalHealth.
  ///
  /// In en, this message translates to:
  /// **'General Health'**
  String get generalHealth;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @tapPlayToStartListening.
  ///
  /// In en, this message translates to:
  /// **'Tap play to start listening'**
  String get tapPlayToStartListening;

  /// No description provided for @mediaLinkMissing.
  ///
  /// In en, this message translates to:
  /// **'Media link is missing'**
  String get mediaLinkMissing;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
