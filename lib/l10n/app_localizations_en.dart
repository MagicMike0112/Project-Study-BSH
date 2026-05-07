// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BSH Smart Food Buddy';

  @override
  String get navToday => 'Today';

  @override
  String get todayGreetingMorning => 'Good morning';

  @override
  String get todayGreetingNoon => 'Good afternoon';

  @override
  String get todayGreetingEvening => 'Good evening';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navShopping => 'Shopping';

  @override
  String get navImpact => 'Impact';

  @override
  String get undo => 'Oops, undo!';

  @override
  String get prefLanguageTitle => 'Language';

  @override
  String get prefLanguageSubtitle => 'Switch app language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageGerman => 'German';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeFollowSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSectionHousehold => 'Household';

  @override
  String get accountSectionMyHome => 'My Home';

  @override
  String get accountSectionIntegrations => 'Integrations';

  @override
  String get accountSectionPreferences => 'Preferences';

  @override
  String get accountSectionAbout => 'About';

  @override
  String get accountNotificationsTitle => 'Notifications';

  @override
  String get accountNotificationsSubtitle => 'Expiry alerts & reminders';

  @override
  String get notificationPermissionBlocked =>
      'Notification permission is blocked in system settings.';

  @override
  String get notificationMealReminderMessage =>
      'Some of your ingredients are expiring soon. Check Smart Food Home.';

  @override
  String get notificationSavedFutureApply =>
      'Saved. New reminder time will apply to future notifications.';

  @override
  String get notificationEnablePermissionFirst =>
      'Please enable notification permission first.';

  @override
  String get notificationTestMessage =>
      'This is a test expiry reminder from Smart Food Home.';

  @override
  String get notificationTestSent => 'Test notification sent.';

  @override
  String get notificationThreeDayExpiryTitle => '3-day expiry alerts';

  @override
  String get notificationThreeDayExpiryDesc =>
      'One-time reminder when an item is 3 days from expiry.';

  @override
  String get notificationMealTimeTitle => 'Meal-time reminders';

  @override
  String get notificationMealTimeDesc =>
      'Two daily reminders at your lunch and dinner time.';

  @override
  String get notificationPermissionAllowed =>
      'System notification permission: allowed';

  @override
  String get notificationPermissionBlockedStatus =>
      'System notification permission: blocked';

  @override
  String notificationStatusCombined(Object mealStatus, Object threeDayStatus) {
    return 'Meal reminders: $mealStatus | 3-day alerts: $threeDayStatus';
  }

  @override
  String get notificationStatusScheduled => 'scheduled';

  @override
  String get notificationStatusOff => 'off';

  @override
  String get notificationMealTimesTitle => 'Meal times';

  @override
  String get notificationMealTimesHint =>
      'We\'ll notify you about expiring items at these times.';

  @override
  String get notificationLunchLabel => 'Usual lunch time';

  @override
  String get notificationDefaultLunchTime => '11:30 (default)';

  @override
  String get notificationDinnerLabel => 'Usual dinner time';

  @override
  String get notificationDefaultDinnerTime => '17:30 (default)';

  @override
  String get notificationResetDefaults => 'Reset to defaults';

  @override
  String get notificationSendTestNow => 'Send test now';

  @override
  String familyLoadMembersFailed(Object error) {
    return 'Failed to load members: $error';
  }

  @override
  String get familyErrorTitle => 'Error';

  @override
  String familyGenerateCodeFailed(Object error) {
    return 'Failed to generate code:\n\n$error';
  }

  @override
  String get familyOk => 'OK';

  @override
  String get familyJoinTitle => 'Join Family';

  @override
  String get familyJoinDesc =>
      'Enter the 6-digit invitation code shared by a family member.';

  @override
  String get familyInviteCodeLabel => 'Invite Code';

  @override
  String get familyJoinAction => 'Join';

  @override
  String get familyJoinedSuccess => 'Joined family successfully!';

  @override
  String get familyInvalidOrExpiredCode => 'Invalid or expired code.';

  @override
  String familyErrorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get familyLeaveTitle => 'Leave Family?';

  @override
  String get familyLeaveDesc =>
      'You will no longer see shared inventory and shopping lists. You will return to your own private home.';

  @override
  String get familyLeaveAction => 'Leave';

  @override
  String get familyLeftSuccess => 'Left family. Switched to private mode.';

  @override
  String get familyLeaveFailed => 'Failed to leave family.';

  @override
  String get familyInviteMemberTitle => 'Invite Member';

  @override
  String get familyInviteMemberDesc =>
      'Share this code with your family member.\nThey can use it to join your home.';

  @override
  String get familyInviteExpiresIn2Days => 'Expires in 2 days';

  @override
  String get familyDone => 'Done';

  @override
  String get familyUpdateNameTitle => 'Update your name';

  @override
  String get familyDisplayNameHint => 'Enter your display name';

  @override
  String get familyNameUpdated => 'Name updated.';

  @override
  String get familyNameUpdateFailed => 'Failed to update name.';

  @override
  String get familyMyFamilyTitle => 'My Family';

  @override
  String get familyMembersTitle => 'Members';

  @override
  String get familyNoMembersFound => 'No members found.';

  @override
  String get familyInviteNewMember => 'Invite New Member';

  @override
  String get familyJoinAnotherFamily => 'Join Another Family';

  @override
  String get familyLeaveThisFamily => 'Leave This Family';

  @override
  String get familyInventoryShoppingSynced =>
      'Inventory and Shopping List Synced';

  @override
  String get familyYourDisplayName => 'Your display name';

  @override
  String get familyEdit => 'Edit';

  @override
  String get familyMigrationFailed => 'Migration failed';

  @override
  String get familyMigratingData => 'Migrating your data';

  @override
  String get familyKeepAppOpen => 'Please keep the app open.';

  @override
  String familyMigrationAttempt(Object attempt, Object total) {
    return 'Attempt $attempt / $total';
  }

  @override
  String get familyInventoryMode => 'Inventory Mode';

  @override
  String get familySharedFridgeTitle => 'Shared Fridge';

  @override
  String get familySharedFridgeDesc => 'All members manage inventory together.';

  @override
  String get familySeparateFridgesTitle => 'Separate Fridges';

  @override
  String get familySeparateFridgesDesc =>
      'Items are strictly assigned to owners.';

  @override
  String get familyUnknownMember => 'Unknown';

  @override
  String get familyUnknownInitial => 'U';

  @override
  String get accountNightModeTitle => 'Night Mode';

  @override
  String get accountStudentModeTitle => 'Student Mode';

  @override
  String get accountStudentModeSubtitle => 'Budget-friendly recipes & tips';

  @override
  String get accountLoyaltyCardsTitle => 'Loyalty Cards';

  @override
  String get accountLoyaltyCardsSubtitle => 'Connect PAYBACK (Coming soon)';

  @override
  String get accountPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String get accountVersionTitle => 'Version';

  @override
  String get accountSignOut => 'Sign Out';

  @override
  String accountHelloUser(Object name) {
    return 'Hello, $name';
  }

  @override
  String get accountGuestTitle => 'Guest Account';

  @override
  String get accountSignInHint => 'Sign in to sync your data';

  @override
  String get accountLogIn => 'Log In';

  @override
  String get accountHomeConnectLinked => 'Home Connect Linked!';

  @override
  String get accountConnectionFailed => 'Connection Failed';

  @override
  String get accountDisconnected => 'Disconnected';

  @override
  String get accountSimulatorAppliances => 'Simulator Appliances';

  @override
  String get accountNoAppliancesFound => 'No appliances found';

  @override
  String get accountUnknown => 'Unknown';

  @override
  String get accountIdCopied => 'ID Copied';

  @override
  String accountApplianceId(Object id) {
    return 'ID: $id';
  }

  @override
  String get accountHomeConnectTitle => 'Home Connect';

  @override
  String get accountRefreshStatus => 'Refresh Status';

  @override
  String get accountViewAppliances => 'View Appliances';

  @override
  String get accountDisconnect => 'Disconnect';

  @override
  String get accountConnecting => 'Connecting...';

  @override
  String get accountActiveSynced => 'Active & Synced';

  @override
  String get accountTapToConnect => 'Tap to connect';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardScopeWorld => 'World';

  @override
  String get leaderboardGlobalTitle => 'Global';

  @override
  String get leaderboardGlobalSubtitle => 'Top performers worldwide';

  @override
  String get leaderboardYourRank => 'Your Rank';

  @override
  String get leaderboardNoDataYet => 'No data yet';

  @override
  String leaderboardRankInScope(Object rank, Object scope) {
    return '#$rank in $scope';
  }

  @override
  String get leaderboardLoadFailedTitle => 'Failed to load leaderboard';

  @override
  String get retry => 'Retry';

  @override
  String leaderboardPointsKgCo2(Object value) {
    return '$value kg CO2';
  }

  @override
  String get leaderboardAddFriendTitle => 'Add Friend';

  @override
  String get leaderboardFriendEmailLabel => 'Friend email';

  @override
  String get leaderboardFriendEmailHint => 'name@email.com';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get leaderboardNoUserForEmail => 'No user found for that email.';

  @override
  String get leaderboardInvalidUserId => 'Invalid user id for that email.';

  @override
  String get leaderboardCannotAddYourself => 'You cannot add yourself.';

  @override
  String get leaderboardFriendAdded => 'Friend added.';

  @override
  String leaderboardAddFriendFailed(Object error) {
    return 'Add friend failed: $error';
  }

  @override
  String get pullToRefreshHint => 'Pull to refresh';

  @override
  String get pullToRefreshRelease => 'Release to refresh';

  @override
  String get foodLocationFridge => 'Fridge';

  @override
  String get foodLocationFreezer => 'Freezer';

  @override
  String get foodLocationPantry => 'Pantry';

  @override
  String foodExpiredDaysAgo(Object days) {
    return 'Expired ${days}d ago';
  }

  @override
  String foodDaysLeft(Object days) {
    return '$days days left';
  }

  @override
  String get foodActionCookEat => 'Cook / Eat';

  @override
  String get foodActionFeedPets => 'Feed Pets';

  @override
  String get foodActionDiscard => 'Discard';

  @override
  String get foodPetsHappy => 'Little Shi & Little Yuan are happy!';

  @override
  String get todayRecipeArchiveTooltip => 'Recipe Archive';

  @override
  String get todayAiChefTitle => 'AI Chef';

  @override
  String get todayAiChefDescription =>
      'Use current ingredients to generate recipes.';

  @override
  String get todayExpiringSoonTitle => 'Expiring Soon';

  @override
  String get todayExpiringSoonDescription =>
      'Quickly cook, feed pets, or discard items.';

  @override
  String get todayPetSafetyWarning =>
      'Please ensure the food is safe for your pet!';

  @override
  String get todayWhatCanICook => 'What can I\ncook today?';

  @override
  String todayBasedOnItems(int count) {
    return 'Based on $count items in your fridge.';
  }

  @override
  String get todayGenerate => 'Generate';

  @override
  String get todayPlanWeekTitle => 'Plan Your Week!';

  @override
  String get todayPlanWeekSubtitle => 'Tap to plan meals.';

  @override
  String get todayViewAll => 'View All';

  @override
  String get todayExpired => 'Expired';

  @override
  String get todayExpiryToday => 'Today';

  @override
  String get todayOneDayLeft => '1 day left';

  @override
  String get todayAllClearTitle => 'All Clear!';

  @override
  String get todayAllClearSubtitle => 'Your fridge is fresh and organized.';

  @override
  String todayUndoCooked(Object name) {
    return 'Cooked \"$name\"';
  }

  @override
  String todayUndoFedPet(Object name) {
    return 'Fed \"$name\" to pet';
  }

  @override
  String todayUndoDiscarded(Object name) {
    return 'Discarded \"$name\"';
  }

  @override
  String todayUndoUpdated(Object name) {
    return 'Updated \"$name\"';
  }

  @override
  String get commonSave => 'Save';

  @override
  String get inventorySyncChangesLabel => 'Sync changes to cloud';

  @override
  String get inventoryCloudSyncStatusLabel => 'Cloud sync status';

  @override
  String get inventorySyncRetryHint => 'Tap to retry syncing pending changes';

  @override
  String get inventorySyncAllSavedHint =>
      'Tap to confirm all changes are saved';

  @override
  String get inventorySyncingChanges => 'Syncing changes...';

  @override
  String get inventoryAllChangesSaved => 'All changes saved';

  @override
  String get inventorySyncingChangesToCloud => 'Syncing changes to cloud...';

  @override
  String get inventoryAllSavedToCloud => 'All changes saved to cloud.';

  @override
  String get inventoryQuickSearchTitle => 'Quick Search';

  @override
  String get inventoryQuickSearchDescription =>
      'Find any item by name in seconds.';

  @override
  String get inventorySearchHint => 'Search items...';

  @override
  String get inventoryNoItemsFound => 'No items found';

  @override
  String get inventoryEmptyTitle => 'Your inventory is empty';

  @override
  String get inventoryEmptySubtitle => 'Tap the + button to add items.';

  @override
  String get inventoryLongPressTitle => 'Long Press Menu';

  @override
  String get inventoryLongPressDescription =>
      'Press and hold an item to edit, use quantity, move, or delete.';

  @override
  String get inventorySwipeDeleteTitle => 'Swipe Left to Delete';

  @override
  String get inventorySwipeDeleteDescription =>
      'Swipe an item to the left to delete it. You can undo right after.';

  @override
  String get inventoryItemNoteTitle => 'Item note';

  @override
  String get inventoryItemNoteHint => 'Add a short note...';

  @override
  String get inventoryEditNote => 'Edit note';

  @override
  String get inventoryAddNote => 'Add note';

  @override
  String get inventorySharedLabel => 'Shared';

  @override
  String get inventoryNoteReminderSubtitle => 'Leave a quick reminder';

  @override
  String get inventoryChangeCategory => 'Change category';

  @override
  String get inventoryRecordUsageUpdateQty =>
      'Record usage and update quantity';

  @override
  String get inventoryGreatForLeftovers => 'Great for leftovers';

  @override
  String get inventoryTrackWasteImproveHabits =>
      'Track waste to improve habits';

  @override
  String inventoryCookedToast(Object qty, Object name) {
    return 'Cooked $qty of $name';
  }

  @override
  String inventoryFedToPetToast(Object name) {
    return 'Fed $name to pet';
  }

  @override
  String inventoryRecordedWasteToast(Object name) {
    return 'Recorded waste: $name';
  }

  @override
  String inventoryDeletedToast(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get inventoryCookWithThis => 'Cook with this';

  @override
  String get inventoryFeedToPet => 'Feed to pet';

  @override
  String get inventoryWastedThrownAway => 'Wasted / Thrown away';

  @override
  String get inventoryEditDetails => 'Edit details';

  @override
  String get inventoryDeleteItem => 'Delete item';

  @override
  String get inventoryDeleteItemQuestion => 'Delete item?';

  @override
  String inventoryDeletePermanentQuestion(Object name) {
    return 'Remove \"$name\" from your inventory permanently?';
  }

  @override
  String get inventoryDeleteAction => 'Delete';

  @override
  String get inventoryDetailQuantity => 'Quantity';

  @override
  String get inventoryDetailAdded => 'Added';

  @override
  String get inventoryDetailStorageLocation => 'Storage Location';

  @override
  String get inventoryDetailNotes => 'Notes';

  @override
  String get inventoryDetailStatusExpired => 'Expired';

  @override
  String get inventoryDetailStatusExpiresToday => 'Expires today';

  @override
  String get inventoryDetailStatusExpiring => 'Expiring';

  @override
  String get inventoryDetailStatusFresh => 'Fresh';

  @override
  String get inventoryDetailAddedToday => 'Added today';

  @override
  String get inventoryDetailAddedOneDayAgo => 'Added 1 day ago';

  @override
  String inventoryDetailAddedDaysAgo(Object days) {
    return 'Added $days days ago';
  }

  @override
  String get inventoryDetailDaysLeftLabel => 'DAYS\nLEFT';

  @override
  String get inventoryDetailEditDetailsSubtitle =>
      'Update item details and expiry';

  @override
  String inventorySheetUpdating(Object name) {
    return 'Updating: $name';
  }

  @override
  String get inventoryActionType => 'Action Type';

  @override
  String get inventoryActionCooked => 'Cooked';

  @override
  String get inventoryActionPetFeed => 'Pet Feed';

  @override
  String get inventoryActionWaste => 'Waste';

  @override
  String get inventoryQuickAssign => 'Quick Assign';

  @override
  String get inventoryEditFamily => 'Edit Family';

  @override
  String get inventoryYouLabel => 'You';

  @override
  String get inventoryConfirmUpdate => 'Confirm Update';

  @override
  String get inventoryQuantityUsed => 'Quantity Used';

  @override
  String inventoryRemainingQty(Object value, Object unit) {
    return 'Remaining: $value$unit';
  }

  @override
  String get inventorySemanticsQuantityUsed => 'Quantity used';

  @override
  String get inventorySemanticsUsageHint =>
      'Drag left or right to adjust usage';

  @override
  String get inventorySemanticsAdjustUsedAmount => 'Adjust used amount';

  @override
  String get shoppingTemporaryListTooltip => 'Temporary List';

  @override
  String get shoppingFridgeCameraTitle => 'Fridge Camera';

  @override
  String get shoppingFridgeCameraDescription =>
      'Scan your fridge to speed up planning.';

  @override
  String get shoppingPurchaseHistoryTitle => 'Purchase History';

  @override
  String get shoppingPurchaseHistoryDescription =>
      'Review bought items and add them back.';

  @override
  String get shoppingCompletedLabel => 'COMPLETED';

  @override
  String get shoppingAiSmartAddTitle => 'AI Smart Add';

  @override
  String get shoppingAiSmartAddDescription => 'Add ingredients from a recipe.';

  @override
  String get shoppingAiSmartAddHint => 'Import ingredients from recipe text';

  @override
  String get shoppingQuickAddTitle => 'Quick Add';

  @override
  String get shoppingQuickAddDescription => 'Add one item instantly.';

  @override
  String get shoppingQuickAddSemanticsLabel => 'Quick add item';

  @override
  String get shoppingInputHint => 'Add item here';

  @override
  String get shoppingRecipeImportTitle => 'Recipe Import';

  @override
  String get shoppingRecipeSignInRequiredAction =>
      'Please sign in to use AI Recipe Scan.';

  @override
  String get shoppingRecipeSignInAction => 'SIGN IN';

  @override
  String get shoppingRecipeProvideInput =>
      'Please provide a recipe name, text, or image.';

  @override
  String shoppingRecipeAnalysisFailed(Object error) {
    return 'Analysis failed: $error';
  }

  @override
  String shoppingRecipeAddedItems(Object count) {
    return 'Added $count items to shopping list';
  }

  @override
  String get shoppingRecipeInputHint => 'Enter dish name or paste recipe...';

  @override
  String get shoppingRecipeIngredientsSection => 'Ingredients';

  @override
  String get shoppingRecipeSeasoningsSection => 'Seasonings';

  @override
  String get shoppingRecipeCamera => 'Camera';

  @override
  String get shoppingRecipeAlbum => 'Album';

  @override
  String get shoppingRecipeAnalyzing => 'Analyzing...';

  @override
  String get shoppingRecipeGetListButton => 'Get Shopping list';

  @override
  String get shoppingRecipeAiThinking => 'AI is thinking...';

  @override
  String get shoppingRecipeResultsPlaceholder =>
      'Your results will appear here';

  @override
  String shoppingRecipeInStockReason(Object reason) {
    return 'In stock: $reason';
  }

  @override
  String shoppingRecipeCategoryLabel(Object category) {
    return 'Category: $category';
  }

  @override
  String shoppingRecipeAddSelectedToList(Object count) {
    return 'Add $count Items to List';
  }

  @override
  String get shoppingRecipeSignInRequiredTitle => 'Sign in Required';

  @override
  String get shoppingRecipeSignInRequiredSubtitle =>
      'Please sign in to sync with your inventory and use AI recipe analysis.';

  @override
  String get shoppingRecipeSignInNow => 'Sign In Now';

  @override
  String get shoppingEmptyTitle => 'Your list is empty';

  @override
  String get shoppingEmptySubtitle =>
      'Add items manually or use recipe import.';

  @override
  String shoppingDeletedToast(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get shoppingUndoAction => 'Undo';

  @override
  String get impactTitle => 'Your Impact';

  @override
  String get impactTimeRangeTitle => 'Time Range';

  @override
  String get impactTimeRangeDescription =>
      'Switch between week, month, and year views.';

  @override
  String get impactSummaryTitle => 'Impact Summary';

  @override
  String get impactSummaryDescription =>
      'See money saved and items rescued here.';

  @override
  String impactKgAvoided(Object value) {
    return '${value}kg avoided';
  }

  @override
  String get impactLevelTitle => 'Level';

  @override
  String get impactStreakTitle => 'Streak';

  @override
  String get impactDaysActive => 'Days active';

  @override
  String get impactActiveBadge => 'Active';

  @override
  String get impactWeeklyReportTitle => 'Weekly Report';

  @override
  String get impactWeeklyReportDescription =>
      'Open your AI weekly summary and insights.';

  @override
  String get impactWeeklyReviewSubtitle =>
      'Review your progress from last week';

  @override
  String get weeklyAddedToShoppingList => 'Added to shopping list.';

  @override
  String get weeklyHeiExplainedTitle => 'HEI-2015 Explained';

  @override
  String get weeklyHeiExplainedIntro =>
      'The Healthy Eating Index (HEI-2015) is a 0-100 score that measures how well a diet aligns with the Dietary Guidelines for Americans.';

  @override
  String get weeklyHeiHowComputeTitle => 'How we compute it';

  @override
  String get weeklyHeiHowComputeBody =>
      'We estimate HEI components using USDA FoodData Central nutrients and your logged foods. Components include:';

  @override
  String get weeklyHeiComponentsList =>
      '- Fruits (total and whole)\n- Vegetables (total and greens/beans)\n- Whole grains\n- Dairy\n- Total protein and seafood/plant protein\n- Fatty acids ratio\n- Moderation: refined grains, sodium, added sugars, saturated fat';

  @override
  String get weeklyHeiMorePoints =>
      'More points = better balance. We normalize per 1,000 kcal where applicable and use HEI-2015 scoring standards.';

  @override
  String get weeklyGotIt => 'Got it';

  @override
  String get weeklyHeiLabelExcellent => 'Excellent';

  @override
  String get weeklyHeiLabelGood => 'Good';

  @override
  String get weeklyHeiLabelFair => 'Fair';

  @override
  String get weeklyHeiLabelNeedsWork => 'Needs Work';

  @override
  String get weeklyMacrosNotEnoughData =>
      'Not enough data to calculate macros.';

  @override
  String get weeklyMacroProtein => 'Protein';

  @override
  String get weeklyMacroCarbs => 'Carbs';

  @override
  String get weeklyMacroFat => 'Fat';

  @override
  String weeklyDataSource(Object source) {
    return 'Data source: $source';
  }

  @override
  String get weeklyPrev => 'Prev';

  @override
  String get weeklyNext => 'Next';

  @override
  String get impactChooseMascot => 'Choose your mascot';

  @override
  String get impactMascotNameTitle => 'Mascot name';

  @override
  String get impactMascotNameHint => 'Give it a name';

  @override
  String get impactMascotCat => 'Cat';

  @override
  String get impactMascotDog => 'Dog';

  @override
  String get impactMascotHamster => 'Hamster';

  @override
  String get impactMascotGuineaPig => 'Guinea Pig';

  @override
  String impactFedToMascot(Object name) {
    return 'Fed to $name';
  }

  @override
  String get impactItemFallback => 'Item';

  @override
  String get impactFridgeMasterTitle => 'Fridge Master!';

  @override
  String impactSavedItemsStreak(Object savedCount, Object streak) {
    return 'Saved $savedCount items - $streak day streak';
  }

  @override
  String get impactTotalSavingsLabel => 'TOTAL SAVINGS';

  @override
  String get impactNextRankLabel => 'Next Rank: Zero Waste Hero';

  @override
  String impactBasedOnSavedItems(Object count) {
    return 'Based on $count items saved';
  }

  @override
  String impactOnTrackYearly(Object amount) {
    return 'On track to save $amount / year';
  }

  @override
  String get impactCommunityQuestTitle => 'Community Quest';

  @override
  String get impactNewBadge => 'New!';

  @override
  String impactYouSavedCo2ThisWeek(Object value) {
    return 'You saved ${value}kg CO2 this week!';
  }

  @override
  String get impactViewLeaderboard => 'View Leaderboard';

  @override
  String get impactTopSaversTitle => 'Top Savers';

  @override
  String get impactSeeAll => 'See all';

  @override
  String get impactMostSavedLabel => 'Most Saved';

  @override
  String get impactRecentActionsTitle => 'Recent Actions';

  @override
  String get impactFamilyLabel => 'Family';

  @override
  String get impactActionCooked => 'Cooked';

  @override
  String get impactActionFedToPet => 'Fed to pet';

  @override
  String get impactActionWasted => 'Wasted';

  @override
  String get impactTapForDietInsights => 'Tap to view your diet insights';

  @override
  String impactEnjoyedLeftovers(Object weight) {
    return 'Enjoyed ${weight}kg of leftovers';
  }

  @override
  String get impactNoDataTitle => 'No data yet';

  @override
  String get impactNoDataSubtitle => 'Start saving food to see your impact!';

  @override
  String get impactRangeWeek => 'Week';

  @override
  String get impactRangeMonth => 'Month';

  @override
  String get impactRangeYear => 'Year';

  @override
  String get addFoodVoiceTapToStart => 'Tap mic to start';

  @override
  String get addFoodDateNotSet => 'Not set';

  @override
  String get addFoodTextTooShort => 'Text too short, please provide more info.';

  @override
  String addFoodRecognizedItems(int count) {
    return 'Recognized $count item(s).';
  }

  @override
  String get addFoodAiParserUnavailable =>
      'AI parser unavailable, used local parser.';

  @override
  String get addFoodAiUnexpectedResponse =>
      'Unexpected AI response, used local parser.';

  @override
  String get addFoodFormFilledFromVoice => 'Form filled from voice.';

  @override
  String get addFoodAiReturnedEmpty =>
      'AI parser returned empty, used local parser.';

  @override
  String get addFoodNetworkParseFailed =>
      'Network parse failed, used local parser.';

  @override
  String addFoodAiParseFailed(Object error) {
    return 'AI parse failed: $error';
  }

  @override
  String get addFoodEnterNameFirst => 'Please enter the food name first';

  @override
  String addFoodExpirySetTo(Object date) {
    return 'Expiry set to $date';
  }

  @override
  String get addFoodMaxFourImages => 'Max 4 images allowed. Selecting first 4.';

  @override
  String get addFoodNoItemsDetected => 'No items detected in images.';

  @override
  String addFoodScanFailed(Object error) {
    return 'Scan failed: $error';
  }

  @override
  String addFoodVoiceError(Object error) {
    return 'Voice error: $error';
  }

  @override
  String get addFoodSpeechNotAvailable => 'Speech not available on this device';

  @override
  String get addFoodSpeechNotSupported =>
      'Speech recognition not supported on this device.';

  @override
  String addFoodSpeechInitFailed(Object code) {
    return 'Speech init failed: $code';
  }

  @override
  String get addFoodSpeechInitUnable =>
      'Unable to initialize speech recognition.';

  @override
  String get addFoodOpeningXiaomiSpeech => 'Opening Xiaomi speech...';

  @override
  String get addFoodVoiceGotIt => 'Got it! Tap Analyze & Fill.';

  @override
  String get addFoodVoiceCanceled => 'Voice canceled. Tap mic to retry.';

  @override
  String get addFoodMicBlocked => 'Mic blocked. Enable in Settings.';

  @override
  String get addFoodMicDenied => 'Mic permission denied.';

  @override
  String get addFoodListeningNow => 'I\'m listening...';

  @override
  String get addFoodAddItemTitle => 'Add Item';

  @override
  String get addFoodEditItemTitle => 'Edit Item';

  @override
  String get addFoodHelpButton => 'Help';

  @override
  String get addFoodTabManual => 'Manual';

  @override
  String get addFoodTabScan => 'Scan';

  @override
  String get addFoodTabVoice => 'Voice';

  @override
  String get addFoodBasicInfoTitle => 'Basic Info';

  @override
  String get addFoodNameLabel => 'Name';

  @override
  String get addFoodRequired => 'Required';

  @override
  String get addFoodQuantityLabel => 'Quantity';

  @override
  String get addFoodUnitLabel => 'Unit';

  @override
  String get addFoodMinStockWarningLabel => 'Min Stock Warning (Optional)';

  @override
  String get addFoodMinStockHint => 'e.g. 2 (Notify when below)';

  @override
  String get addFoodMinStockHelper => 'Leave empty for no warnings';

  @override
  String get addFoodStorageLocationTitle => 'Storage Location';

  @override
  String get addFoodCategoriesTitle => 'Categories';

  @override
  String get addFoodDatesTitle => 'Dates';

  @override
  String get addFoodPurchaseDate => 'Purchase Date';

  @override
  String get addFoodOpenDate => 'Open Date';

  @override
  String get addFoodBestBefore => 'Best Before';

  @override
  String get addFoodSaveToInventory => 'Save to Inventory';

  @override
  String get addFoodScanReceipt => 'Scan Receipt';

  @override
  String get addFoodSnapFridge => 'Snap Fridge';

  @override
  String get addFoodTakePhoto => 'Take Photo';

  @override
  String get addFoodUseCameraToScan => 'Use camera to scan';

  @override
  String get addFoodUploadMax4 => 'Upload (Max 4)';

  @override
  String get addFoodChooseMultipleFromGallery => 'Choose multiple from gallery';

  @override
  String get addFoodAiExtractReceiptItems =>
      'AI will extract items from your receipt(s).';

  @override
  String get addFoodAiIdentifyFridgeItems =>
      'AI will identify items in your fridge or pantry.';

  @override
  String get addFoodAutoLabel => 'Auto';

  @override
  String get addFoodXiaomiSpeechMode => 'Xiaomi speech mode';

  @override
  String addFoodEngineReady(Object locale) {
    return 'Engine ready - $locale';
  }

  @override
  String get addFoodPreparingEngine => 'Preparing speech engine...';

  @override
  String get addFoodVoiceTrySaying =>
      'Try saying: \"3 apples, milk, and 1kg of rice\"';

  @override
  String get addFoodTranscriptHint => 'Transcript will appear here...';

  @override
  String get addFoodClear => 'Clear';

  @override
  String get addFoodAnalyzing => 'Analyzing...';

  @override
  String get addFoodAnalyzeAndFill => 'Analyze & Fill';

  @override
  String get addFoodAiExpiryPrediction => 'AI Expiry Prediction';

  @override
  String get addFoodAutoMagic => 'Auto magic';

  @override
  String get addFoodThinking => 'Thinking...';

  @override
  String get addFoodPredictedExpiry => 'Predicted Expiry';

  @override
  String get addFoodManualDateOverride => 'Manual date will override this';

  @override
  String get addFoodAutoApplied => 'Auto applied';

  @override
  String get addFoodAiSuggestHint =>
      'Let AI suggest based on food type and storage.';

  @override
  String get addFoodErrorPrefix => 'Error:';

  @override
  String get addFoodAutoMagicPrediction => 'Auto Magic Prediction';

  @override
  String get addFoodScanningReceipts => 'Scanning Receipts...';

  @override
  String get addFoodProcessing => 'Processing';

  @override
  String get addFoodItemsTitle => 'Items';

  @override
  String addFoodAddCountItems(int count) {
    return 'Add $count Items';
  }

  @override
  String addFoodAddedItems(int count) {
    return 'Added $count items';
  }

  @override
  String get addFoodHelpTitle => 'Add Item Help';

  @override
  String get addFoodHelpManualTitle => 'Manual';

  @override
  String get addFoodHelpManualPoint1 =>
      'Enter name, quantity, and storage location.';

  @override
  String get addFoodHelpManualPoint2 =>
      'Set Best Before if you know the package date.';

  @override
  String get addFoodHelpManualPoint3 => 'Use note for size/brand reminders.';

  @override
  String get addFoodHelpScanTitle => 'Scan';

  @override
  String get addFoodHelpScanPoint1 => 'Use clear photos with good lighting.';

  @override
  String get addFoodHelpScanPoint2 => 'For receipts, keep text fully visible.';

  @override
  String get addFoodHelpScanPoint3 => 'Review detected items before saving.';

  @override
  String get addFoodHelpVoiceTitle => 'Voice';

  @override
  String get addFoodHelpVoicePoint1 =>
      'Say item + quantity + unit, e.g. \"Milk two liters\".';

  @override
  String get addFoodHelpVoicePoint2 => 'Pause briefly between multiple items.';

  @override
  String get addFoodHelpVoicePoint3 => 'Edit fields before saving if needed.';

  @override
  String get addFoodHelpTip =>
      'Tip: If expiry is unknown, use AI prediction and adjust manually if needed.';

  @override
  String get selectIngredientsKitchenTitle => 'Your Kitchen';

  @override
  String selectIngredientsSelectedCount(int count) {
    return '$count items selected for cooking';
  }

  @override
  String get selectIngredientsNoItemsSubtitle =>
      'Try a different filter or add new items.';

  @override
  String get selectIngredientsExtrasPrompts => 'Extras & Prompts';

  @override
  String get selectIngredientsAddExtraHint => 'Add extra ingredients...';

  @override
  String get selectIngredientsSpecialRequestHint =>
      'Any specific cravings or dietary restrictions?';

  @override
  String get selectIngredientsPageTitle => 'Select Ingredients';

  @override
  String get selectIngredientsReset => 'Reset';

  @override
  String get selectIngredientsFilterAll => 'All Items';

  @override
  String get selectIngredientsFilterExpiring => 'Expiring';

  @override
  String get selectIngredientsFilterVeggie => 'Veggie';

  @override
  String get selectIngredientsFilterMeat => 'Meat';

  @override
  String get selectIngredientsFilterDairy => 'Dairy';

  @override
  String get selectIngredientsExpiringLabel => 'Expiring';

  @override
  String get selectIngredientsSoonLabel => 'Soon';

  @override
  String get selectIngredientsFreshLabel => 'Fresh';

  @override
  String selectIngredientsQuantityLeft(Object value, Object unit) {
    return '$value $unit left';
  }

  @override
  String get selectIngredientsPeopleShort => 'Ppl';

  @override
  String cookingPlanSlot(Object slot) {
    return 'Plan $slot';
  }

  @override
  String get cookingMealNameLabel => 'Meal name';

  @override
  String get cookingMealNameHint => 'e.g. Lemon Chicken Bowl';

  @override
  String get cookingQuickPickRecipes => 'Quick pick from recipes';

  @override
  String get cookingBrowseAll => 'Browse All';

  @override
  String get cookingUseFromInventory => 'Use from inventory';

  @override
  String get cookingMissingItemsLabel => 'Missing items (add to shopping list)';

  @override
  String get cookingMissingItemsHint => 'e.g. garlic, scallions';

  @override
  String get cookingSavePlan => 'Save Plan';

  @override
  String get cookingUntitledMeal => 'Untitled meal';

  @override
  String cookingAddedItemsToShopping(int count) {
    return 'Added $count items to shopping list.';
  }

  @override
  String get cookingMealPlannerTitle => 'Meal Planner';

  @override
  String get cookingJumpToToday => 'Jump to today';

  @override
  String get cookingNoMatches => 'No matches';

  @override
  String cookingMissingItemsCount(int count) {
    return 'Missing $count items';
  }

  @override
  String get cookingAllItemsInFridge => 'All items in fridge';

  @override
  String get cookingSlotBreakfast => 'Breakfast';

  @override
  String get cookingSlotLunch => 'Lunch';

  @override
  String get cookingSlotDinner => 'Dinner';

  @override
  String get shoppingGuestCreateTempTitle => 'Create temporary list';

  @override
  String get shoppingGuestCreateTempSubtitle =>
      'Share with guests without requiring login.';

  @override
  String get shoppingGuestMyListsTitle => 'My guest lists';

  @override
  String get shoppingGuestMyListsSubtitle => 'Manage existing temporary lists.';

  @override
  String get shoppingGuestDialogTitle => 'Create Temporary List';

  @override
  String get shoppingGuestTitleHint => 'e.g. Dinner Party';

  @override
  String get shoppingGuestExpiresIn => 'Expires in';

  @override
  String get shoppingGuestExpire24h => '24 hours';

  @override
  String get shoppingGuestExpire3d => '3 days';

  @override
  String get shoppingGuestExpire7d => '7 days';

  @override
  String get shoppingGuestAttachMineTitle => 'Attach to my account';

  @override
  String get shoppingGuestAttachMineSubtitle =>
      'Only your account can edit owner settings.';

  @override
  String get shoppingGuestCreateAction => 'Create';

  @override
  String get shoppingShareLinkTitle => 'Share this link';

  @override
  String get shoppingLinkCopied => 'Link copied.';

  @override
  String get shoppingCopyLink => 'Copy Link';

  @override
  String get shoppingOpenList => 'Open List';

  @override
  String get shoppingMoveCheckedSemLabel => 'Move checked items';

  @override
  String shoppingMoveCheckedSemHint(Object count) {
    return 'Move $count checked items to inventory';
  }

  @override
  String shoppingMoveCheckedToFridge(Object count) {
    return 'Moved $count item(s) to fridge';
  }

  @override
  String get shoppingEditingItem => 'Editing item';

  @override
  String get shoppingRenameItemHint => 'Rename item';

  @override
  String get recipeArchiveClearTitle => 'Clear archive?';

  @override
  String get recipeArchiveClearDesc =>
      'This removes all saved recipes from your archive.';

  @override
  String get recipeArchiveClearAll => 'Clear All';

  @override
  String get recipeArchiveSavedTitle => 'Saved Recipes';

  @override
  String get recipeArchiveEmptyTitle => 'No saved recipes yet';

  @override
  String get recipeArchiveEmptyDesc =>
      'Save recipes and they will appear here.';

  @override
  String get recipeArchiveGoBack => 'Go Back';

  @override
  String recipeArchiveSavedOn(Object date) {
    return 'Saved on $date';
  }

  @override
  String recipeGeneratorFailed(Object error) {
    return 'Generation failed: $error';
  }

  @override
  String get recipeGeneratorReviewSelectionTitle => 'Review your selection';

  @override
  String get recipeGeneratorReviewSelectionDesc =>
      'Choose ingredients and preferences before generating recipes.';

  @override
  String get recipeGeneratorNoItemsTitle => 'No ingredients selected';

  @override
  String get recipeGeneratorNoItemsDesc =>
      'Select at least one ingredient to continue.';

  @override
  String get recipeGeneratorExtrasTitle => 'Extras & Prompts';

  @override
  String recipeGeneratorCookingFor(Object count) {
    return 'Cooking for $count';
  }

  @override
  String get recipeGeneratorStudentModeOn => 'Student mode ON';

  @override
  String recipeGeneratorNote(Object note) {
    return 'Note: $note';
  }

  @override
  String get recipeGeneratorStartTitle => 'Generate recipes';

  @override
  String get recipeGeneratorStartSubtitle =>
      'We will suggest options based on your ingredients.';

  @override
  String get recipeGeneratorNoRecipes => 'No recipes generated yet.';

  @override
  String get recipeGeneratorSuggestionsTitle => 'Suggestions';

  @override
  String get recipeDetailRemovedFromArchive => 'Removed from archive';

  @override
  String get recipeDetailSavedToArchive => 'Saved to archive';

  @override
  String recipeDetailOperationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get recipeDetailNoOvenTemp =>
      'No oven temperature found in this recipe.';

  @override
  String get recipeDetailOvenBusy => 'Oven is busy. Stop it before preheating.';

  @override
  String recipeDetailOvenPreheating(Object temp) {
    return 'Oven preheating to ${temp}C';
  }

  @override
  String recipeDetailPreheatFailed(Object error) {
    return 'Preheat failed: $error';
  }

  @override
  String get recipeDetailOvenAlreadyIdle => 'Oven is already idle.';

  @override
  String get recipeDetailOvenStopped => 'Oven stopped.';

  @override
  String recipeDetailStopFailed(Object error) {
    return 'Stop failed: $error';
  }

  @override
  String get recipeDetailSavedLeftoversToInventory =>
      'Saved leftovers to inventory.';

  @override
  String get recipeDetailInventoryUpdated => 'Inventory updated.';

  @override
  String get recipeDetailTitle => 'Recipe Details';

  @override
  String recipeDetailYields(Object servings) {
    return 'Yields: $servings';
  }

  @override
  String get recipeDetailSmartKitchen => 'Smart Kitchen';

  @override
  String get recipeDetailOvenReady => 'Oven is Ready';

  @override
  String get recipeDetailPreheatOven => 'Preheat Oven';

  @override
  String recipeDetailPreheatTo(Object temp) {
    return 'Preheat to $temp';
  }

  @override
  String recipeDetailTemp(Object temp) {
    return '${temp}C';
  }

  @override
  String get recipeDetailTapToStop => 'Tap to stop';

  @override
  String get recipeDetailTapToStart => 'Tap to start';

  @override
  String get recipeDetailIngredientsTitle => 'Ingredients';

  @override
  String get recipeDetailInstructionsTitle => 'Instructions';

  @override
  String recipeDetailStep(Object number) {
    return 'Step $number';
  }

  @override
  String get recipeDetailCookedThis => 'I Cooked This';

  @override
  String get recipeDetailReviewUsageTitle => 'Review Ingredients Usage';

  @override
  String get recipeDetailUsageNone => 'None';

  @override
  String get recipeDetailUsageAll => 'All';

  @override
  String get recipeDetailConfirmUsage => 'Confirm Usage';

  @override
  String get recipeDetailMealPrepTitle => 'Did you finish it all?';

  @override
  String get recipeDetailMealPrepDesc => 'Or did you meal prep for later?';

  @override
  String get recipeDetailLeftoversToSave => 'Leftovers to save:';

  @override
  String get recipeDetailWhereStoreLeftovers => 'Where will you store it?';

  @override
  String get recipeDetailSaveLeftovers => 'Save Leftovers';

  @override
  String get recipeDetailAteEverything => 'Ate Everything!';

  @override
  String get guestListAddYourNameTitle => 'Add your name';

  @override
  String get guestListEnterDisplayNameHint => 'Enter a display name';

  @override
  String get guestListAddNoteTitle => 'Add note';

  @override
  String get guestListAddNoteHint => 'e.g. low fat, brand, size';

  @override
  String get guestListShareLinkCopied => 'Share link copied.';

  @override
  String get guestListExpiredEditingDisabled =>
      'This list has expired. Editing is disabled.';

  @override
  String get guestListTitle => 'Guest Shopping List';

  @override
  String get guestListCopyShareLinkTooltip => 'Copy share link';

  @override
  String get guestListMineLabel => 'Mine';

  @override
  String get guestListJoining => 'Joining list...';

  @override
  String get guestListAddNameToEdit => 'Add your name to edit items.';

  @override
  String get guestListAddNameAction => 'Add Name';

  @override
  String get shoppingAddItemHint => 'Add item...';

  @override
  String get guestListNoItemsYet => 'No items yet';

  @override
  String get guestListLookingForList => 'Looking for shared list...';

  @override
  String get guestListFailedLoad => 'Failed to load list.';

  @override
  String get guestListRefreshPage => 'Refresh Page';

  @override
  String get guestListGuestFallback => 'Guest';

  @override
  String get guestArchiveEmpty => 'No guest lists yet';

  @override
  String guestArchiveExpires(Object label) {
    return 'Expires $label';
  }

  @override
  String get guestArchiveExpired => 'Expired';

  @override
  String get guestArchiveActive => 'Active';

  @override
  String get authUnexpectedError => 'Unexpected error, please try again.';

  @override
  String get authEnterEmailFirst => 'Please enter your email first.';

  @override
  String get authResetEmailSent => 'Password reset email sent.';

  @override
  String get authResetEmailFailed => 'Failed to send reset email.';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginWelcomeSubtitle => 'Sign in to continue';

  @override
  String get authPleaseEnterEmail => 'Please enter email.';

  @override
  String get authEmailInvalid => 'Please enter a valid email.';

  @override
  String get authPleaseEnterPassword => 'Please enter password.';

  @override
  String get authAtLeast6Chars => 'At least 6 characters.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLogIn => 'Log In';

  @override
  String get authOr => 'or';

  @override
  String get authNoAccount => 'No account?';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authSkipForNow => 'Skip for now';

  @override
  String get authBack => 'Back';

  @override
  String get registerPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get registerSuccessCheckEmail =>
      'Sign-up successful! Please check your email to confirm.';

  @override
  String get registerBackToLogin => 'Back to login';

  @override
  String get registerCreateAccountTitle => 'Create Account';

  @override
  String get registerCreateAccountSubtitle =>
      'Start your smart kitchen journey.';

  @override
  String get registerNameLabel => 'Name';

  @override
  String get registerNameHint => 'Your display name';

  @override
  String get registerEnterName => 'Please enter your name.';

  @override
  String get registerNameTooShort => 'Name is too short.';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerPasswordHint => 'At least 6 characters';

  @override
  String get registerRepeatPasswordLabel => 'Repeat password';

  @override
  String get registerRepeatPasswordHint => 'Type password again';

  @override
  String get registerPasswordsDoNotMatchInline => 'Passwords do not match';

  @override
  String get registerProfileDetailsTitle => 'Profile details';

  @override
  String get registerGenderLabel => 'Gender';

  @override
  String get registerAgeGroupLabel => 'Age group';

  @override
  String get registerRequired => 'Required';

  @override
  String get registerCountryLabel => 'Country';

  @override
  String get registerCountryHint => 'e.g. Germany';

  @override
  String get registerPleaseEnterCountry => 'Please enter your country.';

  @override
  String get fridgeCameraSignInToConnect =>
      'Please sign in to connect fridge cameras.';

  @override
  String get fridgeCameraNotConnected => 'Home Connect is not connected.';

  @override
  String fridgeCameraLoadFailed(Object error) {
    return 'Failed to load fridge images: $error';
  }

  @override
  String get fridgeCameraTitle => 'Fridge Camera';

  @override
  String get fridgeCameraRefreshTooltip => 'Refresh';

  @override
  String get fridgeCameraNoDevices => 'No connected fridges found.';

  @override
  String get fridgeCameraNoImages => 'No images available yet.';

  @override
  String fridgeCameraImageCount(Object count) {
    return '$count image(s)';
  }

  @override
  String get fridgeCameraImageLoadFailed => 'Failed to load image';

  @override
  String get shoppingArchiveTitle => 'Purchase History';

  @override
  String get shoppingArchiveClearTooltip => 'Clear History';

  @override
  String get shoppingArchiveClearTitle => 'Clear History?';

  @override
  String get shoppingArchiveClearDesc =>
      'This will remove all archived shopping items.';

  @override
  String get shoppingArchiveClearAction => 'Clear';

  @override
  String get shoppingArchiveAddBackTooltip => 'Add back to shopping list';

  @override
  String shoppingArchiveAddedBack(Object name) {
    return 'Added back: $name';
  }

  @override
  String get shoppingArchiveToday => 'Today';

  @override
  String get shoppingArchiveYesterday => 'Yesterday';

  @override
  String get shoppingArchiveEmptyTitle => 'No history yet';

  @override
  String get shoppingArchiveEmptyDesc =>
      'Completed shopping items will appear here.';

  @override
  String get recipeDetailAllLabel => 'All';
}
