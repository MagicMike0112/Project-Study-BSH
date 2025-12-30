// lib/widgets/add_by_recipe_sheet.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:uuid/uuid.dart';
import '../repositories/inventory_repository.dart';
import '../screens/login_page.dart'; 

class AddByRecipeSheet extends StatefulWidget {
  final InventoryRepository repo;
  const AddByRecipeSheet({super.key, required this.repo});

  @override
  State<AddByRecipeSheet> createState() => _AddByRecipeSheetState();
}

class _AddByRecipeSheetState extends State<AddByRecipeSheet> {
  final TextEditingController _textController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isAnalyzing = false;
  List<Map<String, dynamic>> _detectedItems = [];

  final ImagePicker _picker = ImagePicker();
  static const String _backendUrl = 'https://project-study-bsh.vercel.app/api/shop-by-recipe';

  // 🟢 检查登录状态逻辑
  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  // 拍照或多选图
  Future<void> _pickImage(ImageSource source) async {
    if (!_isLoggedIn) {
      _showLoginRequiredAction();
      return;
    }
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await _picker.pickMultiImage();
        if (picked.isNotEmpty) setState(() => _selectedImages.addAll(picked));
      } else {
        final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
        if (picked != null) setState(() => _selectedImages.add(picked));
      }
    } catch (e) {
      debugPrint("Pick image error: $e");
    }
  }

  void _showLoginRequiredAction() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Please sign in to use AI Recipe Scan."),
        action: SnackBarAction(
          label: "SIGN IN",
          onPressed: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => const LoginPage(allowSkip: false))
          ),
        ),
      ),
    );
  }

  // 核心逻辑：分析菜谱 + AI 语义库存对比
  Future<void> _analyzeRecipe() async {
    if (!_isLoggedIn) {
      _showLoginRequiredAction();
      return;
    }

    if (_textController.text.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a recipe name, text, or image.")),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 1. 准备当前库存数据给 AI (用于语义匹配)
      final inventoryData = widget.repo.getActiveItems().map((e) => {
        'name': e.name,
        'category': e.category,
      }).toList();

      // 2. 将图片转为 Base64
      List<String> base64Images = [];
      for (var img in _selectedImages) {
        final bytes = await img.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

      // 3. 调用后端接口
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': _textController.text,
          'imagesBase64': base64Images,
          'currentInventory': inventoryData,
        }),
      );

      if (response.statusCode != 200) throw Exception("Server error: ${response.body}");

      final data = jsonDecode(response.body);
      final List rawItems = data['items'] ?? [];

      setState(() {
        _detectedItems = rawItems.map((item) {
          return {
            'name': item['name'],
            'category': item['category'],
            'inStock': item['inStock'] ?? false,
            'reason': item['reason'] ?? '',
            'selected': !(item['inStock'] ?? false), 
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Analysis failed: $e")),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // 确认导入到购物清单
  void _confirmImport() async {
    final toAdd = _detectedItems.where((i) => i['selected']).toList();
    if (toAdd.isEmpty) {
      Navigator.pop(context);
      return;
    }

    for (var item in toAdd) {
      final newItem = ShoppingItem(
        id: const Uuid().v4(),
        name: item['name'],
        category: (item['category'] as String).toLowerCase(),
        isChecked: false,
      );
      await widget.repo.saveShoppingItem(newItem);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added ${toAdd.length} items to shopping list")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 顶部装饰条
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.auto_awesome, color: _isLoggedIn ? Colors.blueAccent : Colors.grey, size: 24),
              const SizedBox(width: 12),
              const Text("Recipe Import", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          
          // 🟢 如果未登录，显示占位 UI
          if (!_isLoggedIn) 
            _buildLoginPlaceholder()
          else ...[
            // 输入区域
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Enter dish name (e.g. Pasta) or paste recipe...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            
            // 图片预览与选择区
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ImageActionButton(icon: Icons.add_a_photo, label: "Camera", onTap: () => _pickImage(ImageSource.camera)),
                  const SizedBox(width: 8),
                  _ImageActionButton(icon: Icons.photo_library, label: "Album", onTap: () => _pickImage(ImageSource.gallery)),
                  const VerticalDivider(width: 24, indent: 10, endIndent: 10),
                  ..._selectedImages.map((img) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: Colors.grey[300]!)
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        Positioned(right: -2, top: -2, child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.remove(img)),
                          child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                        )),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isAnalyzing ? null : _analyzeRecipe,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF005F87),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isAnalyzing 
                  ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 12), Text("Analyzing...")])
                  : const Text("Get Shopping list", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

            // 结果列表
            Expanded(
              child: _detectedItems.isEmpty 
                ? Center(child: Text(_isAnalyzing ? "AI is thinking..." : "Your results will appear here", style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    itemCount: _detectedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _detectedItems[index];
                      final bool inStock = item['inStock'];
                      return Container(
                        decoration: BoxDecoration(
                          color: inStock ? Colors.green.withOpacity(0.05) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: inStock ? Colors.green.withOpacity(0.2) : Colors.transparent),
                        ),
                        child: CheckboxListTile(
                          value: item['selected'],
                          onChanged: (v) => setState(() => item['selected'] = v),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(inStock ? "In stock: ${item['reason']}" : "Category: ${item['category']}"),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: inStock ? Colors.green : Colors.blueGrey[100], shape: BoxShape.circle),
                            child: Icon(inStock ? Icons.inventory : Icons.shopping_basket, color: Colors.white, size: 18),
                          ),
                          activeColor: const Color(0xFF005F87),
                        ),
                      );
                    },
                  ),
            ),
            
            if (_detectedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _confirmImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("Add ${_detectedItems.where((i)=>i['selected']).length} Items to List"),
                  ),
                ),
              ),
          ]
        ],
      ),
    );
  }

  // 🟢 构建登录引导占位符
  Widget _buildLoginPlaceholder() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blueGrey[50], shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, size: 48, color: Colors.blueGrey[300]),
          ),
          const SizedBox(height: 24),
          const Text("Sign in Required", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Please sign in to sync with your inventory\nand use AI recipe analysis.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const LoginPage(allowSkip: false))
              ),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF005F87)),
              child: const Text("Sign In Now"),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImageActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.blueGrey[700]),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.blueGrey[700], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}