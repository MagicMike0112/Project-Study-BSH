// lib/screens/add_food_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';

const String kBackendBaseUrl = 'https://project-study-bsh.vercel.app';

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
  DateTime? _expiry; // 预测过期（供 Expiring Soon 使用）

  // AI 预测保质期
  DateTime? _aiSuggestedExpiry;
  String? _aiReason;

  // 相机 / 语音
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isProcessing = false; // 所有 AI 调用共用
  bool _isListening = false;
  String _voiceHint = "Tap mic to start, tap again to stop.";
  final TextEditingController _voiceController = TextEditingController();

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

    _purchased = item?.purchasedDate ?? DateTime.now();
    _openDate = item?.openDate;
    _bestBefore = item?.bestBeforeDate;
    _expiry =
        item?.predictedExpiry ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _voiceController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ========= 小工具 =========

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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
    );
    if (picked != null) onPicked(picked);
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        _formatDate(value),
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null && value != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
              tooltip: 'Clear',
            ),
          const Icon(Icons.calendar_today_outlined),
        ],
      ),
      onTap: onTap,
    );
  }

  bool get _canPredictExpiry {
    return _name.trim().isNotEmpty && !_isProcessing;
  }

  void _clearAiExpiry() {
    _aiSuggestedExpiry = null;
    _aiReason = null;
  }

  // ========= 保存 =========

  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _formKey.currentState!.save();

    final newItem = FoodItem(
      id: widget.itemToEdit?.id ?? const Uuid().v4(),
      name: _name,
      location: _location,
      quantity: _qty,
      unit: _unit,
      purchasedDate: _purchased,
      openDate: _openDate,
      bestBeforeDate: _bestBefore,
      predictedExpiry: _expiry,
      category: 'manual',
    );

    if (widget.itemToEdit != null) {
      await widget.repo.updateItem(newItem);
    } else {
      await widget.repo.addItem(newItem);
    }

    if (mounted) Navigator.pop(context);
  }

  // ========= AI：解析文本食材 =========

  Future<void> _runIngredientAi(String text, {required String source}) async {
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文本太短了，再补充一点信息吧～')),
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
          case 'freezer':
            _location = StorageLocation.freezer;
            break;
          case 'pantry':
            _location = StorageLocation.pantry;
            break;
          default:
            _location = StorageLocation.fridge;
        }

        // 修改关键字段后，旧的 AI 预测就作废，避免误导
        _clearAiExpiry();

        _tabController.animateTo(0); // 回到 Manual 给用户确认
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == 'voice'
                ? 'AI 已根据语音预填了表单，请在 Manual 页检查。'
                : 'AI 已根据描述预填了表单，请在 Manual 页检查。',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 解析失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyVoiceWithAi() async {
    await _runIngredientAi(_voiceController.text, source: 'voice');
  }

  // ========= AI：预测保质期 =========

  Future<void> _predictExpiryWithAi() async {
    if (!_canPredictExpiry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写食材名称（至少）再尝试预测保质期。'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/predict-expiry');

      final body = {
        'name': _name,
        'location': _location.name, // fridge / freezer / pantry
        'purchasedDate': _purchased.toIso8601String(),
        if (_openDate != null) 'openedDate': _openDate!.toIso8601String(),
        if (_bestBefore != null)
          'bestBeforeDate': _bestBefore!.toIso8601String(),
      };

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode} - ${resp.body}');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final dateStr = (json['suggestedExpiry'] ?? '').toString();
      final reason = json['reason']?.toString();

      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) {
        throw Exception('Invalid date from AI: $dateStr');
      }

      setState(() {
        _aiSuggestedExpiry = parsed;
        _aiReason = reason;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保质期预测失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _applyAiExpiry() {
    if (_aiSuggestedExpiry == null) return;

    setState(() {
      _bestBefore = _aiSuggestedExpiry;
      _expiry = _aiSuggestedExpiry; // 用于 Expiring Soon 计算
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已应用 AI 推荐保质期：${_formatDate(_aiSuggestedExpiry)}'),
      ),
    );
  }

  // ========= Scan / Camera =========

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission needed")),
        );
      }
      return;
    }

    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    if (!mounted) return;
    String descText = '';

    final desc = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Describe what you scanned'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. half box Greek yogurt in the fridge',
            ),
            onChanged: (v) => descText = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, descText),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (desc == null || desc.trim().isEmpty) return;
    await _runIngredientAi(desc, source: 'scan');
  }

  // ========= Voice =========

  Future<void> _toggleListening() async {
    if (_isProcessing) return;

    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission needed")),
          );
        }
        return;
      }

      final available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _voiceHint = "Listening... tap again to stop.";
        });
        _speech.listen(
          onResult: (res) {
            setState(() => _voiceController.text = res.recognizedWords);
          },
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _voiceHint = _voiceController.text.trim().isEmpty
            ? "No speech detected, please try again."
            : "确认下面的文本，如果有错可以修改，再让 AI 填表。";
      });
      _speech.stop();
    }
  }

  // ========= UI =========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemToEdit != null ? 'Edit Item' : 'Add New Item'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF005F87),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF005F87),
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
              _buildCameraTab(),
              _buildVoiceTab(),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // --- Manual Tab ---

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基础信息
            const Text(
              'Basic info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              onChanged: (v) {
                setState(() {
                  _name = v;
                  _clearAiExpiry(); // 名字变了，旧预测作废
                });
              },
              onSaved: (v) => _name = v ?? '',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _qty.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) =>
                        _qty = double.tryParse(v ?? '1') ?? 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    items: const [
                      'pcs',
                      'kg',
                      'g',
                      'L',
                      'ml',
                      'pack',
                      'box',
                      'cup',
                    ].map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    ).toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 日期区域
            const Text(
              'Dates (optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildDateTile(
              label: 'Purchase Date',
              value: _purchased,
              onTap: () => _pickDate(
                initial: _purchased,
                first: DateTime.now().subtract(const Duration(days: 365)),
                last: DateTime.now().add(const Duration(days: 365)),
                onPicked: (d) => setState(() {
                  _purchased = d!;
                  _clearAiExpiry();
                }),
              ),
            ),
            _buildDateTile(
              label: 'Opened Date',
              value: _openDate,
              onTap: () => _pickDate(
                initial: _openDate ?? DateTime.now(),
                first: DateTime.now().subtract(const Duration(days: 365)),
                last: DateTime.now().add(const Duration(days: 365)),
                onPicked: (d) => setState(() => _openDate = d),
              ),
              onClear: () => setState(() => _openDate = null),
            ),
            _buildDateTile(
              label: 'Best-before Date',
              value: _bestBefore,
              onTap: () => _pickDate(
                initial: _bestBefore ?? DateTime.now(),
                first: DateTime.now().subtract(const Duration(days: 365)),
                last: DateTime.now().add(const Duration(days: 365 * 3)),
                onPicked: (d) => setState(() {
                  _bestBefore = d;
                  // 用户手动输保质期时，不强制清空 AI 预测，作为对比也可以
                }),
              ),
              onClear: () => setState(() => _bestBefore = null),
            ),
            const SizedBox(height: 16),

            // --- AI 预测保质期卡片 ---
            const Text(
              'Smart expiry (beta)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E7F1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Predict expiry date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_aiSuggestedExpiry == null)
                    Text(
                      'Based on name, storage and purchase date.\n'
                      'This is only a suggestion – always follow package labels and food safety rules.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested: ${_formatDate(_aiSuggestedExpiry)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_aiReason != null)
                          Text(
                            _aiReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_aiSuggestedExpiry == null)
                        FilledButton.icon(
                          onPressed: _isProcessing ? null : _predictExpiryWithAi,
                          icon: const Icon(Icons.schedule),
                          label: const Text('Predict now'),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed:
                              _isProcessing ? null : _predictExpiryWithAi,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Recalculate'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _applyAiExpiry,
                          child: const Text('Apply'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 存放位置
            const Text(
              'Storage location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<StorageLocation>(
              segments: const [
                ButtonSegment(
                  value: StorageLocation.fridge,
                  label: Text('Fridge'),
                  icon: Icon(Icons.kitchen),
                ),
                ButtonSegment(
                  value: StorageLocation.freezer,
                  label: Text('Freezer'),
                  icon: Icon(Icons.ac_unit),
                ),
                ButtonSegment(
                  value: StorageLocation.pantry,
                  label: Text('Pantry'),
                  icon: Icon(Icons.weekend),
                ),
              ],
              selected: {_location},
              onSelectionChanged: (s) => setState(() {
                _location = s.first;
                _clearAiExpiry(); // 存放位置变了，旧预测作废
              }),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save to Inventory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Scan Tab ---

  Widget _buildCameraTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_enhance, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Snap a product or ingredient"),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _takePhoto,
            child: const Text("Open Camera"),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "MVP：拍照后用一句话描述食材，AI 会自动帮你填好表单。",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // --- Voice Tab ---

  Widget _buildVoiceTab() {
    final canSend =
        _voiceController.text.trim().length > 2 && !_isProcessing;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color:
                    _isListening ? Colors.red.shade50 : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening ? Colors.red : Colors.grey,
                  width: 2,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 60,
                color: _isListening ? Colors.red : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _voiceHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _voiceController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Recognized text',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              hintText:
                  '例如："半盒希腊酸奶在冰箱" / "500g chicken breast in freezer"',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '如果识别错了可以先手动修改，然后再让 AI 自动填表。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: canSend ? _applyVoiceWithAi : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Use AI to fill form'),
            ),
          ),
        ],
      ),
    );
  }
}
