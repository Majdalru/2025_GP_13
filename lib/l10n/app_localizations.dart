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

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @shortPassword.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get shortPassword;

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

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

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

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

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

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

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

  /// No description provided for @voiceCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice command failed, please try again.'**
  String get voiceCommandFailed;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

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
