// lib/screens/add_food_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_guard.dart';
import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';

const String kBackendBaseUrl = 'https://project-study-bsh.vercel.app';

/// 扫描模式：小票 or 冰箱/货架
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 表单字段
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _qty;
  late String _unit;
  late StorageLocation _location;

  // 日期字段
  late DateTime _purchased;
  DateTime? _openDate;
  DateTime? _bestBefore;
  DateTime? _expiry;

  // AI 状态
  bool _isPredictingExpiry = false;
  DateTime? _predictedExpiryFromAi;
  String? _predictionError;

  // 相机 / 语音
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isProcessing = false;
  bool _isListening = false;
  String _voiceHint = "Tap the mic to start.";
  final TextEditingController _voiceController = TextEditingController();

  // 扫描模式
  StorageScanMode _scanMode = StorageScanMode.receipt;
  StorageScanMode? _activeProcessingScanMode;

  // 统一背景色
  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _primaryColor = Color(0xFF005F87);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.itemToEdit != null ? 0 : widget.initialTab,
    );

    final item = widget.itemToEdit;
    _name = item?.name ?? '';
    _qty = item?.quantity ?? 1.0;
    _unit = item?.unit ?? 'pcs';
    _location = item?.location ?? StorageLocation.fridge;

    const allowedUnits = [
      'pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'cup',
    ];
    if (!allowedUnits.contains(_unit)) {
      _unit = 'pcs';
    } else if (_unit == 'cups') {
      _unit = 'cup';
    }

    _purchased = item?.purchasedDate ?? DateTime.now();
    _openDate = item?.openDate;
    _bestBefore = item?.bestBeforeDate;
    _expiry = item?.predictedExpiry ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _voiceController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ========= Logic Helpers (Kept Original) =========

  String _formatQty(double q) {
    final isInt = (q - q.round()).abs() < 1e-9;
    return isInt ? q.round().toString() : q.toStringAsFixed(1);
  }

  String _locationLabel(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.freezer: return 'Freezer';
      case StorageLocation.pantry: return 'Pantry';
      case StorageLocation.fridge:
      default: return 'Fridge';
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  void _resetPrediction() {
    _predictedExpiryFromAi = null;
    _predictionError = null;
  }

  IconData _locationIcon(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.freezer: return Icons.ac_unit_rounded;
      case StorageLocation.pantry: return Icons.shelves; // Material Symbols style
      case StorageLocation.fridge:
      default: return Icons.kitchen_rounded;
    }
  }

  // ========= Actions (Logic Kept Original) =========

  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final DateTime? effectiveExpiry = _bestBefore ?? _expiry;

    final newItem = FoodItem(
      id: widget.itemToEdit?.id ?? const Uuid().v4(),
      name: _name,
      location: _location,
      quantity: _qty,
      unit: _unit,
      purchasedDate: _purchased,
      openDate: _openDate,
      bestBeforeDate: _bestBefore,
      predictedExpiry: effectiveExpiry,
      category: 'manual',
    );

    if (widget.itemToEdit != null) {
      await widget.repo.updateItem(newItem);
    } else {
      await widget.repo.addItem(newItem);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _runIngredientAi(String text, {required String source}) async {
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text too short, please provide more info.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/parse-ingredient');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': trimmed}),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final name = (json['name'] ?? '').toString();
      final unit = (json['unit'] ?? 'pcs').toString();
      final storageLocation = (json['storageLocation'] ?? 'fridge').toString();

      double quantity = 1.0;
      final qRaw = json['quantity'];
      if (qRaw is num) quantity = qRaw.toDouble();

      setState(() {
        if (name.isNotEmpty) _name = name;
        _qty = quantity;
        _unit = unit;

        switch (storageLocation) {
          case 'freezer': _location = StorageLocation.freezer; break;
          case 'pantry': _location = StorageLocation.pantry; break;
          default: _location = StorageLocation.fridge;
        }

        _resetPrediction();
        _tabController.animateTo(0);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == 'voice'
              ? 'Form filled by AI from voice.'
              : 'Form filled by AI from text.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI parse failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyVoiceWithAi() async {
    await _runIngredientAi(_voiceController.text, source: 'voice');
  }

  Future<void> _predictExpiryWithAi() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the food name first')),
      );
      return;
    }

    setState(() {
      _isPredictingExpiry = true;
      _predictionError = null;
    });

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/recipe');
      final body = <String, dynamic>{
        'name': _name.trim(),
        'location': _location.name,
        'purchasedDate': _purchased.toIso8601String(),
        if (_openDate != null) 'openDate': _openDate!.toIso8601String(),
        if (_bestBefore != null) 'bestBeforeDate': _bestBefore!.toIso8601String(),
      };

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final iso = data['predictedExpiry'] as String?;
      if (iso == null) throw Exception('No predictedExpiry');

      setState(() {
        _predictedExpiryFromAi = DateTime.parse(iso);
        _predictionError = null;
      });
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

    await _scanImageWithAi(xfile, mode: _scanMode);
  }

  Future<void> _pickFromGallery() async {
    final ok = await requireLogin(context);
    if (!ok) return;

    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (xfile == null) return;

    await _scanImageWithAi(xfile, mode: _scanMode);
  }

  Future<void> _scanImageWithAi(XFile xfile, {required StorageScanMode mode}) async {
    final ok = await requireLogin(context);
    if (!ok) return;

    setState(() {
      _isProcessing = true;
      _activeProcessingScanMode = mode;
    });

    try {
      final bytes = await xfile.readAsBytes();
      final base64Str = base64Encode(bytes);
      final uri = Uri.parse('$kBackendBaseUrl/api/scan-inventory');

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageBase64': base64Str,
          'mode': mode == StorageScanMode.receipt ? 'receipt' : 'fridge',
        }),
      );

      if (resp.statusCode != 200) throw Exception('Server error: ${resp.statusCode}');

      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      DateTime purchaseDate = DateTime.now();
      if (root['purchaseDate'] is String) {
        try {
          purchaseDate = DateTime.parse('${root['purchaseDate'].trim()}T00:00:00.000Z');
        } catch (_) {}
      }

      final itemsJson = root['items'] as List<dynamic>? ?? const [];
      if (itemsJson.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items detected.')));
        return;
      }

      final max = purchaseDate.add(const Duration(days: 365));
      final scannedItems = itemsJson.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final name = (m['name'] ?? '').toString().trim();
        double qty = 1;
        if (m['quantity'] is num) qty = (m['quantity'] as num).toDouble();
        
        StorageLocation loc = StorageLocation.fridge;
        if (m['storageLocation'] == 'freezer') loc = StorageLocation.freezer;
        if (m['storageLocation'] == 'pantry') loc = StorageLocation.pantry;

        DateTime? predictedExpiry;
        if (m['predictedExpiry'] is String) {
          try {
            predictedExpiry = DateTime.parse(m['predictedExpiry']);
          } catch (_) {}
        }

        if (predictedExpiry != null) {
          if (predictedExpiry.isBefore(purchaseDate)) predictedExpiry = purchaseDate;
          else if (predictedExpiry.isAfter(max)) predictedExpiry = max;
        }

        return _ScannedItem(
          name: name.isEmpty ? 'Unknown' : name,
          quantity: qty,
          unit: (m['unit'] ?? 'pcs').toString(),
          location: loc,
          category: (m['category'] ?? 'scan').toString(),
          purchaseDate: purchaseDate,
          confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
          predictedExpiry: predictedExpiry,
        );
      }).toList();

      if (!mounted) return;
      await _showScannedItemsPreview(scannedItems);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _activeProcessingScanMode = null;
        });
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isProcessing) return;

    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      final available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _voiceHint = "Listening...";
        });
        _speech.listen(onResult: (res) {
          setState(() => _voiceController.text = res.recognizedWords);
        });
      }
    } else {
      setState(() {
        _isListening = false;
        _voiceHint = "Tap mic to start.";
      });
      _speech.stop();
    }
  }

  // ================== UI Components ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.itemToEdit != null ? 'Edit Item' : 'Add Item',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent, // 去掉 Material 3 的默认分割线，更干净
          tabs: const [
            Tab(text: 'Manual'),
            Tab(text: 'Scan'),
            Tab(text: 'Voice'),
          ],
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

  // --- Manual Tab ---

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormCard(
              title: 'Basic Info',
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: _inputDecoration('Name', Icons.edit_outlined),
                  onChanged: (v) => setState(() {
                    _name = v;
                    _resetPrediction();
                  }),
                  onSaved: (v) => _name = v ?? '',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: _qty.toString(),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Quantity', Icons.numbers),
                        onSaved: (v) => _qty = double.tryParse(v ?? '1') ?? 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        items: ['pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'cup']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                        decoration: _inputDecoration('Unit', null),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildFormCard(
              title: 'Storage',
              children: [
                SegmentedButton<StorageLocation>(
                  segments: const [
                    ButtonSegment(
                        value: StorageLocation.fridge,
                        // 强制单行显示，超出显示省略号
                        label: Text('Fridge', maxLines: 1, overflow: TextOverflow.ellipsis),
                        icon: Icon(Icons.kitchen_outlined)),
                    ButtonSegment(
                        value: StorageLocation.freezer,
                        // 强制单行显示，超出显示省略号
                        label: Text('Freezer', maxLines: 1, overflow: TextOverflow.ellipsis),
                        icon: Icon(Icons.ac_unit_rounded)),
                    ButtonSegment(
                        value: StorageLocation.pantry,
                        // 强制单行显示，超出显示省略号
                        label: Text('Pantry', maxLines: 1, overflow: TextOverflow.ellipsis),
                        icon: Icon(Icons.shelves)),
                  ],
                  selected: {_location},
                  onSelectionChanged: (s) {
                    setState(() {
                      _location = s.first;
                      _resetPrediction();
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: MaterialStateProperty.all(BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildFormCard(
              title: 'Dates',
              children: [
                _buildDateRow('Purchased', _purchased, (d) => setState(() => _purchased = d!)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow('Opened', _openDate, (d) => setState(() => _openDate = d), canClear: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow('Best Before', _bestBefore, (d) => setState(() => _bestBefore = d), canClear: true),
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
                label: const Text('Save to Inventory', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Scan Tab ---

  Widget _buildScanTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mode Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildScanModeOption(
                  StorageScanMode.receipt,
                  'Scan Receipt',
                  Icons.receipt_long_rounded,
                ),
                _buildScanModeOption(
                  StorageScanMode.fridge,
                  'Snap Fridge',
                  Icons.kitchen_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Main Action
          _buildBigActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Take Photo',
            subtitle: 'Use camera to scan',
            color: _primaryColor,
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),
          _buildBigActionButton(
            icon: Icons.photo_library_rounded,
            label: 'Upload',
            subtitle: 'Choose from gallery',
            color: Colors.grey.shade800,
            isOutlined: true,
            onTap: _pickFromGallery,
          ),
          
          const SizedBox(height: 40),
          Text(
            _scanMode == StorageScanMode.receipt 
              ? 'AI will extract items from your receipt.'
              : 'AI will identify items in your fridge or pantry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --- Voice Tab ---

  Widget _buildVoiceTab() {
    final canSend = _voiceController.text.trim().length > 2 && !_isProcessing;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isListening ? Colors.red.withOpacity(0.1) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening ? Colors.red : Colors.grey.shade300,
                  width: _isListening ? 4 : 2,
                ),
                boxShadow: [
                  if (_isListening)
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 40,
                color: _isListening ? Colors.red : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _voiceHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 40),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _voiceController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: 'e.g. "I bought 500g chicken breast and put it in the freezer"',
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: canSend ? _applyVoiceWithAi : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Auto-Fill Form'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== Helper Widgets ==================

  Widget _buildFormCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade600) : null,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDateRow(String label, DateTime? date, ValueChanged<DateTime?> onChanged, {bool canClear = false}) {
    return InkWell(
      onTap: () => _pickDate(
        initial: date ?? DateTime.now(),
        first: DateTime.now().subtract(const Duration(days: 365 * 5)),
        last: DateTime.now().add(const Duration(days: 365 * 5)),
        onPicked: onChanged,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
            Row(
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: date == null ? Colors.grey : _primaryColor,
                    fontWeight: date == null ? FontWeight.normal : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (canClear && date != null)
                  InkWell(
                    onTap: () => onChanged(null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                  )
                else
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryAiCard() {
    final canPredict = _name.trim().isNotEmpty && !_isPredictingExpiry;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.purple.shade400),
              const SizedBox(width: 8),
              const Text('AI Expiry Prediction', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          
          if (_isPredictingExpiry)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Thinking...', style: TextStyle(color: Colors.grey)),
              ]),
            )
          else if (_predictedExpiryFromAi != null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_predictedExpiryFromAi),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                      ),
                      if (_bestBefore != null)
                        const Text('Manual date will override this', style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() => _expiry = _predictedExpiryFromAi);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date applied!')));
                  },
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Apply'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let AI suggest based on food type and storage.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (_predictionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Error: $_predictionError', style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: canPredict ? _predictExpiryWithAi : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.6),
                    side: BorderSide(color: Colors.purple.withOpacity(0.2)),
                  ),
                  child: const Text('Predict Expiry'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScanModeOption(StorageScanMode mode, String label, IconData icon) {
    final isSelected = _scanMode == mode;
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
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(20),
          border: isOutlined ? Border.all(color: Colors.grey.shade300) : null,
          boxShadow: isOutlined ? [] : [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutlined ? Colors.grey.shade100 : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isOutlined ? color : Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isOutlined ? Colors.grey : Colors.white.withOpacity(0.8),
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

  // Preview & Overlay Widgets (Kept largely the same but styled)
  Widget _buildProcessingOverlay() {
    final isReceipt = _activeProcessingScanMode == StorageScanMode.receipt;
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50, height: 50,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                isReceipt ? 'Scanning Receipt...' : 'Analyzing...',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is identifying items and expiry dates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Scan Preview List Logic (Kept, just ensured styling matches)
  Future<void> _showScannedItemsPreview(List<_ScannedItem> items) async {
    final selected = List<bool>.filled(items.length, true);

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            final count = selected.where((v) => v).length;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.8,
              decoration: const BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Text('Scanned Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
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
                          onTap: () => setStateSheet(() => selected[i] = !isSel),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel ? _primaryColor : Colors.transparent,
                                width: 2
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSel,
                                  onChanged: (v) => setStateSheet(() => selected[i] = v!),
                                  activeColor: _primaryColor,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_locationIcon(it.location), color: _primaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        '${_formatQty(it.quantity)} ${it.unit} • ${_locationLabel(it.location)}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () async {
                                    final updated = await _showEditScannedItemDialog(it);
                                    if (updated != null) setStateSheet(() => items[i] = updated);
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
                        onPressed: count == 0 ? null : () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Add $count Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

    // Save Logic (Copied from original)
    for (int i = 0; i < items.length; i++) {
      if (!selected[i]) continue;
      final s = items[i];
      DateTime expiry = s.predictedExpiry ?? s.purchaseDate.add(const Duration(days: 7)); // Simple fallback
      
      final foodItem = FoodItem(
        id: const Uuid().v4(),
        name: s.name,
        location: s.location,
        quantity: s.quantity,
        unit: s.unit,
        purchasedDate: s.purchaseDate,
        predictedExpiry: expiry,
        category: s.category,
      );
      await widget.repo.addItem(foodItem);
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${selected.where((v) => v).length} items ✅')));
  }

  Future<_ScannedItem?> _showEditScannedItemDialog(_ScannedItem item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    
    return showDialog<_ScannedItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, _ScannedItem(
                name: nameCtrl.text,
                quantity: double.tryParse(qtyCtrl.text) ?? 1,
                unit: item.unit,
                location: item.location,
                category: item.category,
                purchaseDate: item.purchaseDate,
                confidence: item.confidence,
                predictedExpiry: item.predictedExpiry,
              ));
            },
            child: const Text('Save'),
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