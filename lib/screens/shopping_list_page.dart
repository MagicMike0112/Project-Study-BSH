// lib/screens/shopping_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../repositories/inventory_repository.dart';
import 'shopping_archive_page.dart';

class ShoppingListPage extends StatefulWidget {
  final InventoryRepository repo;

  const ShoppingListPage({super.key, required this.repo});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _controller = TextEditingController();
  
  // 🟢 智能建议列表：展示我们“懂用户”的能力
  final List<String> _suggestions = [
    'Milk', 'Eggs', 'Avocado', 'Sourdough', 'Chicken Breast', 
    'Toilet Paper', 'Olive Oil', 'Coffee', 'Greek Yogurt', 'Dark Chocolate'
  ];
  
  void _showAutoDismissSnackBar(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 20), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  message, 
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onUndo != null)
                GestureDetector(
                  onTap: () {
                    onUndo();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'UNDO',
                      style: TextStyle(
                        color: Color(0xFF81D4FA), 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          controller.close();
        } catch (_) {}
      }
    });
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addItem(String name) async {
    if (name.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    final newItem = ShoppingItem(
      id: const Uuid().v4(),
      name: name.trim(),
      category: _guessCategory(name),
      isChecked: false,
    );

    await widget.repo.saveShoppingItem(newItem);
    _controller.clear();
  }

  // 🧠 核心升级：懂用户的智能分类引擎
  String _guessCategory(String name) {
    final n = name.toLowerCase();

    // 0. 特例处理 (Context Aware)
    // "Peanut Butter" 属于 Pantry，不属于 Dairy (Butter)
    if (n.contains('peanut butter')) return 'pantry';
    // "Almond Milk" 属于 Dairy/Alternative，不属于 Snacks (Nut)
    if (n.contains('coconut milk') || n.contains('almond milk') || n.contains('soy milk') || n.contains('oat milk')) return 'dairy'; 

    // 1. Pet (宠物) - 优先级最高，避免误判
    if (n.contains('cat') || n.contains('dog') || n.contains('puppy') || n.contains('kitten') || 
        n.contains('litter') || n.contains('pet') || n.contains('hamster') || n.contains('rabbit') || 
        n.contains('guinea') || n.contains('hay') || n.contains('pellet') || n.contains('bird') || n.contains('fish food')) {
      return 'pet';
    }

    // 2. Household & Personal (日用 & 个护)
    if (n.contains('paper') || n.contains('tissue') || n.contains('towel') || n.contains('toilet') || n.contains('napkin') || 
        n.contains('soap') || n.contains('shampoo') || n.contains('conditioner') || n.contains('wash') || n.contains('clean') || 
        n.contains('detergent') || n.contains('bleach') || n.contains('softener') || 
        n.contains('brush') || n.contains('paste') || n.contains('floss') || 
        n.contains('trash') || n.contains('bag') || n.contains('foil') || n.contains('wrap') || 
        n.contains('battery') || n.contains('bulb') || n.contains('sponge') || n.contains('wipe')) {
      return 'household';
    }

    // 3. Frozen (冷冻)
    if (n.contains('frozen') || n.contains('ice cream') || n.contains('gelato') || n.contains('sorbet') || 
        n.contains('pizza') || n.contains('fries') || n.contains('nuggets') || n.contains('waffles') && n.contains('frozen')) {
      return 'frozen';
    }

    // 4. Beverages (饮品)
    if (n.contains('water') || n.contains('juice') || n.contains('soda') || n.contains('coke') || n.contains('pepsi') || n.contains('sprite') || n.contains('drink') || 
        n.contains('beer') || n.contains('wine') || n.contains('liquor') || n.contains('alcohol') || n.contains('vodka') || n.contains('whisky') || n.contains('gin') || 
        n.contains('coffee') || n.contains('tea') || n.contains('espresso') || n.contains('latte') || n.contains('cappuccino') || 
        n.contains('lemonade') || n.contains('smoothie')) {
      return 'beverage';
    }

    // 5. Bakery (烘焙)
    if (n.contains('bread') || n.contains('toast') || n.contains('bagel') || n.contains('bun') || n.contains('roll') || 
        n.contains('croissant') || n.contains('baguette') || n.contains('sourdough') || 
        n.contains('cake') || n.contains('muffin') || n.contains('cupcake') || n.contains('brownie') || n.contains('pie') || n.contains('tart') || 
        n.contains('pastry') || n.contains('doughnut') || n.contains('donut') || 
        n.contains('flour') || n.contains('sugar') || n.contains('baking') || n.contains('yeast') || n.contains('tortilla') || n.contains('pita')) {
      return 'bakery';
    }

    // 6. Dairy & Eggs (乳制品 & 蛋)
    if (n.contains('milk') || n.contains('cream') || n.contains('yogurt') || n.contains('yoghurt') || n.contains('kefir') || 
        n.contains('cheese') || n.contains('cheddar') || n.contains('mozzarella') || n.contains('brie') || n.contains('parmesan') || n.contains('feta') || n.contains('ricotta') || 
        n.contains('butter') || n.contains('margarine') || 
        n.contains('egg')) {
      return 'dairy';
    }

    // 7. Seafood (海鲜)
    if (n.contains('fish') || n.contains('salmon') || n.contains('tuna') || n.contains('cod') || n.contains('tilapia') || n.contains('bass') || n.contains('trout') || 
        n.contains('halibut') || n.contains('sole') || 
        n.contains('shrimp') || n.contains('prawn') || n.contains('crab') || n.contains('lobster') || n.contains('clam') || n.contains('mussel') || 
        n.contains('oyster') || n.contains('scallop') || n.contains('squid') || n.contains('calamari') || n.contains('octopus')) {
      return 'seafood';
    }

    // 8. Meat (肉类)
    if (n.contains('chicken') || n.contains('turkey') || n.contains('duck') || 
        n.contains('beef') || n.contains('steak') || n.contains('ribeye') || n.contains('sirloin') || n.contains('filet') || n.contains('brisket') || n.contains('burger') || n.contains('ground') || 
        n.contains('pork') || n.contains('chop') || n.contains('ribs') || n.contains('bacon') || n.contains('ham') || n.contains('sausage') || n.contains('salami') || n.contains('pepperoni') || n.contains('hot dog') || 
        n.contains('lamb') || n.contains('veal') || n.contains('meat')) {
      return 'meat';
    }

    // 9. Produce (蔬果)
    if (n.contains('apple') || n.contains('banana') || n.contains('orange') || n.contains('lemon') || n.contains('lime') || n.contains('grape') || n.contains('pear') || n.contains('peach') || n.contains('plum') || n.contains('nectarine') || n.contains('apricot') || 
        n.contains('berry') || n.contains('strawberry') || n.contains('blueberry') || n.contains('raspberry') || n.contains('blackberry') || 
        n.contains('melon') || n.contains('watermelon') || n.contains('cantaloupe') || n.contains('honeydew') || 
        n.contains('kiwi') || n.contains('mango') || n.contains('pineapple') || n.contains('papaya') || n.contains('pomegranate') || n.contains('cherry') || n.contains('fig') || n.contains('date') || n.contains('avocado') || n.contains('coconut') || 
        n.contains('tomato') || n.contains('cucumber') || n.contains('pepper') || n.contains('chili') || n.contains('jalapeno') || 
        n.contains('carrot') || n.contains('potato') || n.contains('sweet potato') || n.contains('yam') || n.contains('onion') || n.contains('garlic') || n.contains('shallot') || n.contains('ginger') || 
        n.contains('lettuce') || n.contains('spinach') || n.contains('kale') || n.contains('arugula') || n.contains('cabbage') || n.contains('broccoli') || n.contains('cauliflower') || n.contains('asparagus') || n.contains('celery') || 
        n.contains('zucchini') || n.contains('squash') || n.contains('pumpkin') || n.contains('eggplant') || n.contains('aubergine') || n.contains('corn') || n.contains('pea') || n.contains('bean') || n.contains('mushroom') || 
        n.contains('herb') || n.contains('basil') || n.contains('parsley') || n.contains('cilantro') || n.contains('coriander') || n.contains('dill') || n.contains('mint') || n.contains('rosemary') || n.contains('thyme') || 
        n.contains('fruit') || n.contains('veg') || n.contains('salad')) {
      return 'produce';
    }

    // 10. Snacks (零食)
    if (n.contains('chip') || n.contains('crisp') || n.contains('popcorn') || n.contains('pretzel') || 
        n.contains('nut') || n.contains('peanut') || n.contains('almond') || n.contains('cashew') || n.contains('walnut') || n.contains('pecan') || n.contains('pistachio') || 
        n.contains('cookie') || n.contains('biscuit') || n.contains('cracker') || 
        n.contains('chocolate') || n.contains('candy') || n.contains('sweet') || n.contains('gum') || n.contains('jelly') || n.contains('snack') || n.contains('bar')) {
      return 'snacks';
    }

    // 11. Pantry (粮油副食)
    if (n.contains('rice') || n.contains('pasta') || n.contains('spaghetti') || n.contains('macaroni') || n.contains('noodle') || n.contains('quinoa') || n.contains('couscous') || n.contains('oat') || n.contains('cereal') || n.contains('granola') || 
        n.contains('oil') || n.contains('olive oil') || n.contains('vegetable oil') || n.contains('canola oil') || 
        n.contains('sauce') || n.contains('soy sauce') || n.contains('ketchup') || n.contains('mayo') || n.contains('mustard') || n.contains('bbq') || n.contains('dressing') || n.contains('salsa') || n.contains('hummus') || 
        n.contains('soup') || n.contains('stock') || n.contains('broth') || n.contains('bouillon') || 
        n.contains('can') || n.contains('tin') || n.contains('jar') || 
        n.contains('salt') || n.contains('pepper') || n.contains('spice') || n.contains('seasoning') || n.contains('curry') || n.contains('cinnamon') || n.contains('vanilla') || 
        n.contains('honey') || n.contains('syrup') || n.contains('jam') || n.contains('jelly') || n.contains('spread')) {
      return 'pantry';
    }

    return 'general';
  }

  Future<void> _moveCheckedToInventory(BuildContext context, List<ShoppingItem> checkedItems) async {
    HapticFeedback.mediumImpact();

    await widget.repo.checkoutShoppingItems(checkedItems);

    if (context.mounted) {
      _showAutoDismissSnackBar('${checkedItems.length} items moved to Inventory! 🧊');
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F9FC);
    const primary = Color(0xFF005F87);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Shopping List', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            tooltip: 'Purchase History',
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShoppingArchivePage(
                    repo: widget.repo,
                    onAddBack: (name, category) => _addItem(name),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // 使用 ListenableBuilder 监听 Repo
      body: ListenableBuilder(
        listenable: widget.repo,
        builder: (context, child) {
          final allItems = widget.repo.getShoppingList();
          final activeItems = allItems.where((i) => !i.isChecked).toList();
          final checkedItems = allItems.where((i) => i.isChecked).toList();

          return Column(
            children: [
              // 顶部建议栏
              if (_suggestions.isNotEmpty)
                FadeInSlide(
                  index: 0,
                  child: SizedBox(
                    height: 60,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      itemBuilder: (ctx, i) {
                        final sug = _suggestions[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: BouncingButton(
                            onTap: () => _addItem(sug),
                            child: Chip(
                              elevation: 0,
                              side: BorderSide(color: primary.withOpacity(0.1)),
                              backgroundColor: Colors.white,
                              label: Text(sug, style: const TextStyle(fontSize: 13)),
                              avatar: const Icon(Icons.add, size: 16, color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: primary.withOpacity(0.1)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              
              // 列表区域
              Expanded(
                child: allItems.isEmpty
                    ? FadeInSlide(index: 1, child: _buildEmptyState())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        children: [
                          // 未完成项
                          ...activeItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                          
                          // 分割线
                          if (activeItems.isNotEmpty && checkedItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Completed', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ),

                          // 已完成项
                          ...checkedItems.asMap().entries.map((entry) => FadeInSlide(
                            key: ValueKey(entry.value.id),
                            index: 1 + activeItems.length + (entry.key > 5 ? 5 : entry.key),
                            child: _buildDismissibleItem(entry.value),
                          )),
                          
                          // 底部留白给 BottomSheet
                          if (checkedItems.isNotEmpty) const SizedBox(height: 80), 
                        ],
                      ),
              ),
            ],
          );
        },
      ),

      // 底部输入框和结算按钮
      bottomSheet: ListenableBuilder(
        listenable: widget.repo,
        builder: (context, child) {
          final items = widget.repo.getShoppingList();
          final checkedItems = items.where((i) => i.isChecked).toList();

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checkedItems.isNotEmpty) ...[
                  BouncingButton(
                    onTap: () => _moveCheckedToInventory(context, checkedItems),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Move ${checkedItems.length} items to Fridge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addItem,
                  decoration: InputDecoration(
                    hintText: 'Add item (e.g. Milk)...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded),
                      color: primary,
                      onPressed: () => _addItem(_controller.text),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildDismissibleItem(ShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.repo.deleteShoppingItem(item);
        
        _showAutoDismissSnackBar(
          'Deleted "${item.name}"',
          onUndo: () => widget.repo.saveShoppingItem(item),
        );
      },
      child: _ShoppingTile(
        item: item,
        onToggle: () {
          HapticFeedback.selectionClick();
          widget.repo.toggleShoppingItemStatus(item);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_checkout_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Your list is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Add suggestions above or type your own.', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// 🟢 优雅的头像 Tag
class _UserAvatarTag extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatarTag({required this.name, this.size = 20});

  Color _getNameColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue.shade600,
      Colors.red.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _getNameColor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Tooltip(
      message: 'Added by $name',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2), // 白色边框增加对比度
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ================== Helper Widgets ==================

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;

  const _ShoppingTile({required this.item, required this.onToggle});

  // 🟢 升级：更丰富的颜色映射
  Color _catColor(String c) {
    switch(c) {
      case 'pet': return const Color(0xFF795548); // Brown
      case 'household': return const Color(0xFF607D8B); // BlueGrey
      case 'frozen': return const Color(0xFF00BCD4); // Cyan
      case 'beverage': return const Color(0xFF009688); // Teal
      case 'bakery': return const Color(0xFFFFC107); // Amber
      case 'dairy': return const Color(0xFF2196F3); // Blue
      case 'seafood': return const Color(0xFF3F51B5); // Indigo
      case 'meat': return const Color(0xFFE53935); // Red
      case 'produce': return const Color(0xFF4CAF50); // Green
      case 'snacks': return const Color(0xFFFF5722); // DeepOrange
      case 'pantry': return const Color(0xFFFF9800); // Orange
      default: return Colors.grey;
    }
  }

  // 🟢 升级：更丰富的图标映射 (Material Rounded)
  IconData _catIcon(String c) {
    switch(c) {
      case 'pet': return Icons.pets_rounded;
      case 'household': return Icons.cleaning_services_rounded;
      case 'frozen': return Icons.ac_unit_rounded;
      case 'beverage': return Icons.local_drink_rounded;
      case 'bakery': return Icons.bakery_dining_rounded;
      case 'dairy': return Icons.water_drop_rounded; 
      case 'seafood': return Icons.set_meal_rounded;
      case 'meat': return Icons.restaurant_rounded;
      case 'produce': return Icons.eco_rounded;
      case 'snacks': return Icons.cookie_rounded;
      case 'pantry': return Icons.kitchen_rounded;
      default: return Icons.shopping_bag_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor(item.category);
    final isDone = item.isChecked;

    return BouncingButton(
      onTap: onToggle,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDone ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDone ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDone ? color : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isDone 
                    ? const Icon(Icons.check, size: 16, color: Colors.white) 
                    : null,
                ),
                const SizedBox(width: 16),
                
                // 🟢 优雅修改：将头像 Tag 叠加在图标右下角
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_catIcon(item.category), size: 18, color: color),
                    ),
                    if (item.ownerName != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: _UserAvatarTag(name: item.ownerName!, size: 16),
                      ),
                  ],
                ),
                
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDone ? Colors.grey[600] : Colors.black87,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const BouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.enabled) {
          _controller.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (widget.enabled) _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _controller.value,
          child: widget.child,
        ),
      ),
    );
  }
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index; 
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    final delay = widget.index * 50; 
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _offsetAnim,
        child: widget.child,
      ),
    );
  }
}