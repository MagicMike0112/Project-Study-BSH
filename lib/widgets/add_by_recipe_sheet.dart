// lib/widgets/add_by_recipe_sheet.dart
import 'dart:convert';
import 'dart:io'; // NOTE: legacy comment cleaned.
import 'package:flutter/foundation.dart'
    show kIsWeb; // NOTE: legacy comment cleaned.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../repositories/inventory_repository.dart';
import '../utils/app_haptics.dart';
import '../utils/app_locale.dart';
import '../l10n/app_localizations.dart';
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
  static const String _backendUrl =
      'https://project-study-bsh.vercel.app/api/shop-by-recipe';
  static const Color _brandBlue = Color(0xFF1B78FF);
  static const Color _brandBlueDeep = Color(0xFF135BE8);
  static const Color _brandGreen = Color(0xFF16A34A);

  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  // NOTE: legacy comment cleaned.
  Future<void> _pickImage(ImageSource source) async {
    if (!_isLoggedIn) {
      _showLoginRequiredAction();
      return;
    }
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await _picker.pickMultiImage(
          imageQuality: 70, // NOTE: legacy comment cleaned.
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
    final l10n = AppLocalizations.of(context);
    AppHaptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.shoppingRecipeSignInRequiredAction ?? "Please sign in to use AI Recipe Scan."),
        action: SnackBarAction(
          label: l10n?.shoppingRecipeSignInAction ?? "SIGN IN",
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const LoginPage(allowSkip: false)),
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeRecipe() async {
    final l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      _showLoginRequiredAction();
      return;
    }

    if (_textController.text.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n?.shoppingRecipeProvideInput ?? "Please provide a recipe name, text, or image.")),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final locale = AppLocale.fromContext(context);
      final inventoryData = widget.repo
          .getActiveItems()
          .map((e) => {
                'name': e.name,
                'category': e.category,
              })
          .toList();

      List<String> base64Images = [];
      for (var img in _selectedImages) {
        final bytes = await img.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept-Language': locale,
          'X-App-Locale': locale,
        },
        body: jsonEncode({
          'text': _textController.text,
          'imagesBase64': base64Images,
          'currentInventory': inventoryData,
          'locale': locale,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.body}");
      }

      final data = jsonDecode(response.body);
      final List rawItems = data['items'] ?? [];
      setState(() {
        _detectedItems = rawItems.map((item) {
          return {
            'name': item['name'],
            'category': item['category'],
            'isSeasoning': item['isSeasoning'] == true,
            'inStock': item['inStock'] ?? false,
            'reason': item['reason'] ?? '',
            'selected': !(item['inStock'] ?? false),
          };
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.shoppingRecipeAnalysisFailed(e.toString()) ?? "Analysis failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _confirmImport() async {
    final l10n = AppLocalizations.of(context);
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
        SnackBar(content: Text(l10n?.shoppingRecipeAddedItems(toAdd.length) ?? "Added ${toAdd.length} items to shopping list")),
      );
    }
  }

  bool _isSeasoningItem(Map<String, dynamic> item) {
    if (item['isSeasoning'] == true) return true;
    final category = (item['category'] ?? '').toString().toLowerCase();
    final name = (item['name'] ?? '').toString().toLowerCase();
    if (category.contains('season')) return true;
    if (category.contains('spice')) return true;
    if (category.contains('condiment')) return true;
    if (category == 'pantry') {
      return name.contains('salt') ||
          name.contains('sugar') ||
          name.contains('pepper') ||
          name.contains('soy') ||
          name.contains('vinegar') ||
          name.contains('sauce') ||
          name.contains('oil') ||
          name.contains('sesame') ||
          name.contains('garlic powder') ||
          name.contains('paprika') ||
          name.contains('cumin') ||
          name.contains('oregano') ||
          name.contains('basil') ||
          name.contains('chili') ||
          name.contains('\u9171') ||
          name.contains('\u76d0') ||
          name.contains('\u7cd6') ||
          name.contains('\u6cb9') ||
          name.contains('\u918b') ||
          name.contains('\u80e1\u6912') ||
          name.contains('\u8c03\u5473') ||
          name.contains('\u9999\u6599');
    }
    return false;
  }

  Widget _buildDetectedItemTile(
    BuildContext context,
    Map<String, dynamic> item, {
    required Color cardBg,
    required Color subtleBg,
    required Color success,
    required Color accentStrong,
    required ColorScheme colors,
    required bool isDark,
  }) {
    final l10n = AppLocalizations.of(context);
    final bool inStock = item['inStock'];
    return Container(
      decoration: BoxDecoration(
        color: inStock
            ? success.withValues(alpha: isDark ? 0.22 : 0.10)
            : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inStock
              ? success.withValues(alpha: isDark ? 0.45 : 0.25)
              : colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: CheckboxListTile(
        value: item['selected'],
        onChanged: (v) => setState(() => item['selected'] = v),
        title: Text(
          item['name'],
          style:
              TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        subtitle: Text(
          inStock
              ? (l10n?.shoppingRecipeInStockReason(item['reason']?.toString() ?? '') ??
                  "In stock: ${item['reason']}")
              : (l10n?.shoppingRecipeCategoryLabel(item['category']?.toString() ?? '') ??
                  "Category: ${item['category']}"),
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: inStock ? success : subtleBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            inStock ? Icons.inventory : Icons.shopping_basket,
            color: inStock
                ? Colors.white
                : colors.onSurface.withValues(alpha: 0.76),
            size: 18,
          ),
        ),
        activeColor: accentStrong,
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: colors.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF111827) : colors.surface;
    final cardBg = isDark ? const Color(0xFF162237) : const Color(0xFFF6F9FF);
    final subtleBg = isDark ? const Color(0xFF1C2A40) : const Color(0xFFEFF4FF);
    final inputBg = isDark ? const Color(0xFF121D2F) : Colors.white;
    final accent = isDark ? const Color(0xFF63A9FF) : _brandBlue;
    final accentStrong = isDark ? const Color(0xFF4D95F2) : _brandBlueDeep;
    final success = isDark ? const Color(0xFF4ADE80) : _brandGreen;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: _isLoggedIn
                    ? accent
                    : colors.onSurface.withValues(alpha: 0.4),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                l10n?.shoppingRecipeImportTitle ?? "Recipe Import",
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
            _buildLoginPlaceholder(
              backgroundColor: subtleBg,
              iconColor: colors.onSurface.withValues(alpha: 0.42),
              accentColor: accentStrong,
            )
          else ...[
            TextField(
              controller: _textController,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: l10n?.shoppingRecipeInputHint ?? "Enter dish name or paste recipe...",
                filled: true,
                fillColor: inputBg,
                hintStyle:
                    TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.55)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent, width: 1.4),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // NOTE: legacy comment cleaned.
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none, // NOTE: legacy comment cleaned.
                children: [
                  _ImageActionButton(
                    icon: Icons.add_a_photo,
                    label: l10n?.shoppingRecipeCamera ?? "Camera",
                    onTap: () => _pickImage(ImageSource.camera),
                    backgroundColor: subtleBg,
                    foregroundColor: colors.onSurface.withValues(alpha: 0.78),
                  ),
                  const SizedBox(width: 8),
                  _ImageActionButton(
                    icon: Icons.photo_library,
                    label: l10n?.shoppingRecipeAlbum ?? "Album",
                    onTap: () => _pickImage(ImageSource.gallery),
                    backgroundColor: subtleBg,
                    foregroundColor: colors.onSurface.withValues(alpha: 0.78),
                  ),
                  if (_selectedImages.isNotEmpty)
                    const VerticalDivider(width: 24, indent: 10, endIndent: 10),

                  // NOTE: legacy comment cleaned.
                  ..._selectedImages.map((img) => Padding(
                        padding: const EdgeInsets.only(right: 14.0, top: 4),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: colors.outlineVariant
                                        .withValues(alpha: 0.65)),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: kIsWeb
                                    ? Image.network(img.path, fit: BoxFit.cover)
                                    : Image.file(File(img.path),
                                        fit: BoxFit.cover),
                              ),
                            ),
                            // NOTE: legacy comment cleaned.
                            Positioned(
                              right: -6,
                              top: -6,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedImages.remove(img)),
                                child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Color(0xFFEF4444),
                                    child: Icon(Icons.close,
                                        size: 12, color: Colors.white)),
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
                  backgroundColor: accentStrong,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isAnalyzing
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text(l10n?.shoppingRecipeAnalyzing ?? "Analyzing...")
                      ])
                    : Text(l10n?.shoppingRecipeGetListButton ?? "Get Shopping list",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

            Expanded(
              child: _detectedItems.isEmpty
                  ? Center(
                      child: Text(
                        _isAnalyzing
                            ? (l10n?.shoppingRecipeAiThinking ?? "AI is thinking...")
                            : (l10n?.shoppingRecipeResultsPlaceholder ?? "Your results will appear here"),
                        style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final seasonings = <Map<String, dynamic>>[];
                        final ingredients = <Map<String, dynamic>>[];
                        for (final item in _detectedItems) {
                          if (_isSeasoningItem(item)) {
                            seasonings.add(item);
                          } else {
                            ingredients.add(item);
                          }
                        }

                        final rows = <Widget>[];
                        if (ingredients.isNotEmpty) {
                          rows.add(
                            _buildSectionHeader(
                              l10n?.shoppingRecipeIngredientsSection ??
                                  'Ingredients',
                              colors,
                            ),
                          );
                          for (var i = 0; i < ingredients.length; i++) {
                            rows.add(_buildDetectedItemTile(
                              context,
                              ingredients[i],
                              cardBg: cardBg,
                              subtleBg: subtleBg,
                              success: success,
                              accentStrong: accentStrong,
                              colors: colors,
                              isDark: isDark,
                            ));
                            if (i != ingredients.length - 1 ||
                                seasonings.isNotEmpty) {
                              rows.add(const SizedBox(height: 8));
                            }
                          }
                        }

                        if (seasonings.isNotEmpty) {
                          rows.add(
                            _buildSectionHeader(
                              l10n?.shoppingRecipeSeasoningsSection ??
                                  'Seasonings',
                              colors,
                            ),
                          );
                          for (var i = 0; i < seasonings.length; i++) {
                            rows.add(_buildDetectedItemTile(
                              context,
                              seasonings[i],
                              cardBg: cardBg,
                              subtleBg: subtleBg,
                              success: success,
                              accentStrong: accentStrong,
                              colors: colors,
                              isDark: isDark,
                            ));
                            if (i != seasonings.length - 1) {
                              rows.add(const SizedBox(height: 8));
                            }
                          }
                        }

                        return ListView(
                          children: rows,
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
                      backgroundColor: accentStrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                        l10n?.shoppingRecipeAddSelectedToList(
                              _detectedItems.where((i) => i['selected']).length,
                            ) ??
                            "Add ${_detectedItems.where((i) => i['selected']).length} Items to List"),
                  ),
                ),
              ),
          ]
        ],
      ),
    );
  }

  Widget _buildLoginPlaceholder({
    required Color backgroundColor,
    required Color iconColor,
    required Color accentColor,
  }) {
    final l10n = AppLocalizations.of(context);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
                BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, size: 48, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(l10n?.shoppingRecipeSignInRequiredTitle ?? "Sign in Required",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            l10n?.shoppingRecipeSignInRequiredSubtitle ??
                "Please sign in to sync with your inventory\nand use AI recipe analysis.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginPage(allowSkip: false))),
              style: FilledButton.styleFrom(backgroundColor: accentColor),
              child: Text(l10n?.shoppingRecipeSignInNow ?? "Sign In Now"),
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
  final Color backgroundColor;
  final Color foregroundColor;
  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: foregroundColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

