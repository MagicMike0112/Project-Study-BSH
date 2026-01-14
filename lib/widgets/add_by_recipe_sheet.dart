// lib/widgets/add_by_recipe_sheet.dart
import 'dart:convert';
import 'dart:io'; // 用于移动端 File
import 'package:flutter/foundation.dart' show kIsWeb; // 用于判断 Web 平台
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

  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  // 拍照或多选图
  Future<void> _pickImage(ImageSource source) async {
    if (!_isLoggedIn) {
      _showLoginRequiredAction();
      return;
    }
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await _picker.pickMultiImage(
          imageQuality: 70, // 适当压缩以优化 Base64 传输
        );
        if (picked.isNotEmpty) setState(() => _selectedImages.addAll(picked));
      } else {
        final XFile? picked = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1200,
        );
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
            MaterialPageRoute(builder: (_) => const LoginPage(allowSkip: false)),
          ),
        ),
      ),
    );
  }

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
      final inventoryData = widget.repo.getActiveItems().map((e) => {
        'name': e.name,
        'category': e.category,
      }).toList();

      List<String> base64Images = [];
      for (var img in _selectedImages) {
        final bytes = await img.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: _isLoggedIn ? Colors.blueAccent : colors.onSurface.withOpacity(0.4),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Recipe Import",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_isLoggedIn) 
            _buildLoginPlaceholder()
          else ...[
            TextField(
              controller: _textController,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: "Enter dish name or paste recipe...",
                filled: true,
                fillColor: theme.cardColor,
                hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // 🟢 优化的多图预览区域
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none, // 让删除按钮可以稍微溢出
                children: [
                  _ImageActionButton(icon: Icons.add_a_photo, label: "Camera", onTap: () => _pickImage(ImageSource.camera)),
                  const SizedBox(width: 8),
                  _ImageActionButton(icon: Icons.photo_library, label: "Album", onTap: () => _pickImage(ImageSource.gallery)),
                  if (_selectedImages.isNotEmpty) const VerticalDivider(width: 24, indent: 10, endIndent: 10),
                  
                  // 图片预览列表
                  ..._selectedImages.map((img) => Padding(
                    padding: const EdgeInsets.only(right: 14.0, top: 4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 66, height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: colors.onSurface.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: kIsWeb 
                              ? Image.network(img.path, fit: BoxFit.cover) 
                              : Image.file(File(img.path), fit: BoxFit.cover),
                          ),
                        ),
                        // 删除按钮
                        Positioned(
                          right: -6, top: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImages.remove(img)),
                            child: const CircleAvatar(
                              radius: 10, 
                              backgroundColor: Colors.red, 
                              child: Icon(Icons.close, size: 12, color: Colors.white)
                            ),
                          ),
                        ),
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

            Expanded(
              child: _detectedItems.isEmpty 
                ? Center(
                    child: Text(
                      _isAnalyzing ? "AI is thinking..." : "Your results will appear here",
                      style: TextStyle(color: colors.onSurface.withOpacity(0.5)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _detectedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _detectedItems[index];
                      final bool inStock = item['inStock'];
                      return Container(
                        decoration: BoxDecoration(
                          color: inStock
                              ? Colors.green.withOpacity(isDark ? 0.16 : 0.05)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: inStock ? Colors.green.withOpacity(0.2) : theme.dividerColor,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: item['selected'],
                          onChanged: (v) => setState(() => item['selected'] = v),
                          title: Text(
                            item['name'],
                            style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
                          ),
                          subtitle: Text(
                            inStock ? "In stock: ${item['reason']}" : "Category: ${item['category']}",
                            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? Colors.green
                                  : (isDark ? Colors.blueGrey[700] : Colors.blueGrey[100]),
                              shape: BoxShape.circle,
                            ),
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
                      backgroundColor: isDark ? colors.onSurface : Colors.black87,
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
        width: 66,
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.blueGrey[700]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.blueGrey[700], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
