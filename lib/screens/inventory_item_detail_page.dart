// lib/screens/inventory_item_detail_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../utils/food_icon_mapping.dart';
import '../l10n/app_localizations.dart';
import 'add_food_page.dart';

class InventoryItemDetailPage extends StatefulWidget {
  final FoodItem item;
  final InventoryRepository repo;

  const InventoryItemDetailPage({
    super.key,
    required this.item,
    required this.repo,
  });

  @override
  State<InventoryItemDetailPage> createState() => _InventoryItemDetailPageState();
}

class _InventoryItemDetailPageState extends State<InventoryItemDetailPage>
    with WidgetsBindingObserver {
  late final TextEditingController _noteController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _quantityFocusNode;
  late final ScrollController _scrollController;
  late FoodItem _item;
  double _lastViewInset = 0;
  bool _isEditingName = false;
  bool _isSavingName = false;
  bool _isEditingQuantity = false;
  bool _isSavingQuantity = false;
  bool _isSavingDates = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _noteController = TextEditingController(text: _item.note ?? '');
    _nameController = TextEditingController(text: _item.name);
    _quantityController = TextEditingController(text: _formatQuantityForInput(_item.quantity));
    _nameFocusNode = FocusNode();
    _quantityFocusNode = FocusNode();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _isEditingName) {
        _submitNameEdit();
      }
    });
    _quantityFocusNode.addListener(() {
      if (!_quantityFocusNode.hasFocus && _isEditingQuantity) {
        _submitQuantityEdit();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastViewInset = MediaQuery.of(context).viewInsets.bottom;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _nameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final inset = _currentViewInset();
    if (_lastViewInset > 0 && inset == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());
    }
    _lastViewInset = inset;
  }

  double _currentViewInset() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final view = views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _restoreScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final current = position.pixels;
    if (current > max) {
      _scrollController.jumpTo(max);
      return;
    }
    if (max - current < 120) {
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final assetPath = _resolveHeroAsset(_item);
    final daysLeft = _item.daysToExpiry;
    final statusLabel = _statusLabel(context, daysLeft);
    final statusColor = _statusColor(daysLeft);
    final addedLabel = _addedLabel(context, _item.purchasedDate);
    final topHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, _) {
          final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
          final blurSigma = (offset / 140).clamp(0.0, 1.0) * 14.0;
          final parallaxY = -offset * 0.25;
          // Keep a subtle lift effect without clipping bottom entries too early.
          final coverLift = (-offset * 0.18).clamp(-28.0, 0.0);
          final backVisibility = (1 - (offset / 120)).clamp(0.0, 1.0).toDouble();
          final backBgOpacity = (0.2 + (offset / 160).clamp(0.0, 1.0) * 0.65).clamp(0.2, 0.85);

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark ? const Color(0xFF10221A) : const Color(0xFFF6F8F7),
                        isDark ? const Color(0xFF162E24) : const Color(0xFFFFFFFF),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topHeight,
                child: Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(0, parallaxY),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.25),
                              statusColor.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: _buildHeroIcon(assetPath, statusColor),
                        ),
                      ),
                    ),
                    if (blurSigma > 0.1)
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: blurSigma,
                              sigmaY: blurSigma,
                            ),
                            child: Container(
                              color: Colors.white.withValues(alpha: isDark ? 0.02 : 0.08),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, coverLift),
                  child: PrimaryScrollController(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: topHeight - 24,
                        bottom: 32 + MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF162E24).withValues(alpha: 0.95)
                              : Colors.white.withValues(alpha: 0.96),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatusChip(label: statusLabel, color: statusColor),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: _startNameEdit,
                                  child: _isEditingName
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _nameController,
                                                focusNode: _nameFocusNode,
                                                textInputAction: TextInputAction.done,
                                                onSubmitted: (_) => _submitNameEdit(),
                                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 32,
                                                  color: colors.onSurface,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                            if (_isSavingName) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      : Text(
                                          _item.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 32,
                                            color: colors.onSurface,
                                            height: 1.1,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  addedLabel,
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DaysLeftRing(daysLeft: daysLeft, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              title: AppLocalizations.of(context)?.inventoryDetailQuantity ?? 'Quantity',
                              icon: Icons.scale_rounded,
                              color: statusColor,
                              onTap: _startQuantityEdit,
                              child: _isEditingQuantity
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _quantityController,
                                            focusNode: _quantityFocusNode,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.done,
                                            onSubmitted: (_) => _submitQuantityEdit(),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 22,
                                              color: colors.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _item.unit,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: colors.onSurface.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        if (_isSavingQuantity) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Text(
                                      '${_item.quantity} ${_item.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: colors.onSurface,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              title: AppLocalizations.of(context)?.inventoryDetailAdded ?? 'Added',
                              icon: Icons.schedule_rounded,
                              color: statusColor,
                              child: Text(
                                addedLabel
                                    .replaceFirst(
                                      '${AppLocalizations.of(context)?.inventoryDetailAdded ?? 'Added'} ',
                                      '',
                                    ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: colors.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: AppLocalizations.of(context)?.addFoodDatesTitle ?? 'Dates',
                        child: Column(
                          children: [
                            _DateEntryTile(
                              label: AppLocalizations.of(context)?.addFoodPurchaseDate ?? 'Purchase Date',
                              value: _formatAbsoluteDate(context, _item.purchasedDate),
                              icon: Icons.shopping_bag_rounded,
                              color: statusColor,
                              onTap: _isSavingDates ? null : () => _pickAndSaveDate(_EditableDateField.purchased),
                              isLoading: _isSavingDates,
                            ),
                            const SizedBox(height: 10),
                            _DateEntryTile(
                              label: AppLocalizations.of(context)?.addFoodOpenDate ?? 'Open Date',
                              value: _formatAbsoluteDate(context, _item.openDate),
                              icon: Icons.lock_open_rounded,
                              color: statusColor,
                              onTap: _isSavingDates ? null : () => _pickAndSaveDate(_EditableDateField.opened),
                              onClear: _isSavingDates || _item.openDate == null
                                  ? null
                                  : () => _clearDate(_EditableDateField.opened),
                            ),
                            const SizedBox(height: 10),
                            _DateEntryTile(
                              label: AppLocalizations.of(context)?.addFoodBestBefore ?? 'Best Before',
                              value: _formatAbsoluteDate(context, _item.bestBeforeDate),
                              icon: Icons.event_busy_rounded,
                              color: statusColor,
                              onTap: _isSavingDates ? null : () => _pickAndSaveDate(_EditableDateField.bestBefore),
                              onClear: _isSavingDates || _item.bestBeforeDate == null
                                  ? null
                                  : () => _clearDate(_EditableDateField.bestBefore),
                            ),
                            const SizedBox(height: 12),
                            _ExpiryEstimateTile(
                              label: AppLocalizations.of(context)?.addFoodPredictedExpiry ?? 'Predicted Expiry',
                              value: _formatAbsoluteDate(context, _item.predictedExpiry),
                              hint: _estimateHint(context),
                              color: statusColor,
                              isLoading: _isSavingDates,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: AppLocalizations.of(context)?.inventoryDetailStorageLocation ?? 'Storage Location',
                        child: _LocationRow(
                          location: _item.location,
                          onSelected: _updateLocation,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: AppLocalizations.of(context)?.inventoryDetailNotes ?? 'Notes',
                        child: _NotesField(
                          controller: _noteController,
                          onSave: _saveNote,
                          onSubmitExit: _saveNoteAndExit,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _EditDetailsCard(
                        onTap: _openEditDetails,
                      ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IgnorePointer(
                      ignoring: backVisibility < 0.05,
                      child: Opacity(
                        opacity: backVisibility,
                        child: _BackButton(
                          backgroundOpacity: backBgOpacity,
                          onTap: _handleBackTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNote(String value) async {
    final trimmed = value.trim();
    if (trimmed == (_item.note ?? '').trim()) return;
    final updated = _item.copyWith(note: trimmed);
    await widget.repo.updateItem(updated);
    if (!mounted) return;
    setState(() => _item = updated);
  }

  Future<void> _saveNoteAndExit(String value) async {
    await _saveNote(value);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _updateLocation(StorageLocation location) async {
    if (location == _item.location) return;
    final predicted = await _resolvePredictedExpiry(
      name: _item.name,
      location: location,
      purchasedDate: _item.purchasedDate,
      bestBeforeDate: _item.bestBeforeDate,
      fallback: _item.predictedExpiry,
    );
    final updated = _item.copyWith(
      location: location,
      predictedExpiry: predicted,
    );
    await widget.repo.updateItem(updated);
    if (!mounted) return;
    setState(() => _item = updated);
  }

  String _formatAbsoluteDate(BuildContext context, DateTime? date) {
    final l10n = AppLocalizations.of(context);
    if (date == null) return l10n?.addFoodDateNotSet ?? 'Not set';
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _estimateHint(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_item.predictedExpiry == null) {
      return l10n?.addFoodAiSuggestHint ?? 'Let AI suggest based on food type and storage.';
    }
    if (_item.bestBeforeDate != null && _isSameDay(_item.bestBeforeDate!, _item.predictedExpiry!)) {
      return l10n?.addFoodManualDateOverride ?? 'Manual date will override this';
    }
    return l10n?.addFoodAutoApplied ?? 'Auto applied';
  }

  Future<void> _pickAndSaveDate(_EditableDateField field) async {
    final now = DateTime.now();
    final initial = _dateForField(field) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10, 1, 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null) return;
    await _saveDates(field: field, value: picked);
  }

  Future<void> _clearDate(_EditableDateField field) async {
    await _saveDates(field: field, value: null);
  }

  DateTime? _dateForField(_EditableDateField field) {
    switch (field) {
      case _EditableDateField.purchased:
        return _item.purchasedDate;
      case _EditableDateField.opened:
        return _item.openDate;
      case _EditableDateField.bestBefore:
        return _item.bestBeforeDate;
    }
  }

  Future<void> _saveDates({
    required _EditableDateField field,
    required DateTime? value,
  }) async {
    if (_isSavingDates) return;
    var purchased = _item.purchasedDate;
    var opened = _item.openDate;
    var bestBefore = _item.bestBeforeDate;

    switch (field) {
      case _EditableDateField.purchased:
        if (value == null) return;
        purchased = value;
      case _EditableDateField.opened:
        opened = value;
      case _EditableDateField.bestBefore:
        bestBefore = value;
    }

    final unchanged = _isSameDay(purchased, _item.purchasedDate) &&
        _nullableSameDay(opened, _item.openDate) &&
        _nullableSameDay(bestBefore, _item.bestBeforeDate);
    if (unchanged) return;

    setState(() => _isSavingDates = true);
    final predicted = await _resolvePredictedExpiry(
      name: _item.name,
      location: _item.location,
      purchasedDate: purchased,
      bestBeforeDate: bestBefore,
      fallback: _item.predictedExpiry,
    );
    final updated = _item.copyWith(
      purchasedDate: purchased,
      openDate: opened,
      bestBeforeDate: bestBefore,
      predictedExpiry: predicted,
    );
    await widget.repo.updateItem(updated);
    if (!mounted) return;
    setState(() {
      _item = updated;
      _isSavingDates = false;
    });
  }

  Future<DateTime?> _resolvePredictedExpiry({
    required String name,
    required StorageLocation location,
    required DateTime purchasedDate,
    required DateTime? bestBeforeDate,
    required DateTime? fallback,
  }) async {
    if (bestBeforeDate != null) return bestBeforeDate;
    final predicted = await widget.repo.predictExpiryDate(
      name,
      location.name,
      purchasedDate,
    );
    return predicted ?? fallback ?? purchasedDate.add(const Duration(days: 7));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _nullableSameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return _isSameDay(a, b);
  }

  String _formatQuantityForInput(double value) {
    final s = value.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _startNameEdit() {
    if (_isSavingName) return;
    setState(() {
      _isEditingName = true;
      _nameController.text = _item.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  Future<void> _submitNameEdit() async {
    if (!_isEditingName || _isSavingName) return;
    final l10n = AppLocalizations.of(context);
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.addFoodEnterNameFirst ?? 'Please enter the food name first')),
      );
      setState(() {
        _isEditingName = false;
        _nameController.text = _item.name;
      });
      return;
    }
    if (trimmed == _item.name) {
      setState(() => _isEditingName = false);
      return;
    }

    setState(() => _isSavingName = true);
    final updated = _item.copyWith(name: trimmed);
    await widget.repo.updateItem(updated);
    if (!mounted) return;
    setState(() {
      _item = updated;
      _isSavingName = false;
      _isEditingName = false;
      _nameController.text = updated.name;
    });
  }

  void _startQuantityEdit() {
    if (_isSavingQuantity) return;
    setState(() {
      _isEditingQuantity = true;
      _quantityController.text = _formatQuantityForInput(_item.quantity);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _quantityFocusNode.requestFocus();
      _quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantityController.text.length,
      );
    });
  }

  Future<void> _submitQuantityEdit() async {
    if (!_isEditingQuantity || _isSavingQuantity) return;
    final raw = _quantityController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid quantity'),
        ),
      );
      setState(() {
        _isEditingQuantity = false;
        _quantityController.text = _formatQuantityForInput(_item.quantity);
      });
      return;
    }

    if ((parsed - _item.quantity).abs() < 0.0001) {
      setState(() => _isEditingQuantity = false);
      return;
    }

    setState(() => _isSavingQuantity = true);
    final updated = _item.copyWith(quantity: parsed);
    await widget.repo.updateItem(updated);
    if (!mounted) return;
    setState(() {
      _item = updated;
      _isSavingQuantity = false;
      _isEditingQuantity = false;
      _quantityController.text = _formatQuantityForInput(updated.quantity);
    });
  }


  Future<void> _openEditDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(
          repo: widget.repo,
          itemToEdit: _item,
          initialTab: 0,
        ),
      ),
    );
    if (!mounted) return;
    final updated = widget.repo
        .getActiveItems()
        .cast<FoodItem?>()
        .firstWhere((i) => i?.id == _item.id, orElse: () => null);
    if (updated != null) {
      setState(() => _item = updated);
      _noteController.text = updated.note ?? '';
    }
  }

  static Widget _buildHeroIcon(String? assetPath, Color accent) {
    if (assetPath == null || assetPath.isEmpty) {
      return Icon(Icons.inventory_2_rounded, size: 140, color: accent.withValues(alpha: 0.4));
    }
    return Image.asset(
      assetPath,
      width: 180,
      height: 180,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Icon(Icons.inventory_2_rounded, size: 140, color: accent.withValues(alpha: 0.4));
      },
    );
  }

  String _statusLabel(BuildContext context, int daysLeft) {
    final l10n = AppLocalizations.of(context);
    if (daysLeft < 0) return l10n?.inventoryDetailStatusExpired ?? 'Expired';
    if (daysLeft == 0) return l10n?.inventoryDetailStatusExpiresToday ?? 'Expires today';
    if (daysLeft <= 3) return l10n?.inventoryDetailStatusExpiring ?? 'Expiring';
    return l10n?.inventoryDetailStatusFresh ?? 'Fresh';
  }

  static Color _statusColor(int daysLeft) {
    if (daysLeft < 0) return const Color(0xFFE53935);
    if (daysLeft <= 3) return const Color(0xFFFFA000);
    return const Color(0xFF2BEE9D);
  }

  String _addedLabel(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final added = DateTime(date.year, date.month, date.day);
    final diff = today.difference(added).inDays;
    if (diff <= 0) return l10n?.inventoryDetailAddedToday ?? 'Added today';
    if (diff == 1) return l10n?.inventoryDetailAddedOneDayAgo ?? 'Added 1 day ago';
    return l10n?.inventoryDetailAddedDaysAgo(diff) ?? 'Added $diff days ago';
  }

  String? _resolveHeroAsset(FoodItem item) {
    final primary = foodIconAssetForItem(item);
    if (!_isDefaultAsset(primary)) return primary;

    final categoryName = item.category ?? '';
    if (categoryName.trim().isNotEmpty) {
      final categoryAsset = foodIconAssetForName(categoryName);
      if (!_isDefaultAsset(categoryAsset)) return categoryAsset;
    }

    return null;
  }

  bool _isDefaultAsset(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) return true;
    return assetPath.endsWith('/default.png');
  }

  void _handleBackTap() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }
}

enum _EditableDateField { purchased, opened, bestBefore }

class _BackButton extends StatelessWidget {
  final double backgroundOpacity;
  final VoidCallback onTap;

  const _BackButton({
    this.backgroundOpacity = 0.2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgBase = isDark ? const Color(0xFF3A3E46) : const Color(0xFFE2E5EA);
    final borderBase = isDark ? const Color(0xFF616773) : const Color(0xFFC5CAD3);
    final iconColor = isDark ? const Color(0xFFE7E9EE) : const Color(0xFF58606E);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgBase.withValues(alpha: backgroundOpacity),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderBase.withValues(alpha: 0.28)),
        ),
        child: Icon(Icons.arrow_back_ios_new, color: iconColor, size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysLeftRing extends StatelessWidget {
  final int daysLeft;
  final Color color;

  const _DaysLeftRing({required this.daysLeft, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = daysLeft < 0 ? '0' : daysLeft.toString();
    final progress = _progressValue(daysLeft);
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                display,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                l10n?.inventoryDetailDaysLeftLabel ?? 'DAYS\nLEFT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _progressValue(int daysLeft) {
    if (daysLeft <= 0) return 0.05;
    if (daysLeft >= 10) return 1.0;
    return (daysLeft / 10).clamp(0.05, 1.0);
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162E24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162E24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DateEntryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool isLoading;

  const _DateEntryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onClear,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else ...[
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 16, color: colors.onSurface.withValues(alpha: 0.45)),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear',
                ),
              Icon(Icons.edit_calendar_rounded, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpiryEstimateTile extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;
  final bool isLoading;

  const _ExpiryEstimateTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
        ],
      ),
    );
  }
}

class _EditDetailsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EditDetailsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.edit_rounded, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.inventoryEditDetails ?? 'Edit details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.inventoryDetailEditDetailsSubtitle ?? 'Update item details & expiry',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final StorageLocation location;
  final ValueChanged<StorageLocation> onSelected;

  const _LocationRow({
    required this.location,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: StorageLocation.values.map((entry) {
          final selected = entry == location;
          final label = _label(context, entry);
          final icon = _icon(entry);
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? const Color(0xFF2D8EFF) : Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? const Color(0xFF2D8EFF) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(BuildContext context, StorageLocation location) {
    final l10n = AppLocalizations.of(context);
    switch (location) {
      case StorageLocation.fridge:
        return l10n?.foodLocationFridge ?? 'Fridge';
      case StorageLocation.freezer:
        return l10n?.foodLocationFreezer ?? 'Freezer';
      case StorageLocation.pantry:
        return l10n?.foodLocationPantry ?? 'Pantry';
    }
  }

  static IconData _icon(StorageLocation location) {
    switch (location) {
      case StorageLocation.fridge:
        return Icons.kitchen_rounded;
      case StorageLocation.freezer:
        return Icons.ac_unit_rounded;
      case StorageLocation.pantry:
        return Icons.shelves;
    }
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onSubmitExit;

  const _NotesField({
    required this.controller,
    required this.onSave,
    required this.onSubmitExit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.notes_rounded, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) onSave(controller.text);
              },
              child: TextField(
                controller: controller,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n?.inventoryItemNoteHint ?? 'Add a short note...',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
                ),
                onSubmitted: onSubmitExit,
                onEditingComplete: () => onSave(controller.text),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


