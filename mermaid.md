stateDiagram-v2

[*] --> AppLaunch
AppLaunch --> InitServices : start
InitServices --> AuthRoot : init done
AppLaunch --> WidgetRecipeRoute : deep link /widget-recipe

state AuthRoot {
  [*] --> LoggedOut
  LoggedOut --> LoggedIn : auth stream (session)
  LoggedIn --> LoggedOut : auth stream (null) / sign out

  LoggedOut --> LoginPage : profile/auth required
  LoginPage --> RegisterPage : tap register
  RegisterPage --> LoginPage : back
  LoginPage --> LoggedIn : login success
}

AuthRoot --> MainScaffold : stream-driven auth (always render)

state MainScaffold {
  state Tabs {
    [*] --> Today
    Today --> Inventory : tab / swipe
    Inventory --> Shopping : tab / swipe
    Shopping --> Impact : tab / swipe
    Impact --> Today : tab / swipe
  }

  %% ---------- Today ----------
  state TodayFlow {
    [*] --> Today
    Today --> SelectIngredientsPage : tap AI Chef
    Today --> CookingCalendarPage : tap hero card
    Today --> RecipeArchivePage : tap app bar icon
  }

  %% ---------- AI Chef ----------
  state AIChef {
    [*] --> SelectIngredientsPage

    SelectIngredientsPage --> RequireLoginDialog : confirm (if LoggedOut)
    RequireLoginDialog --> LoginPage : Log in
    RequireLoginDialog --> SelectIngredientsPage : cancel

    SelectIngredientsPage --> AI_Request : confirm ingredients
    AI_Request --> AI_Response : model returns
    AI_Response --> RecipeGeneratorSheet : build results

    RecipeGeneratorSheet --> RecipeDetailPage : tap recipe
    RecipeGeneratorSheet --> RecipeArchivePage : save/view
    RecipeArchivePage --> RecipeDetailPage : open recipe
  }

  %% ---------- Cooking Calendar ----------
  state CookingCalendar {
    [*] --> CookingCalendarPage
    CookingCalendarPage --> EditMealSheet : tap slot
    EditMealSheet --> RecipeArchivePage : browse all
  }

  %% ---------- Inventory ----------
  state InventoryFlow {
    [*] --> Inventory
    Inventory --> AddFoodPage : FAB/manual/photo/voice or edit
    Inventory --> ItemActionsSheet : open item actions
    ItemActionsSheet --> QuantityDialog : eat/pet/trash

    AddFoodPage --> DatePicker : pick date
    AddFoodPage --> ScanPreviewSheet : scan preview
    ScanPreviewSheet --> EditScannedItemDialog : edit scanned item
  }

  %% ---------- Shopping ----------
  state ShoppingFlow {
    [*] --> Shopping
    Shopping --> AddByRecipeSheet : AI import
    Shopping --> FridgeCameraPage : open camera
    Shopping --> ShoppingArchivePage : open archive
    Shopping --> EditItemDialog : edit item
  }

  %% ---------- Impact / Account ----------
  state ImpactFlow {
    [*] --> Impact
    Impact --> WeeklyReportPage : open weekly report
    Impact --> AccountPage : open account

    AccountPage --> NotificationSettingsPage : notification settings
    AccountPage --> FamilyPage : family

    AccountPage --> StudentMode : toggle student mode
    AccountPage --> SharedFamilyMode : join family

    %% AI usage in Impact
    WeeklyReportPage --> AI_CacheHit : cached week
    AI_CacheHit --> WeeklyReportPage : render cached

    WeeklyReportPage --> AI_Request : generate report
    AI_Request --> AI_Response : model returns
    AI_Response --> WeeklyReportPage : render report
  }

  %% ---------- Modes (global effects) ----------
  state Modes {
    [*] --> DefaultMode
    DefaultMode --> StudentMode : enable
    StudentMode --> DefaultMode : disable

    DefaultMode --> SharedFamilyMode : join family
    SharedFamilyMode --> DefaultMode : leave family

    note right of StudentMode
      StudentMode affects AI_Request:
      cheaper / faster model profile
    end note

    note right of SharedFamilyMode
      SharedFamilyMode affects Inventory/Shopping/Impact:
      shared data scope
    end note
  }
}

%% ---------- Widget route ----------
state WidgetRecipeRoute {
  [*] --> ResolveWidgetRecipe
  ResolveWidgetRecipe --> RecipeDetailPage : resolved recipe
}

MainScaffold --> WidgetRecipeRoute : deep link /widget-recipe
AuthRoot --> WidgetRecipeRoute : deep link /widget-recipe
