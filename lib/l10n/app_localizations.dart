import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BSH Smart Food Buddy'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @todayGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get todayGreetingMorning;

  /// No description provided for @todayGreetingNoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get todayGreetingNoon;

  /// No description provided for @todayGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get todayGreetingEvening;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get navShopping;

  /// No description provided for @navImpact.
  ///
  /// In en, this message translates to:
  /// **'Impact'**
  String get navImpact;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Oops, undo!'**
  String get undo;

  /// No description provided for @prefLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get prefLanguageTitle;

  /// No description provided for @prefLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch app language'**
  String get prefLanguageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeFollowSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSectionHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get accountSectionHousehold;

  /// No description provided for @accountSectionMyHome.
  ///
  /// In en, this message translates to:
  /// **'My Home'**
  String get accountSectionMyHome;

  /// No description provided for @accountSectionIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get accountSectionIntegrations;

  /// No description provided for @accountSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get accountSectionPreferences;

  /// No description provided for @accountSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get accountSectionAbout;

  /// No description provided for @accountNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotificationsTitle;

  /// No description provided for @accountNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry alerts & reminders'**
  String get accountNotificationsSubtitle;

  /// No description provided for @notificationPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is blocked in system settings.'**
  String get notificationPermissionBlocked;

  /// No description provided for @notificationMealReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'Some of your ingredients are expiring soon. Check Smart Food Home.'**
  String get notificationMealReminderMessage;

  /// No description provided for @notificationSavedFutureApply.
  ///
  /// In en, this message translates to:
  /// **'Saved. New reminder time will apply to future notifications.'**
  String get notificationSavedFutureApply;

  /// No description provided for @notificationEnablePermissionFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enable notification permission first.'**
  String get notificationEnablePermissionFirst;

  /// No description provided for @notificationTestMessage.
  ///
  /// In en, this message translates to:
  /// **'This is a test expiry reminder from Smart Food Home.'**
  String get notificationTestMessage;

  /// No description provided for @notificationTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.'**
  String get notificationTestSent;

  /// No description provided for @notificationThreeDayExpiryTitle.
  ///
  /// In en, this message translates to:
  /// **'3-day expiry alerts'**
  String get notificationThreeDayExpiryTitle;

  /// No description provided for @notificationThreeDayExpiryDesc.
  ///
  /// In en, this message translates to:
  /// **'One-time reminder when an item is 3 days from expiry.'**
  String get notificationThreeDayExpiryDesc;

  /// No description provided for @notificationMealTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal-time reminders'**
  String get notificationMealTimeTitle;

  /// No description provided for @notificationMealTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Two daily reminders at your lunch and dinner time.'**
  String get notificationMealTimeDesc;

  /// No description provided for @notificationPermissionAllowed.
  ///
  /// In en, this message translates to:
  /// **'System notification permission: allowed'**
  String get notificationPermissionAllowed;

  /// No description provided for @notificationPermissionBlockedStatus.
  ///
  /// In en, this message translates to:
  /// **'System notification permission: blocked'**
  String get notificationPermissionBlockedStatus;

  /// No description provided for @notificationStatusCombined.
  ///
  /// In en, this message translates to:
  /// **'Meal reminders: {mealStatus} | 3-day alerts: {threeDayStatus}'**
  String notificationStatusCombined(Object mealStatus, Object threeDayStatus);

  /// No description provided for @notificationStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get notificationStatusScheduled;

  /// No description provided for @notificationStatusOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get notificationStatusOff;

  /// No description provided for @notificationMealTimesTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal times'**
  String get notificationMealTimesTitle;

  /// No description provided for @notificationMealTimesHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify you about expiring items at these times.'**
  String get notificationMealTimesHint;

  /// No description provided for @notificationLunchLabel.
  ///
  /// In en, this message translates to:
  /// **'Usual lunch time'**
  String get notificationLunchLabel;

  /// No description provided for @notificationDefaultLunchTime.
  ///
  /// In en, this message translates to:
  /// **'11:30 (default)'**
  String get notificationDefaultLunchTime;

  /// No description provided for @notificationDinnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Usual dinner time'**
  String get notificationDinnerLabel;

  /// No description provided for @notificationDefaultDinnerTime.
  ///
  /// In en, this message translates to:
  /// **'17:30 (default)'**
  String get notificationDefaultDinnerTime;

  /// No description provided for @notificationResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get notificationResetDefaults;

  /// No description provided for @notificationSendTestNow.
  ///
  /// In en, this message translates to:
  /// **'Send test now'**
  String get notificationSendTestNow;

  /// No description provided for @familyLoadMembersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load members: {error}'**
  String familyLoadMembersFailed(Object error);

  /// No description provided for @familyErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get familyErrorTitle;

  /// No description provided for @familyGenerateCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate code:\n\n{error}'**
  String familyGenerateCodeFailed(Object error);

  /// No description provided for @familyOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get familyOk;

  /// No description provided for @familyJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Family'**
  String get familyJoinTitle;

  /// No description provided for @familyJoinDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit invitation code shared by a family member.'**
  String get familyJoinDesc;

  /// No description provided for @familyInviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get familyInviteCodeLabel;

  /// No description provided for @familyJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get familyJoinAction;

  /// No description provided for @familyJoinedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined family successfully!'**
  String get familyJoinedSuccess;

  /// No description provided for @familyInvalidOrExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code.'**
  String get familyInvalidOrExpiredCode;

  /// No description provided for @familyErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String familyErrorMessage(Object error);

  /// No description provided for @familyLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Family?'**
  String get familyLeaveTitle;

  /// No description provided for @familyLeaveDesc.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see shared inventory and shopping lists. You will return to your own private home.'**
  String get familyLeaveDesc;

  /// No description provided for @familyLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get familyLeaveAction;

  /// No description provided for @familyLeftSuccess.
  ///
  /// In en, this message translates to:
  /// **'Left family. Switched to private mode.'**
  String get familyLeftSuccess;

  /// No description provided for @familyLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave family.'**
  String get familyLeaveFailed;

  /// No description provided for @familyInviteMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get familyInviteMemberTitle;

  /// No description provided for @familyInviteMemberDesc.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your family member.\nThey can use it to join your home.'**
  String get familyInviteMemberDesc;

  /// No description provided for @familyInviteExpiresIn2Days.
  ///
  /// In en, this message translates to:
  /// **'Expires in 2 days'**
  String get familyInviteExpiresIn2Days;

  /// No description provided for @familyDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get familyDone;

  /// No description provided for @familyUpdateNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Update your name'**
  String get familyUpdateNameTitle;

  /// No description provided for @familyDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get familyDisplayNameHint;

  /// No description provided for @familyNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated.'**
  String get familyNameUpdated;

  /// No description provided for @familyNameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update name.'**
  String get familyNameUpdateFailed;

  /// No description provided for @familyMyFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'My Family'**
  String get familyMyFamilyTitle;

  /// No description provided for @familyMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get familyMembersTitle;

  /// No description provided for @familyNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found.'**
  String get familyNoMembersFound;

  /// No description provided for @familyInviteNewMember.
  ///
  /// In en, this message translates to:
  /// **'Invite New Member'**
  String get familyInviteNewMember;

  /// No description provided for @familyJoinAnotherFamily.
  ///
  /// In en, this message translates to:
  /// **'Join Another Family'**
  String get familyJoinAnotherFamily;

  /// No description provided for @familyLeaveThisFamily.
  ///
  /// In en, this message translates to:
  /// **'Leave This Family'**
  String get familyLeaveThisFamily;

  /// No description provided for @familyInventoryShoppingSynced.
  ///
  /// In en, this message translates to:
  /// **'Inventory and Shopping List Synced'**
  String get familyInventoryShoppingSynced;

  /// No description provided for @familyYourDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get familyYourDisplayName;

  /// No description provided for @familyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get familyEdit;

  /// No description provided for @familyMigrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Migration failed'**
  String get familyMigrationFailed;

  /// No description provided for @familyMigratingData.
  ///
  /// In en, this message translates to:
  /// **'Migrating your data'**
  String get familyMigratingData;

  /// No description provided for @familyKeepAppOpen.
  ///
  /// In en, this message translates to:
  /// **'Please keep the app open.'**
  String get familyKeepAppOpen;

  /// No description provided for @familyMigrationAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt {attempt} / {total}'**
  String familyMigrationAttempt(Object attempt, Object total);

  /// No description provided for @familyInventoryMode.
  ///
  /// In en, this message translates to:
  /// **'Inventory Mode'**
  String get familyInventoryMode;

  /// No description provided for @familySharedFridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared Fridge'**
  String get familySharedFridgeTitle;

  /// No description provided for @familySharedFridgeDesc.
  ///
  /// In en, this message translates to:
  /// **'All members manage inventory together.'**
  String get familySharedFridgeDesc;

  /// No description provided for @familySeparateFridgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Separate Fridges'**
  String get familySeparateFridgesTitle;

  /// No description provided for @familySeparateFridgesDesc.
  ///
  /// In en, this message translates to:
  /// **'Items are strictly assigned to owners.'**
  String get familySeparateFridgesDesc;

  /// No description provided for @familyUnknownMember.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get familyUnknownMember;

  /// No description provided for @familyUnknownInitial.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get familyUnknownInitial;

  /// No description provided for @accountNightModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get accountNightModeTitle;

  /// No description provided for @accountStudentModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Mode'**
  String get accountStudentModeTitle;

  /// No description provided for @accountStudentModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Budget-friendly recipes & tips'**
  String get accountStudentModeSubtitle;

  /// No description provided for @accountLoyaltyCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Cards'**
  String get accountLoyaltyCardsTitle;

  /// No description provided for @accountLoyaltyCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect PAYBACK (Coming soon)'**
  String get accountLoyaltyCardsSubtitle;

  /// No description provided for @accountPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get accountPrivacyPolicyTitle;

  /// No description provided for @accountVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get accountVersionTitle;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get accountSignOut;

  /// No description provided for @accountHelloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String accountHelloUser(Object name);

  /// No description provided for @accountGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest Account'**
  String get accountGuestTitle;

  /// No description provided for @accountSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data'**
  String get accountSignInHint;

  /// No description provided for @accountLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get accountLogIn;

  /// No description provided for @accountHomeConnectLinked.
  ///
  /// In en, this message translates to:
  /// **'Home Connect Linked!'**
  String get accountHomeConnectLinked;

  /// No description provided for @accountConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get accountConnectionFailed;

  /// No description provided for @accountDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get accountDisconnected;

  /// No description provided for @accountSimulatorAppliances.
  ///
  /// In en, this message translates to:
  /// **'Simulator Appliances'**
  String get accountSimulatorAppliances;

  /// No description provided for @accountNoAppliancesFound.
  ///
  /// In en, this message translates to:
  /// **'No appliances found'**
  String get accountNoAppliancesFound;

  /// No description provided for @accountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get accountUnknown;

  /// No description provided for @accountIdCopied.
  ///
  /// In en, this message translates to:
  /// **'ID Copied'**
  String get accountIdCopied;

  /// No description provided for @accountApplianceId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String accountApplianceId(Object id);

  /// No description provided for @accountHomeConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Connect'**
  String get accountHomeConnectTitle;

  /// No description provided for @accountRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get accountRefreshStatus;

  /// No description provided for @accountViewAppliances.
  ///
  /// In en, this message translates to:
  /// **'View Appliances'**
  String get accountViewAppliances;

  /// No description provided for @accountDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get accountDisconnect;

  /// No description provided for @accountConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get accountConnecting;

  /// No description provided for @accountActiveSynced.
  ///
  /// In en, this message translates to:
  /// **'Active & Synced'**
  String get accountActiveSynced;

  /// No description provided for @accountTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get accountTapToConnect;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardScopeWorld.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get leaderboardScopeWorld;

  /// No description provided for @leaderboardGlobalTitle.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get leaderboardGlobalTitle;

  /// No description provided for @leaderboardGlobalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top performers worldwide'**
  String get leaderboardGlobalSubtitle;

  /// No description provided for @leaderboardYourRank.
  ///
  /// In en, this message translates to:
  /// **'Your Rank'**
  String get leaderboardYourRank;

  /// No description provided for @leaderboardNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get leaderboardNoDataYet;

  /// No description provided for @leaderboardRankInScope.
  ///
  /// In en, this message translates to:
  /// **'#{rank} in {scope}'**
  String leaderboardRankInScope(Object rank, Object scope);

  /// No description provided for @leaderboardLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load leaderboard'**
  String get leaderboardLoadFailedTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @leaderboardPointsKgCo2.
  ///
  /// In en, this message translates to:
  /// **'{value} kg CO2'**
  String leaderboardPointsKgCo2(Object value);

  /// No description provided for @leaderboardAddFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get leaderboardAddFriendTitle;

  /// No description provided for @leaderboardFriendEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend email'**
  String get leaderboardFriendEmailLabel;

  /// No description provided for @leaderboardFriendEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@email.com'**
  String get leaderboardFriendEmailHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @leaderboardNoUserForEmail.
  ///
  /// In en, this message translates to:
  /// **'No user found for that email.'**
  String get leaderboardNoUserForEmail;

  /// No description provided for @leaderboardInvalidUserId.
  ///
  /// In en, this message translates to:
  /// **'Invalid user id for that email.'**
  String get leaderboardInvalidUserId;

  /// No description provided for @leaderboardCannotAddYourself.
  ///
  /// In en, this message translates to:
  /// **'You cannot add yourself.'**
  String get leaderboardCannotAddYourself;

  /// No description provided for @leaderboardFriendAdded.
  ///
  /// In en, this message translates to:
  /// **'Friend added.'**
  String get leaderboardFriendAdded;

  /// No description provided for @leaderboardAddFriendFailed.
  ///
  /// In en, this message translates to:
  /// **'Add friend failed: {error}'**
  String leaderboardAddFriendFailed(Object error);

  /// No description provided for @pullToRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefreshHint;

  /// No description provided for @pullToRefreshRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get pullToRefreshRelease;

  /// No description provided for @foodLocationFridge.
  ///
  /// In en, this message translates to:
  /// **'Fridge'**
  String get foodLocationFridge;

  /// No description provided for @foodLocationFreezer.
  ///
  /// In en, this message translates to:
  /// **'Freezer'**
  String get foodLocationFreezer;

  /// No description provided for @foodLocationPantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get foodLocationPantry;

  /// No description provided for @foodExpiredDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Expired {days}d ago'**
  String foodExpiredDaysAgo(Object days);

  /// No description provided for @foodDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String foodDaysLeft(Object days);

  /// No description provided for @foodActionCookEat.
  ///
  /// In en, this message translates to:
  /// **'Cook / Eat'**
  String get foodActionCookEat;

  /// No description provided for @foodActionFeedPets.
  ///
  /// In en, this message translates to:
  /// **'Feed Pets'**
  String get foodActionFeedPets;

  /// No description provided for @foodActionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get foodActionDiscard;

  /// No description provided for @foodPetsHappy.
  ///
  /// In en, this message translates to:
  /// **'Little Shi & Little Yuan are happy!'**
  String get foodPetsHappy;

  /// No description provided for @todayRecipeArchiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recipe Archive'**
  String get todayRecipeArchiveTooltip;

  /// No description provided for @todayAiChefTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chef'**
  String get todayAiChefTitle;

  /// No description provided for @todayAiChefDescription.
  ///
  /// In en, this message translates to:
  /// **'Use current ingredients to generate recipes.'**
  String get todayAiChefDescription;

  /// No description provided for @todayExpiringSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get todayExpiringSoonTitle;

  /// No description provided for @todayExpiringSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'Quickly cook, feed pets, or discard items.'**
  String get todayExpiringSoonDescription;

  /// No description provided for @todayPetSafetyWarning.
  ///
  /// In en, this message translates to:
  /// **'Please ensure the food is safe for your pet!'**
  String get todayPetSafetyWarning;

  /// No description provided for @todayWhatCanICook.
  ///
  /// In en, this message translates to:
  /// **'What can I\ncook today?'**
  String get todayWhatCanICook;

  /// No description provided for @todayBasedOnItems.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} items in your fridge.'**
  String todayBasedOnItems(int count);

  /// No description provided for @todayGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get todayGenerate;

  /// No description provided for @todayPlanWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan Your Week!'**
  String get todayPlanWeekTitle;

  /// No description provided for @todayPlanWeekSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to plan meals.'**
  String get todayPlanWeekSubtitle;

  /// No description provided for @todayViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get todayViewAll;

  /// No description provided for @todayExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get todayExpired;

  /// No description provided for @todayExpiryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayExpiryToday;

  /// No description provided for @todayOneDayLeft.
  ///
  /// In en, this message translates to:
  /// **'1 day left'**
  String get todayOneDayLeft;

  /// No description provided for @todayAllClearTitle.
  ///
  /// In en, this message translates to:
  /// **'All Clear!'**
  String get todayAllClearTitle;

  /// No description provided for @todayAllClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your fridge is fresh and organized.'**
  String get todayAllClearSubtitle;

  /// No description provided for @todayUndoCooked.
  ///
  /// In en, this message translates to:
  /// **'Cooked \"{name}\"'**
  String todayUndoCooked(Object name);

  /// No description provided for @todayUndoFedPet.
  ///
  /// In en, this message translates to:
  /// **'Fed \"{name}\" to pet'**
  String todayUndoFedPet(Object name);

  /// No description provided for @todayUndoDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded \"{name}\"'**
  String todayUndoDiscarded(Object name);

  /// No description provided for @todayUndoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated \"{name}\"'**
  String todayUndoUpdated(Object name);

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @inventorySyncChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync changes to cloud'**
  String get inventorySyncChangesLabel;

  /// No description provided for @inventoryCloudSyncStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync status'**
  String get inventoryCloudSyncStatusLabel;

  /// No description provided for @inventorySyncRetryHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry syncing pending changes'**
  String get inventorySyncRetryHint;

  /// No description provided for @inventorySyncAllSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to confirm all changes are saved'**
  String get inventorySyncAllSavedHint;

  /// No description provided for @inventorySyncingChanges.
  ///
  /// In en, this message translates to:
  /// **'Syncing changes...'**
  String get inventorySyncingChanges;

  /// No description provided for @inventoryAllChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'All changes saved'**
  String get inventoryAllChangesSaved;

  /// No description provided for @inventorySyncingChangesToCloud.
  ///
  /// In en, this message translates to:
  /// **'Syncing changes to cloud...'**
  String get inventorySyncingChangesToCloud;

  /// No description provided for @inventoryAllSavedToCloud.
  ///
  /// In en, this message translates to:
  /// **'All changes saved to cloud.'**
  String get inventoryAllSavedToCloud;

  /// No description provided for @inventoryQuickSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Search'**
  String get inventoryQuickSearchTitle;

  /// No description provided for @inventoryQuickSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Find any item by name in seconds.'**
  String get inventoryQuickSearchDescription;

  /// No description provided for @inventorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get inventorySearchHint;

  /// No description provided for @inventoryNoItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get inventoryNoItemsFound;

  /// No description provided for @inventoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your inventory is empty'**
  String get inventoryEmptyTitle;

  /// No description provided for @inventoryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add items.'**
  String get inventoryEmptySubtitle;

  /// No description provided for @inventoryLongPressTitle.
  ///
  /// In en, this message translates to:
  /// **'Long Press Menu'**
  String get inventoryLongPressTitle;

  /// No description provided for @inventoryLongPressDescription.
  ///
  /// In en, this message translates to:
  /// **'Press and hold an item to edit, use quantity, move, or delete.'**
  String get inventoryLongPressDescription;

  /// No description provided for @inventorySwipeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe Left to Delete'**
  String get inventorySwipeDeleteTitle;

  /// No description provided for @inventorySwipeDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Swipe an item to the left to delete it. You can undo right after.'**
  String get inventorySwipeDeleteDescription;

  /// No description provided for @inventoryItemNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Item note'**
  String get inventoryItemNoteTitle;

  /// No description provided for @inventoryItemNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note...'**
  String get inventoryItemNoteHint;

  /// No description provided for @inventoryEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get inventoryEditNote;

  /// No description provided for @inventoryAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get inventoryAddNote;

  /// No description provided for @inventorySharedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get inventorySharedLabel;

  /// No description provided for @inventoryNoteReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a quick reminder'**
  String get inventoryNoteReminderSubtitle;

  /// No description provided for @inventoryChangeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get inventoryChangeCategory;

  /// No description provided for @inventoryRecordUsageUpdateQty.
  ///
  /// In en, this message translates to:
  /// **'Record usage and update quantity'**
  String get inventoryRecordUsageUpdateQty;

  /// No description provided for @inventoryGreatForLeftovers.
  ///
  /// In en, this message translates to:
  /// **'Great for leftovers'**
  String get inventoryGreatForLeftovers;

  /// No description provided for @inventoryTrackWasteImproveHabits.
  ///
  /// In en, this message translates to:
  /// **'Track waste to improve habits'**
  String get inventoryTrackWasteImproveHabits;

  /// No description provided for @inventoryCookedToast.
  ///
  /// In en, this message translates to:
  /// **'Cooked {qty} of {name}'**
  String inventoryCookedToast(Object qty, Object name);

  /// No description provided for @inventoryFedToPetToast.
  ///
  /// In en, this message translates to:
  /// **'Fed {name} to pet'**
  String inventoryFedToPetToast(Object name);

  /// No description provided for @inventoryRecordedWasteToast.
  ///
  /// In en, this message translates to:
  /// **'Recorded waste: {name}'**
  String inventoryRecordedWasteToast(Object name);

  /// No description provided for @inventoryDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String inventoryDeletedToast(Object name);

  /// No description provided for @inventoryCookWithThis.
  ///
  /// In en, this message translates to:
  /// **'Cook with this'**
  String get inventoryCookWithThis;

  /// No description provided for @inventoryFeedToPet.
  ///
  /// In en, this message translates to:
  /// **'Feed to pet'**
  String get inventoryFeedToPet;

  /// No description provided for @inventoryWastedThrownAway.
  ///
  /// In en, this message translates to:
  /// **'Wasted / Thrown away'**
  String get inventoryWastedThrownAway;

  /// No description provided for @inventoryEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get inventoryEditDetails;

  /// No description provided for @inventoryDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get inventoryDeleteItem;

  /// No description provided for @inventoryDeleteItemQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get inventoryDeleteItemQuestion;

  /// No description provided for @inventoryDeletePermanentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from your inventory permanently?'**
  String inventoryDeletePermanentQuestion(Object name);

  /// No description provided for @inventoryDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get inventoryDeleteAction;

  /// No description provided for @inventoryDetailQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get inventoryDetailQuantity;

  /// No description provided for @inventoryDetailAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get inventoryDetailAdded;

  /// No description provided for @inventoryDetailStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get inventoryDetailStorageLocation;

  /// No description provided for @inventoryDetailNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inventoryDetailNotes;

  /// No description provided for @inventoryDetailStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inventoryDetailStatusExpired;

  /// No description provided for @inventoryDetailStatusExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get inventoryDetailStatusExpiresToday;

  /// No description provided for @inventoryDetailStatusExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get inventoryDetailStatusExpiring;

  /// No description provided for @inventoryDetailStatusFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get inventoryDetailStatusFresh;

  /// No description provided for @inventoryDetailAddedToday.
  ///
  /// In en, this message translates to:
  /// **'Added today'**
  String get inventoryDetailAddedToday;

  /// No description provided for @inventoryDetailAddedOneDayAgo.
  ///
  /// In en, this message translates to:
  /// **'Added 1 day ago'**
  String get inventoryDetailAddedOneDayAgo;

  /// No description provided for @inventoryDetailAddedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Added {days} days ago'**
  String inventoryDetailAddedDaysAgo(Object days);

  /// No description provided for @inventoryDetailDaysLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'DAYS\nLEFT'**
  String get inventoryDetailDaysLeftLabel;

  /// No description provided for @inventoryDetailEditDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update item details and expiry'**
  String get inventoryDetailEditDetailsSubtitle;

  /// No description provided for @inventorySheetUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating: {name}'**
  String inventorySheetUpdating(Object name);

  /// No description provided for @inventoryActionType.
  ///
  /// In en, this message translates to:
  /// **'Action Type'**
  String get inventoryActionType;

  /// No description provided for @inventoryActionCooked.
  ///
  /// In en, this message translates to:
  /// **'Cooked'**
  String get inventoryActionCooked;

  /// No description provided for @inventoryActionPetFeed.
  ///
  /// In en, this message translates to:
  /// **'Pet Feed'**
  String get inventoryActionPetFeed;

  /// No description provided for @inventoryActionWaste.
  ///
  /// In en, this message translates to:
  /// **'Waste'**
  String get inventoryActionWaste;

  /// No description provided for @inventoryQuickAssign.
  ///
  /// In en, this message translates to:
  /// **'Quick Assign'**
  String get inventoryQuickAssign;

  /// No description provided for @inventoryEditFamily.
  ///
  /// In en, this message translates to:
  /// **'Edit Family'**
  String get inventoryEditFamily;

  /// No description provided for @inventoryYouLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get inventoryYouLabel;

  /// No description provided for @inventoryConfirmUpdate.
  ///
  /// In en, this message translates to:
  /// **'Confirm Update'**
  String get inventoryConfirmUpdate;

  /// No description provided for @inventoryQuantityUsed.
  ///
  /// In en, this message translates to:
  /// **'Quantity Used'**
  String get inventoryQuantityUsed;

  /// No description provided for @inventoryRemainingQty.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {value}{unit}'**
  String inventoryRemainingQty(Object value, Object unit);

  /// No description provided for @inventorySemanticsQuantityUsed.
  ///
  /// In en, this message translates to:
  /// **'Quantity used'**
  String get inventorySemanticsQuantityUsed;

  /// No description provided for @inventorySemanticsUsageHint.
  ///
  /// In en, this message translates to:
  /// **'Drag left or right to adjust usage'**
  String get inventorySemanticsUsageHint;

  /// No description provided for @inventorySemanticsAdjustUsedAmount.
  ///
  /// In en, this message translates to:
  /// **'Adjust used amount'**
  String get inventorySemanticsAdjustUsedAmount;

  /// No description provided for @shoppingTemporaryListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Temporary List'**
  String get shoppingTemporaryListTooltip;

  /// No description provided for @shoppingFridgeCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Fridge Camera'**
  String get shoppingFridgeCameraTitle;

  /// No description provided for @shoppingFridgeCameraDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan your fridge to speed up planning.'**
  String get shoppingFridgeCameraDescription;

  /// No description provided for @shoppingPurchaseHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase History'**
  String get shoppingPurchaseHistoryTitle;

  /// No description provided for @shoppingPurchaseHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Review bought items and add them back.'**
  String get shoppingPurchaseHistoryDescription;

  /// No description provided for @shoppingCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get shoppingCompletedLabel;

  /// No description provided for @shoppingAiSmartAddTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Smart Add'**
  String get shoppingAiSmartAddTitle;

  /// No description provided for @shoppingAiSmartAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add ingredients from a recipe.'**
  String get shoppingAiSmartAddDescription;

  /// No description provided for @shoppingAiSmartAddHint.
  ///
  /// In en, this message translates to:
  /// **'Import ingredients from recipe text'**
  String get shoppingAiSmartAddHint;

  /// No description provided for @shoppingQuickAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get shoppingQuickAddTitle;

  /// No description provided for @shoppingQuickAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add one item instantly.'**
  String get shoppingQuickAddDescription;

  /// No description provided for @shoppingQuickAddSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick add item'**
  String get shoppingQuickAddSemanticsLabel;

  /// No description provided for @shoppingInputHint.
  ///
  /// In en, this message translates to:
  /// **'Add item here'**
  String get shoppingInputHint;

  /// No description provided for @shoppingRecipeImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipe Import'**
  String get shoppingRecipeImportTitle;

  /// No description provided for @shoppingRecipeSignInRequiredAction.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to use AI Recipe Scan.'**
  String get shoppingRecipeSignInRequiredAction;

  /// No description provided for @shoppingRecipeSignInAction.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get shoppingRecipeSignInAction;

  /// No description provided for @shoppingRecipeProvideInput.
  ///
  /// In en, this message translates to:
  /// **'Please provide a recipe name, text, or image.'**
  String get shoppingRecipeProvideInput;

  /// No description provided for @shoppingRecipeAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed: {error}'**
  String shoppingRecipeAnalysisFailed(Object error);

  /// No description provided for @shoppingRecipeAddedItems.
  ///
  /// In en, this message translates to:
  /// **'Added {count} items to shopping list'**
  String shoppingRecipeAddedItems(Object count);

  /// No description provided for @shoppingRecipeInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter dish name or paste recipe...'**
  String get shoppingRecipeInputHint;

  /// No description provided for @shoppingRecipeIngredientsSection.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get shoppingRecipeIngredientsSection;

  /// No description provided for @shoppingRecipeSeasoningsSection.
  ///
  /// In en, this message translates to:
  /// **'Seasonings'**
  String get shoppingRecipeSeasoningsSection;

  /// No description provided for @shoppingRecipeCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get shoppingRecipeCamera;

  /// No description provided for @shoppingRecipeAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get shoppingRecipeAlbum;

  /// No description provided for @shoppingRecipeAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get shoppingRecipeAnalyzing;

  /// No description provided for @shoppingRecipeGetListButton.
  ///
  /// In en, this message translates to:
  /// **'Get Shopping list'**
  String get shoppingRecipeGetListButton;

  /// No description provided for @shoppingRecipeAiThinking.
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get shoppingRecipeAiThinking;

  /// No description provided for @shoppingRecipeResultsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your results will appear here'**
  String get shoppingRecipeResultsPlaceholder;

  /// No description provided for @shoppingRecipeInStockReason.
  ///
  /// In en, this message translates to:
  /// **'In stock: {reason}'**
  String shoppingRecipeInStockReason(Object reason);

  /// No description provided for @shoppingRecipeCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String shoppingRecipeCategoryLabel(Object category);

  /// No description provided for @shoppingRecipeAddSelectedToList.
  ///
  /// In en, this message translates to:
  /// **'Add {count} Items to List'**
  String shoppingRecipeAddSelectedToList(Object count);

  /// No description provided for @shoppingRecipeSignInRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in Required'**
  String get shoppingRecipeSignInRequiredTitle;

  /// No description provided for @shoppingRecipeSignInRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to sync with your inventory and use AI recipe analysis.'**
  String get shoppingRecipeSignInRequiredSubtitle;

  /// No description provided for @shoppingRecipeSignInNow.
  ///
  /// In en, this message translates to:
  /// **'Sign In Now'**
  String get shoppingRecipeSignInNow;

  /// No description provided for @shoppingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your list is empty'**
  String get shoppingEmptyTitle;

  /// No description provided for @shoppingEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add items manually or use recipe import.'**
  String get shoppingEmptySubtitle;

  /// No description provided for @shoppingDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String shoppingDeletedToast(Object name);

  /// No description provided for @shoppingUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get shoppingUndoAction;

  /// No description provided for @impactTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Impact'**
  String get impactTitle;

  /// No description provided for @impactTimeRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get impactTimeRangeTitle;

  /// No description provided for @impactTimeRangeDescription.
  ///
  /// In en, this message translates to:
  /// **'Switch between week, month, and year views.'**
  String get impactTimeRangeDescription;

  /// No description provided for @impactSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Impact Summary'**
  String get impactSummaryTitle;

  /// No description provided for @impactSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'See money saved and items rescued here.'**
  String get impactSummaryDescription;

  /// No description provided for @impactKgAvoided.
  ///
  /// In en, this message translates to:
  /// **'{value}kg avoided'**
  String impactKgAvoided(Object value);

  /// No description provided for @impactLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get impactLevelTitle;

  /// No description provided for @impactStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get impactStreakTitle;

  /// No description provided for @impactDaysActive.
  ///
  /// In en, this message translates to:
  /// **'Days active'**
  String get impactDaysActive;

  /// No description provided for @impactActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get impactActiveBadge;

  /// No description provided for @impactWeeklyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Report'**
  String get impactWeeklyReportTitle;

  /// No description provided for @impactWeeklyReportDescription.
  ///
  /// In en, this message translates to:
  /// **'Open your AI weekly summary and insights.'**
  String get impactWeeklyReportDescription;

  /// No description provided for @impactWeeklyReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your progress from last week'**
  String get impactWeeklyReviewSubtitle;

  /// No description provided for @weeklyAddedToShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Added to shopping list.'**
  String get weeklyAddedToShoppingList;

  /// No description provided for @weeklyHeiExplainedTitle.
  ///
  /// In en, this message translates to:
  /// **'HEI-2015 Explained'**
  String get weeklyHeiExplainedTitle;

  /// No description provided for @weeklyHeiExplainedIntro.
  ///
  /// In en, this message translates to:
  /// **'The Healthy Eating Index (HEI-2015) is a 0-100 score that measures how well a diet aligns with the Dietary Guidelines for Americans.'**
  String get weeklyHeiExplainedIntro;

  /// No description provided for @weeklyHeiHowComputeTitle.
  ///
  /// In en, this message translates to:
  /// **'How we compute it'**
  String get weeklyHeiHowComputeTitle;

  /// No description provided for @weeklyHeiHowComputeBody.
  ///
  /// In en, this message translates to:
  /// **'We estimate HEI components using USDA FoodData Central nutrients and your logged foods. Components include:'**
  String get weeklyHeiHowComputeBody;

  /// No description provided for @weeklyHeiComponentsList.
  ///
  /// In en, this message translates to:
  /// **'- Fruits (total and whole)\n- Vegetables (total and greens/beans)\n- Whole grains\n- Dairy\n- Total protein and seafood/plant protein\n- Fatty acids ratio\n- Moderation: refined grains, sodium, added sugars, saturated fat'**
  String get weeklyHeiComponentsList;

  /// No description provided for @weeklyHeiMorePoints.
  ///
  /// In en, this message translates to:
  /// **'More points = better balance. We normalize per 1,000 kcal where applicable and use HEI-2015 scoring standards.'**
  String get weeklyHeiMorePoints;

  /// No description provided for @weeklyGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get weeklyGotIt;

  /// No description provided for @weeklyHeiLabelExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get weeklyHeiLabelExcellent;

  /// No description provided for @weeklyHeiLabelGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get weeklyHeiLabelGood;

  /// No description provided for @weeklyHeiLabelFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get weeklyHeiLabelFair;

  /// No description provided for @weeklyHeiLabelNeedsWork.
  ///
  /// In en, this message translates to:
  /// **'Needs Work'**
  String get weeklyHeiLabelNeedsWork;

  /// No description provided for @weeklyMacrosNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data to calculate macros.'**
  String get weeklyMacrosNotEnoughData;

  /// No description provided for @weeklyMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get weeklyMacroProtein;

  /// No description provided for @weeklyMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get weeklyMacroCarbs;

  /// No description provided for @weeklyMacroFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get weeklyMacroFat;

  /// No description provided for @weeklyDataSource.
  ///
  /// In en, this message translates to:
  /// **'Data source: {source}'**
  String weeklyDataSource(Object source);

  /// No description provided for @weeklyPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get weeklyPrev;

  /// No description provided for @weeklyNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get weeklyNext;

  /// No description provided for @impactChooseMascot.
  ///
  /// In en, this message translates to:
  /// **'Choose your mascot'**
  String get impactChooseMascot;

  /// No description provided for @impactMascotNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Mascot name'**
  String get impactMascotNameTitle;

  /// No description provided for @impactMascotNameHint.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get impactMascotNameHint;

  /// No description provided for @impactMascotCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get impactMascotCat;

  /// No description provided for @impactMascotDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get impactMascotDog;

  /// No description provided for @impactMascotHamster.
  ///
  /// In en, this message translates to:
  /// **'Hamster'**
  String get impactMascotHamster;

  /// No description provided for @impactMascotGuineaPig.
  ///
  /// In en, this message translates to:
  /// **'Guinea Pig'**
  String get impactMascotGuineaPig;

  /// No description provided for @impactFedToMascot.
  ///
  /// In en, this message translates to:
  /// **'Fed to {name}'**
  String impactFedToMascot(Object name);

  /// No description provided for @impactItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get impactItemFallback;

  /// No description provided for @impactFridgeMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Fridge Master!'**
  String get impactFridgeMasterTitle;

  /// No description provided for @impactSavedItemsStreak.
  ///
  /// In en, this message translates to:
  /// **'Saved {savedCount} items - {streak} day streak'**
  String impactSavedItemsStreak(Object savedCount, Object streak);

  /// No description provided for @impactTotalSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL SAVINGS'**
  String get impactTotalSavingsLabel;

  /// No description provided for @impactNextRankLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Rank: Zero Waste Hero'**
  String get impactNextRankLabel;

  /// No description provided for @impactBasedOnSavedItems.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} items saved'**
  String impactBasedOnSavedItems(Object count);

  /// No description provided for @impactOnTrackYearly.
  ///
  /// In en, this message translates to:
  /// **'On track to save {amount} / year'**
  String impactOnTrackYearly(Object amount);

  /// No description provided for @impactCommunityQuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Quest'**
  String get impactCommunityQuestTitle;

  /// No description provided for @impactNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New!'**
  String get impactNewBadge;

  /// No description provided for @impactYouSavedCo2ThisWeek.
  ///
  /// In en, this message translates to:
  /// **'You saved {value}kg CO2 this week!'**
  String impactYouSavedCo2ThisWeek(Object value);

  /// No description provided for @impactViewLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'View Leaderboard'**
  String get impactViewLeaderboard;

  /// No description provided for @impactTopSaversTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Savers'**
  String get impactTopSaversTitle;

  /// No description provided for @impactSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get impactSeeAll;

  /// No description provided for @impactMostSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'Most Saved'**
  String get impactMostSavedLabel;

  /// No description provided for @impactRecentActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Actions'**
  String get impactRecentActionsTitle;

  /// No description provided for @impactFamilyLabel.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get impactFamilyLabel;

  /// No description provided for @impactActionCooked.
  ///
  /// In en, this message translates to:
  /// **'Cooked'**
  String get impactActionCooked;

  /// No description provided for @impactActionFedToPet.
  ///
  /// In en, this message translates to:
  /// **'Fed to pet'**
  String get impactActionFedToPet;

  /// No description provided for @impactActionWasted.
  ///
  /// In en, this message translates to:
  /// **'Wasted'**
  String get impactActionWasted;

  /// No description provided for @impactTapForDietInsights.
  ///
  /// In en, this message translates to:
  /// **'Tap to view your diet insights'**
  String get impactTapForDietInsights;

  /// No description provided for @impactEnjoyedLeftovers.
  ///
  /// In en, this message translates to:
  /// **'Enjoyed {weight}kg of leftovers'**
  String impactEnjoyedLeftovers(Object weight);

  /// No description provided for @impactNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get impactNoDataTitle;

  /// No description provided for @impactNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start saving food to see your impact!'**
  String get impactNoDataSubtitle;

  /// No description provided for @impactRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get impactRangeWeek;

  /// No description provided for @impactRangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get impactRangeMonth;

  /// No description provided for @impactRangeYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get impactRangeYear;

  /// No description provided for @addFoodVoiceTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap mic to start'**
  String get addFoodVoiceTapToStart;

  /// No description provided for @addFoodDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get addFoodDateNotSet;

  /// No description provided for @addFoodTextTooShort.
  ///
  /// In en, this message translates to:
  /// **'Text too short, please provide more info.'**
  String get addFoodTextTooShort;

  /// No description provided for @addFoodRecognizedItems.
  ///
  /// In en, this message translates to:
  /// **'Recognized {count} item(s).'**
  String addFoodRecognizedItems(int count);

  /// No description provided for @addFoodAiParserUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI parser unavailable, used local parser.'**
  String get addFoodAiParserUnavailable;

  /// No description provided for @addFoodAiUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected AI response, used local parser.'**
  String get addFoodAiUnexpectedResponse;

  /// No description provided for @addFoodFormFilledFromVoice.
  ///
  /// In en, this message translates to:
  /// **'Form filled from voice.'**
  String get addFoodFormFilledFromVoice;

  /// No description provided for @addFoodAiReturnedEmpty.
  ///
  /// In en, this message translates to:
  /// **'AI parser returned empty, used local parser.'**
  String get addFoodAiReturnedEmpty;

  /// No description provided for @addFoodNetworkParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Network parse failed, used local parser.'**
  String get addFoodNetworkParseFailed;

  /// No description provided for @addFoodAiParseFailed.
  ///
  /// In en, this message translates to:
  /// **'AI parse failed: {error}'**
  String addFoodAiParseFailed(Object error);

  /// No description provided for @addFoodEnterNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter the food name first'**
  String get addFoodEnterNameFirst;

  /// No description provided for @addFoodExpirySetTo.
  ///
  /// In en, this message translates to:
  /// **'Expiry set to {date}'**
  String addFoodExpirySetTo(Object date);

  /// No description provided for @addFoodMaxFourImages.
  ///
  /// In en, this message translates to:
  /// **'Max 4 images allowed. Selecting first 4.'**
  String get addFoodMaxFourImages;

  /// No description provided for @addFoodNoItemsDetected.
  ///
  /// In en, this message translates to:
  /// **'No items detected in images.'**
  String get addFoodNoItemsDetected;

  /// No description provided for @addFoodScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String addFoodScanFailed(Object error);

  /// No description provided for @addFoodVoiceError.
  ///
  /// In en, this message translates to:
  /// **'Voice error: {error}'**
  String addFoodVoiceError(Object error);

  /// No description provided for @addFoodSpeechNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Speech not available on this device'**
  String get addFoodSpeechNotAvailable;

  /// No description provided for @addFoodSpeechNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition not supported on this device.'**
  String get addFoodSpeechNotSupported;

  /// No description provided for @addFoodSpeechInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech init failed: {code}'**
  String addFoodSpeechInitFailed(Object code);

  /// No description provided for @addFoodSpeechInitUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to initialize speech recognition.'**
  String get addFoodSpeechInitUnable;

  /// No description provided for @addFoodOpeningXiaomiSpeech.
  ///
  /// In en, this message translates to:
  /// **'Opening Xiaomi speech...'**
  String get addFoodOpeningXiaomiSpeech;

  /// No description provided for @addFoodVoiceGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it! Tap Analyze & Fill.'**
  String get addFoodVoiceGotIt;

  /// No description provided for @addFoodVoiceCanceled.
  ///
  /// In en, this message translates to:
  /// **'Voice canceled. Tap mic to retry.'**
  String get addFoodVoiceCanceled;

  /// No description provided for @addFoodMicBlocked.
  ///
  /// In en, this message translates to:
  /// **'Mic blocked. Enable in Settings.'**
  String get addFoodMicBlocked;

  /// No description provided for @addFoodMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Mic permission denied.'**
  String get addFoodMicDenied;

  /// No description provided for @addFoodListeningNow.
  ///
  /// In en, this message translates to:
  /// **'I\'m listening...'**
  String get addFoodListeningNow;

  /// No description provided for @addFoodAddItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addFoodAddItemTitle;

  /// No description provided for @addFoodEditItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get addFoodEditItemTitle;

  /// No description provided for @addFoodHelpButton.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get addFoodHelpButton;

  /// No description provided for @addFoodTabManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get addFoodTabManual;

  /// No description provided for @addFoodTabScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get addFoodTabScan;

  /// No description provided for @addFoodTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get addFoodTabVoice;

  /// No description provided for @addFoodBasicInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get addFoodBasicInfoTitle;

  /// No description provided for @addFoodNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addFoodNameLabel;

  /// No description provided for @addFoodRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get addFoodRequired;

  /// No description provided for @addFoodQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get addFoodQuantityLabel;

  /// No description provided for @addFoodUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get addFoodUnitLabel;

  /// No description provided for @addFoodMinStockWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Stock Warning (Optional)'**
  String get addFoodMinStockWarningLabel;

  /// No description provided for @addFoodMinStockHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2 (Notify when below)'**
  String get addFoodMinStockHint;

  /// No description provided for @addFoodMinStockHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no warnings'**
  String get addFoodMinStockHelper;

  /// No description provided for @addFoodStorageLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get addFoodStorageLocationTitle;

  /// No description provided for @addFoodCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get addFoodCategoriesTitle;

  /// No description provided for @addFoodDatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get addFoodDatesTitle;

  /// No description provided for @addFoodPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get addFoodPurchaseDate;

  /// No description provided for @addFoodOpenDate.
  ///
  /// In en, this message translates to:
  /// **'Open Date'**
  String get addFoodOpenDate;

  /// No description provided for @addFoodBestBefore.
  ///
  /// In en, this message translates to:
  /// **'Best Before'**
  String get addFoodBestBefore;

  /// No description provided for @addFoodSaveToInventory.
  ///
  /// In en, this message translates to:
  /// **'Save to Inventory'**
  String get addFoodSaveToInventory;

  /// No description provided for @addFoodScanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan Receipt'**
  String get addFoodScanReceipt;

  /// No description provided for @addFoodSnapFridge.
  ///
  /// In en, this message translates to:
  /// **'Snap Fridge'**
  String get addFoodSnapFridge;

  /// No description provided for @addFoodTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get addFoodTakePhoto;

  /// No description provided for @addFoodUseCameraToScan.
  ///
  /// In en, this message translates to:
  /// **'Use camera to scan'**
  String get addFoodUseCameraToScan;

  /// No description provided for @addFoodUploadMax4.
  ///
  /// In en, this message translates to:
  /// **'Upload (Max 4)'**
  String get addFoodUploadMax4;

  /// No description provided for @addFoodChooseMultipleFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose multiple from gallery'**
  String get addFoodChooseMultipleFromGallery;

  /// No description provided for @addFoodAiExtractReceiptItems.
  ///
  /// In en, this message translates to:
  /// **'AI will extract items from your receipt(s).'**
  String get addFoodAiExtractReceiptItems;

  /// No description provided for @addFoodAiIdentifyFridgeItems.
  ///
  /// In en, this message translates to:
  /// **'AI will identify items in your fridge or pantry.'**
  String get addFoodAiIdentifyFridgeItems;

  /// No description provided for @addFoodAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get addFoodAutoLabel;

  /// No description provided for @addFoodXiaomiSpeechMode.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi speech mode'**
  String get addFoodXiaomiSpeechMode;

  /// No description provided for @addFoodEngineReady.
  ///
  /// In en, this message translates to:
  /// **'Engine ready - {locale}'**
  String addFoodEngineReady(Object locale);

  /// No description provided for @addFoodPreparingEngine.
  ///
  /// In en, this message translates to:
  /// **'Preparing speech engine...'**
  String get addFoodPreparingEngine;

  /// No description provided for @addFoodVoiceTrySaying.
  ///
  /// In en, this message translates to:
  /// **'Try saying: \"3 apples, milk, and 1kg of rice\"'**
  String get addFoodVoiceTrySaying;

  /// No description provided for @addFoodTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Transcript will appear here...'**
  String get addFoodTranscriptHint;

  /// No description provided for @addFoodClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get addFoodClear;

  /// No description provided for @addFoodAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get addFoodAnalyzing;

  /// No description provided for @addFoodAnalyzeAndFill.
  ///
  /// In en, this message translates to:
  /// **'Analyze & Fill'**
  String get addFoodAnalyzeAndFill;

  /// No description provided for @addFoodAiExpiryPrediction.
  ///
  /// In en, this message translates to:
  /// **'AI Expiry Prediction'**
  String get addFoodAiExpiryPrediction;

  /// No description provided for @addFoodAutoMagic.
  ///
  /// In en, this message translates to:
  /// **'Auto magic'**
  String get addFoodAutoMagic;

  /// No description provided for @addFoodThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get addFoodThinking;

  /// No description provided for @addFoodPredictedExpiry.
  ///
  /// In en, this message translates to:
  /// **'Predicted Expiry'**
  String get addFoodPredictedExpiry;

  /// No description provided for @addFoodManualDateOverride.
  ///
  /// In en, this message translates to:
  /// **'Manual date will override this'**
  String get addFoodManualDateOverride;

  /// No description provided for @addFoodAutoApplied.
  ///
  /// In en, this message translates to:
  /// **'Auto applied'**
  String get addFoodAutoApplied;

  /// No description provided for @addFoodAiSuggestHint.
  ///
  /// In en, this message translates to:
  /// **'Let AI suggest based on food type and storage.'**
  String get addFoodAiSuggestHint;

  /// No description provided for @addFoodErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error:'**
  String get addFoodErrorPrefix;

  /// No description provided for @addFoodAutoMagicPrediction.
  ///
  /// In en, this message translates to:
  /// **'Auto Magic Prediction'**
  String get addFoodAutoMagicPrediction;

  /// No description provided for @addFoodScanningReceipts.
  ///
  /// In en, this message translates to:
  /// **'Scanning Receipts...'**
  String get addFoodScanningReceipts;

  /// No description provided for @addFoodProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get addFoodProcessing;

  /// No description provided for @addFoodItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get addFoodItemsTitle;

  /// No description provided for @addFoodAddCountItems.
  ///
  /// In en, this message translates to:
  /// **'Add {count} Items'**
  String addFoodAddCountItems(int count);

  /// No description provided for @addFoodAddedItems.
  ///
  /// In en, this message translates to:
  /// **'Added {count} items'**
  String addFoodAddedItems(int count);

  /// No description provided for @addFoodHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item Help'**
  String get addFoodHelpTitle;

  /// No description provided for @addFoodHelpManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get addFoodHelpManualTitle;

  /// No description provided for @addFoodHelpManualPoint1.
  ///
  /// In en, this message translates to:
  /// **'Enter name, quantity, and storage location.'**
  String get addFoodHelpManualPoint1;

  /// No description provided for @addFoodHelpManualPoint2.
  ///
  /// In en, this message translates to:
  /// **'Set Best Before if you know the package date.'**
  String get addFoodHelpManualPoint2;

  /// No description provided for @addFoodHelpManualPoint3.
  ///
  /// In en, this message translates to:
  /// **'Use note for size/brand reminders.'**
  String get addFoodHelpManualPoint3;

  /// No description provided for @addFoodHelpScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get addFoodHelpScanTitle;

  /// No description provided for @addFoodHelpScanPoint1.
  ///
  /// In en, this message translates to:
  /// **'Use clear photos with good lighting.'**
  String get addFoodHelpScanPoint1;

  /// No description provided for @addFoodHelpScanPoint2.
  ///
  /// In en, this message translates to:
  /// **'For receipts, keep text fully visible.'**
  String get addFoodHelpScanPoint2;

  /// No description provided for @addFoodHelpScanPoint3.
  ///
  /// In en, this message translates to:
  /// **'Review detected items before saving.'**
  String get addFoodHelpScanPoint3;

  /// No description provided for @addFoodHelpVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get addFoodHelpVoiceTitle;

  /// No description provided for @addFoodHelpVoicePoint1.
  ///
  /// In en, this message translates to:
  /// **'Say item + quantity + unit, e.g. \"Milk two liters\".'**
  String get addFoodHelpVoicePoint1;

  /// No description provided for @addFoodHelpVoicePoint2.
  ///
  /// In en, this message translates to:
  /// **'Pause briefly between multiple items.'**
  String get addFoodHelpVoicePoint2;

  /// No description provided for @addFoodHelpVoicePoint3.
  ///
  /// In en, this message translates to:
  /// **'Edit fields before saving if needed.'**
  String get addFoodHelpVoicePoint3;

  /// No description provided for @addFoodHelpTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: If expiry is unknown, use AI prediction and adjust manually if needed.'**
  String get addFoodHelpTip;

  /// No description provided for @selectIngredientsKitchenTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Kitchen'**
  String get selectIngredientsKitchenTitle;

  /// No description provided for @selectIngredientsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected for cooking'**
  String selectIngredientsSelectedCount(int count);

  /// No description provided for @selectIngredientsNoItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter or add new items.'**
  String get selectIngredientsNoItemsSubtitle;

  /// No description provided for @selectIngredientsExtrasPrompts.
  ///
  /// In en, this message translates to:
  /// **'Extras & Prompts'**
  String get selectIngredientsExtrasPrompts;

  /// No description provided for @selectIngredientsAddExtraHint.
  ///
  /// In en, this message translates to:
  /// **'Add extra ingredients...'**
  String get selectIngredientsAddExtraHint;

  /// No description provided for @selectIngredientsSpecialRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Any specific cravings or dietary restrictions?'**
  String get selectIngredientsSpecialRequestHint;

  /// No description provided for @selectIngredientsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Ingredients'**
  String get selectIngredientsPageTitle;

  /// No description provided for @selectIngredientsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get selectIngredientsReset;

  /// No description provided for @selectIngredientsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get selectIngredientsFilterAll;

  /// No description provided for @selectIngredientsFilterExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get selectIngredientsFilterExpiring;

  /// No description provided for @selectIngredientsFilterVeggie.
  ///
  /// In en, this message translates to:
  /// **'Veggie'**
  String get selectIngredientsFilterVeggie;

  /// No description provided for @selectIngredientsFilterMeat.
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get selectIngredientsFilterMeat;

  /// No description provided for @selectIngredientsFilterDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get selectIngredientsFilterDairy;

  /// No description provided for @selectIngredientsExpiringLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get selectIngredientsExpiringLabel;

  /// No description provided for @selectIngredientsSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get selectIngredientsSoonLabel;

  /// No description provided for @selectIngredientsFreshLabel.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get selectIngredientsFreshLabel;

  /// No description provided for @selectIngredientsQuantityLeft.
  ///
  /// In en, this message translates to:
  /// **'{value} {unit} left'**
  String selectIngredientsQuantityLeft(Object value, Object unit);

  /// No description provided for @selectIngredientsPeopleShort.
  ///
  /// In en, this message translates to:
  /// **'Ppl'**
  String get selectIngredientsPeopleShort;

  /// No description provided for @cookingPlanSlot.
  ///
  /// In en, this message translates to:
  /// **'Plan {slot}'**
  String cookingPlanSlot(Object slot);

  /// No description provided for @cookingMealNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Meal name'**
  String get cookingMealNameLabel;

  /// No description provided for @cookingMealNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Lemon Chicken Bowl'**
  String get cookingMealNameHint;

  /// No description provided for @cookingQuickPickRecipes.
  ///
  /// In en, this message translates to:
  /// **'Quick pick from recipes'**
  String get cookingQuickPickRecipes;

  /// No description provided for @cookingBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'Browse All'**
  String get cookingBrowseAll;

  /// No description provided for @cookingUseFromInventory.
  ///
  /// In en, this message translates to:
  /// **'Use from inventory'**
  String get cookingUseFromInventory;

  /// No description provided for @cookingMissingItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing items (add to shopping list)'**
  String get cookingMissingItemsLabel;

  /// No description provided for @cookingMissingItemsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. garlic, scallions'**
  String get cookingMissingItemsHint;

  /// No description provided for @cookingSavePlan.
  ///
  /// In en, this message translates to:
  /// **'Save Plan'**
  String get cookingSavePlan;

  /// No description provided for @cookingUntitledMeal.
  ///
  /// In en, this message translates to:
  /// **'Untitled meal'**
  String get cookingUntitledMeal;

  /// No description provided for @cookingAddedItemsToShopping.
  ///
  /// In en, this message translates to:
  /// **'Added {count} items to shopping list.'**
  String cookingAddedItemsToShopping(int count);

  /// No description provided for @cookingMealPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal Planner'**
  String get cookingMealPlannerTitle;

  /// No description provided for @cookingJumpToToday.
  ///
  /// In en, this message translates to:
  /// **'Jump to today'**
  String get cookingJumpToToday;

  /// No description provided for @cookingNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get cookingNoMatches;

  /// No description provided for @cookingMissingItemsCount.
  ///
  /// In en, this message translates to:
  /// **'Missing {count} items'**
  String cookingMissingItemsCount(int count);

  /// No description provided for @cookingAllItemsInFridge.
  ///
  /// In en, this message translates to:
  /// **'All items in fridge'**
  String get cookingAllItemsInFridge;

  /// No description provided for @cookingSlotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get cookingSlotBreakfast;

  /// No description provided for @cookingSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get cookingSlotLunch;

  /// No description provided for @cookingSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get cookingSlotDinner;

  /// No description provided for @shoppingGuestCreateTempTitle.
  ///
  /// In en, this message translates to:
  /// **'Create temporary list'**
  String get shoppingGuestCreateTempTitle;

  /// No description provided for @shoppingGuestCreateTempSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share with guests without requiring login.'**
  String get shoppingGuestCreateTempSubtitle;

  /// No description provided for @shoppingGuestMyListsTitle.
  ///
  /// In en, this message translates to:
  /// **'My guest lists'**
  String get shoppingGuestMyListsTitle;

  /// No description provided for @shoppingGuestMyListsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage existing temporary lists.'**
  String get shoppingGuestMyListsSubtitle;

  /// No description provided for @shoppingGuestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Temporary List'**
  String get shoppingGuestDialogTitle;

  /// No description provided for @shoppingGuestTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dinner Party'**
  String get shoppingGuestTitleHint;

  /// No description provided for @shoppingGuestExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in'**
  String get shoppingGuestExpiresIn;

  /// No description provided for @shoppingGuestExpire24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get shoppingGuestExpire24h;

  /// No description provided for @shoppingGuestExpire3d.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get shoppingGuestExpire3d;

  /// No description provided for @shoppingGuestExpire7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get shoppingGuestExpire7d;

  /// No description provided for @shoppingGuestAttachMineTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach to my account'**
  String get shoppingGuestAttachMineTitle;

  /// No description provided for @shoppingGuestAttachMineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only your account can edit owner settings.'**
  String get shoppingGuestAttachMineSubtitle;

  /// No description provided for @shoppingGuestCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shoppingGuestCreateAction;

  /// No description provided for @shoppingShareLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this link'**
  String get shoppingShareLinkTitle;

  /// No description provided for @shoppingLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get shoppingLinkCopied;

  /// No description provided for @shoppingCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get shoppingCopyLink;

  /// No description provided for @shoppingOpenList.
  ///
  /// In en, this message translates to:
  /// **'Open List'**
  String get shoppingOpenList;

  /// No description provided for @shoppingMoveCheckedSemLabel.
  ///
  /// In en, this message translates to:
  /// **'Move checked items'**
  String get shoppingMoveCheckedSemLabel;

  /// No description provided for @shoppingMoveCheckedSemHint.
  ///
  /// In en, this message translates to:
  /// **'Move {count} checked items to inventory'**
  String shoppingMoveCheckedSemHint(Object count);

  /// No description provided for @shoppingMoveCheckedToFridge.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} item(s) to fridge'**
  String shoppingMoveCheckedToFridge(Object count);

  /// No description provided for @shoppingEditingItem.
  ///
  /// In en, this message translates to:
  /// **'Editing item'**
  String get shoppingEditingItem;

  /// No description provided for @shoppingRenameItemHint.
  ///
  /// In en, this message translates to:
  /// **'Rename item'**
  String get shoppingRenameItemHint;

  /// No description provided for @recipeArchiveClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear archive?'**
  String get recipeArchiveClearTitle;

  /// No description provided for @recipeArchiveClearDesc.
  ///
  /// In en, this message translates to:
  /// **'This removes all saved recipes from your archive.'**
  String get recipeArchiveClearDesc;

  /// No description provided for @recipeArchiveClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get recipeArchiveClearAll;

  /// No description provided for @recipeArchiveSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Recipes'**
  String get recipeArchiveSavedTitle;

  /// No description provided for @recipeArchiveEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved recipes yet'**
  String get recipeArchiveEmptyTitle;

  /// No description provided for @recipeArchiveEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Save recipes and they will appear here.'**
  String get recipeArchiveEmptyDesc;

  /// No description provided for @recipeArchiveGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get recipeArchiveGoBack;

  /// No description provided for @recipeArchiveSavedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved on {date}'**
  String recipeArchiveSavedOn(Object date);

  /// No description provided for @recipeGeneratorFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String recipeGeneratorFailed(Object error);

  /// No description provided for @recipeGeneratorReviewSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Review your selection'**
  String get recipeGeneratorReviewSelectionTitle;

  /// No description provided for @recipeGeneratorReviewSelectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose ingredients and preferences before generating recipes.'**
  String get recipeGeneratorReviewSelectionDesc;

  /// No description provided for @recipeGeneratorNoItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No ingredients selected'**
  String get recipeGeneratorNoItemsTitle;

  /// No description provided for @recipeGeneratorNoItemsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select at least one ingredient to continue.'**
  String get recipeGeneratorNoItemsDesc;

  /// No description provided for @recipeGeneratorExtrasTitle.
  ///
  /// In en, this message translates to:
  /// **'Extras & Prompts'**
  String get recipeGeneratorExtrasTitle;

  /// No description provided for @recipeGeneratorCookingFor.
  ///
  /// In en, this message translates to:
  /// **'Cooking for {count}'**
  String recipeGeneratorCookingFor(Object count);

  /// No description provided for @recipeGeneratorStudentModeOn.
  ///
  /// In en, this message translates to:
  /// **'Student mode ON'**
  String get recipeGeneratorStudentModeOn;

  /// No description provided for @recipeGeneratorNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String recipeGeneratorNote(Object note);

  /// No description provided for @recipeGeneratorStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate recipes'**
  String get recipeGeneratorStartTitle;

  /// No description provided for @recipeGeneratorStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will suggest options based on your ingredients.'**
  String get recipeGeneratorStartSubtitle;

  /// No description provided for @recipeGeneratorNoRecipes.
  ///
  /// In en, this message translates to:
  /// **'No recipes generated yet.'**
  String get recipeGeneratorNoRecipes;

  /// No description provided for @recipeGeneratorSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get recipeGeneratorSuggestionsTitle;

  /// No description provided for @recipeDetailRemovedFromArchive.
  ///
  /// In en, this message translates to:
  /// **'Removed from archive'**
  String get recipeDetailRemovedFromArchive;

  /// No description provided for @recipeDetailSavedToArchive.
  ///
  /// In en, this message translates to:
  /// **'Saved to archive'**
  String get recipeDetailSavedToArchive;

  /// No description provided for @recipeDetailOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String recipeDetailOperationFailed(Object error);

  /// No description provided for @recipeDetailNoOvenTemp.
  ///
  /// In en, this message translates to:
  /// **'No oven temperature found in this recipe.'**
  String get recipeDetailNoOvenTemp;

  /// No description provided for @recipeDetailOvenBusy.
  ///
  /// In en, this message translates to:
  /// **'Oven is busy. Stop it before preheating.'**
  String get recipeDetailOvenBusy;

  /// No description provided for @recipeDetailOvenPreheating.
  ///
  /// In en, this message translates to:
  /// **'Oven preheating to {temp}C'**
  String recipeDetailOvenPreheating(Object temp);

  /// No description provided for @recipeDetailPreheatFailed.
  ///
  /// In en, this message translates to:
  /// **'Preheat failed: {error}'**
  String recipeDetailPreheatFailed(Object error);

  /// No description provided for @recipeDetailOvenAlreadyIdle.
  ///
  /// In en, this message translates to:
  /// **'Oven is already idle.'**
  String get recipeDetailOvenAlreadyIdle;

  /// No description provided for @recipeDetailOvenStopped.
  ///
  /// In en, this message translates to:
  /// **'Oven stopped.'**
  String get recipeDetailOvenStopped;

  /// No description provided for @recipeDetailStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Stop failed: {error}'**
  String recipeDetailStopFailed(Object error);

  /// No description provided for @recipeDetailSavedLeftoversToInventory.
  ///
  /// In en, this message translates to:
  /// **'Saved leftovers to inventory.'**
  String get recipeDetailSavedLeftoversToInventory;

  /// No description provided for @recipeDetailInventoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Inventory updated.'**
  String get recipeDetailInventoryUpdated;

  /// No description provided for @recipeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipe Details'**
  String get recipeDetailTitle;

  /// No description provided for @recipeDetailYields.
  ///
  /// In en, this message translates to:
  /// **'Yields: {servings}'**
  String recipeDetailYields(Object servings);

  /// No description provided for @recipeDetailSmartKitchen.
  ///
  /// In en, this message translates to:
  /// **'Smart Kitchen'**
  String get recipeDetailSmartKitchen;

  /// No description provided for @recipeDetailOvenReady.
  ///
  /// In en, this message translates to:
  /// **'Oven is Ready'**
  String get recipeDetailOvenReady;

  /// No description provided for @recipeDetailPreheatOven.
  ///
  /// In en, this message translates to:
  /// **'Preheat Oven'**
  String get recipeDetailPreheatOven;

  /// No description provided for @recipeDetailPreheatTo.
  ///
  /// In en, this message translates to:
  /// **'Preheat to {temp}'**
  String recipeDetailPreheatTo(Object temp);

  /// No description provided for @recipeDetailTemp.
  ///
  /// In en, this message translates to:
  /// **'{temp}C'**
  String recipeDetailTemp(Object temp);

  /// No description provided for @recipeDetailTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get recipeDetailTapToStop;

  /// No description provided for @recipeDetailTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get recipeDetailTapToStart;

  /// No description provided for @recipeDetailIngredientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get recipeDetailIngredientsTitle;

  /// No description provided for @recipeDetailInstructionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get recipeDetailInstructionsTitle;

  /// No description provided for @recipeDetailStep.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String recipeDetailStep(Object number);

  /// No description provided for @recipeDetailCookedThis.
  ///
  /// In en, this message translates to:
  /// **'I Cooked This'**
  String get recipeDetailCookedThis;

  /// No description provided for @recipeDetailReviewUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Ingredients Usage'**
  String get recipeDetailReviewUsageTitle;

  /// No description provided for @recipeDetailUsageNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get recipeDetailUsageNone;

  /// No description provided for @recipeDetailUsageAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recipeDetailUsageAll;

  /// No description provided for @recipeDetailConfirmUsage.
  ///
  /// In en, this message translates to:
  /// **'Confirm Usage'**
  String get recipeDetailConfirmUsage;

  /// No description provided for @recipeDetailMealPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Did you finish it all?'**
  String get recipeDetailMealPrepTitle;

  /// No description provided for @recipeDetailMealPrepDesc.
  ///
  /// In en, this message translates to:
  /// **'Or did you meal prep for later?'**
  String get recipeDetailMealPrepDesc;

  /// No description provided for @recipeDetailLeftoversToSave.
  ///
  /// In en, this message translates to:
  /// **'Leftovers to save:'**
  String get recipeDetailLeftoversToSave;

  /// No description provided for @recipeDetailWhereStoreLeftovers.
  ///
  /// In en, this message translates to:
  /// **'Where will you store it?'**
  String get recipeDetailWhereStoreLeftovers;

  /// No description provided for @recipeDetailSaveLeftovers.
  ///
  /// In en, this message translates to:
  /// **'Save Leftovers'**
  String get recipeDetailSaveLeftovers;

  /// No description provided for @recipeDetailAteEverything.
  ///
  /// In en, this message translates to:
  /// **'Ate Everything!'**
  String get recipeDetailAteEverything;

  /// No description provided for @guestListAddYourNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get guestListAddYourNameTitle;

  /// No description provided for @guestListEnterDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name'**
  String get guestListEnterDisplayNameHint;

  /// No description provided for @guestListAddNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get guestListAddNoteTitle;

  /// No description provided for @guestListAddNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. low fat, brand, size'**
  String get guestListAddNoteHint;

  /// No description provided for @guestListShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Share link copied.'**
  String get guestListShareLinkCopied;

  /// No description provided for @guestListExpiredEditingDisabled.
  ///
  /// In en, this message translates to:
  /// **'This list has expired. Editing is disabled.'**
  String get guestListExpiredEditingDisabled;

  /// No description provided for @guestListTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest Shopping List'**
  String get guestListTitle;

  /// No description provided for @guestListCopyShareLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy share link'**
  String get guestListCopyShareLinkTooltip;

  /// No description provided for @guestListMineLabel.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get guestListMineLabel;

  /// No description provided for @guestListJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining list...'**
  String get guestListJoining;

  /// No description provided for @guestListAddNameToEdit.
  ///
  /// In en, this message translates to:
  /// **'Add your name to edit items.'**
  String get guestListAddNameToEdit;

  /// No description provided for @guestListAddNameAction.
  ///
  /// In en, this message translates to:
  /// **'Add Name'**
  String get guestListAddNameAction;

  /// No description provided for @shoppingAddItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get shoppingAddItemHint;

  /// No description provided for @guestListNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get guestListNoItemsYet;

  /// No description provided for @guestListLookingForList.
  ///
  /// In en, this message translates to:
  /// **'Looking for shared list...'**
  String get guestListLookingForList;

  /// No description provided for @guestListFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load list.'**
  String get guestListFailedLoad;

  /// No description provided for @guestListRefreshPage.
  ///
  /// In en, this message translates to:
  /// **'Refresh Page'**
  String get guestListRefreshPage;

  /// No description provided for @guestListGuestFallback.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestListGuestFallback;

  /// No description provided for @guestArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No guest lists yet'**
  String get guestArchiveEmpty;

  /// No description provided for @guestArchiveExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {label}'**
  String guestArchiveExpires(Object label);

  /// No description provided for @guestArchiveExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get guestArchiveExpired;

  /// No description provided for @guestArchiveActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get guestArchiveActive;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error, please try again.'**
  String get authUnexpectedError;

  /// No description provided for @authEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email first.'**
  String get authEnterEmailFirst;

  /// No description provided for @authResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent.'**
  String get authResetEmailSent;

  /// No description provided for @authResetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get authResetEmailFailed;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginWelcomeSubtitle;

  /// No description provided for @authPleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter email.'**
  String get authPleaseEnterEmail;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email.'**
  String get authEmailInvalid;

  /// No description provided for @authPleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter password.'**
  String get authPleaseEnterPassword;

  /// No description provided for @authAtLeast6Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get authAtLeast6Chars;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogIn;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account?'**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get authSkipForNow;

  /// No description provided for @authBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authBack;

  /// No description provided for @registerPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get registerPasswordsDoNotMatch;

  /// No description provided for @registerSuccessCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign-up successful! Please check your email to confirm.'**
  String get registerSuccessCheckEmail;

  /// No description provided for @registerBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get registerBackToLogin;

  /// No description provided for @registerCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerCreateAccountTitle;

  /// No description provided for @registerCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start your smart kitchen journey.'**
  String get registerCreateAccountSubtitle;

  /// No description provided for @registerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get registerNameLabel;

  /// No description provided for @registerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get registerNameHint;

  /// No description provided for @registerEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get registerEnterName;

  /// No description provided for @registerNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name is too short.'**
  String get registerNameTooShort;

  /// No description provided for @registerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get registerPasswordHint;

  /// No description provided for @registerRepeatPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get registerRepeatPasswordLabel;

  /// No description provided for @registerRepeatPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Type password again'**
  String get registerRepeatPasswordHint;

  /// No description provided for @registerPasswordsDoNotMatchInline.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerPasswordsDoNotMatchInline;

  /// No description provided for @registerProfileDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get registerProfileDetailsTitle;

  /// No description provided for @registerGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get registerGenderLabel;

  /// No description provided for @registerAgeGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Age group'**
  String get registerAgeGroupLabel;

  /// No description provided for @registerRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registerRequired;

  /// No description provided for @registerCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get registerCountryLabel;

  /// No description provided for @registerCountryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Germany'**
  String get registerCountryHint;

  /// No description provided for @registerPleaseEnterCountry.
  ///
  /// In en, this message translates to:
  /// **'Please enter your country.'**
  String get registerPleaseEnterCountry;

  /// No description provided for @fridgeCameraSignInToConnect.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to connect fridge cameras.'**
  String get fridgeCameraSignInToConnect;

  /// No description provided for @fridgeCameraNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Home Connect is not connected.'**
  String get fridgeCameraNotConnected;

  /// No description provided for @fridgeCameraLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load fridge images: {error}'**
  String fridgeCameraLoadFailed(Object error);

  /// No description provided for @fridgeCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Fridge Camera'**
  String get fridgeCameraTitle;

  /// No description provided for @fridgeCameraRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fridgeCameraRefreshTooltip;

  /// No description provided for @fridgeCameraNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No connected fridges found.'**
  String get fridgeCameraNoDevices;

  /// No description provided for @fridgeCameraNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images available yet.'**
  String get fridgeCameraNoImages;

  /// No description provided for @fridgeCameraImageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} image(s)'**
  String fridgeCameraImageCount(Object count);

  /// No description provided for @fridgeCameraImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get fridgeCameraImageLoadFailed;

  /// No description provided for @shoppingArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase History'**
  String get shoppingArchiveTitle;

  /// No description provided for @shoppingArchiveClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get shoppingArchiveClearTooltip;

  /// No description provided for @shoppingArchiveClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get shoppingArchiveClearTitle;

  /// No description provided for @shoppingArchiveClearDesc.
  ///
  /// In en, this message translates to:
  /// **'This will remove all archived shopping items.'**
  String get shoppingArchiveClearDesc;

  /// No description provided for @shoppingArchiveClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get shoppingArchiveClearAction;

  /// No description provided for @shoppingArchiveAddBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add back to shopping list'**
  String get shoppingArchiveAddBackTooltip;

  /// No description provided for @shoppingArchiveAddedBack.
  ///
  /// In en, this message translates to:
  /// **'Added back: {name}'**
  String shoppingArchiveAddedBack(Object name);

  /// No description provided for @shoppingArchiveToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get shoppingArchiveToday;

  /// No description provided for @shoppingArchiveYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get shoppingArchiveYesterday;

  /// No description provided for @shoppingArchiveEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get shoppingArchiveEmptyTitle;

  /// No description provided for @shoppingArchiveEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed shopping items will appear here.'**
  String get shoppingArchiveEmptyDesc;

  /// No description provided for @recipeDetailAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recipeDetailAllLabel;
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
      <String>['de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
