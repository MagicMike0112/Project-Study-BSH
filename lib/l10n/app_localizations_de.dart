// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BSH Smart Food Buddy';

  @override
  String get navToday => 'Heute';

  @override
  String get todayGreetingMorning => 'Guten Morgen';

  @override
  String get todayGreetingNoon => 'Guten Tag';

  @override
  String get todayGreetingEvening => 'Guten Abend';

  @override
  String get navInventory => 'Vorrat';

  @override
  String get navShopping => 'Einkauf';

  @override
  String get navImpact => 'Wirkung';

  @override
  String get undo => 'Hoppla, rueckgaengig';

  @override
  String get prefLanguageTitle => 'Sprache';

  @override
  String get prefLanguageSubtitle => 'App-Sprache wechseln';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageChinese => 'Chinesisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get themeTitle => 'Design';

  @override
  String get themeFollowSystem => 'System folgen';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSectionHousehold => 'Haushalt';

  @override
  String get accountSectionMyHome => 'Mein Zuhause';

  @override
  String get accountSectionIntegrations => 'Integrationen';

  @override
  String get accountSectionPreferences => 'Einstellungen';

  @override
  String get accountSectionAbout => 'Info';

  @override
  String get accountNotificationsTitle => 'Benachrichtigungen';

  @override
  String get accountNotificationsSubtitle =>
      'Ablauf- und Mahlzeit-Erinnerungen';

  @override
  String get notificationPermissionBlocked =>
      'Die Benachrichtigungsberechtigung ist in den Systemeinstellungen blockiert.';

  @override
  String get notificationMealReminderMessage =>
      'Einige deiner Zutaten laufen bald ab. Schau in Smart Food Home vorbei.';

  @override
  String get notificationSavedFutureApply =>
      'Gespeichert. Die neue Erinnerungszeit gilt fuer kommende Benachrichtigungen.';

  @override
  String get notificationEnablePermissionFirst =>
      'Bitte aktiviere zuerst die Benachrichtigungsberechtigung.';

  @override
  String get notificationTestMessage =>
      'Dies ist eine Test-Ablauferinnerung von Smart Food Home.';

  @override
  String get notificationTestSent => 'Testbenachrichtigung gesendet.';

  @override
  String get notificationThreeDayExpiryTitle => '3-Tage-Ablaufwarnung';

  @override
  String get notificationThreeDayExpiryDesc =>
      'Einmalige Erinnerung, wenn ein Artikel in 3 Tagen ablaeuft.';

  @override
  String get notificationMealTimeTitle => 'Mahlzeit-Erinnerungen';

  @override
  String get notificationMealTimeDesc =>
      'Zwei taegliche Erinnerungen zu deiner Mittags- und Abendzeit.';

  @override
  String get notificationPermissionAllowed =>
      'System-Benachrichtigung: erlaubt';

  @override
  String get notificationPermissionBlockedStatus =>
      'System-Benachrichtigung: blockiert';

  @override
  String notificationStatusCombined(Object mealStatus, Object threeDayStatus) {
    return 'Mahlzeit-Erinnerungen: $mealStatus | 3-Tage-Warnungen: $threeDayStatus';
  }

  @override
  String get notificationStatusScheduled => 'aktiv';

  @override
  String get notificationStatusOff => 'aus';

  @override
  String get notificationMealTimesTitle => 'Mahlzeitenzeiten';

  @override
  String get notificationMealTimesHint =>
      'Zu diesen Zeiten erinnern wir dich an bald ablaufende Zutaten.';

  @override
  String get notificationLunchLabel => 'Uebliche Mittagszeit';

  @override
  String get notificationDefaultLunchTime => '11:30 (Standard)';

  @override
  String get notificationDinnerLabel => 'Uebliche Abendzeit';

  @override
  String get notificationDefaultDinnerTime => '17:30 (Standard)';

  @override
  String get notificationResetDefaults => 'Auf Standard zuruecksetzen';

  @override
  String get notificationSendTestNow => 'Test jetzt senden';

  @override
  String familyLoadMembersFailed(Object error) {
    return 'Mitglieder konnten nicht geladen werden: $error';
  }

  @override
  String get familyErrorTitle => 'Fehler';

  @override
  String familyGenerateCodeFailed(Object error) {
    return 'Code konnte nicht erzeugt werden:\n\n$error';
  }

  @override
  String get familyOk => 'OK';

  @override
  String get familyJoinTitle => 'Familie beitreten';

  @override
  String get familyJoinDesc =>
      'Gib den 6-stelligen Einladungscode eines Familienmitglieds ein.';

  @override
  String get familyInviteCodeLabel => 'Einladungscode';

  @override
  String get familyJoinAction => 'Beitreten';

  @override
  String get familyJoinedSuccess => 'Familie erfolgreich beigetreten!';

  @override
  String get familyInvalidOrExpiredCode =>
      'Ungueltiger oder abgelaufener Code.';

  @override
  String familyErrorMessage(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get familyLeaveTitle => 'Familie verlassen?';

  @override
  String get familyLeaveDesc =>
      'Du siehst dann keine geteilten Vorrats- und Einkaufslisten mehr und wechselst in dein privates Zuhause.';

  @override
  String get familyLeaveAction => 'Verlassen';

  @override
  String get familyLeftSuccess =>
      'Familie verlassen. In den privaten Modus gewechselt.';

  @override
  String get familyLeaveFailed => 'Familie konnte nicht verlassen werden.';

  @override
  String get familyInviteMemberTitle => 'Mitglied einladen';

  @override
  String get familyInviteMemberDesc =>
      'Teile diesen Code mit deinem Familienmitglied.\nDamit kann es deinem Zuhause beitreten.';

  @override
  String get familyInviteExpiresIn2Days => 'Laeuft in 2 Tagen ab';

  @override
  String get familyDone => 'Fertig';

  @override
  String get familyUpdateNameTitle => 'Deinen Namen aktualisieren';

  @override
  String get familyDisplayNameHint => 'Deinen Anzeigenamen eingeben';

  @override
  String get familyNameUpdated => 'Name aktualisiert.';

  @override
  String get familyNameUpdateFailed => 'Name konnte nicht aktualisiert werden.';

  @override
  String get familyMyFamilyTitle => 'Meine Familie';

  @override
  String get familyMembersTitle => 'Mitglieder';

  @override
  String get familyNoMembersFound => 'Keine Mitglieder gefunden.';

  @override
  String get familyInviteNewMember => 'Neues Mitglied einladen';

  @override
  String get familyJoinAnotherFamily => 'Anderer Familie beitreten';

  @override
  String get familyLeaveThisFamily => 'Diese Familie verlassen';

  @override
  String get familyInventoryShoppingSynced =>
      'Vorrat und Einkaufsliste synchronisiert';

  @override
  String get familyYourDisplayName => 'Dein Anzeigename';

  @override
  String get familyEdit => 'Bearbeiten';

  @override
  String get familyMigrationFailed => 'Migration fehlgeschlagen';

  @override
  String get familyMigratingData => 'Deine Daten werden migriert';

  @override
  String get familyKeepAppOpen => 'Bitte halte die App geoeffnet.';

  @override
  String familyMigrationAttempt(Object attempt, Object total) {
    return 'Versuch $attempt / $total';
  }

  @override
  String get familyInventoryMode => 'Vorratsmodus';

  @override
  String get familySharedFridgeTitle => 'Geteilter Kuehlschrank';

  @override
  String get familySharedFridgeDesc =>
      'Alle Mitglieder verwalten den Vorrat gemeinsam.';

  @override
  String get familySeparateFridgesTitle => 'Getrennte Kuehlschraenke';

  @override
  String get familySeparateFridgesDesc =>
      'Artikel sind strikt Eigentuemern zugeordnet.';

  @override
  String get familyUnknownMember => 'Unbekannt';

  @override
  String get familyUnknownInitial => 'U';

  @override
  String get accountNightModeTitle => 'Nachtmodus';

  @override
  String get accountStudentModeTitle => 'Studentenmodus';

  @override
  String get accountStudentModeSubtitle => 'Budgetfreundliche Rezepte & Tipps';

  @override
  String get accountLoyaltyCardsTitle => 'Treuekarten';

  @override
  String get accountLoyaltyCardsSubtitle =>
      'PAYBACK verbinden (bald verfuegbar)';

  @override
  String get accountPrivacyPolicyTitle => 'Datenschutz';

  @override
  String get accountVersionTitle => 'Version';

  @override
  String get accountSignOut => 'Abmelden';

  @override
  String accountHelloUser(Object name) {
    return 'Hallo, $name';
  }

  @override
  String get accountGuestTitle => 'Gastkonto';

  @override
  String get accountSignInHint => 'Zum Synchronisieren bitte anmelden';

  @override
  String get accountLogIn => 'Anmelden';

  @override
  String get accountHomeConnectLinked => 'Home Connect verbunden!';

  @override
  String get accountConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get accountDisconnected => 'Getrennt';

  @override
  String get accountSimulatorAppliances => 'Simulator-Geraete';

  @override
  String get accountNoAppliancesFound => 'Keine Geraete gefunden';

  @override
  String get accountUnknown => 'Unbekannt';

  @override
  String get accountIdCopied => 'ID kopiert';

  @override
  String accountApplianceId(Object id) {
    return 'ID: $id';
  }

  @override
  String get accountHomeConnectTitle => 'Home Connect';

  @override
  String get accountRefreshStatus => 'Status aktualisieren';

  @override
  String get accountViewAppliances => 'Geraete anzeigen';

  @override
  String get accountDisconnect => 'Trennen';

  @override
  String get accountConnecting => 'Verbinden...';

  @override
  String get accountActiveSynced => 'Aktiv & synchronisiert';

  @override
  String get accountTapToConnect => 'Tippen zum Verbinden';

  @override
  String get leaderboardTitle => 'Rangliste';

  @override
  String get leaderboardScopeWorld => 'Welt';

  @override
  String get leaderboardGlobalTitle => 'Global';

  @override
  String get leaderboardGlobalSubtitle => 'Top-Leistungen weltweit';

  @override
  String get leaderboardYourRank => 'Dein Rang';

  @override
  String get leaderboardNoDataYet => 'Noch keine Daten';

  @override
  String leaderboardRankInScope(Object rank, Object scope) {
    return '#$rank in $scope';
  }

  @override
  String get leaderboardLoadFailedTitle =>
      'Rangliste konnte nicht geladen werden';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String leaderboardPointsKgCo2(Object value) {
    return '$value kg CO2';
  }

  @override
  String get leaderboardAddFriendTitle => 'Freund hinzufuegen';

  @override
  String get leaderboardFriendEmailLabel => 'E-Mail des Freundes';

  @override
  String get leaderboardFriendEmailHint => 'name@email.com';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get add => 'Hinzufuegen';

  @override
  String get leaderboardNoUserForEmail =>
      'Kein Nutzer mit dieser E-Mail gefunden.';

  @override
  String get leaderboardInvalidUserId =>
      'Ungueltige Nutzer-ID fuer diese E-Mail.';

  @override
  String get leaderboardCannotAddYourself =>
      'Du kannst dich nicht selbst hinzufuegen.';

  @override
  String get leaderboardFriendAdded => 'Freund hinzugefuegt.';

  @override
  String leaderboardAddFriendFailed(Object error) {
    return 'Freund hinzufuegen fehlgeschlagen: $error';
  }

  @override
  String get pullToRefreshHint => 'Zum Aktualisieren ziehen';

  @override
  String get pullToRefreshRelease => 'Loslassen zum Aktualisieren';

  @override
  String get foodLocationFridge => 'Kuehlschrank';

  @override
  String get foodLocationFreezer => 'Gefrierschrank';

  @override
  String get foodLocationPantry => 'Vorratsschrank';

  @override
  String foodExpiredDaysAgo(Object days) {
    return 'Seit $days T. abgelaufen';
  }

  @override
  String foodDaysLeft(Object days) {
    return '$days Tage uebrig';
  }

  @override
  String get foodActionCookEat => 'Kochen / Essen';

  @override
  String get foodActionFeedPets => 'Haustiere fuettern';

  @override
  String get foodActionDiscard => 'Wegwerfen';

  @override
  String get foodPetsHappy => 'Little Shi & Little Yuan sind happy!';

  @override
  String get todayRecipeArchiveTooltip => 'Rezept-Archiv';

  @override
  String get todayAiChefTitle => 'KI-Koch';

  @override
  String get todayAiChefDescription =>
      'Nutze aktuelle Zutaten, um Rezepte zu erstellen.';

  @override
  String get todayExpiringSoonTitle => 'Bald ablaufend';

  @override
  String get todayExpiringSoonDescription =>
      'Schnell kochen, Haustiere fuettern oder entsorgen.';

  @override
  String get todayPetSafetyWarning =>
      'Bitte stelle sicher, dass das Futter fuer dein Haustier sicher ist!';

  @override
  String get todayWhatCanICook => 'Was kann ich kochen?';

  @override
  String todayBasedOnItems(int count) {
    return 'Basierend auf $count Zutaten in deinem Kuehlschrank.';
  }

  @override
  String get todayGenerate => 'Erstellen';

  @override
  String get todayPlanWeekTitle => 'Plane deine Woche!';

  @override
  String get todayPlanWeekSubtitle => 'Tippe, um Mahlzeiten zu planen.';

  @override
  String get todayViewAll => 'Alle anzeigen';

  @override
  String get todayExpired => 'Abgelaufen';

  @override
  String get todayExpiryToday => 'Heute';

  @override
  String get todayOneDayLeft => '1 Tag uebrig';

  @override
  String get todayAllClearTitle => 'Alles in Ordnung!';

  @override
  String get todayAllClearSubtitle =>
      'Dein Kuehlschrank ist frisch und gut organisiert.';

  @override
  String todayUndoCooked(Object name) {
    return '\"$name\" gekocht';
  }

  @override
  String todayUndoFedPet(Object name) {
    return '\"$name\" an Haustier verfuettert';
  }

  @override
  String todayUndoDiscarded(Object name) {
    return '\"$name\" entsorgt';
  }

  @override
  String todayUndoUpdated(Object name) {
    return '\"$name\" aktualisiert';
  }

  @override
  String get commonSave => 'Speichern';

  @override
  String get inventorySyncChangesLabel =>
      'Aenderungen in die Cloud synchronisieren';

  @override
  String get inventoryCloudSyncStatusLabel => 'Cloud-Sync-Status';

  @override
  String get inventorySyncRetryHint =>
      'Tippen, um ausstehende Synchronisierung zu wiederholen';

  @override
  String get inventorySyncAllSavedHint =>
      'Tippen, um zu bestaetigen, dass alles gespeichert ist';

  @override
  String get inventorySyncingChanges => 'Synchronisierung laeuft...';

  @override
  String get inventoryAllChangesSaved => 'Alle Aenderungen gespeichert';

  @override
  String get inventorySyncingChangesToCloud =>
      'Synchronisiere Aenderungen in die Cloud...';

  @override
  String get inventoryAllSavedToCloud =>
      'Alle Aenderungen in der Cloud gespeichert.';

  @override
  String get inventoryQuickSearchTitle => 'Schnellsuche';

  @override
  String get inventoryQuickSearchDescription =>
      'Finde Artikel in Sekunden nach Name.';

  @override
  String get inventorySearchHint => 'Artikel suchen...';

  @override
  String get inventoryNoItemsFound => 'Keine Artikel gefunden';

  @override
  String get inventoryEmptyTitle => 'Dein Vorrat ist leer';

  @override
  String get inventoryEmptySubtitle => 'Tippe auf +, um Artikel hinzuzufuegen.';

  @override
  String get inventoryLongPressTitle => 'Langdruck-Menue';

  @override
  String get inventoryLongPressDescription =>
      'Gedrueckt halten zum Bearbeiten, Verbrauch, Verschieben oder Loeschen.';

  @override
  String get inventorySwipeDeleteTitle => 'Nach links wischen zum Loeschen';

  @override
  String get inventorySwipeDeleteDescription =>
      'Wische einen Artikel nach links, um ihn zu loeschen. Direkt danach kannst du rueckgaengig machen.';

  @override
  String get inventoryItemNoteTitle => 'Artikelnotiz';

  @override
  String get inventoryItemNoteHint => 'Kurze Notiz hinzufuegen...';

  @override
  String get inventoryEditNote => 'Notiz bearbeiten';

  @override
  String get inventoryAddNote => 'Notiz hinzufuegen';

  @override
  String get inventorySharedLabel => 'Geteilt';

  @override
  String get inventoryNoteReminderSubtitle => 'Kurze Erinnerung hinterlassen';

  @override
  String get inventoryChangeCategory => 'Kategorie aendern';

  @override
  String get inventoryRecordUsageUpdateQty =>
      'Verbrauch erfassen und Menge aktualisieren';

  @override
  String get inventoryGreatForLeftovers => 'Ideal fuer Reste';

  @override
  String get inventoryTrackWasteImproveHabits =>
      'Verschwendung erfassen und Gewohnheiten verbessern';

  @override
  String inventoryCookedToast(Object qty, Object name) {
    return '$qty von $name gekocht';
  }

  @override
  String inventoryFedToPetToast(Object name) {
    return '$name an Haustier verfuettert';
  }

  @override
  String inventoryRecordedWasteToast(Object name) {
    return 'Verschwendung erfasst: $name';
  }

  @override
  String inventoryDeletedToast(Object name) {
    return '\"$name\" geloescht';
  }

  @override
  String get inventoryCookWithThis => 'Damit kochen';

  @override
  String get inventoryFeedToPet => 'An Haustier verfuettern';

  @override
  String get inventoryWastedThrownAway => 'Verschwendet / Weggeworfen';

  @override
  String get inventoryEditDetails => 'Details bearbeiten';

  @override
  String get inventoryDeleteItem => 'Artikel loeschen';

  @override
  String get inventoryDeleteItemQuestion => 'Diesen Artikel loeschen?';

  @override
  String inventoryDeletePermanentQuestion(Object name) {
    return '\"$name\" dauerhaft aus dem Vorrat entfernen?';
  }

  @override
  String get inventoryDeleteAction => 'Loeschen';

  @override
  String get inventoryDetailQuantity => 'Menge';

  @override
  String get inventoryDetailAdded => 'Hinzugefuegt';

  @override
  String get inventoryDetailStorageLocation => 'Aufbewahrungsort';

  @override
  String get inventoryDetailNotes => 'Notizen';

  @override
  String get inventoryDetailStatusExpired => 'Abgelaufen';

  @override
  String get inventoryDetailStatusExpiresToday => 'Laeuft heute ab';

  @override
  String get inventoryDetailStatusExpiring => 'Laeuft bald ab';

  @override
  String get inventoryDetailStatusFresh => 'Frisch';

  @override
  String get inventoryDetailAddedToday => 'Heute hinzugefuegt';

  @override
  String get inventoryDetailAddedOneDayAgo => 'Vor 1 Tag hinzugefuegt';

  @override
  String inventoryDetailAddedDaysAgo(Object days) {
    return 'Vor $days Tagen hinzugefuegt';
  }

  @override
  String get inventoryDetailDaysLeftLabel => 'TAGE\nUEBRIG';

  @override
  String get inventoryDetailEditDetailsSubtitle =>
      'Artikeldetails und Ablaufdatum aktualisieren';

  @override
  String inventorySheetUpdating(Object name) {
    return 'Aktualisieren: $name';
  }

  @override
  String get inventoryActionType => 'Aktionstyp';

  @override
  String get inventoryActionCooked => 'Gekocht';

  @override
  String get inventoryActionPetFeed => 'Haustierfutter';

  @override
  String get inventoryActionWaste => 'Verschwendung';

  @override
  String get inventoryQuickAssign => 'Schnell zuweisen';

  @override
  String get inventoryEditFamily => 'Familie bearbeiten';

  @override
  String get inventoryYouLabel => 'Du';

  @override
  String get inventoryConfirmUpdate => 'Aktualisierung bestaetigen';

  @override
  String get inventoryQuantityUsed => 'Verbrauchte Menge';

  @override
  String inventoryRemainingQty(Object value, Object unit) {
    return 'Uebrig: $value$unit';
  }

  @override
  String get inventorySemanticsQuantityUsed => 'Verbrauchte Menge';

  @override
  String get inventorySemanticsUsageHint =>
      'Nach links oder rechts ziehen, um den Verbrauch anzupassen';

  @override
  String get inventorySemanticsAdjustUsedAmount => 'Verbrauchte Menge anpassen';

  @override
  String get shoppingTemporaryListTooltip => 'Temporäre Liste';

  @override
  String get shoppingFridgeCameraTitle => 'Kuehlschrankkamera';

  @override
  String get shoppingFridgeCameraDescription =>
      'Scanne deinen Kuehlschrank fuer schnellere Planung.';

  @override
  String get shoppingPurchaseHistoryTitle => 'Kaufverlauf';

  @override
  String get shoppingPurchaseHistoryDescription =>
      'Gekaufte Artikel ansehen und wieder hinzufuegen.';

  @override
  String get shoppingCompletedLabel => 'ERLEDIGT';

  @override
  String get shoppingAiSmartAddTitle => 'KI Smart Add';

  @override
  String get shoppingAiSmartAddDescription =>
      'Zutaten aus einem Rezept hinzufuegen.';

  @override
  String get shoppingAiSmartAddHint => 'Zutaten aus Rezepttext importieren';

  @override
  String get shoppingQuickAddTitle => 'Schnell hinzufuegen';

  @override
  String get shoppingQuickAddDescription => 'Sofort einen Artikel hinzufuegen.';

  @override
  String get shoppingQuickAddSemanticsLabel =>
      'Schnell einen Artikel hinzufuegen';

  @override
  String get shoppingInputHint => 'Artikel hier hinzufuegen';

  @override
  String get shoppingRecipeImportTitle => 'Rezeptimport';

  @override
  String get shoppingRecipeSignInRequiredAction =>
      'Bitte melde dich an, um den KI-Rezeptscan zu nutzen.';

  @override
  String get shoppingRecipeSignInAction => 'ANMELDEN';

  @override
  String get shoppingRecipeProvideInput =>
      'Bitte gib einen Rezeptnamen, Text oder ein Bild an.';

  @override
  String shoppingRecipeAnalysisFailed(Object error) {
    return 'Analyse fehlgeschlagen: $error';
  }

  @override
  String shoppingRecipeAddedItems(Object count) {
    return '$count Artikel zur Einkaufsliste hinzugefuegt';
  }

  @override
  String get shoppingRecipeInputHint =>
      'Gericht eingeben oder Rezept einfuegen...';

  @override
  String get shoppingRecipeIngredientsSection => 'Zutaten';

  @override
  String get shoppingRecipeSeasoningsSection => 'Gewuerze';

  @override
  String get shoppingRecipeCamera => 'Kamera';

  @override
  String get shoppingRecipeAlbum => 'Album';

  @override
  String get shoppingRecipeAnalyzing => 'Analysiere...';

  @override
  String get shoppingRecipeGetListButton => 'Einkaufsliste erstellen';

  @override
  String get shoppingRecipeAiThinking => 'KI denkt nach...';

  @override
  String get shoppingRecipeResultsPlaceholder =>
      'Deine Ergebnisse erscheinen hier';

  @override
  String shoppingRecipeInStockReason(Object reason) {
    return 'Auf Lager: $reason';
  }

  @override
  String shoppingRecipeCategoryLabel(Object category) {
    return 'Kategorie: $category';
  }

  @override
  String shoppingRecipeAddSelectedToList(Object count) {
    return '$count Artikel zur Liste hinzufuegen';
  }

  @override
  String get shoppingRecipeSignInRequiredTitle => 'Anmeldung erforderlich';

  @override
  String get shoppingRecipeSignInRequiredSubtitle =>
      'Bitte melde dich an, um mit deinem Vorrat zu synchronisieren und die KI-Rezeptanalyse zu nutzen.';

  @override
  String get shoppingRecipeSignInNow => 'Jetzt anmelden';

  @override
  String get shoppingEmptyTitle => 'Deine Liste ist leer';

  @override
  String get shoppingEmptySubtitle =>
      'Fuege Artikel manuell hinzu oder importiere ein Rezept.';

  @override
  String shoppingDeletedToast(Object name) {
    return '\"$name\" geloescht';
  }

  @override
  String get shoppingUndoAction => 'Rueckgaengig';

  @override
  String get impactTitle => 'Dein Impact';

  @override
  String get impactTimeRangeTitle => 'Zeitraum';

  @override
  String get impactTimeRangeDescription =>
      'Zwischen Woche, Monat und Jahr wechseln.';

  @override
  String get impactSummaryTitle => 'Impact Uebersicht';

  @override
  String get impactSummaryDescription =>
      'Hier siehst du gespartes Geld und gerettete Lebensmittel.';

  @override
  String impactKgAvoided(Object value) {
    return '${value}kg vermieden';
  }

  @override
  String get impactLevelTitle => 'Level';

  @override
  String get impactStreakTitle => 'Serie';

  @override
  String get impactDaysActive => 'Aktive Tage';

  @override
  String get impactActiveBadge => 'Aktiv';

  @override
  String get impactWeeklyReportTitle => 'Wochenbericht';

  @override
  String get impactWeeklyReportDescription =>
      'Oeffne deine KI-Wochenzusammenfassung mit Insights.';

  @override
  String get impactWeeklyReviewSubtitle =>
      'Sieh dir deinen Fortschritt der letzten Woche an';

  @override
  String get weeklyAddedToShoppingList => 'Zur Einkaufsliste hinzugefuegt.';

  @override
  String get weeklyHeiExplainedTitle => 'HEI-2015 erklaert';

  @override
  String get weeklyHeiExplainedIntro =>
      'Der Healthy Eating Index (HEI-2015) ist ein 0-100-Wert, der misst, wie gut eine Ernaehrung zu den Dietary Guidelines for Americans passt.';

  @override
  String get weeklyHeiHowComputeTitle => 'So berechnen wir ihn';

  @override
  String get weeklyHeiHowComputeBody =>
      'Wir schaetzen die HEI-Komponenten mit USDA FoodData Central Naehrwerten und deinen erfassten Lebensmitteln. Enthalten sind:';

  @override
  String get weeklyHeiComponentsList =>
      '- Obst (gesamt und ganz)\n- Gemuese (gesamt und gruenes Gemuese/Bohnen)\n- Vollkorn\n- Milchprodukte\n- Gesamtprotein sowie Meeresfruechte-/Pflanzenprotein\n- Fettsaeure-Verhaeltnis\n- Moderation: raffiniertes Getreide, Natrium, zugesetzter Zucker, gesaettigte Fette';

  @override
  String get weeklyHeiMorePoints =>
      'Mehr Punkte bedeuten bessere Balance. Wo sinnvoll normalisieren wir pro 1.000 kcal und nutzen die HEI-2015 Bewertungsstandards.';

  @override
  String get weeklyGotIt => 'Verstanden';

  @override
  String get weeklyHeiLabelExcellent => 'Ausgezeichnet';

  @override
  String get weeklyHeiLabelGood => 'Gut';

  @override
  String get weeklyHeiLabelFair => 'Okay';

  @override
  String get weeklyHeiLabelNeedsWork => 'Ausbaufähig';

  @override
  String get weeklyMacrosNotEnoughData =>
      'Nicht genug Daten zur Berechnung der Makros.';

  @override
  String get weeklyMacroProtein => 'Protein';

  @override
  String get weeklyMacroCarbs => 'Kohlenhydrate';

  @override
  String get weeklyMacroFat => 'Fett';

  @override
  String weeklyDataSource(Object source) {
    return 'Datenquelle: $source';
  }

  @override
  String get weeklyPrev => 'Zurueck';

  @override
  String get weeklyNext => 'Weiter';

  @override
  String get impactChooseMascot => 'Waehle dein Maskottchen';

  @override
  String get impactMascotNameTitle => 'Maskottchen-Name';

  @override
  String get impactMascotNameHint => 'Gib ihm einen Namen';

  @override
  String get impactMascotCat => 'Katze';

  @override
  String get impactMascotDog => 'Hund';

  @override
  String get impactMascotHamster => 'Hamster';

  @override
  String get impactMascotGuineaPig => 'Meerschweinchen';

  @override
  String impactFedToMascot(Object name) {
    return 'An $name verfuettert';
  }

  @override
  String get impactItemFallback => 'Artikel';

  @override
  String get impactFridgeMasterTitle => 'Kuehlschrank-Profi!';

  @override
  String impactSavedItemsStreak(Object savedCount, Object streak) {
    return '$savedCount Artikel gerettet - $streak Tage Serie';
  }

  @override
  String get impactTotalSavingsLabel => 'GESAMT ERSPART';

  @override
  String get impactNextRankLabel => 'Naechster Rang: Zero-Waste-Held';

  @override
  String impactBasedOnSavedItems(Object count) {
    return 'Basierend auf $count geretteten Artikeln';
  }

  @override
  String impactOnTrackYearly(Object amount) {
    return 'Auf Kurs fuer $amount Ersparnis pro Jahr';
  }

  @override
  String get impactCommunityQuestTitle => 'Community Quest';

  @override
  String get impactNewBadge => 'Neu!';

  @override
  String impactYouSavedCo2ThisWeek(Object value) {
    return 'Du hast diese Woche ${value}kg CO2 eingespart!';
  }

  @override
  String get impactViewLeaderboard => 'Rangliste ansehen';

  @override
  String get impactTopSaversTitle => 'Top-Sparer';

  @override
  String get impactSeeAll => 'Alle ansehen';

  @override
  String get impactMostSavedLabel => 'Meist gespart';

  @override
  String get impactRecentActionsTitle => 'Letzte Aktionen';

  @override
  String get impactFamilyLabel => 'Familie';

  @override
  String get impactActionCooked => 'Gekocht';

  @override
  String get impactActionFedToPet => 'An Haustier verfuettert';

  @override
  String get impactActionWasted => 'Verschwendet';

  @override
  String get impactTapForDietInsights =>
      'Tippe fuer deine Ernaehrungs-Insights';

  @override
  String impactEnjoyedLeftovers(Object weight) {
    return '${weight}kg Reste verwertet';
  }

  @override
  String get impactNoDataTitle => 'Noch keine Daten';

  @override
  String get impactNoDataSubtitle =>
      'Rette Lebensmittel und dein Impact erscheint hier.';

  @override
  String get impactRangeWeek => 'Woche';

  @override
  String get impactRangeMonth => 'Monat';

  @override
  String get impactRangeYear => 'Jahr';

  @override
  String get addFoodVoiceTapToStart => 'Zum Start auf das Mikro tippen';

  @override
  String get addFoodDateNotSet => 'Nicht gesetzt';

  @override
  String get addFoodTextTooShort =>
      'Text ist zu kurz, bitte mehr Details angeben.';

  @override
  String addFoodRecognizedItems(int count) {
    return '$count Eintrag(e) erkannt.';
  }

  @override
  String get addFoodAiParserUnavailable =>
      'KI-Parser nicht verfuegbar, lokaler Parser verwendet.';

  @override
  String get addFoodAiUnexpectedResponse =>
      'Unerwartete KI-Antwort, lokaler Parser verwendet.';

  @override
  String get addFoodFormFilledFromVoice => 'Formular per Sprache ausgefuellt.';

  @override
  String get addFoodAiReturnedEmpty =>
      'KI-Parser lieferte leer, lokaler Parser verwendet.';

  @override
  String get addFoodNetworkParseFailed =>
      'Netzwerk-Parsing fehlgeschlagen, lokaler Parser verwendet.';

  @override
  String addFoodAiParseFailed(Object error) {
    return 'KI-Parsing fehlgeschlagen: $error';
  }

  @override
  String get addFoodEnterNameFirst =>
      'Bitte zuerst den Lebensmittelnamen eingeben';

  @override
  String addFoodExpirySetTo(Object date) {
    return 'Ablaufdatum gesetzt auf $date';
  }

  @override
  String get addFoodMaxFourImages =>
      'Maximal 4 Bilder erlaubt. Die ersten 4 wurden gewaehlt.';

  @override
  String get addFoodNoItemsDetected => 'Keine Artikel in den Bildern erkannt.';

  @override
  String addFoodScanFailed(Object error) {
    return 'Scan fehlgeschlagen: $error';
  }

  @override
  String addFoodVoiceError(Object error) {
    return 'Sprachfehler: $error';
  }

  @override
  String get addFoodSpeechNotAvailable =>
      'Spracherkennung auf diesem Geraet nicht verfuegbar';

  @override
  String get addFoodSpeechNotSupported =>
      'Spracherkennung wird auf diesem Geraet nicht unterstuetzt.';

  @override
  String addFoodSpeechInitFailed(Object code) {
    return 'Sprachinitialisierung fehlgeschlagen: $code';
  }

  @override
  String get addFoodSpeechInitUnable =>
      'Spracherkennung konnte nicht initialisiert werden.';

  @override
  String get addFoodOpeningXiaomiSpeech =>
      'Xiaomi-Spracherkennung wird geoeffnet...';

  @override
  String get addFoodVoiceGotIt =>
      'Verstanden! Auf \"Analysieren & Fuellen\" tippen.';

  @override
  String get addFoodVoiceCanceled =>
      'Spracheingabe abgebrochen. Mikro antippen zum Wiederholen.';

  @override
  String get addFoodMicBlocked =>
      'Mikrofon blockiert. Bitte in den Einstellungen aktivieren.';

  @override
  String get addFoodMicDenied => 'Mikrofonberechtigung verweigert.';

  @override
  String get addFoodListeningNow => 'Ich hoere zu...';

  @override
  String get addFoodAddItemTitle => 'Artikel hinzufuegen';

  @override
  String get addFoodEditItemTitle => 'Artikel bearbeiten';

  @override
  String get addFoodHelpButton => 'Hilfe';

  @override
  String get addFoodTabManual => 'Manuell';

  @override
  String get addFoodTabScan => 'Scan';

  @override
  String get addFoodTabVoice => 'Sprache';

  @override
  String get addFoodBasicInfoTitle => 'Basisdaten';

  @override
  String get addFoodNameLabel => 'Name';

  @override
  String get addFoodRequired => 'Pflichtfeld';

  @override
  String get addFoodQuantityLabel => 'Menge';

  @override
  String get addFoodUnitLabel => 'Einheit';

  @override
  String get addFoodMinStockWarningLabel => 'Mindestbestand-Warnung (optional)';

  @override
  String get addFoodMinStockHint => 'z. B. 2 (Warnung bei Unterschreitung)';

  @override
  String get addFoodMinStockHelper => 'Leer lassen fuer keine Warnung';

  @override
  String get addFoodStorageLocationTitle => 'Lagerort';

  @override
  String get addFoodCategoriesTitle => 'Kategorien';

  @override
  String get addFoodDatesTitle => 'Daten';

  @override
  String get addFoodPurchaseDate => 'Kaufdatum';

  @override
  String get addFoodOpenDate => 'Oeffnungsdatum';

  @override
  String get addFoodBestBefore => 'Mindestens haltbar bis';

  @override
  String get addFoodSaveToInventory => 'Im Vorrat speichern';

  @override
  String get addFoodScanReceipt => 'Beleg scannen';

  @override
  String get addFoodSnapFridge => 'Kuehlschrank fotografieren';

  @override
  String get addFoodTakePhoto => 'Foto aufnehmen';

  @override
  String get addFoodUseCameraToScan => 'Kamera zum Scannen verwenden';

  @override
  String get addFoodUploadMax4 => 'Hochladen (max. 4)';

  @override
  String get addFoodChooseMultipleFromGallery =>
      'Mehrere aus der Galerie waehlen';

  @override
  String get addFoodAiExtractReceiptItems =>
      'Die KI extrahiert Artikel aus deinem Beleg.';

  @override
  String get addFoodAiIdentifyFridgeItems =>
      'Die KI erkennt Artikel im Kuehlschrank oder Vorrat.';

  @override
  String get addFoodAutoLabel => 'Auto';

  @override
  String get addFoodXiaomiSpeechMode => 'Xiaomi-Sprachmodus';

  @override
  String addFoodEngineReady(Object locale) {
    return 'Engine bereit - $locale';
  }

  @override
  String get addFoodPreparingEngine => 'Sprach-Engine wird vorbereitet...';

  @override
  String get addFoodVoiceTrySaying =>
      'Versuche: \"3 Aepfel, Milch und 1 kg Reis\"';

  @override
  String get addFoodTranscriptHint => 'Transkript erscheint hier...';

  @override
  String get addFoodClear => 'Leeren';

  @override
  String get addFoodAnalyzing => 'Analysiere...';

  @override
  String get addFoodAnalyzeAndFill => 'Analysieren & Fuellen';

  @override
  String get addFoodAiExpiryPrediction => 'KI-Ablaufprognose';

  @override
  String get addFoodAutoMagic => 'Auto-Magie';

  @override
  String get addFoodThinking => 'Denke nach...';

  @override
  String get addFoodPredictedExpiry => 'Prognostiziertes Ablaufdatum';

  @override
  String get addFoodManualDateOverride =>
      'Manuelles Datum ueberschreibt diese Angabe';

  @override
  String get addFoodAutoApplied => 'Automatisch uebernommen';

  @override
  String get addFoodAiSuggestHint =>
      'Die KI schlaegt basierend auf Lebensmitteltyp und Lagerung vor.';

  @override
  String get addFoodErrorPrefix => 'Fehler:';

  @override
  String get addFoodAutoMagicPrediction => 'Auto-Magic-Prognose';

  @override
  String get addFoodScanningReceipts => 'Belege werden gescannt...';

  @override
  String get addFoodProcessing => 'Verarbeitung';

  @override
  String get addFoodItemsTitle => 'Eintraege';

  @override
  String addFoodAddCountItems(int count) {
    return '$count Artikel hinzufuegen';
  }

  @override
  String addFoodAddedItems(int count) {
    return '$count Artikel hinzugefuegt';
  }

  @override
  String get addFoodHelpTitle => 'Hilfe: Artikel hinzufuegen';

  @override
  String get addFoodHelpManualTitle => 'Manuell';

  @override
  String get addFoodHelpManualPoint1 => 'Name, Menge und Lagerort eingeben.';

  @override
  String get addFoodHelpManualPoint2 =>
      'Setze MHD, wenn das Verpackungsdatum bekannt ist.';

  @override
  String get addFoodHelpManualPoint3 => 'Nutze Notizen fuer Groesse/Marke.';

  @override
  String get addFoodHelpScanTitle => 'Scan';

  @override
  String get addFoodHelpScanPoint1 =>
      'Klare Fotos mit guter Beleuchtung verwenden.';

  @override
  String get addFoodHelpScanPoint2 =>
      'Bei Belegen den Text vollstaendig sichtbar halten.';

  @override
  String get addFoodHelpScanPoint3 =>
      'Erkannte Artikel vor dem Speichern pruefen.';

  @override
  String get addFoodHelpVoiceTitle => 'Sprache';

  @override
  String get addFoodHelpVoicePoint1 =>
      'Sage Artikel + Menge + Einheit, z. B. \"Milch zwei Liter\".';

  @override
  String get addFoodHelpVoicePoint2 =>
      'Zwischen mehreren Artikeln kurz pausieren.';

  @override
  String get addFoodHelpVoicePoint3 =>
      'Felder bei Bedarf vor dem Speichern bearbeiten.';

  @override
  String get addFoodHelpTip =>
      'Tipp: Wenn das Ablaufdatum unbekannt ist, nutze die KI-Prognose und passe sie manuell an.';

  @override
  String get selectIngredientsKitchenTitle => 'Deine Kueche';

  @override
  String selectIngredientsSelectedCount(int count) {
    return '$count Zutaten zum Kochen ausgewaehlt';
  }

  @override
  String get selectIngredientsNoItemsSubtitle =>
      'Versuche einen anderen Filter oder fuege neue Artikel hinzu.';

  @override
  String get selectIngredientsExtrasPrompts => 'Extras & Vorgaben';

  @override
  String get selectIngredientsAddExtraHint =>
      'Zusaetzliche Zutaten hinzufuegen...';

  @override
  String get selectIngredientsSpecialRequestHint =>
      'Besondere Vorlieben oder Ernaehrungseinschraenkungen?';

  @override
  String get selectIngredientsPageTitle => 'Zutaten auswaehlen';

  @override
  String get selectIngredientsReset => 'Zuruecksetzen';

  @override
  String get selectIngredientsFilterAll => 'Alle';

  @override
  String get selectIngredientsFilterExpiring => 'Bald ablaufend';

  @override
  String get selectIngredientsFilterVeggie => 'Gemuese';

  @override
  String get selectIngredientsFilterMeat => 'Fleisch';

  @override
  String get selectIngredientsFilterDairy => 'Milchprodukte';

  @override
  String get selectIngredientsExpiringLabel => 'Bald faellig';

  @override
  String get selectIngredientsSoonLabel => 'Bald';

  @override
  String get selectIngredientsFreshLabel => 'Frisch';

  @override
  String selectIngredientsQuantityLeft(Object value, Object unit) {
    return '$value $unit uebrig';
  }

  @override
  String get selectIngredientsPeopleShort => 'Pers.';

  @override
  String cookingPlanSlot(Object slot) {
    return '$slot planen';
  }

  @override
  String get cookingMealNameLabel => 'Mahlzeitenname';

  @override
  String get cookingMealNameHint => 'z. B. Zitronen-Haehnchen-Bowl';

  @override
  String get cookingQuickPickRecipes => 'Schnellauswahl aus Rezepten';

  @override
  String get cookingBrowseAll => 'Alle durchsuchen';

  @override
  String get cookingUseFromInventory => 'Aus dem Vorrat verwenden';

  @override
  String get cookingMissingItemsLabel =>
      'Fehlende Artikel (zur Einkaufsliste hinzufuegen)';

  @override
  String get cookingMissingItemsHint => 'z. B. Knoblauch, Fruehlingszwiebeln';

  @override
  String get cookingSavePlan => 'Plan speichern';

  @override
  String get cookingUntitledMeal => 'Unbenannte Mahlzeit';

  @override
  String cookingAddedItemsToShopping(int count) {
    return '$count Artikel zur Einkaufsliste hinzugefuegt.';
  }

  @override
  String get cookingMealPlannerTitle => 'Mahlzeitenplaner';

  @override
  String get cookingJumpToToday => 'Zu heute springen';

  @override
  String get cookingNoMatches => 'Keine Treffer';

  @override
  String cookingMissingItemsCount(int count) {
    return '$count Artikel fehlen';
  }

  @override
  String get cookingAllItemsInFridge => 'Alle Artikel im Kuehlschrank';

  @override
  String get cookingSlotBreakfast => 'Fruehstueck';

  @override
  String get cookingSlotLunch => 'Mittagessen';

  @override
  String get cookingSlotDinner => 'Abendessen';

  @override
  String get shoppingGuestCreateTempTitle => 'Temporare Liste erstellen';

  @override
  String get shoppingGuestCreateTempSubtitle =>
      'Mit Gaesten teilen, ohne Login.';

  @override
  String get shoppingGuestMyListsTitle => 'Meine Gastlisten';

  @override
  String get shoppingGuestMyListsSubtitle =>
      'Vorhandene temporaere Listen verwalten.';

  @override
  String get shoppingGuestDialogTitle => 'Temporare Liste erstellen';

  @override
  String get shoppingGuestTitleHint => 'z. B. Dinnerparty';

  @override
  String get shoppingGuestExpiresIn => 'Laeuft ab in';

  @override
  String get shoppingGuestExpire24h => '24 Stunden';

  @override
  String get shoppingGuestExpire3d => '3 Tage';

  @override
  String get shoppingGuestExpire7d => '7 Tage';

  @override
  String get shoppingGuestAttachMineTitle => 'Mit meinem Konto verknuepfen';

  @override
  String get shoppingGuestAttachMineSubtitle =>
      'Nur Kontoinhaber koennen Besitzer-Einstellungen aendern.';

  @override
  String get shoppingGuestCreateAction => 'Erstellen';

  @override
  String get shoppingShareLinkTitle => 'Diesen Link teilen';

  @override
  String get shoppingLinkCopied => 'Link kopiert.';

  @override
  String get shoppingCopyLink => 'Link kopieren';

  @override
  String get shoppingOpenList => 'Liste oeffnen';

  @override
  String get shoppingMoveCheckedSemLabel => 'Markierte Elemente verschieben';

  @override
  String shoppingMoveCheckedSemHint(Object count) {
    return 'Verschiebe $count markierte Elemente ins Inventar';
  }

  @override
  String shoppingMoveCheckedToFridge(Object count) {
    return '$count Element(e) in den Kuehlschrank verschoben';
  }

  @override
  String get shoppingEditingItem => 'Element wird bearbeitet';

  @override
  String get shoppingRenameItemHint => 'Element umbenennen';

  @override
  String get recipeArchiveClearTitle => 'Archiv leeren?';

  @override
  String get recipeArchiveClearDesc =>
      'Dadurch werden alle gespeicherten Rezepte entfernt.';

  @override
  String get recipeArchiveClearAll => 'Alles loeschen';

  @override
  String get recipeArchiveSavedTitle => 'Gespeicherte Rezepte';

  @override
  String get recipeArchiveEmptyTitle => 'Noch keine gespeicherten Rezepte';

  @override
  String get recipeArchiveEmptyDesc => 'Gespeicherte Rezepte erscheinen hier.';

  @override
  String get recipeArchiveGoBack => 'Zurueck';

  @override
  String recipeArchiveSavedOn(Object date) {
    return 'Gespeichert am $date';
  }

  @override
  String recipeGeneratorFailed(Object error) {
    return 'Generierung fehlgeschlagen: $error';
  }

  @override
  String get recipeGeneratorReviewSelectionTitle => 'Auswahl pruefen';

  @override
  String get recipeGeneratorReviewSelectionDesc =>
      'Zutaten und Praeferenzen vor der Generierung waehlen.';

  @override
  String get recipeGeneratorNoItemsTitle => 'Keine Zutaten ausgewaehlt';

  @override
  String get recipeGeneratorNoItemsDesc => 'Waehle mindestens eine Zutat aus.';

  @override
  String get recipeGeneratorExtrasTitle => 'Extras & Hinweise';

  @override
  String recipeGeneratorCookingFor(Object count) {
    return 'Kochen fuer $count';
  }

  @override
  String get recipeGeneratorStudentModeOn => 'Studentenmodus aktiv';

  @override
  String recipeGeneratorNote(Object note) {
    return 'Hinweis: $note';
  }

  @override
  String get recipeGeneratorStartTitle => 'Rezepte generieren';

  @override
  String get recipeGeneratorStartSubtitle =>
      'Wir schlagen Rezepte passend zu deinen Zutaten vor.';

  @override
  String get recipeGeneratorNoRecipes => 'Noch keine Rezepte generiert.';

  @override
  String get recipeGeneratorSuggestionsTitle => 'Vorschlaege';

  @override
  String get recipeDetailRemovedFromArchive => 'Aus dem Archiv entfernt';

  @override
  String get recipeDetailSavedToArchive => 'Im Archiv gespeichert';

  @override
  String recipeDetailOperationFailed(Object error) {
    return 'Vorgang fehlgeschlagen: $error';
  }

  @override
  String get recipeDetailNoOvenTemp =>
      'Keine Ofentemperatur im Rezept gefunden.';

  @override
  String get recipeDetailOvenBusy =>
      'Ofen ist beschaeftigt. Bitte zuerst stoppen.';

  @override
  String recipeDetailOvenPreheating(Object temp) {
    return 'Ofen heizt auf ${temp}C vor';
  }

  @override
  String recipeDetailPreheatFailed(Object error) {
    return 'Vorheizen fehlgeschlagen: $error';
  }

  @override
  String get recipeDetailOvenAlreadyIdle => 'Ofen ist bereits inaktiv.';

  @override
  String get recipeDetailOvenStopped => 'Ofen gestoppt.';

  @override
  String recipeDetailStopFailed(Object error) {
    return 'Stoppen fehlgeschlagen: $error';
  }

  @override
  String get recipeDetailSavedLeftoversToInventory =>
      'Reste wurden ins Inventar gespeichert.';

  @override
  String get recipeDetailInventoryUpdated => 'Inventar aktualisiert.';

  @override
  String get recipeDetailTitle => 'Rezeptdetails';

  @override
  String recipeDetailYields(Object servings) {
    return 'Portionen: $servings';
  }

  @override
  String get recipeDetailSmartKitchen => 'Smart Kitchen';

  @override
  String get recipeDetailOvenReady => 'Ofen ist bereit';

  @override
  String get recipeDetailPreheatOven => 'Ofen vorheizen';

  @override
  String recipeDetailPreheatTo(Object temp) {
    return 'Vorheizen auf $temp';
  }

  @override
  String recipeDetailTemp(Object temp) {
    return '${temp}C';
  }

  @override
  String get recipeDetailTapToStop => 'Tippen zum Stoppen';

  @override
  String get recipeDetailTapToStart => 'Tippen zum Starten';

  @override
  String get recipeDetailIngredientsTitle => 'Zutaten';

  @override
  String get recipeDetailInstructionsTitle => 'Anleitung';

  @override
  String recipeDetailStep(Object number) {
    return 'Schritt $number';
  }

  @override
  String get recipeDetailCookedThis => 'Ich habe das gekocht';

  @override
  String get recipeDetailReviewUsageTitle => 'Zutatenverbrauch pruefen';

  @override
  String get recipeDetailUsageNone => 'Kein';

  @override
  String get recipeDetailUsageAll => 'Alles';

  @override
  String get recipeDetailConfirmUsage => 'Verbrauch bestaetigen';

  @override
  String get recipeDetailMealPrepTitle => 'Alles aufgegessen?';

  @override
  String get recipeDetailMealPrepDesc => 'Oder etwas fuer spaeter vorbereitet?';

  @override
  String get recipeDetailLeftoversToSave => 'Zu speichernde Reste:';

  @override
  String get recipeDetailWhereStoreLeftovers => 'Wo moechtest du es lagern?';

  @override
  String get recipeDetailSaveLeftovers => 'Reste speichern';

  @override
  String get recipeDetailAteEverything => 'Alles aufgegessen!';

  @override
  String get guestListAddYourNameTitle => 'Namen hinzufuegen';

  @override
  String get guestListEnterDisplayNameHint => 'Anzeigenamen eingeben';

  @override
  String get guestListAddNoteTitle => 'Notiz hinzufuegen';

  @override
  String get guestListAddNoteHint => 'z. B. fettarm, Marke, Groesse';

  @override
  String get guestListShareLinkCopied => 'Freigabelink kopiert.';

  @override
  String get guestListExpiredEditingDisabled =>
      'Diese Liste ist abgelaufen. Bearbeiten ist deaktiviert.';

  @override
  String get guestListTitle => 'Gast-Einkaufsliste';

  @override
  String get guestListCopyShareLinkTooltip => 'Freigabelink kopieren';

  @override
  String get guestListMineLabel => 'Meine';

  @override
  String get guestListJoining => 'Liste wird geoeffnet...';

  @override
  String get guestListAddNameToEdit =>
      'Zum Bearbeiten zuerst Namen hinzufuegen.';

  @override
  String get guestListAddNameAction => 'Namen hinzufuegen';

  @override
  String get shoppingAddItemHint => 'Element hinzufuegen...';

  @override
  String get guestListNoItemsYet => 'Noch keine Elemente';

  @override
  String get guestListLookingForList => 'Freigegebene Liste wird gesucht...';

  @override
  String get guestListFailedLoad => 'Liste konnte nicht geladen werden.';

  @override
  String get guestListRefreshPage => 'Seite neu laden';

  @override
  String get guestListGuestFallback => 'Gast';

  @override
  String get guestArchiveEmpty => 'Noch keine Gastlisten';

  @override
  String guestArchiveExpires(Object label) {
    return 'Laeuft ab: $label';
  }

  @override
  String get guestArchiveExpired => 'Abgelaufen';

  @override
  String get guestArchiveActive => 'Aktiv';

  @override
  String get authUnexpectedError =>
      'Unerwarteter Fehler, bitte erneut versuchen.';

  @override
  String get authEnterEmailFirst => 'Bitte zuerst E-Mail eingeben.';

  @override
  String get authResetEmailSent => 'E-Mail zum Zuruecksetzen wurde gesendet.';

  @override
  String get authResetEmailFailed => 'Senden der Reset-E-Mail fehlgeschlagen.';

  @override
  String get loginWelcomeBack => 'Willkommen zurueck';

  @override
  String get loginWelcomeSubtitle => 'Melde dich an, um fortzufahren';

  @override
  String get authPleaseEnterEmail => 'Bitte E-Mail eingeben.';

  @override
  String get authEmailInvalid => 'Bitte gueltige E-Mail eingeben.';

  @override
  String get authPleaseEnterPassword => 'Bitte Passwort eingeben.';

  @override
  String get authAtLeast6Chars => 'Mindestens 6 Zeichen.';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort verbergen';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authLogIn => 'Anmelden';

  @override
  String get authOr => 'oder';

  @override
  String get authNoAccount => 'Noch kein Konto?';

  @override
  String get authSignUp => 'Registrieren';

  @override
  String get authSkipForNow => 'Jetzt ueberspringen';

  @override
  String get authBack => 'Zurueck';

  @override
  String get registerPasswordsDoNotMatch =>
      'Passwoerter stimmen nicht ueberein.';

  @override
  String get registerSuccessCheckEmail =>
      'Registrierung erfolgreich! Bitte E-Mail bestaetigen.';

  @override
  String get registerBackToLogin => 'Zurueck zum Login';

  @override
  String get registerCreateAccountTitle => 'Konto erstellen';

  @override
  String get registerCreateAccountSubtitle =>
      'Starte deine Smart-Kitchen-Reise.';

  @override
  String get registerNameLabel => 'Name';

  @override
  String get registerNameHint => 'Dein Anzeigename';

  @override
  String get registerEnterName => 'Bitte Namen eingeben.';

  @override
  String get registerNameTooShort => 'Name ist zu kurz.';

  @override
  String get registerEmailLabel => 'E-Mail';

  @override
  String get registerPasswordLabel => 'Passwort';

  @override
  String get registerPasswordHint => 'Mindestens 6 Zeichen';

  @override
  String get registerRepeatPasswordLabel => 'Passwort wiederholen';

  @override
  String get registerRepeatPasswordHint => 'Passwort erneut eingeben';

  @override
  String get registerPasswordsDoNotMatchInline =>
      'Passwoerter stimmen nicht ueberein';

  @override
  String get registerProfileDetailsTitle => 'Profildetails';

  @override
  String get registerGenderLabel => 'Geschlecht';

  @override
  String get registerAgeGroupLabel => 'Altersgruppe';

  @override
  String get registerRequired => 'Pflichtfeld';

  @override
  String get registerCountryLabel => 'Land';

  @override
  String get registerCountryHint => 'z. B. Deutschland';

  @override
  String get registerPleaseEnterCountry => 'Bitte Land eingeben.';

  @override
  String get fridgeCameraSignInToConnect =>
      'Bitte anmelden, um Kuehlschrankkameras zu verbinden.';

  @override
  String get fridgeCameraNotConnected => 'Home Connect ist nicht verbunden.';

  @override
  String fridgeCameraLoadFailed(Object error) {
    return 'Kuehlschrankbilder konnten nicht geladen werden: $error';
  }

  @override
  String get fridgeCameraTitle => 'Kuehlschrankkamera';

  @override
  String get fridgeCameraRefreshTooltip => 'Aktualisieren';

  @override
  String get fridgeCameraNoDevices =>
      'Keine verbundenen Kuehlschraenke gefunden.';

  @override
  String get fridgeCameraNoImages => 'Noch keine Bilder verfuegbar.';

  @override
  String fridgeCameraImageCount(Object count) {
    return '$count Bild(er)';
  }

  @override
  String get fridgeCameraImageLoadFailed => 'Bild konnte nicht geladen werden';

  @override
  String get shoppingArchiveTitle => 'Kaufverlauf';

  @override
  String get shoppingArchiveClearTooltip => 'Verlauf leeren';

  @override
  String get shoppingArchiveClearTitle => 'Kaufverlauf leeren?';

  @override
  String get shoppingArchiveClearDesc =>
      'Dadurch werden alle archivierten Einkaufselemente entfernt.';

  @override
  String get shoppingArchiveClearAction => 'Leeren';

  @override
  String get shoppingArchiveAddBackTooltip => 'Zur Einkaufsliste hinzufuegen';

  @override
  String shoppingArchiveAddedBack(Object name) {
    return 'Wieder hinzugefuegt: $name';
  }

  @override
  String get shoppingArchiveToday => 'Heute';

  @override
  String get shoppingArchiveYesterday => 'Gestern';

  @override
  String get shoppingArchiveEmptyTitle => 'Noch kein Verlauf';

  @override
  String get shoppingArchiveEmptyDesc =>
      'Abgeschlossene Einkaeufe erscheinen hier.';

  @override
  String get recipeDetailAllLabel => 'Alles';
}
