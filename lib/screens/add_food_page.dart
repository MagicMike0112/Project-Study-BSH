// lib/screens/add_food_page.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../models/food_item.dart';
import '../repositories/inventory_repository.dart';

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
  late DateTime _purchased; // 默认今天，用户可以改
  DateTime? _openDate; // 可选
  DateTime? _bestBefore; // 可选
  DateTime? _expiry; // 预测保质期（只读展示）

  // 相机/语音状态
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isProcessing = false;
  String _voiceText = "Tap mic to speak...";
  bool _isListening = false;

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
    _expiry = item?.predictedExpiry;

    // 如果没有已有的 predictedExpiry，则用规则先算一个
    if (_expiry == null) {
      _expiry = _predictFromCurrentState();
    }
  }

  // ========= 工具函数 =========

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not set';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  DateTime _predictFromCurrentState() {
    final temp = FoodItem(
      id: widget.itemToEdit?.id ?? const Uuid().v4(),
      name: _name.isEmpty ? 'temp' : _name,
      location: _location,
      quantity: _qty,
      unit: _unit,
      purchasedDate: _purchased,
      openDate: _openDate,
      bestBeforeDate: _bestBefore,
      predictedExpiry: null,
      status: widget.itemToEdit?.status ?? FoodStatus.good,
      category: widget.itemToEdit?.category,
      source: widget.itemToEdit?.source,
    );
    return widget.repo.predictExpiryForItem(temp);
  }

  void _recalculateExpiry() {
    setState(() {
      _expiry = _predictFromCurrentState();
    });
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime?> onChanged,
    bool allowNull = false,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(picked);
      _recalculateExpiry();
    } else if (allowNull) {
      onChanged(null);
      _recalculateExpiry();
    }
  }

  // ========= 保存 =========

  void _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();

      // 再算一遍，确保最新
      final predicted = _expiry ?? _predictFromCurrentState();

      final newItem = FoodItem(
        id: widget.itemToEdit?.id ?? const Uuid().v4(),
        name: _name,
        quantity: _qty,
        unit: _unit,
        location: _location,
        purchasedDate: _purchased,
        openDate: _openDate,
        bestBeforeDate: _bestBefore,
        predictedExpiry: predicted,
        category: 'manual',
      );

      if (widget.itemToEdit != null) {
        await widget.repo.updateItem(newItem);
      } else {
        await widget.repo.addItem(newItem);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  // --- AI 逻辑 (模拟) ---
  Future<void> _processAiInput(String source) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2)); // 模拟 API 调用
    setState(() {
      _isProcessing = false;
      _name = source == 'camera' ? 'Detected Apples' : 'Voice Carrots';
      _qty = 5;
      _unit = 'pcs';
      _tabController.animateTo(0); // 切换到手动标签页以确认
    });
    _recalculateExpiry();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI extracted data! Please confirm.")),
      );
    }
  }

  Future<void> _takePhoto() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      final xfile = await _picker.pickImage(source: ImageSource.camera);
      if (xfile != null) _processAiInput('camera');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission needed")),
        );
      }
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (res) =>
                setState(() => _voiceText = res.recognizedWords),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_voiceText.length > 2) _processAiInput('voice');
    }
  }

  // ========= UI =========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.itemToEdit != null ? 'Edit Item' : 'Add New Item'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF004A77),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF004A77),
          tabs: const [
            Tab(text: 'Manual'),
            Tab(text: 'Scan'),
            Tab(text: 'Voice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManualForm(),
          _buildCameraTab(),
          _buildVoiceTab(),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              onSaved: (v) => _name = v ?? '',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
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
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    items: ['pcs', 'kg', 'g', 'L', 'pack']
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
              onSelectionChanged: (s) {
                setState(() => _location = s.first);
                _recalculateExpiry();
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Dates (optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Purchase date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase date'),
              subtitle: Text(_formatDate(_purchased)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () => _pickDate(
                initial: _purchased,
                onChanged: (d) => setState(() => _purchased = d!),
              ),
            ),
            const Divider(),
            // Open date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open date'),
              subtitle: Text(
                _openDate == null
                    ? 'Not set'
                    : _formatDate(_openDate),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_openDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _openDate = null);
                        _recalculateExpiry();
                      },
                    ),
                  const Icon(Icons.calendar_today_rounded),
                ],
              ),
              onTap: () => _pickDate(
                initial: _openDate ?? DateTime.now(),
                onChanged: (d) => setState(() => _openDate = d),
                allowNull: true,
              ),
            ),
            const Divider(),
            // Best-before
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Best-before date'),
              subtitle: Text(
                _bestBefore == null
                    ? 'Not set'
                    : _formatDate(_bestBefore),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_bestBefore != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _bestBefore = null);
                        _recalculateExpiry();
                      },
                    ),
                  const Icon(Icons.calendar_today_rounded),
                ],
              ),
              onTap: () => _pickDate(
                initial: _bestBefore ?? DateTime.now(),
                onChanged: (d) => setState(() => _bestBefore = d),
                allowNull: true,
              ),
            ),
            const SizedBox(height: 16),
            // Predicted expiry card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Predicted expiry',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _expiry == null
                                ? 'Will be estimated automatically'
                                : _formatDate(_expiry),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save to Inventory'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004A77),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTab() {
    return Center(
      child: _isProcessing
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_enhance,
                    size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("Snap a receipt or product"),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _takePhoto,
                  child: const Text("Open Camera"),
                ),
              ],
            ),
    );
  }

  Widget _buildVoiceTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _isListening
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
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
          const SizedBox(height: 24),
          Text(
            _voiceText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
