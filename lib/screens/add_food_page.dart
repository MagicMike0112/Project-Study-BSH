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
  DateTime? _expiry; // 真正保存到模型里的“effective expiry”（手动/AI）

  // AI 保质期预测状态
  bool _isPredictingExpiry = false;
  DateTime? _predictedExpiryFromAi; // 只用于 UI 显示和 Apply 按钮
  String? _predictionError;

  // 相机 / 语音
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isProcessing = false;
  bool _isListening = false;
  String _voiceHint = "Tap mic to start or stop.";
  final TextEditingController _voiceController = TextEditingController();

  // 扫描模式（一个入口，前端选择是小票还是冰箱）
  StorageScanMode _scanMode = StorageScanMode.receipt;

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

    // 兜底 unit，防止 dropdown 崩
    const allowedUnits = [
      'pcs',
      'kg',
      'g',
      'L',
      'ml',
      'pack',
      'box',
      'cup',
      'cups',
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _voiceController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ========= 小工具 =========

  String _formatQty(double q) {
    final isInt = (q - q.round()).abs() < 1e-9;
    return isInt ? q.round().toString() : q.toStringAsFixed(1);
  }

  String _locationLabel(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.freezer:
        return 'Freezer';
      case StorageLocation.pantry:
        return 'Pantry';
      case StorageLocation.fridge:
      default:
        return 'Fridge';
    }
  }

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

  void _resetPrediction() {
    _predictedExpiryFromAi = null;
    _predictionError = null;
  }

  IconData _locationIcon(StorageLocation loc) {
    switch (loc) {
      case StorageLocation.freezer:
        return Icons.ac_unit;
      case StorageLocation.pantry:
        return Icons.inventory_2_outlined;
      case StorageLocation.fridge:
      default:
        return Icons.kitchen;
    }
  }

  // ========= 保存 =========

  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    // 手动填写的 bestBefore 优先级最高
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

  // ========= /api/parse-ingredient =========

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

        _resetPrediction();
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

  // ========= 调用 /api/recipe 做“保质期预测” =========

  Future<void> _predictExpiryWithAi() async {
  // ✅ 未登录：不能用 AI 保质期预测
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
      throw Exception('Server error: ${resp.statusCode} - ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final iso = data['predictedExpiry'] as String?;
    if (iso == null) {
      throw Exception('No predictedExpiry in response');
    }

    setState(() {
      _predictedExpiryFromAi = DateTime.parse(iso);
      _predictionError = null;
    });
  } catch (e) {
    setState(() {
      _predictionError = e.toString();
    });
  } finally {
    if (mounted) {
      setState(() {
        _isPredictingExpiry = false;
      });
    }
  }
}


  // ========= Scan 统一入口：拍照 / 相册 + 调 /api/scan-inventory =========

  Future<void> _takePhoto() async {
  // ✅ 未登录：不能用 Scan 上传
  final ok = await requireLogin(context);
  if (!ok) return;

  final status = await Permission.camera.request();
  if (!status.isGranted) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission needed")),
      );
    }
    return;
  }

  final xfile = await _picker.pickImage(source: ImageSource.camera,maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,);
  if (xfile == null) return;

  await _scanImageWithAi(xfile, mode: _scanMode);
}

