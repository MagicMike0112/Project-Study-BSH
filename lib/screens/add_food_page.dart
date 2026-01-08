// lib/screens/add_food_page.dart
import 'dart:convert';
import 'dart:io';

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
    with TickerProviderStateMixin {
  
  late TabController _tabController;

  // 🟢 动画控制器 (语音波纹)
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // 表单字段
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _qty;
  late String _unit;
  double? _minQty;
  late StorageLocation _location;

  // 日期字段
  late DateTime _purchased;
  DateTime? _openDate;
  DateTime? _bestBefore;
  
  // _expiry 存储 AI 预测的日期，作为 bestBefore 的后备
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
  String _voiceHint = "Tap mic to start";
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

    // 🟢 初始化呼吸动画
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
    _rippleController.dispose();
    _voiceController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ========= Logic Helpers =========

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
      case StorageLocation.freezer: return Icons.ac_unit_rounded;
      case StorageLocation.pantry: return Icons.shelves;
      case StorageLocation.fridge:
      default: return Icons.kitchen_rounded;
    }
  }

  // ========= Actions =========

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
      minQuantity: _minQty,
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

  // 🟢 核心修改：智能语音分析 (支持单品和多品)
  Future<void> _processVoiceInputWithAi(String text) async {
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text too short, please provide more info.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 提示：后端需要能处理自然语言列表。
      // 这里调用一个假设的智能接口，如果返回 items 数组则为多品，否则为单品
      final uri = Uri.parse('$kBackendBaseUrl/api/parse-ingredient');
      
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': trimmed,
          'expectList': true // 🟢 告诉后端尝试解析列表
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server error: ${resp.statusCode}');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;

      // 🟢 检查是否返回了多物品列表 (backend should return "items": [...] for lists)
      if (json.containsKey('items') && json['items'] is List && (json['items'] as List).isNotEmpty) {
        
        // CASE A: 多品模式 -> 复用扫描预览页
        final itemsRaw = json['items'] as List;
        final scannedItems = itemsRaw.map((e) => _mapJsonToScannedItem(e)).toList();

        if (mounted) {
          setState(() => _isProcessing = false); // 提前结束 loading 以显示 sheet
          await _showScannedItemsPreview(scannedItems);
        }

      } else {
        
        // CASE B: 单品模式 -> 填入表单
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

          // 如果后端顺便返回了预测日期
          if (json['predictedExpiry'] != null) {
             try {
               final d = DateTime.parse(json['predictedExpiry']);
               _predictedExpiryFromAi = d;
               _expiry = d;
               _bestBefore = d;
             } catch(_) {}
          } else {
             _resetPrediction();
          }

          _tabController.animateTo(0); // 切换回 Manual 页面查看填好的表单
        });

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form filled from voice.')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI parse failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Helper: 将后端通用的 Item JSON 转为本地 ScannedItem 对象
  _ScannedItem _mapJsonToScannedItem(dynamic json) {
     final m = json as Map<String, dynamic>;
     final name = (m['name'] ?? '').toString().trim();
     double qty = 1;
     if (m['quantity'] is num) qty = (m['quantity'] as num).toDouble();
     
     StorageLocation loc = StorageLocation.fridge;
     if (m['storageLocation'] == 'freezer') loc = StorageLocation.freezer;
     if (m['storageLocation'] == 'pantry') loc = StorageLocation.pantry;

     DateTime purchaseDate = DateTime.now();
     // 如果语音里提到了 "bought yesterday"，后端可能返回 purchaseDate
     if (m['purchaseDate'] != null) {
       try { purchaseDate = DateTime.parse(m['purchaseDate']); } catch (_) {}
     }

     DateTime? predictedExpiry;
     if (m['predictedExpiry'] is String) {
       try { predictedExpiry = DateTime.parse(m['predictedExpiry']); } catch (_) {}
     }

     return _ScannedItem(
       name: name.isEmpty ? 'Unknown' : name,
       quantity: qty,
       unit: (m['unit'] ?? 'pcs').toString(),
       location: loc,
       category: (m['category'] ?? 'voice').toString(),
       purchaseDate: purchaseDate,
       confidence: 0.9, // 语音通常比较准
       predictedExpiry: predictedExpiry,
     );
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

      final predictedDate = DateTime.parse(iso);
      setState(() {
        _predictedExpiryFromAi = predictedDate;
        _expiry = predictedDate; 
        _bestBefore = predictedDate; // 自动填入
        _predictionError = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expiry set to ${_formatDate(predictedDate)} ✨'),
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

  // 📸 Camera
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

  // 🖼️ Gallery
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 4 images allowed. Selecting first 4.')),
        );
      }
      processedImages = images.sublist(0, 4);
    }

    await _processScanImages(processedImages, mode: _scanMode);
  }

  /// 核心处理函数：并行处理多张图片
  Future<void> _processScanImages(List<XFile> xfiles, {required StorageScanMode mode}) async {
    setState(() {
      _isProcessing = true;
      _activeProcessingScanMode = mode;
    });

    try {
      final futures = xfiles.map((file) => _analyzeSingleImage(file, mode)).toList();
      final results = await Future.wait(futures);
      
      final allItems = results.expand((i) => i).toList();

      if (allItems.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items detected in images.')));
        return;
      }

      if (!mounted) return;
      await _showScannedItemsPreview(allItems);
      
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

  /// Helper: 处理单张图片的 API 调用
  Future<List<_ScannedItem>> _analyzeSingleImage(XFile xfile, StorageScanMode mode) async {
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
      throw Exception('Server error: ${resp.statusCode}');
    }

    final root = jsonDecode(resp.body) as Map<String, dynamic>;
    // 复用通用的映射逻辑 (虽然有点小差异，但字段结构类似)
    if (root['items'] is List) {
       return (root['items'] as List).map((e) => _mapJsonToScannedItem(e)).toList();
    }
    return [];
  }

  // 语音监听逻辑
  Future<void> _toggleListening() async {
    if (_isProcessing) return;

    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      final available = await _speech.initialize(
        onError: (e) => setState(() {
          _isListening = false;
          _voiceHint = "Error: ${e.errorMsg}";
          _rippleController.stop();
          _rippleController.reset();
        }),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() {
                _isListening = false;
                _voiceHint = "Tap mic to start";
                _rippleController.stop();
                _rippleController.reset();
              });
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _voiceHint = "I'm listening...";
          _voiceController.clear();
        });
        _rippleController.forward();

        _speech.listen(
          onResult: (res) {
            setState(() {
              _voiceController.text = res.recognizedWords;
              if (res.finalResult) {
                 _voiceHint = "Got it! Tap to analyze.";
              }
            });
          },
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
          cancelOnError: true,
          partialResults: true,
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _voiceHint = "Tap mic to start.";
      });
      _speech.stop();
      _rippleController.stop();
      _rippleController.reset();
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
          dividerColor: Colors.transparent,
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
                  onChanged: (v) {
                    setState(() {
                      _name = v;
                      _resetPrediction();
                    });
                  },
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
                        initialValue: _unit,
                        items: ['pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'cup']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                        decoration: _inputDecoration('Unit', null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _minQty?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Min Stock Warning (Optional)', Icons.notifications_active_outlined).copyWith(
                    hintText: 'e.g. 2 (Notify when below)',
                    helperText: 'Leave empty for no warnings',
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
              title: 'Storage',
              children: [
                SegmentedButton<StorageLocation>(
                  segments: const [
                    ButtonSegment(value: StorageLocation.fridge, label: Text('Fridge', maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(Icons.kitchen_outlined)),
                    ButtonSegment(value: StorageLocation.freezer, label: Text('Freezer', maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(Icons.ac_unit_rounded)),
                    ButtonSegment(value: StorageLocation.pantry, label: Text('Pantry', maxLines: 1, overflow: TextOverflow.ellipsis), icon: Icon(Icons.shelves)),
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
                    side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildFormCard(
              title: 'Dates',
              children: [
                _buildDateRow('Purchased', _purchased, (d) {
                  setState(() {
                    _purchased = d!;
                    _resetPrediction();
                  });
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow('Opened', _openDate, (d) {
                  setState(() {
                    _openDate = d;
                    _resetPrediction();
                  });
                }, canClear: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDateRow('Best Before', _bestBefore, (d) {
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildScanModeOption(StorageScanMode.receipt, 'Scan Receipt', Icons.receipt_long_rounded),
                _buildScanModeOption(StorageScanMode.fridge, 'Snap Fridge', Icons.kitchen_rounded),
              ],
            ),
          ),
          const SizedBox(height: 40),

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
            label: 'Upload (Max 4)',
            subtitle: 'Choose multiple from gallery',
            color: Colors.grey.shade800,
            isOutlined: true,
            onTap: _pickFromGallery,
          ),
          
          const SizedBox(height: 40),
          Text(
            _scanMode == StorageScanMode.receipt 
              ? 'AI will extract items from your receipt(s).'
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
    final hasText = _voiceController.text.trim().length > 2;
    
    return SingleChildScrollView(
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
                          color: _primaryColor.withOpacity(0.2 - (_rippleAnimation.value - 1.0) / 2),
                        ),
                      );
                    },
                  ),
                
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isListening ? _primaryColor : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isListening 
                            ? _primaryColor.withOpacity(0.4) 
                            : Colors.grey.shade300,
                        blurRadius: _isListening ? 20 : 10,
                        spreadRadius: _isListening ? 5 : 2,
                        offset: const Offset(0, 4)
                      )
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
                color: _isListening ? _primaryColor : Colors.grey.shade700
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          if (!_isListening && !hasText)
            Text(
              'Try saying: "3 apples, milk, and 1kg of rice"',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),

          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hasText ? _primaryColor.withOpacity(0.5) : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _voiceController,
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Transcript will appear here...',
                hintStyle: TextStyle(color: Colors.black12),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_isProcessing ? 'Analyzing...' : 'Analyze & Fill'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Row(
                        children: [
                          Text(
                            _formatDate(_predictedExpiryFromAi),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Auto Applied ✅', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      if (_bestBefore != null && _bestBefore != _predictedExpiryFromAi)
                         const Text('Manual date will override this', style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                      setState(() {
                        _expiry = null;
                        _predictedExpiryFromAi = null;
                      });
                  },
                  child: const Text('Undo', style: TextStyle(fontSize: 12)),
                )
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
                isReceipt ? 'Scanning Receipts...' : 'Analyzing...',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is processing your images/voice and identifying items.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

    for (int i = 0; i < items.length; i++) {
      if (!selected[i]) continue;
      final s = items[i];
      DateTime expiry = s.predictedExpiry ?? s.purchaseDate.add(const Duration(days: 7));
      
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