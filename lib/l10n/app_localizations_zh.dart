// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BSH 智能食物小管家';

  @override
  String get navToday => '今天';

  @override
  String get todayGreetingMorning => '早上好';

  @override
  String get todayGreetingNoon => '下午好';

  @override
  String get todayGreetingEvening => '晚上好';

  @override
  String get navInventory => '库存';

  @override
  String get navShopping => '购物';

  @override
  String get navImpact => '影响';

  @override
  String get undo => '哎呀，撤销一下';

  @override
  String get prefLanguageTitle => '语言';

  @override
  String get prefLanguageSubtitle => '切换应用语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => '英语';

  @override
  String get languageChinese => '中文';

  @override
  String get languageGerman => '德语';

  @override
  String get themeTitle => '主题';

  @override
  String get themeFollowSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get accountTitle => '账户';

  @override
  String get accountSectionHousehold => '家庭';

  @override
  String get accountSectionMyHome => '我的家';

  @override
  String get accountSectionIntegrations => '集成';

  @override
  String get accountSectionPreferences => '偏好设置';

  @override
  String get accountSectionAbout => '关于';

  @override
  String get accountNotificationsTitle => '通知';

  @override
  String get accountNotificationsSubtitle => '过期提醒与餐时提醒';

  @override
  String get notificationPermissionBlocked => '系统设置中已阻止通知权限。';

  @override
  String get notificationMealReminderMessage =>
      '你的部分食材即将过期，快来 Smart Food Home 看看。';

  @override
  String get notificationSavedFutureApply => '已保存，新提醒时间将应用于后续通知。';

  @override
  String get notificationEnablePermissionFirst => '请先开启通知权限。';

  @override
  String get notificationTestMessage => '这是一条来自 Smart Food Home 的测试过期提醒。';

  @override
  String get notificationTestSent => '测试通知已发送。';

  @override
  String get notificationThreeDayExpiryTitle => '3 天过期提醒';

  @override
  String get notificationThreeDayExpiryDesc => '当食材距离过期 3 天时提醒一次。';

  @override
  String get notificationMealTimeTitle => '餐时提醒';

  @override
  String get notificationMealTimeDesc => '每天在午餐和晚餐时间提醒两次。';

  @override
  String get notificationPermissionAllowed => '系统通知权限：已允许';

  @override
  String get notificationPermissionBlockedStatus => '系统通知权限：已阻止';

  @override
  String notificationStatusCombined(Object mealStatus, Object threeDayStatus) {
    return '餐时提醒：$mealStatus | 3 天提醒：$threeDayStatus';
  }

  @override
  String get notificationStatusScheduled => '已安排';

  @override
  String get notificationStatusOff => '关闭';

  @override
  String get notificationMealTimesTitle => '用餐时间';

  @override
  String get notificationMealTimesHint => '我们会在这些时间提醒你查看即将过期的食材。';

  @override
  String get notificationLunchLabel => '常用午餐时间';

  @override
  String get notificationDefaultLunchTime => '11:30（默认）';

  @override
  String get notificationDinnerLabel => '常用晚餐时间';

  @override
  String get notificationDefaultDinnerTime => '17:30（默认）';

  @override
  String get notificationResetDefaults => '恢复默认';

  @override
  String get notificationSendTestNow => '立即发送测试';

  @override
  String familyLoadMembersFailed(Object error) {
    return '加载成员失败：$error';
  }

  @override
  String get familyErrorTitle => '错误';

  @override
  String familyGenerateCodeFailed(Object error) {
    return '生成邀请码失败：\n\n$error';
  }

  @override
  String get familyOk => '确定';

  @override
  String get familyJoinTitle => '加入家庭';

  @override
  String get familyJoinDesc => '请输入家庭成员分享的 6 位邀请码。';

  @override
  String get familyInviteCodeLabel => '邀请码';

  @override
  String get familyJoinAction => '加入';

  @override
  String get familyJoinedSuccess => '已成功加入家庭！';

  @override
  String get familyInvalidOrExpiredCode => '邀请码无效或已过期。';

  @override
  String familyErrorMessage(Object error) {
    return '错误：$error';
  }

  @override
  String get familyLeaveTitle => '退出家庭？';

  @override
  String get familyLeaveDesc => '退出后你将不再看到共享库存和购物清单，并回到个人私有空间。';

  @override
  String get familyLeaveAction => '退出';

  @override
  String get familyLeftSuccess => '已退出家庭，已切换到私有模式。';

  @override
  String get familyLeaveFailed => '退出家庭失败。';

  @override
  String get familyInviteMemberTitle => '邀请成员';

  @override
  String get familyInviteMemberDesc => '把这个邀请码发给你的家庭成员。\n他们可用它加入你的家庭空间。';

  @override
  String get familyInviteExpiresIn2Days => '2 天后过期';

  @override
  String get familyDone => '完成';

  @override
  String get familyUpdateNameTitle => '更新你的昵称';

  @override
  String get familyDisplayNameHint => '输入你的显示名称';

  @override
  String get familyNameUpdated => '名称已更新。';

  @override
  String get familyNameUpdateFailed => '名称更新失败。';

  @override
  String get familyMyFamilyTitle => '我的家庭';

  @override
  String get familyMembersTitle => '成员';

  @override
  String get familyNoMembersFound => '未找到成员。';

  @override
  String get familyInviteNewMember => '邀请新成员';

  @override
  String get familyJoinAnotherFamily => '加入其他家庭';

  @override
  String get familyLeaveThisFamily => '退出当前家庭';

  @override
  String get familyInventoryShoppingSynced => '库存与购物清单已同步';

  @override
  String get familyYourDisplayName => '你的显示名称';

  @override
  String get familyEdit => '编辑';

  @override
  String get familyMigrationFailed => '迁移失败';

  @override
  String get familyMigratingData => '正在迁移你的数据';

  @override
  String get familyKeepAppOpen => '请保持应用开启。';

  @override
  String familyMigrationAttempt(Object attempt, Object total) {
    return '尝试 $attempt / $total';
  }

  @override
  String get familyInventoryMode => '库存模式';

  @override
  String get familySharedFridgeTitle => '共享冰箱';

  @override
  String get familySharedFridgeDesc => '所有成员共同管理库存。';

  @override
  String get familySeparateFridgesTitle => '独立冰箱';

  @override
  String get familySeparateFridgesDesc => '食材严格按成员归属。';

  @override
  String get familyUnknownMember => '未知';

  @override
  String get familyUnknownInitial => 'U';

  @override
  String get accountNightModeTitle => '夜间模式';

  @override
  String get accountStudentModeTitle => '学生模式';

  @override
  String get accountStudentModeSubtitle => '更省钱的食谱与建议';

  @override
  String get accountLoyaltyCardsTitle => '会员卡';

  @override
  String get accountLoyaltyCardsSubtitle => '连接 PAYBACK（即将上线）';

  @override
  String get accountPrivacyPolicyTitle => '隐私政策';

  @override
  String get accountVersionTitle => '版本';

  @override
  String get accountSignOut => '退出登录';

  @override
  String accountHelloUser(Object name) {
    return '你好，$name';
  }

  @override
  String get accountGuestTitle => '游客账户';

  @override
  String get accountSignInHint => '登录后可同步你的数据';

  @override
  String get accountLogIn => '登录';

  @override
  String get accountHomeConnectLinked => 'Home Connect 已连接！';

  @override
  String get accountConnectionFailed => '连接失败';

  @override
  String get accountDisconnected => '已断开连接';

  @override
  String get accountSimulatorAppliances => '模拟器设备';

  @override
  String get accountNoAppliancesFound => '未找到设备';

  @override
  String get accountUnknown => '未知';

  @override
  String get accountIdCopied => 'ID 已复制';

  @override
  String accountApplianceId(Object id) {
    return 'ID：$id';
  }

  @override
  String get accountHomeConnectTitle => 'Home Connect';

  @override
  String get accountRefreshStatus => '刷新状态';

  @override
  String get accountViewAppliances => '查看设备';

  @override
  String get accountDisconnect => '断开连接';

  @override
  String get accountConnecting => '连接中...';

  @override
  String get accountActiveSynced => '已激活并同步';

  @override
  String get accountTapToConnect => '点击连接';

  @override
  String get leaderboardTitle => '排行榜';

  @override
  String get leaderboardScopeWorld => '全球';

  @override
  String get leaderboardGlobalTitle => '全球榜';

  @override
  String get leaderboardGlobalSubtitle => '全球表现最佳用户';

  @override
  String get leaderboardYourRank => '你的排名';

  @override
  String get leaderboardNoDataYet => '暂无数据';

  @override
  String leaderboardRankInScope(Object rank, Object scope) {
    return '$scope 第 $rank 名';
  }

  @override
  String get leaderboardLoadFailedTitle => '排行榜加载失败';

  @override
  String get retry => '重试';

  @override
  String leaderboardPointsKgCo2(Object value) {
    return '$value kg CO2';
  }

  @override
  String get leaderboardAddFriendTitle => '添加好友';

  @override
  String get leaderboardFriendEmailLabel => '好友邮箱';

  @override
  String get leaderboardFriendEmailHint => 'name@email.com';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get leaderboardNoUserForEmail => '没有找到该邮箱对应用户。';

  @override
  String get leaderboardInvalidUserId => '该邮箱对应用户 ID 无效。';

  @override
  String get leaderboardCannotAddYourself => '不能添加自己。';

  @override
  String get leaderboardFriendAdded => '已添加好友。';

  @override
  String leaderboardAddFriendFailed(Object error) {
    return '添加好友失败：$error';
  }

  @override
  String get pullToRefreshHint => '下拉刷新';

  @override
  String get pullToRefreshRelease => '松手刷新';

  @override
  String get foodLocationFridge => '冷藏';

  @override
  String get foodLocationFreezer => '冷冻';

  @override
  String get foodLocationPantry => '常温';

  @override
  String foodExpiredDaysAgo(Object days) {
    return '已过期 $days 天';
  }

  @override
  String foodDaysLeft(Object days) {
    return '还剩 $days 天';
  }

  @override
  String get foodActionCookEat => '做饭 / 食用';

  @override
  String get foodActionFeedPets => '喂宠物';

  @override
  String get foodActionDiscard => '丢弃';

  @override
  String get foodPetsHappy => '小屎和小远很开心！';

  @override
  String get todayRecipeArchiveTooltip => '菜谱归档';

  @override
  String get todayAiChefTitle => 'AI 厨师';

  @override
  String get todayAiChefDescription => '使用当前食材生成菜谱。';

  @override
  String get todayExpiringSoonTitle => '即将过期';

  @override
  String get todayExpiringSoonDescription => '快速烹饪、喂宠物或丢弃食材。';

  @override
  String get todayPetSafetyWarning => '请确认该食物对宠物安全！';

  @override
  String get todayWhatCanICook => '想烹饪什么？';

  @override
  String todayBasedOnItems(int count) {
    return '基于你冰箱里的 $count 个食材。';
  }

  @override
  String get todayGenerate => '看看';

  @override
  String get todayPlanWeekTitle => '规划这一周！';

  @override
  String get todayPlanWeekSubtitle => '点击开始安排餐食。';

  @override
  String get todayViewAll => '查看全部';

  @override
  String get todayExpired => '已过期';

  @override
  String get todayExpiryToday => '今天到期';

  @override
  String get todayOneDayLeft => '剩 1 天';

  @override
  String get todayAllClearTitle => '一切正常！';

  @override
  String get todayAllClearSubtitle => '你的冰箱很新鲜也很整洁。';

  @override
  String todayUndoCooked(Object name) {
    return '已烹饪“$name”';
  }

  @override
  String todayUndoFedPet(Object name) {
    return '已将“$name”喂给宠物';
  }

  @override
  String todayUndoDiscarded(Object name) {
    return '已丢弃“$name”';
  }

  @override
  String todayUndoUpdated(Object name) {
    return '已更新“$name”';
  }

  @override
  String get commonSave => '保存';

  @override
  String get inventorySyncChangesLabel => '将更改同步到云端';

  @override
  String get inventoryCloudSyncStatusLabel => '云同步状态';

  @override
  String get inventorySyncRetryHint => '点击重试同步未完成的更改';

  @override
  String get inventorySyncAllSavedHint => '点击确认所有更改已保存';

  @override
  String get inventorySyncingChanges => '正在同步更改...';

  @override
  String get inventoryAllChangesSaved => '所有更改已保存';

  @override
  String get inventorySyncingChangesToCloud => '正在将更改同步到云端...';

  @override
  String get inventoryAllSavedToCloud => '所有更改已保存到云端。';

  @override
  String get inventoryQuickSearchTitle => '快速搜索';

  @override
  String get inventoryQuickSearchDescription => '按名称快速找到任意食材。';

  @override
  String get inventorySearchHint => '搜索食材...';

  @override
  String get inventoryNoItemsFound => '未找到食材';

  @override
  String get inventoryEmptyTitle => '库存为空';

  @override
  String get inventoryEmptySubtitle => '点击 + 按钮添加食材。';

  @override
  String get inventoryLongPressTitle => '长按菜单';

  @override
  String get inventoryLongPressDescription => '长按食材可编辑、使用数量、移动或删除。';

  @override
  String get inventorySwipeDeleteTitle => '左滑删除';

  @override
  String get inventorySwipeDeleteDescription => '将食材向左滑动即可删除，删除后可立即撤销。';

  @override
  String get inventoryItemNoteTitle => '食材备注';

  @override
  String get inventoryItemNoteHint => '添加一条简短备注...';

  @override
  String get inventoryEditNote => '编辑备注';

  @override
  String get inventoryAddNote => '添加备注';

  @override
  String get inventorySharedLabel => '共享';

  @override
  String get inventoryNoteReminderSubtitle => '留一个简短提醒';

  @override
  String get inventoryChangeCategory => '更改分类';

  @override
  String get inventoryRecordUsageUpdateQty => '记录用量并更新数量';

  @override
  String get inventoryGreatForLeftovers => '很适合处理剩余食物';

  @override
  String get inventoryTrackWasteImproveHabits => '记录浪费，改进习惯';

  @override
  String inventoryCookedToast(Object qty, Object name) {
    return '已烹饪 $qty 的 $name';
  }

  @override
  String inventoryFedToPetToast(Object name) {
    return '已把 $name 喂给宠物';
  }

  @override
  String inventoryRecordedWasteToast(Object name) {
    return '已记录浪费：$name';
  }

  @override
  String inventoryDeletedToast(Object name) {
    return '已删除“$name”';
  }

  @override
  String get inventoryCookWithThis => '用这个做饭';

  @override
  String get inventoryFeedToPet => '喂给宠物';

  @override
  String get inventoryWastedThrownAway => '浪费 / 丢弃';

  @override
  String get inventoryEditDetails => '编辑详情';

  @override
  String get inventoryDeleteItem => '删除食材';

  @override
  String get inventoryDeleteItemQuestion => '确定删除该食材吗？';

  @override
  String inventoryDeletePermanentQuestion(Object name) {
    return '要将“$name”从库存中永久移除吗？';
  }

  @override
  String get inventoryDeleteAction => '删除';

  @override
  String get inventoryDetailQuantity => '数量';

  @override
  String get inventoryDetailAdded => '添加时间';

  @override
  String get inventoryDetailStorageLocation => '存放位置';

  @override
  String get inventoryDetailNotes => '备注';

  @override
  String get inventoryDetailStatusExpired => '已过期';

  @override
  String get inventoryDetailStatusExpiresToday => '今日到期';

  @override
  String get inventoryDetailStatusExpiring => '即将过期';

  @override
  String get inventoryDetailStatusFresh => '新鲜';

  @override
  String get inventoryDetailAddedToday => '今天添加';

  @override
  String get inventoryDetailAddedOneDayAgo => '1 天前添加';

  @override
  String inventoryDetailAddedDaysAgo(Object days) {
    return '$days 天前添加';
  }

  @override
  String get inventoryDetailDaysLeftLabel => '剩余\n天数';

  @override
  String get inventoryDetailEditDetailsSubtitle => '更新食材详情和到期时间';

  @override
  String inventorySheetUpdating(Object name) {
    return '正在更新：$name';
  }

  @override
  String get inventoryActionType => '操作类型';

  @override
  String get inventoryActionCooked => '已烹饪';

  @override
  String get inventoryActionPetFeed => '喂宠物';

  @override
  String get inventoryActionWaste => '浪费';

  @override
  String get inventoryQuickAssign => '快速分配';

  @override
  String get inventoryEditFamily => '编辑家庭成员';

  @override
  String get inventoryYouLabel => '你';

  @override
  String get inventoryConfirmUpdate => '确认更新';

  @override
  String get inventoryQuantityUsed => '已使用数量';

  @override
  String inventoryRemainingQty(Object value, Object unit) {
    return '剩余：$value$unit';
  }

  @override
  String get inventorySemanticsQuantityUsed => '已使用数量';

  @override
  String get inventorySemanticsUsageHint => '左右拖动来调整使用量';

  @override
  String get inventorySemanticsAdjustUsedAmount => '调整已使用数量';

  @override
  String get shoppingTemporaryListTooltip => '临时清单';

  @override
  String get shoppingFridgeCameraTitle => '冰箱拍照';

  @override
  String get shoppingFridgeCameraDescription => '拍一下冰箱，快速规划购物。';

  @override
  String get shoppingPurchaseHistoryTitle => '购买记录';

  @override
  String get shoppingPurchaseHistoryDescription => '查看已购买食材并一键加回。';

  @override
  String get shoppingCompletedLabel => '已完成';

  @override
  String get shoppingAiSmartAddTitle => 'AI 智能添加';

  @override
  String get shoppingAiSmartAddDescription => '从菜谱中提取食材并添加。';

  @override
  String get shoppingAiSmartAddHint => '从菜谱文本导入食材';

  @override
  String get shoppingQuickAddTitle => '快速添加';

  @override
  String get shoppingQuickAddDescription => '一键快速添加单个食材。';

  @override
  String get shoppingQuickAddSemanticsLabel => '快速添加条目';

  @override
  String get shoppingInputHint => '在这里添加条目';

  @override
  String get shoppingRecipeImportTitle => '菜谱导入';

  @override
  String get shoppingRecipeSignInRequiredAction => '请先登录以使用 AI 菜谱识别。';

  @override
  String get shoppingRecipeSignInAction => '去登录';

  @override
  String get shoppingRecipeProvideInput => '请提供菜名、菜谱文本或图片。';

  @override
  String shoppingRecipeAnalysisFailed(Object error) {
    return '解析失败：$error';
  }

  @override
  String shoppingRecipeAddedItems(Object count) {
    return '已添加 $count 个条目到购物清单';
  }

  @override
  String get shoppingRecipeInputHint => '输入菜名或粘贴菜谱...';

  @override
  String get shoppingRecipeIngredientsSection => '食材';

  @override
  String get shoppingRecipeSeasoningsSection => '调味料';

  @override
  String get shoppingRecipeCamera => '拍照';

  @override
  String get shoppingRecipeAlbum => '相册';

  @override
  String get shoppingRecipeAnalyzing => '分析中...';

  @override
  String get shoppingRecipeGetListButton => '生成购物清单';

  @override
  String get shoppingRecipeAiThinking => 'AI 正在思考...';

  @override
  String get shoppingRecipeResultsPlaceholder => '解析结果会显示在这里';

  @override
  String shoppingRecipeInStockReason(Object reason) {
    return '库存中：$reason';
  }

  @override
  String shoppingRecipeCategoryLabel(Object category) {
    return '分类：$category';
  }

  @override
  String shoppingRecipeAddSelectedToList(Object count) {
    return '添加 $count 项到清单';
  }

  @override
  String get shoppingRecipeSignInRequiredTitle => '需要登录';

  @override
  String get shoppingRecipeSignInRequiredSubtitle => '请先登录，同步库存并使用 AI 菜谱分析功能。';

  @override
  String get shoppingRecipeSignInNow => '立即登录';

  @override
  String get shoppingEmptyTitle => '清单为空';

  @override
  String get shoppingEmptySubtitle => '手动添加食材，或使用菜谱导入。';

  @override
  String shoppingDeletedToast(Object name) {
    return '已删除“$name”';
  }

  @override
  String get shoppingUndoAction => '撤销';

  @override
  String get impactTitle => '你的影响力';

  @override
  String get impactTimeRangeTitle => '时间范围';

  @override
  String get impactTimeRangeDescription => '可切换查看周、月、年数据。';

  @override
  String get impactSummaryTitle => '影响力总览';

  @override
  String get impactSummaryDescription => '这里可以看到省下的钱和拯救的食材。';

  @override
  String impactKgAvoided(Object value) {
    return '减少 ${value}kg 排放';
  }

  @override
  String get impactLevelTitle => '等级';

  @override
  String get impactStreakTitle => '连续天数';

  @override
  String get impactDaysActive => '活跃天数';

  @override
  String get impactActiveBadge => '活跃中';

  @override
  String get impactWeeklyReportTitle => '周报';

  @override
  String get impactWeeklyReportDescription => '查看你的 AI 周总结和建议。';

  @override
  String get impactWeeklyReviewSubtitle => '回顾你上周的表现';

  @override
  String get weeklyAddedToShoppingList => '已添加到购物清单。';

  @override
  String get weeklyHeiExplainedTitle => 'HEI-2015 说明';

  @override
  String get weeklyHeiExplainedIntro =>
      '健康饮食指数（HEI-2015）是 0-100 分，用于衡量饮食与美国膳食指南的一致程度。';

  @override
  String get weeklyHeiHowComputeTitle => '计算方式';

  @override
  String get weeklyHeiHowComputeBody =>
      '我们基于 USDA FoodData Central 营养数据和你记录的食物估算 HEI 组成项，包括：';

  @override
  String get weeklyHeiComponentsList =>
      '- 水果（总量与整果）\n- 蔬菜（总量与深绿/豆类）\n- 全谷物\n- 乳制品\n- 总蛋白与海鲜/植物蛋白\n- 脂肪酸比例\n- 适度项：精制谷物、钠、添加糖、饱和脂肪';

  @override
  String get weeklyHeiMorePoints =>
      '分数越高表示饮食越均衡。我们在适用场景按每 1000 千卡归一化，并使用 HEI-2015 评分标准。';

  @override
  String get weeklyGotIt => '知道了';

  @override
  String get weeklyHeiLabelExcellent => '优秀';

  @override
  String get weeklyHeiLabelGood => '良好';

  @override
  String get weeklyHeiLabelFair => '一般';

  @override
  String get weeklyHeiLabelNeedsWork => '需改进';

  @override
  String get weeklyMacrosNotEnoughData => '数据不足，无法计算宏量营养素。';

  @override
  String get weeklyMacroProtein => '蛋白质';

  @override
  String get weeklyMacroCarbs => '碳水';

  @override
  String get weeklyMacroFat => '脂肪';

  @override
  String weeklyDataSource(Object source) {
    return '数据来源：$source';
  }

  @override
  String get weeklyPrev => '上一周';

  @override
  String get weeklyNext => '下一周';

  @override
  String get impactChooseMascot => '选择你的吉祥物';

  @override
  String get impactMascotNameTitle => '吉祥物名称';

  @override
  String get impactMascotNameHint => '给它取个名字';

  @override
  String get impactMascotCat => '猫咪';

  @override
  String get impactMascotDog => '狗狗';

  @override
  String get impactMascotHamster => '仓鼠';

  @override
  String get impactMascotGuineaPig => '豚鼠';

  @override
  String impactFedToMascot(Object name) {
    return '喂给 $name 的食材';
  }

  @override
  String get impactItemFallback => '食材';

  @override
  String get impactFridgeMasterTitle => '冰箱达人！';

  @override
  String impactSavedItemsStreak(Object savedCount, Object streak) {
    return '已拯救 $savedCount 个食材，连续 $streak 天';
  }

  @override
  String get impactTotalSavingsLabel => '累计节省';

  @override
  String get impactNextRankLabel => '下一级：零浪费英雄';

  @override
  String impactBasedOnSavedItems(Object count) {
    return '基于已拯救的 $count 个食材';
  }

  @override
  String impactOnTrackYearly(Object amount) {
    return '按当前节奏，全年可节省 $amount';
  }

  @override
  String get impactCommunityQuestTitle => '社区挑战';

  @override
  String get impactNewBadge => '新';

  @override
  String impactYouSavedCo2ThisWeek(Object value) {
    return '本周你减少了 ${value}kg 的 CO2！';
  }

  @override
  String get impactViewLeaderboard => '查看排行榜';

  @override
  String get impactTopSaversTitle => '最省钱类别';

  @override
  String get impactSeeAll => '查看全部';

  @override
  String get impactMostSavedLabel => '节省最多';

  @override
  String get impactRecentActionsTitle => '最近操作';

  @override
  String get impactFamilyLabel => '家庭';

  @override
  String get impactActionCooked => '已烹饪';

  @override
  String get impactActionFedToPet => '已喂宠物';

  @override
  String get impactActionWasted => '已浪费';

  @override
  String get impactTapForDietInsights => '点我查看你的饮食洞察';

  @override
  String impactEnjoyedLeftovers(Object weight) {
    return '吃掉了 ${weight}kg 的剩余食材';
  }

  @override
  String get impactNoDataTitle => '暂无数据';

  @override
  String get impactNoDataSubtitle => '开始减少浪费，这里就会出现你的影响力！';

  @override
  String get impactRangeWeek => '周';

  @override
  String get impactRangeMonth => '月';

  @override
  String get impactRangeYear => '年';

  @override
  String get addFoodVoiceTapToStart => '点按麦克风开始';

  @override
  String get addFoodDateNotSet => '未设置';

  @override
  String get addFoodTextTooShort => '文本太短，请提供更多信息。';

  @override
  String addFoodRecognizedItems(int count) {
    return '识别到 $count 个条目。';
  }

  @override
  String get addFoodAiParserUnavailable => 'AI 解析器不可用，已使用本地解析。';

  @override
  String get addFoodAiUnexpectedResponse => 'AI 返回异常，已使用本地解析。';

  @override
  String get addFoodFormFilledFromVoice => '已根据语音填充表单。';

  @override
  String get addFoodAiReturnedEmpty => 'AI 返回为空，已使用本地解析。';

  @override
  String get addFoodNetworkParseFailed => '网络解析失败，已使用本地解析。';

  @override
  String addFoodAiParseFailed(Object error) {
    return 'AI 解析失败：$error';
  }

  @override
  String get addFoodEnterNameFirst => '请先输入食材名称';

  @override
  String addFoodExpirySetTo(Object date) {
    return '保质期已设置为 $date';
  }

  @override
  String get addFoodMaxFourImages => '最多支持 4 张图片，已选取前 4 张。';

  @override
  String get addFoodNoItemsDetected => '图片中未识别到食材。';

  @override
  String addFoodScanFailed(Object error) {
    return '扫描失败：$error';
  }

  @override
  String addFoodVoiceError(Object error) {
    return '语音错误：$error';
  }

  @override
  String get addFoodSpeechNotAvailable => '此设备不支持语音识别';

  @override
  String get addFoodSpeechNotSupported => '当前设备不支持语音识别。';

  @override
  String addFoodSpeechInitFailed(Object code) {
    return '语音初始化失败：$code';
  }

  @override
  String get addFoodSpeechInitUnable => '无法初始化语音识别。';

  @override
  String get addFoodOpeningXiaomiSpeech => '正在打开小米语音...';

  @override
  String get addFoodVoiceGotIt => '收到，点“解析并填充”。';

  @override
  String get addFoodVoiceCanceled => '语音已取消，点麦克风重试。';

  @override
  String get addFoodMicBlocked => '麦克风被禁用，请到设置开启。';

  @override
  String get addFoodMicDenied => '麦克风权限被拒绝。';

  @override
  String get addFoodListeningNow => '正在聆听...';

  @override
  String get addFoodAddItemTitle => '新增食材';

  @override
  String get addFoodEditItemTitle => '编辑食材';

  @override
  String get addFoodHelpButton => '帮助';

  @override
  String get addFoodTabManual => '手动';

  @override
  String get addFoodTabScan => '扫描';

  @override
  String get addFoodTabVoice => '语音';

  @override
  String get addFoodBasicInfoTitle => '基础信息';

  @override
  String get addFoodNameLabel => '名称';

  @override
  String get addFoodRequired => '必填';

  @override
  String get addFoodQuantityLabel => '数量';

  @override
  String get addFoodUnitLabel => '单位';

  @override
  String get addFoodMinStockWarningLabel => '最低库存预警（可选）';

  @override
  String get addFoodMinStockHint => '例如：2（低于时提醒）';

  @override
  String get addFoodMinStockHelper => '留空表示不提醒';

  @override
  String get addFoodStorageLocationTitle => '存储位置';

  @override
  String get addFoodCategoriesTitle => '分类';

  @override
  String get addFoodDatesTitle => '日期';

  @override
  String get addFoodPurchaseDate => '购买日期';

  @override
  String get addFoodOpenDate => '开封日期';

  @override
  String get addFoodBestBefore => '最佳食用期';

  @override
  String get addFoodSaveToInventory => '保存到库存';

  @override
  String get addFoodScanReceipt => '扫描小票';

  @override
  String get addFoodSnapFridge => '拍摄冰箱';

  @override
  String get addFoodTakePhoto => '拍照';

  @override
  String get addFoodUseCameraToScan => '使用相机扫描';

  @override
  String get addFoodUploadMax4 => '上传（最多 4 张）';

  @override
  String get addFoodChooseMultipleFromGallery => '从相册选择多张';

  @override
  String get addFoodAiExtractReceiptItems => 'AI 将从小票中提取食材。';

  @override
  String get addFoodAiIdentifyFridgeItems => 'AI 将识别冰箱或储物区中的食材。';

  @override
  String get addFoodAutoLabel => '自动';

  @override
  String get addFoodXiaomiSpeechMode => '小米语音模式';

  @override
  String addFoodEngineReady(Object locale) {
    return '识别引擎就绪 - $locale';
  }

  @override
  String get addFoodPreparingEngine => '正在准备语音引擎...';

  @override
  String get addFoodVoiceTrySaying => '试试说：“3个苹果、牛奶、1公斤大米”';

  @override
  String get addFoodTranscriptHint => '识别文本会显示在这里...';

  @override
  String get addFoodClear => '清空';

  @override
  String get addFoodAnalyzing => '分析中...';

  @override
  String get addFoodAnalyzeAndFill => '解析并填充';

  @override
  String get addFoodAiExpiryPrediction => 'AI 保质期预测';

  @override
  String get addFoodAutoMagic => '自动预测';

  @override
  String get addFoodThinking => '思考中...';

  @override
  String get addFoodPredictedExpiry => '预测到期日';

  @override
  String get addFoodManualDateOverride => '手动日期将覆盖此结果';

  @override
  String get addFoodAutoApplied => '已自动应用';

  @override
  String get addFoodAiSuggestHint => '让 AI 根据食材类型和存储方式给出建议。';

  @override
  String get addFoodErrorPrefix => '错误：';

  @override
  String get addFoodAutoMagicPrediction => '自动魔法预测';

  @override
  String get addFoodScanningReceipts => '正在扫描小票...';

  @override
  String get addFoodProcessing => '处理中';

  @override
  String get addFoodItemsTitle => '条目';

  @override
  String addFoodAddCountItems(int count) {
    return '添加 $count 项';
  }

  @override
  String addFoodAddedItems(int count) {
    return '已添加 $count 项';
  }

  @override
  String get addFoodHelpTitle => '新增食材帮助';

  @override
  String get addFoodHelpManualTitle => '手动';

  @override
  String get addFoodHelpManualPoint1 => '输入名称、数量和存储位置。';

  @override
  String get addFoodHelpManualPoint2 => '如果知道包装日期，请设置最佳食用期。';

  @override
  String get addFoodHelpManualPoint3 => '可在备注里记录规格或品牌。';

  @override
  String get addFoodHelpScanTitle => '扫描';

  @override
  String get addFoodHelpScanPoint1 => '请使用清晰、光线充足的照片。';

  @override
  String get addFoodHelpScanPoint2 => '扫描小票时请保证文字完整可见。';

  @override
  String get addFoodHelpScanPoint3 => '保存前请检查识别结果。';

  @override
  String get addFoodHelpVoiceTitle => '语音';

  @override
  String get addFoodHelpVoicePoint1 => '请说“食材 + 数量 + 单位”，例如“牛奶 两升”。';

  @override
  String get addFoodHelpVoicePoint2 => '多个食材之间请稍作停顿。';

  @override
  String get addFoodHelpVoicePoint3 => '保存前可再手动编辑字段。';

  @override
  String get addFoodHelpTip => '提示：若不确定保质期，可先用 AI 预测，再手动微调。';

  @override
  String get selectIngredientsKitchenTitle => '你的厨房';

  @override
  String selectIngredientsSelectedCount(int count) {
    return '已选择 $count 个食材用于烹饪';
  }

  @override
  String get selectIngredientsNoItemsSubtitle => '试试其他筛选条件，或先添加新食材。';

  @override
  String get selectIngredientsExtrasPrompts => '额外食材与偏好';

  @override
  String get selectIngredientsAddExtraHint => '添加额外食材...';

  @override
  String get selectIngredientsSpecialRequestHint => '有特别口味偏好或饮食限制吗？';

  @override
  String get selectIngredientsPageTitle => '选择食材';

  @override
  String get selectIngredientsReset => '重置';

  @override
  String get selectIngredientsFilterAll => '全部';

  @override
  String get selectIngredientsFilterExpiring => '临期';

  @override
  String get selectIngredientsFilterVeggie => '蔬菜';

  @override
  String get selectIngredientsFilterMeat => '肉类';

  @override
  String get selectIngredientsFilterDairy => '乳制品';

  @override
  String get selectIngredientsExpiringLabel => '即将到期';

  @override
  String get selectIngredientsSoonLabel => '尽快食用';

  @override
  String get selectIngredientsFreshLabel => '新鲜';

  @override
  String selectIngredientsQuantityLeft(Object value, Object unit) {
    return '剩余 $value $unit';
  }

  @override
  String get selectIngredientsPeopleShort => '人份';

  @override
  String cookingPlanSlot(Object slot) {
    return '规划 $slot';
  }

  @override
  String get cookingMealNameLabel => '餐食名称';

  @override
  String get cookingMealNameHint => '例如：柠檬鸡肉饭碗';

  @override
  String get cookingQuickPickRecipes => '从菜谱快速选择';

  @override
  String get cookingBrowseAll => '浏览全部';

  @override
  String get cookingUseFromInventory => '从库存选择';

  @override
  String get cookingMissingItemsLabel => '缺失食材（将加入购物清单）';

  @override
  String get cookingMissingItemsHint => '例如：大蒜、香葱';

  @override
  String get cookingSavePlan => '保存计划';

  @override
  String get cookingUntitledMeal => '未命名餐食';

  @override
  String cookingAddedItemsToShopping(int count) {
    return '已将 $count 项添加到购物清单。';
  }

  @override
  String get cookingMealPlannerTitle => '餐食计划';

  @override
  String get cookingJumpToToday => '跳转到今天';

  @override
  String get cookingNoMatches => '无匹配项';

  @override
  String cookingMissingItemsCount(int count) {
    return '缺少 $count 项食材';
  }

  @override
  String get cookingAllItemsInFridge => '食材都在冰箱里';

  @override
  String get cookingSlotBreakfast => '早餐';

  @override
  String get cookingSlotLunch => '午餐';

  @override
  String get cookingSlotDinner => '晚餐';

  @override
  String get shoppingGuestCreateTempTitle => '创建临时清单';

  @override
  String get shoppingGuestCreateTempSubtitle => '可分享给访客，无需登录。';

  @override
  String get shoppingGuestMyListsTitle => '我的访客清单';

  @override
  String get shoppingGuestMyListsSubtitle => '管理已有的临时清单。';

  @override
  String get shoppingGuestDialogTitle => '创建临时清单';

  @override
  String get shoppingGuestTitleHint => '例如：周末聚餐';

  @override
  String get shoppingGuestExpiresIn => '有效期';

  @override
  String get shoppingGuestExpire24h => '24 小时';

  @override
  String get shoppingGuestExpire3d => '3 天';

  @override
  String get shoppingGuestExpire7d => '7 天';

  @override
  String get shoppingGuestAttachMineTitle => '绑定到我的账号';

  @override
  String get shoppingGuestAttachMineSubtitle => '仅账号拥有者可修改拥有者设置。';

  @override
  String get shoppingGuestCreateAction => '创建';

  @override
  String get shoppingShareLinkTitle => '分享这个链接';

  @override
  String get shoppingLinkCopied => '链接已复制。';

  @override
  String get shoppingCopyLink => '复制链接';

  @override
  String get shoppingOpenList => '打开清单';

  @override
  String get shoppingMoveCheckedSemLabel => '移动已勾选项目';

  @override
  String shoppingMoveCheckedSemHint(Object count) {
    return '将 $count 个已勾选项目移到库存';
  }

  @override
  String shoppingMoveCheckedToFridge(Object count) {
    return '已将 $count 个项目移入冰箱';
  }

  @override
  String get shoppingEditingItem => '正在编辑';

  @override
  String get shoppingRenameItemHint => '重命名项目';

  @override
  String get recipeArchiveClearTitle => '清空归档？';

  @override
  String get recipeArchiveClearDesc => '这将移除归档中的全部已保存菜谱。';

  @override
  String get recipeArchiveClearAll => '全部清空';

  @override
  String get recipeArchiveSavedTitle => '已保存菜谱';

  @override
  String get recipeArchiveEmptyTitle => '还没有保存的菜谱';

  @override
  String get recipeArchiveEmptyDesc => '保存菜谱后会显示在这里。';

  @override
  String get recipeArchiveGoBack => '返回';

  @override
  String recipeArchiveSavedOn(Object date) {
    return '保存于 $date';
  }

  @override
  String recipeGeneratorFailed(Object error) {
    return '生成失败：$error';
  }

  @override
  String get recipeGeneratorReviewSelectionTitle => '确认你的选择';

  @override
  String get recipeGeneratorReviewSelectionDesc => '先选择食材和偏好，再生成菜谱。';

  @override
  String get recipeGeneratorNoItemsTitle => '未选择食材';

  @override
  String get recipeGeneratorNoItemsDesc => '请至少选择一种食材后继续。';

  @override
  String get recipeGeneratorExtrasTitle => '额外食材与提示';

  @override
  String recipeGeneratorCookingFor(Object count) {
    return '就餐人数：$count';
  }

  @override
  String get recipeGeneratorStudentModeOn => '学生模式已开启';

  @override
  String recipeGeneratorNote(Object note) {
    return '备注：$note';
  }

  @override
  String get recipeGeneratorStartTitle => '开始生成菜谱';

  @override
  String get recipeGeneratorStartSubtitle => '我们会基于你的食材给出建议。';

  @override
  String get recipeGeneratorNoRecipes => '还没有生成菜谱。';

  @override
  String get recipeGeneratorSuggestionsTitle => '推荐结果';

  @override
  String get recipeDetailRemovedFromArchive => '已从归档移除';

  @override
  String get recipeDetailSavedToArchive => '已保存到归档';

  @override
  String recipeDetailOperationFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get recipeDetailNoOvenTemp => '该菜谱未识别到烤箱温度。';

  @override
  String get recipeDetailOvenBusy => '烤箱正在运行，请先停止再预热。';

  @override
  String recipeDetailOvenPreheating(Object temp) {
    return '烤箱正在预热到 ${temp}C';
  }

  @override
  String recipeDetailPreheatFailed(Object error) {
    return '预热失败：$error';
  }

  @override
  String get recipeDetailOvenAlreadyIdle => '烤箱当前未运行。';

  @override
  String get recipeDetailOvenStopped => '烤箱已停止。';

  @override
  String recipeDetailStopFailed(Object error) {
    return '停止失败：$error';
  }

  @override
  String get recipeDetailSavedLeftoversToInventory => '剩菜已保存到库存。';

  @override
  String get recipeDetailInventoryUpdated => '库存已更新。';

  @override
  String get recipeDetailTitle => '菜谱详情';

  @override
  String recipeDetailYields(Object servings) {
    return '份量：$servings';
  }

  @override
  String get recipeDetailSmartKitchen => '智慧厨房';

  @override
  String get recipeDetailOvenReady => '烤箱已就绪';

  @override
  String get recipeDetailPreheatOven => '预热烤箱';

  @override
  String recipeDetailPreheatTo(Object temp) {
    return '预热到 $temp';
  }

  @override
  String recipeDetailTemp(Object temp) {
    return '${temp}C';
  }

  @override
  String get recipeDetailTapToStop => '点按停止';

  @override
  String get recipeDetailTapToStart => '点按开始';

  @override
  String get recipeDetailIngredientsTitle => '食材';

  @override
  String get recipeDetailInstructionsTitle => '步骤';

  @override
  String recipeDetailStep(Object number) {
    return '第 $number 步';
  }

  @override
  String get recipeDetailCookedThis => '我做过这道菜';

  @override
  String get recipeDetailReviewUsageTitle => '确认食材用量';

  @override
  String get recipeDetailUsageNone => '未使用';

  @override
  String get recipeDetailUsageAll => '全部';

  @override
  String get recipeDetailConfirmUsage => '确认用量';

  @override
  String get recipeDetailMealPrepTitle => '这顿都吃完了吗？';

  @override
  String get recipeDetailMealPrepDesc => '还是想留作备餐？';

  @override
  String get recipeDetailLeftoversToSave => '要保存的剩余份数：';

  @override
  String get recipeDetailWhereStoreLeftovers => '准备存放在哪里？';

  @override
  String get recipeDetailSaveLeftovers => '保存剩菜';

  @override
  String get recipeDetailAteEverything => '我都吃完了！';

  @override
  String get guestListAddYourNameTitle => '添加你的名字';

  @override
  String get guestListEnterDisplayNameHint => '输入展示名称';

  @override
  String get guestListAddNoteTitle => '添加备注';

  @override
  String get guestListAddNoteHint => '例如：低脂、品牌、规格';

  @override
  String get guestListShareLinkCopied => '分享链接已复制。';

  @override
  String get guestListExpiredEditingDisabled => '该清单已过期，无法编辑。';

  @override
  String get guestListTitle => '访客购物清单';

  @override
  String get guestListCopyShareLinkTooltip => '复制分享链接';

  @override
  String get guestListMineLabel => '我的';

  @override
  String get guestListJoining => '正在加入清单...';

  @override
  String get guestListAddNameToEdit => '先添加你的名字再编辑项目。';

  @override
  String get guestListAddNameAction => '添加名字';

  @override
  String get shoppingAddItemHint => '添加项目...';

  @override
  String get guestListNoItemsYet => '暂无项目';

  @override
  String get guestListLookingForList => '正在查找分享清单...';

  @override
  String get guestListFailedLoad => '加载清单失败。';

  @override
  String get guestListRefreshPage => '刷新页面';

  @override
  String get guestListGuestFallback => '访客';

  @override
  String get guestArchiveEmpty => '暂无访客清单';

  @override
  String guestArchiveExpires(Object label) {
    return '到期：$label';
  }

  @override
  String get guestArchiveExpired => '已过期';

  @override
  String get guestArchiveActive => '进行中';

  @override
  String get authUnexpectedError => '发生异常，请稍后重试。';

  @override
  String get authEnterEmailFirst => '请先输入邮箱。';

  @override
  String get authResetEmailSent => '重置密码邮件已发送。';

  @override
  String get authResetEmailFailed => '发送重置邮件失败。';

  @override
  String get loginWelcomeBack => '欢迎回来';

  @override
  String get loginWelcomeSubtitle => '登录后继续';

  @override
  String get authPleaseEnterEmail => '请输入邮箱。';

  @override
  String get authEmailInvalid => '请输入有效邮箱。';

  @override
  String get authPleaseEnterPassword => '请输入密码。';

  @override
  String get authAtLeast6Chars => '至少 6 个字符。';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authLogIn => '登录';

  @override
  String get authOr => '或';

  @override
  String get authNoAccount => '还没有账号？';

  @override
  String get authSignUp => '注册';

  @override
  String get authSkipForNow => '暂时跳过';

  @override
  String get authBack => '返回';

  @override
  String get registerPasswordsDoNotMatch => '两次输入的密码不一致。';

  @override
  String get registerSuccessCheckEmail => '注册成功！请查收邮件完成验证。';

  @override
  String get registerBackToLogin => '返回登录';

  @override
  String get registerCreateAccountTitle => '创建账号';

  @override
  String get registerCreateAccountSubtitle => '开启你的智能厨房之旅。';

  @override
  String get registerNameLabel => '姓名';

  @override
  String get registerNameHint => '你的显示名称';

  @override
  String get registerEnterName => '请输入姓名。';

  @override
  String get registerNameTooShort => '姓名太短。';

  @override
  String get registerEmailLabel => '邮箱';

  @override
  String get registerPasswordLabel => '密码';

  @override
  String get registerPasswordHint => '至少 6 个字符';

  @override
  String get registerRepeatPasswordLabel => '重复密码';

  @override
  String get registerRepeatPasswordHint => '再次输入密码';

  @override
  String get registerPasswordsDoNotMatchInline => '两次密码不一致';

  @override
  String get registerProfileDetailsTitle => '个人信息';

  @override
  String get registerGenderLabel => '性别';

  @override
  String get registerAgeGroupLabel => '年龄段';

  @override
  String get registerRequired => '必填';

  @override
  String get registerCountryLabel => '国家/地区';

  @override
  String get registerCountryHint => '例如：中国';

  @override
  String get registerPleaseEnterCountry => '请输入国家/地区。';

  @override
  String get fridgeCameraSignInToConnect => '请先登录后再连接冰箱相机。';

  @override
  String get fridgeCameraNotConnected => '尚未连接 Home Connect。';

  @override
  String fridgeCameraLoadFailed(Object error) {
    return '加载冰箱图片失败：$error';
  }

  @override
  String get fridgeCameraTitle => '冰箱相机';

  @override
  String get fridgeCameraRefreshTooltip => '刷新';

  @override
  String get fridgeCameraNoDevices => '未找到已连接的冰箱设备。';

  @override
  String get fridgeCameraNoImages => '暂无可用图片。';

  @override
  String fridgeCameraImageCount(Object count) {
    return '$count 张图片';
  }

  @override
  String get fridgeCameraImageLoadFailed => '图片加载失败';

  @override
  String get shoppingArchiveTitle => '购买记录';

  @override
  String get shoppingArchiveClearTooltip => '清空记录';

  @override
  String get shoppingArchiveClearTitle => '清空购买记录？';

  @override
  String get shoppingArchiveClearDesc => '这将移除所有已归档的购物项目。';

  @override
  String get shoppingArchiveClearAction => '清空';

  @override
  String get shoppingArchiveAddBackTooltip => '重新加入购物清单';

  @override
  String shoppingArchiveAddedBack(Object name) {
    return '已重新加入：$name';
  }

  @override
  String get shoppingArchiveToday => '今天';

  @override
  String get shoppingArchiveYesterday => '昨天';

  @override
  String get shoppingArchiveEmptyTitle => '暂无记录';

  @override
  String get shoppingArchiveEmptyDesc => '完成购买的项目会显示在这里。';

  @override
  String get recipeDetailAllLabel => '全部';
}