Future<void> _pickFromGallery() async {
  // ✅ 未登录：不能用 Scan 上传
  final ok = await requireLogin(context);
  if (!ok) return;

  final xfile = await _picker.pickImage(source: ImageSource.gallery,maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,);
  if (xfile == null) return;

  await _scanImageWithAi(xfile, mode: _scanMode);
}


  Future<void> _scanImageWithAi(
    XFile xfile, {
    required StorageScanMode mode,
  }) async {
    // ✅ 兜底：防止未来从别处绕过入口直接调用上传
        final ok = await requireLogin(context);
      if (!ok) return;

    setState(() => _isProcessing = true);

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

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode} - ${resp.body}');
      }

      final root = jsonDecode(resp.body) as Map<String, dynamic>;

      // purchaseDate: 如果缺失或非法，前端用今天
      DateTime purchaseDate = DateTime.now();
      final pRaw = root['purchaseDate'];
      if (pRaw is String && pRaw.trim().isNotEmpty) {
        try {
          purchaseDate = DateTime.parse('${pRaw.trim()}T00:00:00.000Z');
        } catch (_) {
          // ignore, fallback to now
        }
      }

      final itemsJson = root['items'] as List<dynamic>? ?? const [];
      if (itemsJson.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items detected from scan.')),
          );
        }
        return;
      }

      final now = DateTime.now();
      final max = now.add(const Duration(days: 365));

      // 解析为临时对象，给用户预览
      final scannedItems = itemsJson.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final name = (m['name'] ?? '').toString().trim();
        final qtyRaw = m['quantity'];
        double qty = 1;
        if (qtyRaw is num) qty = qtyRaw.toDouble();
        final unit = (m['unit'] ?? 'pcs').toString();
        final locStr = (m['storageLocation'] ?? 'fridge').toString();
        final category = (m['category'] ?? 'scan').toString();
        final conf = (m['confidence'] as num?)?.toDouble() ?? 0.0;

        StorageLocation loc;
        switch (locStr) {
          case 'freezer':
            loc = StorageLocation.freezer;
            break;
          case 'pantry':
            loc = StorageLocation.pantry;
            break;
          default:
            loc = StorageLocation.fridge;
        }

        DateTime? predictedExpiry;
        final expRaw = m['predictedExpiry'];
        if (expRaw is String && expRaw.trim().isNotEmpty) {
          try {
            predictedExpiry = DateTime.parse(expRaw);
          } catch (_) {}
        }

        // 前端再兜底一次：不能早于今天，也不要超过 365 天
        if (predictedExpiry != null) {
          if (predictedExpiry.isBefore(now)) {
            predictedExpiry = now.add(const Duration(days: 3));
          } else if (predictedExpiry.isAfter(max)) {
            predictedExpiry = max;
          }
        }

        return _ScannedItem(
          name: name.isEmpty ? 'Unknown item' : name,
          quantity: qty,
          unit: unit,
          location: loc,
          category: category,
          purchaseDate: purchaseDate,
          confidence: conf,
          predictedExpiry: predictedExpiry,
        );
      }).toList();

      if (!mounted) return;

      await _showScannedItemsPreview(scannedItems);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ========= Scan 预览（优化布局：只展示关键数据 + 不溢出） =========

  Future<void> _showScannedItemsPreview(List<_ScannedItem> items) async {
  final selected = List<bool>.filled(items.length, true);

  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * 0.78;

      return StatefulBuilder(
        builder: (ctx, setStateSheet) {
          final count = selected.where((v) => v).length;

          return SafeArea(
            child: Container(
              height: maxH,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    spreadRadius: 2,
                    color: Color(0x22000000),
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 顶部标题
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add scanned items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  Text(
                    'Review and edit if needed. Uncheck items you don’t want to add.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                  const SizedBox(height: 12),

                  // 列表
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(items.length, (i) {
                          final it = items[i];

                          // ✅ 只保留关键数据：qty + unit + location
                          final line1 =
                              '${_formatQty(it.quantity)} ${it.unit} • ${_locationLabel(it.location)}';

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                setStateSheet(() => selected[i] = !selected[i]),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 10, 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected[i]
                                      ? const Color(0xFF005F87)
                                          .withOpacity(0.25)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _locationIcon(it.location),
                                      color: const Color(0xFF005F87),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          line1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey[850],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),

                                        // ✅ 不要 Purchased 那行：删掉
                                        // （这里不留 SizedBox，不占高度）
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  SizedBox(
                                    width: 82,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () async {
                                            final updated =
                                                await _showEditScannedItemDialog(
                                                    it);
                                            if (updated != null) {
                                              setStateSheet(
                                                  () => items[i] = updated);
                                            }
                                          },
                                        ),
                                        Checkbox(
                                          value: selected[i],
                                          onChanged: (v) => setStateSheet(
                                              () =>
                                                  selected[i] = v ?? false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 底部按钮条
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: count == 0
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: Text('Add ($count)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  // 保存（expiry 也一起存）
  for (int i = 0; i < items.length; i++) {
    if (!selected[i]) continue;
    final s = items[i];

    DateTime expiry = s.predictedExpiry ??
        (s.location == StorageLocation.freezer
            ? s.purchaseDate.add(const Duration(days: 90))
            : s.location == StorageLocation.pantry
                ? s.purchaseDate.add(const Duration(days: 30))
                : s.purchaseDate.add(const Duration(days: 7)));

    if (expiry.isBefore(s.purchaseDate)) {
      expiry = s.purchaseDate.add(const Duration(days: 3));
    }

    final foodItem = FoodItem(
      id: const Uuid().v4(),
      name: s.name,
      location: s.location,
      quantity: s.quantity,
      unit: s.unit,
      purchasedDate: s.purchaseDate,
      openDate: null,
      bestBeforeDate: null,
      predictedExpiry: expiry,
      category: s.category,
    );
    await widget.repo.addItem(foodItem);
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${selected.where((v) => v).length} items ✅')),
    );
  }
}

  Future<_ScannedItem?> _showEditScannedItemDialog(_ScannedItem item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final unitCtrl = TextEditingController(text: item.unit);
    DateTime purchase = item.purchaseDate;
    DateTime? expiry = item.predictedExpiry;
    StorageLocation loc = item.location;

    final result = await showDialog<_ScannedItem>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit item',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Storage location',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<StorageLocation>(
                      segments: const [
                        ButtonSegment(
                          value: StorageLocation.fridge,
                          icon: Icon(Icons.kitchen_outlined),
                          label: SizedBox.shrink(),
                        ),
                        ButtonSegment(
                          value: StorageLocation.freezer,
                          icon: Icon(Icons.ac_unit),
                          label: SizedBox.shrink(),
                        ),
                        ButtonSegment(
                          value: StorageLocation.pantry,
                          icon: Icon(Icons.inventory_2_outlined),
                          label: SizedBox.shrink(),
                        ),
                      ],
                      selected: {loc},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        setStateDialog(() => loc = s.first);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tip: 🔵 fridge   ❄ freezer   📦 pantry',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Purchased date
                    const Text(
                      'Purchased date',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: purchase,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setStateDialog(() => purchase = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatDate(purchase),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Expiry
                    const Text(
                      'Predicted expiry',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final base = expiry ?? purchase;
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: base,
                                firstDate: purchase,
                                lastDate: purchase.add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setStateDialog(() => expiry = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.06)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(expiry),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear expiry',
                          onPressed: () => setStateDialog(() => expiry = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
                            Navigator.pop(
                              ctx,
                              _ScannedItem(
                                name: nameCtrl.text.trim().isEmpty
                                    ? item.name
                                    : nameCtrl.text.trim(),
                                quantity: qty,
                                unit: unitCtrl.text.trim().isEmpty
                                    ? item.unit
                                    : unitCtrl.text.trim(),
                                location: loc,
                                category: item.category,
                                purchaseDate: purchase,
                                confidence: item.confidence,
                                predictedExpiry: expiry,
                              ),
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    return result;
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
            : "确认下面的文本，如果有错可以修改，然后再让 AI 填表。";
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
                  _resetPrediction();
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
                    onSaved: (v) => _qty = double.tryParse(v ?? '1') ?? 1,
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
                      'cups',
                    ].toSet().map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      );
                    }).toList(),
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
                onPicked: (d) {
                  setState(() {
                    _purchased = d!;
                    _resetPrediction();
                  });
                },
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
                onPicked: (d) => setState(() => _bestBefore = d),
              ),
              onClear: () => setState(() => _bestBefore = null),
            ),
            const SizedBox(height: 12),

            _buildExpiryAiCard(),
            const SizedBox(height: 20),

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
              onSelectionChanged: (s) {
                setState(() {
                  _location = s.first;
                  _resetPrediction();
                });
              },
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

  // ✅ 优化：避免 Row 里长文本溢出
  Widget _buildExpiryAiCard() {
    final canPredict = _name.trim().isNotEmpty && !_isPredictingExpiry;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI expiry suggestion (optional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Based on food type, storage and purchase date, ask AI to suggest an expiry date. '
              'If you manually set Best-before, that will override AI when saving.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            if (_isPredictingExpiry) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Predicting expiry...'),
                ],
              ),
            ] else if (_predictedExpiryFromAi != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI suggests: ${_formatDate(_predictedExpiryFromAi)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _expiry = _predictedExpiryFromAi;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expiry date applied')),
                      );
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
              if (_bestBefore != null)
                Text(
                  'Note: current Best-before ${_formatDate(_bestBefore)} will override this when saving.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                  ),
                ),
            ] else ...[
              if (_predictionError != null) ...[
                Text(
                  '上次预测失败：$_predictionError',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canPredict ? _predictExpiryWithAi : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Let AI predict expiry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Scan Tab ---

  Widget _buildCameraTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Scan to auto-fill inventory",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what you want to scan, then use camera or gallery.\n'
              'We will extract items, suggest storage, and create an inventory list.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            SegmentedButton<StorageScanMode>(
              segments: const [
                ButtonSegment(
                  value: StorageScanMode.receipt,
                  label: Text('Receipt'),
                  icon: Icon(Icons.receipt_long),
                ),
                ButtonSegment(
                  value: StorageScanMode.fridge,
                  label: Text('Fridge / shelf'),
                  icon: Icon(Icons.kitchen),
                ),
              ],
              selected: {_scanMode},
              onSelectionChanged: (s) {
                setState(() => _scanMode = s.first);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text("Scan with camera"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text("Choose from gallery"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Voice Tab ---

  Widget _buildVoiceTab() {
    final canSend = _voiceController.text.trim().length > 2 && !_isProcessing;

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
                color: _isListening ? Colors.red.shade50 : Colors.grey.shade100,
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
              hintText: 'For example: "500g chicken breast in freezer"',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'If there are mistakes, please edit the text before sending to AI.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
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

/// 扫描出来的临时结构
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
