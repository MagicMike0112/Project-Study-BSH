// lib/screens/add_food_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../services/mi_speech_service.dart';
import '../utils/app_locale.dart';
import '../utils/auth_guard.dart';
import '../utils/reveal_route.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';
import '../l10n/app_localizations.dart';

const String kBackendBaseUrl = 'https://project-study-bsh.vercel.app';

// NOTE: legacy comment cleaned.
enum StorageScanMode { receipt, fridge }

class AddFoodPage extends StatefulWidget {
  final InventoryRepository repo;
  final int initialTab;
  final FoodItem? itemToEdit;

  const AddFoodPage({
    super.key,
    required this.repo,
    this.initialTab = 0,
    this.itemToEdit,
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final ScrollController _manualScrollController;
  late final ScrollController _voiceScrollController;
  double _lastViewInset = 0;

  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // NOTE: legacy comment cleaned.
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _qty;
  late String _unit;
  double? _minQty;
  late StorageLocation _location;
  late String _note;
  late String _categoryKey;

  // NOTE: legacy comment cleaned.
  late DateTime _purchased;
  DateTime? _openDate;
  DateTime? _bestBefore;

  DateTime? _expiry;

  // NOTE: legacy comment cleaned.
  bool _isPredictingExpiry = false;
  DateTime? _predictedExpiryFromAi;
  String? _predictionError;

  // NOTE: legacy comment cleaned.
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isProcessing = false;
  bool _isListening = false;
  String _voiceHint = "Tap mic to start";
  final TextEditingController _voiceController = TextEditingController();
  bool _speechReady = false;
  bool _speechInitializing = false;
  String? _speechLocaleId;
  bool _miSpeechAvailable = false;
  bool _isMiDevice = false;
  bool _depsReady = false;

  // NOTE: legacy comment cleaned.
  StorageScanMode _scanMode = StorageScanMode.receipt;
  StorageScanMode? _activeProcessingScanMode;

  // Unified accent color for legacy controls.
  static const Color _primaryColor = Color(0xFF1B78FF);
  static const String _autoCategoryKey = '__auto__';
  static const List<_CategoryOption> _categoryOptions = [
    _CategoryOption('produce', 'Produce', Icons.eco_rounded, Color(0xFF7C9A84)),
    _CategoryOption(
        'dairy', 'Dairy', Icons.water_drop_rounded, Color(0xFF7E9DBB)),
    _CategoryOption(
        'meat', 'Meat', Icons.restaurant_rounded, Color(0xFFA77979)),
    _CategoryOption(
        'seafood', 'Seafood', Icons.set_meal_rounded, Color(0xFF7689A4)),
    _CategoryOption(
        'bakery', 'Bakery', Icons.bakery_dining_rounded, Color(0xFFB39A76)),
    _CategoryOption(
        'frozen', 'Frozen', Icons.ac_unit_rounded, Color(0xFF7EA7B3)),
    _CategoryOption(
        'beverage', 'Beverage', Icons.local_drink_rounded, Color(0xFF6D9B95)),
    _CategoryOption(
        'pantry', 'Pantry', Icons.kitchen_rounded, Color(0xFFA48B74)),
    _CategoryOption(
        'snacks', 'Snacks', Icons.cookie_rounded, Color(0xFFA67F76)),
    _CategoryOption('household', 'Household', Icons.cleaning_services_rounded,
        Color(0xFF7E8B96)),
    _CategoryOption('pet', 'Pet', Icons.pets_rounded, Color(0xFF8E7F73)),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.itemToEdit != null ? 0 : widget.initialTab,
    );
    _tabController.addListener(_handleTabChanged);
    _manualScrollController = ScrollController();
    _voiceScrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    _voiceController.addListener(_onVoiceTextChanged);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rippleController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _rippleController.forward();
      }
    });

    final item = widget.itemToEdit;
    _name = item?.name ?? '';
    _qty = item?.quantity ?? 1.0;
    _unit = item?.unit ?? 'pcs';
    _minQty = item?.minQuantity;
    _location = item?.location ?? StorageLocation.fridge;
    _note = item?.note ?? '';
    _categoryKey = widget.repo.isExplicitCategory(item?.category)
        ? _normalizeCategoryKey(item!.category!.trim().toLowerCase())
        : _autoCategoryKey;
    if (!_isValidCategoryKey(_categoryKey)) {
      _categoryKey = _autoCategoryKey;
    }

    const allowedUnits = [
      'pcs',
      'kg',
      'g',
      'L',
      'ml',
      'pack',
      'box',
      'cup',
    ];
    if (!allowedUnits.contains(_unit)) {
      _unit = 'pcs';
    } else if (_unit == 'cups') {
      _unit = 'cup';
    }

    _purchased = item?.purchasedDate ?? DateTime.now();
    _openDate = item?.openDate;
    _bestBefore = item?.bestBeforeDate;
    _expiry =
        item?.predictedExpiry ?? DateTime.now().add(const Duration(days: 7));
    _initSpeechBackends();
  }

  Future<void> _initSpeechBackends() async {
    await _ensureSpeechInitialized();
    final support = await MiSpeechService.getSpeechSupport();
    if (!mounted) return;
    final manufacturer =
        (support['manufacturer'] ?? '').toString().toLowerCase();
    final isMi = manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco');
    setState(() {
      _miSpeechAvailable = support['available'] == true;
      _isMiDevice = isMi;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _depsReady = true;
    _lastViewInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context);
    if (_voiceHint == "Tap mic to start") {
      _voiceHint = l10n?.addFoodVoiceTapToStart ?? "Tap mic to start";
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _rippleController.dispose();
    _manualScrollController.dispose();
    _voiceScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _voiceController.removeListener(_onVoiceTextChanged);
    _voiceController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onVoiceTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleTabChanged() {
    if (_tabController.index != 2 && _isListening) {
      _stopListening(resetHint: true);
    }
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

  ScrollController? _activeScrollController() {
    final index = _tabController.index;
    if (index == 0) return _manualScrollController;
    if (index == 2) return _voiceScrollController;
    return null;
  }

  void _restoreScroll() {
    final controller = _activeScrollController();
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    final max = position.maxScrollExtent;
    final current = position.pixels;
    if (current > max) {
      controller.jumpTo(max);
      return;
    }
    if (max - current < 120) {
      controller.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  // ========= Logic Helpers =========

  String _formatQty(double q) {
    final isInt = (q - q.round()).abs() < 1e-9;
    return isInt ? q.round().toString() : q.toStringAsFixed(1);
  }

  String _locationLabel(StorageLocation loc) {
    final l10n = AppLocalizations.of(context);
    switch (loc) {
      case StorageLocation.freezer:
        return l10n?.foodLocationFreezer ?? 'Freezer';
      case StorageLocation.pantry:
        return l10n?.foodLocationPantry ?? 'Pantry';
      case StorageLocation.fridge:
        return l10n?.foodLocationFridge ?? 'Fridge';
    }
  }

  String _formatDate(DateTime? d) {
    final l10n = AppLocalizations.of(context);
    if (d == null) return l10n?.addFoodDateNotSet ?? 'Not set';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final primary = Theme.of(context).colorScheme.primary;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  void _resetPrediction() {
    if (_predictedExpiryFromAi != null) {
      setState(() {
        _predictedExpiryFromAi = null;
        _expiry = null;
        _predictionError = null;
      });
    }
  }

  IconData _locationIcon(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.freezer:
        return Icons.ac_unit_rounded;
      case StorageLocation.pantry:
        return Icons.shelves;
      case StorageLocation.fridge:
        return Icons.kitchen_rounded;
    }
  }

  // ========= Actions =========

  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final DateTime? effectiveExpiry = _bestBefore ?? _expiry;
    final resolvedCategory = _categoryKey == _autoCategoryKey
        ? widget.repo.inferCategoryForName(_name,
            existingCategory: widget.itemToEdit?.category)
        : _categoryKey;
    final categoryToSave = resolvedCategory ?? 'general';

    final newItem = FoodItem(
      id: widget.itemToEdit?.id ?? const Uuid().v4(),
      name: _name,
      location: _location,
      quantity: _qty,
      unit: _unit,
      minQuantity: _minQty,
      purchasedDate: _purchased,
      openDate: _openDate,
      bestBeforeDate: _bestBefore,
      predictedExpiry: effectiveExpiry,
      category: categoryToSave,
      note: _note.trim().isEmpty ? null : _note.trim(),
    );

    if (widget.itemToEdit != null) {
      await widget.repo.updateItem(newItem);
    } else {
      await widget.repo.addItem(newItem);
    }

    if (_categoryKey != _autoCategoryKey) {
      await widget.repo.rememberCategoryForName(_name, _categoryKey);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _processVoiceInputWithAi(String text) async {
    final l10n = AppLocalizations.of(context);
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n?.addFoodTextTooShort ?? 'Text too short, please provide more info.')),
      );
      return;
    }

    if (_isListening) {
      _stopListening();
    }

    setState(() => _isProcessing = true);

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/parse-ingredient');
      final locale = AppLocale.fromContext(context);

      List<_ScannedItem> fallbackItems() => _parseVoiceInputLocally(trimmed);

      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept-Language': locale,
              'X-App-Locale': locale,
            },
            body: jsonEncode({
              'text': trimmed,
              'expectList': true,
              'locale': locale,
            }),
          )
          .timeout(const Duration(seconds: 18));

      if (resp.statusCode != 200) {
        final localItems = fallbackItems();
        if (localItems.isNotEmpty && mounted) {
          await _showScannedItemsPreview(localItems);
          if (!mounted) return;
          setState(
              () => _voiceHint = (l10n?.addFoodRecognizedItems(localItems.length) ?? 'Recognized ${localItems.length} item(s).'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n?.addFoodAiParserUnavailable ?? 'AI parser unavailable, used local parser.')),
          );
          return;
        }
        throw Exception('Server error: ${resp.statusCode}');
      }

      final decoded = jsonDecode(resp.body);
      final parsedItems = _extractParsedItemsFromResponse(decoded);
      if (parsedItems.isNotEmpty) {
        final scannedItems =
            parsedItems.map((e) => _mapJsonToScannedItem(e)).toList();

        if (scannedItems.isNotEmpty) {
          if (mounted) {
            await _showScannedItemsPreview(scannedItems);
            setState(() {
              _voiceHint = 'Recognized ${scannedItems.length} item(s).';
            });
          }
          return;
        }
      }

      if (decoded is! Map<String, dynamic>) {
        final localItems = fallbackItems();
        if (localItems.isNotEmpty && mounted) {
          await _showScannedItemsPreview(localItems);
          if (!mounted) return;
          setState(
              () => _voiceHint = (l10n?.addFoodRecognizedItems(localItems.length) ?? 'Recognized ${localItems.length} item(s).'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n?.addFoodAiUnexpectedResponse ?? 'Unexpected AI response, used local parser.')),
          );
          return;
        }
        throw Exception('Invalid parser response');
      }
      final json = decoded;

      // Fallback: single-item payload or local parser
      final name = (json['name'] ?? '').toString();
      final unit = (json['unit'] ?? 'pcs').toString();
      final storageLocation = (json['storageLocation'] ?? 'fridge').toString();

      if (name.isNotEmpty) {
        double quantity = 1.0;
        final qRaw = json['quantity'];
        if (qRaw is num) quantity = qRaw.toDouble();

        setState(() {
          _name = name;
          _qty = quantity;
          _unit = unit;

          switch (storageLocation) {
            case 'freezer':
              _location = StorageLocation.freezer;
              break;
            case 'pantry':
              _location = StorageLocation.pantry;
              break;
            default:
              _location = StorageLocation.fridge;
          }

          if (json['predictedExpiry'] != null) {
            try {
              final d = DateTime.parse(json['predictedExpiry']);
              _predictedExpiryFromAi = d;
              _expiry = d;
              _bestBefore = d;
            } catch (_) {}
          } else {
            _resetPrediction();
          }
        });

        if (mounted) {
          _tabController.animateTo(0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.addFoodFormFilledFromVoice ?? 'Form filled from voice.')),
          );
        }
        return;
      }

      final localItems = fallbackItems();
      if (localItems.isNotEmpty && mounted) {
        await _showScannedItemsPreview(localItems);
        if (!mounted) return;
        setState(() => _voiceHint = (l10n?.addFoodRecognizedItems(localItems.length) ?? 'Recognized ${localItems.length} item(s).'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n?.addFoodAiReturnedEmpty ?? 'AI parser returned empty, used local parser.')),
        );
        return;
      }

      throw Exception('No parsable items');
    } catch (e) {
      final localItems = _parseVoiceInputLocally(trimmed);
      if (localItems.isNotEmpty && mounted) {
        await _showScannedItemsPreview(localItems);
        if (!mounted) return;
        setState(() => _voiceHint = (l10n?.addFoodRecognizedItems(localItems.length) ?? 'Recognized ${localItems.length} item(s).'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n?.addFoodNetworkParseFailed ?? 'Network parse failed, used local parser.')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.addFoodAiParseFailed(e.toString()) ?? 'AI parse failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  List<Map<String, dynamic>> _extractParsedItemsFromResponse(dynamic decoded) {
    List<dynamic> raw = const [];

    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final directCandidates = [
        decoded['items'],
        decoded['inventoryList'],
        decoded['list'],
        decoded['ingredients'],
        decoded['ingredientList'],
      ];
      for (final c in directCandidates) {
        if (c is List && c.isNotEmpty) {
          raw = c;
          break;
        }
      }

      if (raw.isEmpty && decoded['data'] is Map) {
        final nested = Map<String, dynamic>.from(decoded['data'] as Map);
        final nestedCandidates = [
          nested['items'],
          nested['inventoryList'],
          nested['list'],
          nested['ingredients'],
          nested['ingredientList'],
        ];
        for (final c in nestedCandidates) {
          if (c is List && c.isNotEmpty) {
            raw = c;
            break;
          }
        }
      }
    }

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<_ScannedItem> _parseVoiceInputLocally(String text) {
    final normalized = text
        .replaceAll(RegExp(r'\band\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'[，、；;]+'), ',')
        .replaceAll('&', ',');

    final parts = normalized
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final results = <_ScannedItem>[];
    for (final part in parts) {
      final parsed = _parseSingleVoiceSegment(part);
      if (parsed != null) {
        results.add(parsed);
      }
    }
    return results;
  }

  _ScannedItem? _parseSingleVoiceSegment(String segment) {
    final cleaned = segment.trim();
    if (cleaned.isEmpty) return null;

    final regex = RegExp(
        r'^\s*(\d+(?:\.\d+)?)?\s*([a-zA-Z]+|kg|g|ml|l|pcs|pack|box|cup)?\s*(.+)$');
    final match = regex.firstMatch(cleaned);

    double qty = 1.0;
    var unit = 'pcs';
    var name = cleaned;

    if (match != null) {
      final q = match.group(1);
      final u = match.group(2);
      final n = match.group(3);
      if (q != null && q.isNotEmpty) {
        qty = double.tryParse(q) ?? 1.0;
      }
      if (u != null && u.isNotEmpty) {
        unit = _normalizeVoiceUnit(u);
      }
      if (n != null && n.trim().isNotEmpty) {
        name = n.trim();
      }
    }

    if (name.length < 2) return null;
    final inferredCategory = widget.repo.inferCategoryForName(name) ?? 'voice';

    return _ScannedItem(
      name: name[0].toUpperCase() + name.substring(1),
      quantity: qty,
      unit: unit,
      location: StorageLocation.fridge,
      category: inferredCategory,
      purchaseDate: DateTime.now(),
      predictedExpiry: null,
      confidence: 0.35,
    );
  }

  String _normalizeVoiceUnit(String raw) {
    final u = raw.trim().toLowerCase();
    switch (u) {
      case 'l':
      case 'liter':
      case 'litre':
        return 'L';
      case 'ml':
        return 'ml';
      case 'kg':
        return 'kg';
      case 'g':
      case 'gram':
      case 'grams':
        return 'g';
      case 'cup':
      case 'cups':
        return 'cup';
      case 'pack':
      case 'packs':
        return 'pack';
      case 'box':
      case 'boxes':
        return 'box';
      case 'pc':
      case 'pcs':
      case 'piece':
      case 'pieces':
      default:
        return 'pcs';
    }
  }

  _ScannedItem _mapJsonToScannedItem(dynamic json) {
    final m = json as Map<String, dynamic>;
    final name = (m['name'] ?? '').toString().trim();
    double qty = 1;
    if (m['quantity'] is num) qty = (m['quantity'] as num).toDouble();

    StorageLocation loc = StorageLocation.fridge;
    if (m['storageLocation'] == 'freezer') loc = StorageLocation.freezer;
    if (m['storageLocation'] == 'pantry') loc = StorageLocation.pantry;

    DateTime purchaseDate = DateTime.now();
    if (m['purchaseDate'] != null) {
      try {
        purchaseDate = DateTime.parse(m['purchaseDate']);
      } catch (_) {}
    }

    DateTime? predictedExpiry;
    if (m['predictedExpiry'] is String) {
      try {
        predictedExpiry = DateTime.parse(m['predictedExpiry']);
      } catch (_) {}
    }

    final confidenceRaw = m['confidence'];
    final confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.9;
    return _ScannedItem(
      name: name.isEmpty ? 'Unknown' : name,
      quantity: qty,
      unit: (m['unit'] ?? 'pcs').toString(),
      location: loc,
      category: (m['category'] ?? 'voice').toString(),
      purchaseDate: purchaseDate,
      predictedExpiry: predictedExpiry,
      confidence: confidence,
    );
  }

  Future<void> _predictExpiryWithAi() async {
    final l10n = AppLocalizations.of(context);
    final ok = await requireLogin(context);
    if (!ok) return;
    if (!mounted) return;

    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.addFoodEnterNameFirst ?? 'Please enter the food name first')),
      );
      return;
    }

    setState(() {
      _isPredictingExpiry = true;
      _predictionError = null;
    });

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/recipe');
      final locale = AppLocale.fromContext(context);
      final body = <String, dynamic>{
        'name': _name.trim(),
        'location': _location.name,
        'purchasedDate': _purchased.toIso8601String(),
        'locale': locale,
        if (_openDate != null) 'openDate': _openDate!.toIso8601String(),
        if (_bestBefore != null)
          'bestBeforeDate': _bestBefore!.toIso8601String(),
      };

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': locale,
          'X-App-Locale': locale,
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final iso = data['predictedExpiry'] as String?;
      if (iso == null) throw Exception('No predictedExpiry');

      final predictedDate = DateTime.parse(iso);
      setState(() {
        _predictedExpiryFromAi = predictedDate;
        _expiry = predictedDate;
        _bestBefore = predictedDate; // NOTE: legacy comment cleaned.
        _predictionError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.addFoodExpirySetTo(_formatDate(predictedDate)) ?? 'Expiry set to ${_formatDate(predictedDate)}'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      setState(() => _predictionError = e.toString());
    } finally {
      if (mounted) setState(() => _isPredictingExpiry = false);
    }
  }

  Future<void> _takePhoto() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (xfile == null) return;

    await _processScanImages([xfile], mode: _scanMode);
  }

  Future<void> _pickFromGallery() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );

    if (images.isEmpty) return;

    List<XFile> processedImages = images;
    if (images.length > 4) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n?.addFoodMaxFourImages ?? 'Max 4 images allowed. Selecting first 4.')),
        );
      }
      processedImages = images.sublist(0, 4);
    }

    await _processScanImages(processedImages, mode: _scanMode);
  }

  Future<void> _processScanImages(List<XFile> xfiles,
      {required StorageScanMode mode}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isProcessing = true;
      _activeProcessingScanMode = mode;
    });

    try {
      final futures =
          xfiles.map((file) => _analyzeSingleImage(file, mode)).toList();
      final results = await Future.wait(futures);

      final allItems = results.expand((i) => i).toList();

      if (allItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n?.addFoodNoItemsDetected ?? 'No items detected in images.')));
        }
        return;
      }

      if (!mounted) return;
      await _showScannedItemsPreview(allItems);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n?.addFoodScanFailed(e.toString()) ?? 'Scan failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _activeProcessingScanMode = null;
        });
      }
    }
  }

  Future<List<_ScannedItem>> _analyzeSingleImage(
      XFile xfile, StorageScanMode mode) async {
    final locale = AppLocale.fromContext(context);
    final bytes = await xfile.readAsBytes();
    final base64Str = base64Encode(bytes);
    final uri = Uri.parse('$kBackendBaseUrl/api/scan-inventory');

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': locale,
        'X-App-Locale': locale,
      },
      body: jsonEncode({
        'imageBase64': base64Str,
        'mode': mode == StorageScanMode.receipt ? 'receipt' : 'fridge',
        'locale': locale,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Server error: ${resp.statusCode}');
    }

    final root = jsonDecode(resp.body) as Map<String, dynamic>;
    if (root['items'] is List) {
      return (root['items'] as List)
          .map((e) => _mapJsonToScannedItem(e))
          .toList();
    }
    return [];
  }

  String _normalizeVoiceTranscript(String raw) {
    var text = raw
        .replaceAll(RegExp(r'[，、；;]+'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > 1) {
      text = text[0].toUpperCase() + text.substring(1);
    }
    return text;
  }

  Future<void> _ensureSpeechInitialized() async {
    final l10n = _depsReady ? AppLocalizations.of(context) : null;
    if (_speechReady || _speechInitializing) return;
    _speechInitializing = true;
    try {
      final available = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _voiceHint = l10n?.addFoodVoiceError(e.errorMsg) ?? "Voice error: ${e.errorMsg}";
          });
          _rippleController.stop();
          _rippleController.reset();
        },
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'done' || status == 'notListening') && _isListening) {
            setState(() {
              _isListening = false;
              _voiceHint = l10n?.addFoodVoiceTapToStart ?? "Tap mic to start";
            });
            _rippleController.stop();
            _rippleController.reset();
          }
        },
      );
      if (!mounted) return;
      if (!available) {
        setState(() {
          _speechReady = false;
          _voiceHint = l10n?.addFoodSpeechNotAvailable ?? "Speech not available on this device";
        });
        return;
      }

      final locales = await _speech.locales();
      const preferred = ['en_US', 'en_GB', 'zh_CN', 'zh_TW'];
      String? chosen;
      for (final p in preferred) {
        if (locales.any((l) => l.localeId == p)) {
          chosen = p;
          break;
        }
      }
      chosen ??= locales.isNotEmpty ? locales.first.localeId : null;

      setState(() {
        _speechReady = true;
        _speechLocaleId = chosen;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final notAvailable = e.code == 'recognizerNotAvailable';
      setState(() {
        _speechReady = false;
        _speechLocaleId = null;
        _voiceHint = notAvailable
            ? (l10n?.addFoodSpeechNotSupported ?? 'Speech recognition not supported on this device.')
            : (l10n?.addFoodSpeechInitFailed(e.code) ?? 'Speech init failed: ${e.code}');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _speechLocaleId = null;
        _voiceHint = l10n?.addFoodSpeechInitUnable ?? 'Unable to initialize speech recognition.';
      });
    } finally {
      _speechInitializing = false;
    }
  }

  void _stopListening({bool resetHint = false}) {
    _speech.stop();
    _rippleController.stop();
    _rippleController.reset();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      if (resetHint) {
        final l10n = _depsReady ? AppLocalizations.of(context) : null;
        _voiceHint = l10n?.addFoodVoiceTapToStart ?? "Tap mic to start";
      }
    });
  }

  Future<void> _recognizeWithMiSpeech() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() {
      _isListening = true;
      _voiceHint = l10n?.addFoodOpeningXiaomiSpeech ?? "Opening Xiaomi speech...";
    });
    _rippleController.forward();

    final text = await MiSpeechService.recognizeOnce(
      locale: 'zh_CN',
      prompt: '说出要添加的食材',
    );

    _rippleController.stop();
    _rippleController.reset();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      if (text != null && text.isNotEmpty) {
        final normalized = _normalizeVoiceTranscript(text);
        _voiceController.value = TextEditingValue(
          text: normalized,
          selection: TextSelection.collapsed(offset: normalized.length),
        );
        _voiceHint = l10n?.addFoodVoiceGotIt ?? "Got it! Tap Analyze & Fill.";
      } else {
        _voiceHint = l10n?.addFoodVoiceCanceled ?? "Voice canceled. Tap mic to retry.";
      }
    });
  }

  // NOTE: legacy comment cleaned.
  Future<void> _toggleListening() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    if (!_isListening) {
      if (_isMiDevice && _miSpeechAvailable) {
        await _recognizeWithMiSpeech();
        return;
      }

      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _voiceHint = status.isPermanentlyDenied
              ? (l10n?.addFoodMicBlocked ?? "Mic blocked. Enable in Settings.")
              : (l10n?.addFoodMicDenied ?? "Mic permission denied.");
        });
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }

      await _ensureSpeechInitialized();
      if (!_speechReady) return;

      setState(() {
        _isListening = true;
        _voiceHint = l10n?.addFoodListeningNow ?? "I'm listening...";
      });
      _rippleController.forward();

      _speech.listen(
        localeId: _speechLocaleId,
        onResult: (res) {
          if (!mounted) return;
          final normalized = _normalizeVoiceTranscript(res.recognizedWords);
          setState(() {
            _voiceController.value = TextEditingValue(
              text: normalized,
              selection: TextSelection.collapsed(offset: normalized.length),
            );
            if (res.finalResult) {
              _voiceHint = l10n?.addFoodVoiceGotIt ?? "Got it! Tap Analyze & Fill.";
            }
          });
        },
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 45),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } else {
      _stopListening(resetHint: true);
    }
  }

  // ================== UI Components ==================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bgColor = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.itemToEdit != null
              ? (l10n?.addFoodEditItemTitle ?? 'Edit Item')
              : (l10n?.addFoodAddItemTitle ?? 'Add Item'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                topRightRevealRoute(const _AddItemHelpPage()),
              );
            },
            child: Text(
              l10n?.addFoodHelpButton ?? 'Help',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildPillTabBar(
              isDark: isDark,
              onSurface: colors.onSurface,
              primary: colors.primary,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildManualForm(),
              _buildScanTab(),
              _buildVoiceTab(),
            ],
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPillTabBar({
    required bool isDark,
    required Color onSurface,
    required Color primary,
  }) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n?.addFoodTabManual ?? 'Manual',
      l10n?.addFoodTabScan ?? 'Scan',
      l10n?.addFoodTabVoice ?? 'Voice',
    ];
    final bgColor = isDark ? const Color(0xFF20323A) : const Color(0xFFE5E7EB);
    final animation = _tabController.animation;

    return AnimatedBuilder(
      animation: animation ?? _tabController,
      builder: (context, _) {
        final t = animation?.value ?? _tabController.index.toDouble();
        return Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / labels.length;
              return Stack(
                children: [
                  Positioned(
                    left: segmentWidth * t,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (index) {
                      final selectedness =
                          (1 - (t - index).abs()).clamp(0.0, 1.0);
                      final textColor = Color.lerp(
                        onSurface.withValues(alpha: 0.56),
                        Colors.white,
                        selectedness,
                      )!;
                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _tabController.animateTo(
                            index,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                          child: Center(
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: selectedness > 0.5
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // --- Manual Tab ---
  Widget _buildManualForm() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      controller: _manualScrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormCard(
              title: l10n?.addFoodBasicInfoTitle ?? 'Basic Info',
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration:
                      _inputDecoration(context, l10n?.addFoodNameLabel ?? 'Name', Icons.edit_outlined),
                  onChanged: (v) {
                    setState(() {
                      _name = v;
                      _resetPrediction();
                    });
                  },
                  onSaved: (v) => _name = v ?? '',
                  validator: (v) => v!.isEmpty ? (l10n?.addFoodRequired ?? 'Required') : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: _qty.toString(),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                            context, l10n?.addFoodQuantityLabel ?? 'Quantity', Icons.numbers),
                        onSaved: (v) => _qty = double.tryParse(v ?? '1') ?? 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        borderRadius: BorderRadius.circular(24),
                        elevation: 12,
                        menuMaxHeight: 360,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        items: [
                          'pcs',
                          'kg',
                          'g',
                          'L',
                          'ml',
                          'pack',
                          'box',
                          'cup'
                        ]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                        decoration: _inputDecoration(context, l10n?.addFoodUnitLabel ?? 'Unit', null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _minQty?.toString() ?? '',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(
                          context,
                          l10n?.addFoodMinStockWarningLabel ?? 'Min Stock Warning (Optional)',
                          Icons.notifications_active_outlined)
                      .copyWith(
                    hintText: l10n?.addFoodMinStockHint ?? 'e.g. 2 (Notify when below)',
                    helperText: l10n?.addFoodMinStockHelper ?? 'Leave empty for no warnings',
                  ),
                  onSaved: (v) {
                    if (v == null || v.trim().isEmpty) {
                      _minQty = null;
                    } else {
                      _minQty = double.tryParse(v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFormCard(
              title: l10n?.addFoodStorageLocationTitle ?? 'Storage Location',
              children: [
                _buildStorageSelector(),
              ],
            ),
            const SizedBox(height: 20),
            _buildFormCard(
              title: l10n?.addFoodCategoriesTitle ?? 'Categories',
              children: [
                _buildCategoryChips(),
              ],
            ),
            const SizedBox(height: 20),
            _buildFormCard(
              title: l10n?.addFoodDatesTitle ?? 'Dates',
              children: [
                _buildDateRow(
                    l10n?.addFoodPurchaseDate ?? 'Purchase Date', _purchased, Icons.shopping_bag_rounded,
                    (d) {
                  setState(() {
                    _purchased = d!;
                    _resetPrediction();
                  });
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow(l10n?.addFoodOpenDate ?? 'Open Date', _openDate, Icons.lock_open_rounded,
                    (d) {
                  setState(() {
                    _openDate = d;
                    _resetPrediction();
                  });
                }, canClear: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow(
                    l10n?.addFoodBestBefore ?? 'Best Before', _bestBefore, Icons.event_busy_rounded, (d) {
                  setState(() {
                    _bestBefore = d;
                    _resetPrediction();
                  });
                }, canClear: true),
              ],
            ),
            const SizedBox(height: 20),
            _buildExpiryAiCard(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(l10n?.addFoodSaveToInventory ?? 'Save to Inventory',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _isValidCategoryKey(String key) {
    if (key == _autoCategoryKey) return true;
    for (final option in _categoryOptions) {
      if (option.key == key) return true;
    }
    return false;
  }

  String _normalizeCategoryKey(String key) {
    final value = key.trim().toLowerCase();
    switch (value) {
      case _autoCategoryKey:
        return _autoCategoryKey;
      case 'drink':
      case 'drinks':
      case 'beverages':
      case 'beverage':
      case 'bev':
        return 'beverage';
      case 'snack':
      case 'snacks':
        return 'snacks';
      case 'vegetable':
      case 'vegetables':
      case 'veggie':
      case 'veggies':
      case 'greens':
      case 'produce':
        return 'produce';
      case 'dairy':
      case 'milk':
      case 'cheese':
        return 'dairy';
      case 'protein':
      case 'meat':
      case 'poultry':
        return 'meat';
      case 'fish':
      case 'seafood':
        return 'seafood';
      case 'bread':
      case 'bakery':
      case 'baked':
        return 'bakery';
      case 'frozen':
      case 'freezer':
        return 'frozen';
      case 'pantry':
      case 'staple':
      case 'staples':
      case 'condiment':
      case 'condiments':
        return 'pantry';
      case 'household':
      case 'cleaning':
        return 'household';
      case 'pet':
      case 'pets':
        return 'pet';
      default:
        return value;
    }
  }

  // --- Scan Tab ---
  Widget _buildScanTab() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                _buildScanModeOption(StorageScanMode.receipt,
                    l10n?.addFoodScanReceipt ?? 'Scan Receipt',
                    Icons.receipt_long_rounded),
                _buildScanModeOption(StorageScanMode.fridge,
                    l10n?.addFoodSnapFridge ?? 'Snap Fridge',
                    Icons.kitchen_rounded),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildBigActionButton(
            icon: Icons.camera_alt_rounded,
            label: l10n?.addFoodTakePhoto ?? 'Take Photo',
            subtitle: l10n?.addFoodUseCameraToScan ?? 'Use camera to scan',
            color: _primaryColor,
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),
          _buildBigActionButton(
            icon: Icons.photo_library_rounded,
            label: l10n?.addFoodUploadMax4 ?? 'Upload (Max 4)',
            subtitle:
                l10n?.addFoodChooseMultipleFromGallery ??
                    'Choose multiple from gallery',
            color: colors.onSurface.withValues(alpha: 0.8),
            isOutlined: true,
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 40),
          Text(
            _scanMode == StorageScanMode.receipt
                ? (l10n?.addFoodAiExtractReceiptItems ??
                    'AI will extract items from your receipt(s).')
                : (l10n?.addFoodAiIdentifyFridgeItems ??
                    'AI will identify items in your fridge or pantry.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- Voice Tab ---
  Widget _buildVoiceTab() {
    final l10n = AppLocalizations.of(context);
    final hasText = _voiceController.text.trim().length > 2;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localeLabel = _speechLocaleId == null
        ? (l10n?.addFoodAutoLabel ?? 'Auto')
        : _speechLocaleId!;
    final speechModeLabel = (_isMiDevice && _miSpeechAvailable)
        ? (l10n?.addFoodXiaomiSpeechMode ?? 'Xiaomi speech mode')
        : (_speechReady
            ? (l10n?.addFoodEngineReady(localeLabel) ??
                'Engine ready - $localeLabel')
            : (l10n?.addFoodPreparingEngine ?? 'Preparing speech engine...'));

    return SingleChildScrollView(
      controller: _voiceScrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          GestureDetector(
            onTap: _toggleListening,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100 * _rippleAnimation.value,
                        height: 100 * _rippleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryColor.withValues(
                              alpha: 0.2 - (_rippleAnimation.value - 1.0) / 2),
                        ),
                      );
                    },
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isListening ? _primaryColor : theme.cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _isListening
                              ? _primaryColor.withValues(alpha: 0.4)
                              : colors.onSurface.withValues(alpha: 0.2),
                          blurRadius: _isListening ? 20 : 10,
                          spreadRadius: _isListening ? 5 : 2,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    size: 48,
                    color: _isListening ? Colors.white : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _voiceHint,
              key: ValueKey(_voiceHint),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? _primaryColor
                      : colors.onSurface.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            speechModeLabel,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.52),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (!_isListening && !hasText)
            Text(
              l10n?.addFoodVoiceTrySaying ??
                  'Try saying: "3 apples, milk, and 1kg of rice"',
              style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.5), fontSize: 13),
            ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasText
                    ? _primaryColor.withValues(alpha: 0.5)
                    : theme.dividerColor,
              ),
            ),
            child: TextField(
              controller: _voiceController,
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: colors.onSurface),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText:
                    l10n?.addFoodTranscriptHint ??
                        'Transcript will appear here...',
                hintStyle:
                    TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _voiceController.text.trim().isEmpty
                    ? null
                    : () {
                        _voiceController.clear();
                        setState(() {
                          _voiceHint = l10n?.addFoodVoiceTapToStart ??
                              'Tap mic to start';
                        });
                      },
                icon: const Icon(Icons.backspace_outlined, size: 16),
                label: Text(l10n?.addFoodClear ?? 'Clear'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: hasText ? 1.0 : 0.0,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: (hasText && !_isProcessing)
                    ? () => _processVoiceInputWithAi(_voiceController.text)
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_isProcessing
                    ? (l10n?.addFoodAnalyzing ?? 'Analyzing...')
                    : (l10n?.addFoodAnalyzeAndFill ?? 'Analyze & Fill')),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== Helper Widgets ==================

  Widget _buildFormCard(
      {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18282F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      BuildContext context, String label, IconData? icon) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.6), fontSize: 12),
      hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.6))
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF20323A) : const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide:
            BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildDateRow(String label, DateTime? date, IconData icon,
      ValueChanged<DateTime?> onChanged,
      {bool canClear = false}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasDate = date != null;
    return InkWell(
      onTap: () => _pickDate(
        initial: date ?? DateTime.now(),
        first: DateTime.now().subtract(const Duration(days: 365 * 5)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        onPicked: onChanged,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF20323A)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasDate
                        ? colors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hasDate ? _formatDate(date) : (l10n?.addFoodDateNotSet ?? 'Not set'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasDate
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.5),
                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (canClear && hasDate)
                  InkWell(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close_rounded,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.6)),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF20323A) : const Color(0xFFF1F5F9);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildStorageOption(
            location: StorageLocation.fridge,
            icon: Icons.kitchen_rounded,
            label: 'Fridge',
            selected: _location == StorageLocation.fridge,
          ),
          _buildStorageOption(
            location: StorageLocation.freezer,
            icon: Icons.ac_unit_rounded,
            label: 'Freezer',
            selected: _location == StorageLocation.freezer,
          ),
          _buildStorageOption(
            location: StorageLocation.pantry,
            icon: Icons.shelves,
            label: 'Pantry',
            selected: _location == StorageLocation.pantry,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageOption({
    required StorageLocation location,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = isDark ? colors.primary : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _location = location),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary
                          .withValues(alpha: isDark ? 0.35 : 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? (isDark ? Colors.white : colors.primary)
                    : colors.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: selected
                      ? (isDark ? Colors.white : colors.primary)
                      : colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chips = <_CategoryOption>[
      const _CategoryOption(_autoCategoryKey, 'Auto',
          Icons.auto_awesome_rounded, Color(0xFF7E57C2)),
      ..._categoryOptions,
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final option = chips[index];
          final selected = _categoryKey == option.key;
          return _buildCategoryChip(
            option: option,
            selected: selected,
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required _CategoryOption option,
    required bool selected,
    required bool isDark,
  }) {
    final colors = Theme.of(context).colorScheme;
    final base = option.color;
    final frostedTop =
        isDark ? const Color(0xFF2A3038) : const Color(0xFFFFFFFF);
    final frostedBottom =
        isDark ? const Color(0xFF1E242C) : const Color(0xFFF1F4F8);
    final ringColor = selected
        ? base.withValues(alpha: isDark ? 0.42 : 0.5)
        : colors.outline.withValues(alpha: isDark ? 0.2 : 0.16);
    return GestureDetector(
      onTap: () => setState(() => _categoryKey = option.key),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [
                        Color.alphaBlend(
                            base.withValues(alpha: isDark ? 0.24 : 0.18),
                            frostedTop),
                        Color.alphaBlend(
                            base.withValues(alpha: isDark ? 0.12 : 0.08),
                            frostedBottom),
                      ]
                    : [frostedTop, frostedBottom],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: ringColor,
                width: selected ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: selected ? 14 : 10,
                  offset: const Offset(0, 6),
                ),
                if (!isDark)
                  const BoxShadow(
                    color: Color(0x66FFFFFF),
                    blurRadius: 8,
                    offset: Offset(-2, -2),
                  ),
              ],
            ),
            child: Icon(option.icon,
                color:
                    selected ? base.withValues(alpha: 0.95) : colors.onSurface.withValues(alpha: 0.52),
                size: 26),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryAiCard() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canPredict = _name.trim().isNotEmpty && !_isPredictingExpiry;
    final primary = colors.primary;
    final accent = const Color(0xFF7E57C2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E1B4B), Color(0xFF172554)]
              : [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [accent, primary]),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.addFoodAiExpiryPrediction ?? 'AI Expiry Prediction',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        fontSize: 13),
                  ),
                  Text(
                    l10n?.addFoodAutoMagic ?? 'Auto magic',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isPredictingExpiry)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(l10n?.addFoodThinking ?? 'Thinking...',
                    style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6))),
              ]),
            )
          else if (_predictedExpiryFromAi != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.addFoodPredictedExpiry ?? 'Predicted Expiry',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_predictedExpiryFromAi),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                        ),
                        if (_bestBefore != null &&
                            _bestBefore != _predictedExpiryFromAi)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l10n?.addFoodManualDateOverride ??
                                  'Manual date will override this',
                              style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.6)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n?.addFoodAutoApplied ?? 'Auto applied',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _expiry = null;
                        _predictedExpiryFromAi = null;
                      });
                    },
                    icon: Icon(Icons.undo_rounded,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.addFoodAiSuggestHint ??
                      'Let AI suggest based on food type and storage.',
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                if (_predictionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        '${l10n?.addFoodErrorPrefix ?? 'Error:'} $_predictionError',
                        style:
                            const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: canPredict ? _predictExpiryWithAi : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                      l10n?.addFoodAutoMagicPrediction ??
                          'Auto Magic Prediction'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScanModeOption(
      StorageScanMode mode, String label, IconData icon) {
    final isSelected = _scanMode == mode;
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scanMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? Colors.white
                      : colors.onSurface.withValues(alpha: 0.6)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : colors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isOutlined ? theme.cardColor : color,
          borderRadius: BorderRadius.circular(20),
          border: isOutlined ? Border.all(color: theme.dividerColor) : null,
          boxShadow: isOutlined
              ? []
              : [
                  BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutlined
                    ? colors.onSurface.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isOutlined ? color : Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? colors.onSurface : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isOutlined
                        ? colors.onSurface.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    final l10n = AppLocalizations.of(context);
    final isReceipt = _activeProcessingScanMode == StorageScanMode.receipt;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                isReceipt
                    ? (l10n?.addFoodScanningReceipts ??
                        'Scanning Receipts...')
                    : (l10n?.addFoodAnalyzing ?? 'Analyzing...'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.addFoodProcessing ?? 'Processing',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showScannedItemsPreview(List<_ScannedItem> items) async {
    final l10n = AppLocalizations.of(context);
    final selected = List<bool>.filled(items.length, true);

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            final count = selected.where((v) => v).length;
            final bgColor = Theme.of(ctx).cardColor;
            final colors = Theme.of(ctx).colorScheme;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.8,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          l10n?.addFoodItemsTitle ?? 'Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: colors.onSurface),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final isSel = selected[i];
                        return InkWell(
                          onTap: () =>
                              setStateSheet(() => selected[i] = !isSel),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSel
                                      ? _primaryColor
                                      : Theme.of(ctx).dividerColor,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSel,
                                  onChanged: (v) =>
                                      setStateSheet(() => selected[i] = v!),
                                  activeColor: _primaryColor,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.onSurface
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_locationIcon(it.location),
                                      color: _primaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurface),
                                      ),
                                      Text(
                                        '${_formatQty(it.quantity)} ${it.unit} - ${_locationLabel(it.location)}',
                                        style: TextStyle(
                                            color: colors.onSurface
                                                .withValues(alpha: 0.6),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () async {
                                    final updated =
                                        await _showEditScannedItemDialog(it);
                                    if (updated != null) {
                                      setStateSheet(() => items[i] = updated);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed:
                            count == 0 ? null : () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                            l10n?.addFoodAddCountItems(count) ??
                                'Add $count Items',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    for (int i = 0; i < items.length; i++) {
      if (!selected[i]) {
        continue;
      }
      final s = items[i];
      DateTime expiry =
          s.predictedExpiry ?? s.purchaseDate.add(const Duration(days: 7));
      final resolvedCategory = widget.repo
              .inferCategoryForName(s.name, existingCategory: s.category) ??
          s.category;

      final foodItem = FoodItem(
        id: const Uuid().v4(),
        name: s.name,
        location: s.location,
        quantity: s.quantity,
        unit: s.unit,
        purchasedDate: s.purchaseDate,
        predictedExpiry: expiry,
        category: resolvedCategory,
      );
      await widget.repo.addItem(foodItem);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l10n?.addFoodAddedItems(selected.where((v) => v).length) ??
                  'Added ${selected.where((v) => v).length} items'),
        ),
      );
    }
  }

  Future<_ScannedItem?> _showEditScannedItemDialog(_ScannedItem item) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    var selectedLocation = item.location;

    return showDialog<_ScannedItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(l10n?.addFoodEditItemTitle ?? 'Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: l10n?.addFoodNameLabel ?? 'Name'),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: InputDecoration(
                    labelText: l10n?.addFoodQuantityLabel ?? 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StorageLocation>(
                initialValue: selectedLocation,
                decoration: InputDecoration(
                  labelText: l10n?.addFoodStorageLocationTitle ??
                      'Storage Location',
                  filled: true,
                  fillColor: Theme.of(ctx)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(ctx).dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                      width: 1.4,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(24),
                elevation: 12,
                menuMaxHeight: 360,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                dropdownColor: Theme.of(ctx).cardColor,
                selectedItemBuilder: (context) => [
                  Row(
                    children: [
                      const Icon(Icons.kitchen_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n?.foodLocationFridge ?? 'Fridge',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.ac_unit_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n?.foodLocationFreezer ?? 'Freezer',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shelves, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n?.foodLocationPantry ?? 'Pantry',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                items: [
                  DropdownMenuItem(
                    value: StorageLocation.fridge,
                    child: Row(
                      children: [
                        const Icon(Icons.kitchen_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n?.foodLocationFridge ?? 'Fridge',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: StorageLocation.freezer,
                    child: Row(
                      children: [
                        const Icon(Icons.ac_unit_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n?.foodLocationFreezer ?? 'Freezer',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: StorageLocation.pantry,
                    child: Row(
                      children: [
                        const Icon(Icons.shelves, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n?.foodLocationPantry ?? 'Pantry',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setStateDialog(() => selectedLocation = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n?.cancel ?? 'Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                    ctx,
                    _ScannedItem(
                      name: nameCtrl.text,
                      quantity: double.tryParse(qtyCtrl.text) ?? 1,
                      unit: item.unit,
                      location: selectedLocation,
                      category: item.category,
                      purchaseDate: item.purchaseDate,
                      confidence: item.confidence,
                      predictedExpiry: item.predictedExpiry,
                    ));
              },
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemHelpPage extends StatelessWidget {
  const _AddItemHelpPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.addFoodHelpTitle ?? 'Add Item Help'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HelpCard(
            title: l10n?.addFoodHelpManualTitle ?? 'Manual',
            points: [
              l10n?.addFoodHelpManualPoint1 ??
                  'Enter name, quantity, and storage location.',
              l10n?.addFoodHelpManualPoint2 ??
                  'Set Best Before if you know the package date.',
              l10n?.addFoodHelpManualPoint3 ??
                  'Use note for size/brand reminders.',
            ],
          ),
          const SizedBox(height: 12),
          _HelpCard(
            title: l10n?.addFoodHelpScanTitle ?? 'Scan',
            points: [
              l10n?.addFoodHelpScanPoint1 ??
                  'Use clear photos with good lighting.',
              l10n?.addFoodHelpScanPoint2 ??
                  'For receipts, keep text fully visible.',
              l10n?.addFoodHelpScanPoint3 ??
                  'Review detected items before saving.',
            ],
          ),
          const SizedBox(height: 12),
          _HelpCard(
            title: l10n?.addFoodHelpVoiceTitle ?? 'Voice',
            points: [
              l10n?.addFoodHelpVoicePoint1 ??
                  'Say item + quantity + unit, e.g. "Milk two liters".',
              l10n?.addFoodHelpVoicePoint2 ??
                  'Pause briefly between multiple items.',
              l10n?.addFoodHelpVoicePoint3 ??
                  'Edit fields before saving if needed.',
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              l10n?.addFoodHelpTip ??
                  'Tip: If expiry is unknown, use AI prediction and adjust manually if needed.',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final List<String> points;

  const _HelpCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannedItem {
  final String name;
  final double quantity;
  final String unit;
  final StorageLocation location;
  final String category;
  final DateTime purchaseDate;
  final double confidence;
  final DateTime? predictedExpiry;

  _ScannedItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.category,
    required this.purchaseDate,
    required this.confidence,
    required this.predictedExpiry,
  });
}

class _CategoryOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryOption(this.key, this.label, this.icon, this.color);
}
