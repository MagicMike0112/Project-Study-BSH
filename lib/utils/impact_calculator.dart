// lib/utils/impact_calculator.dart

class ImpactFactors {
  final double pricePerKg; // 欧元 €
  final double co2PerKg;   // kg CO2e (二氧化碳当量)

  const ImpactFactors(this.pricePerKg, this.co2PerKg);
}

class ImpactCalculator {
  // === 1. 基础数据表 (2024 欧洲平均估值) ===
  // CO2 数据来源参考: Our World in Data / Carbon Cloud
  static final Map<String, ImpactFactors> _categoryFactors = {
    'meat': const ImpactFactors(15.0, 20.0),    // 肉类平均 (含红肉)
    'dairy': const ImpactFactors(5.0, 3.0),     // 乳制品平均
    'produce': const ImpactFactors(3.0, 0.5),   // 蔬果平均
    'fruit': const ImpactFactors(3.0, 0.4),
    'vegetable': const ImpactFactors(2.5, 0.4),
    'pantry': const ImpactFactors(2.0, 1.5),    // 谷物/干货
    'bakery': const ImpactFactors(4.0, 0.8),
    'seafood': const ImpactFactors(20.0, 10.0),
    'beverage': const ImpactFactors(2.0, 0.5),
    'general': const ImpactFactors(4.0, 2.5),   // 默认兜底
  };

  // === 2. 关键词匹配表 (高优先级) ===
  // 越具体的词放前面，包含英文和部分常见中文(如果需要)
  static final Map<String, ImpactFactors> _keywordFactors = {
    // --- 肉类 (高碳排) ---
    'beef': const ImpactFactors(20.0, 60.0),     // 牛肉：碳排之王
    'steak': const ImpactFactors(30.0, 60.0),
    'burger': const ImpactFactors(15.0, 40.0),
    'lamb': const ImpactFactors(18.0, 24.0),     // 羊肉
    'pork': const ImpactFactors(9.0, 7.0),       // 猪肉
    'bacon': const ImpactFactors(12.0, 8.0),
    'ham': const ImpactFactors(12.0, 7.0),
    'chicken': const ImpactFactors(8.0, 6.0),    // 鸡肉
    'turkey': const ImpactFactors(9.0, 6.0),
    'duck': const ImpactFactors(12.0, 7.0),
    'sausage': const ImpactFactors(10.0, 6.5),

    // --- 海鲜 ---
    'salmon': const ImpactFactors(22.0, 12.0),
    'tuna': const ImpactFactors(18.0, 10.0),
    'shrimp': const ImpactFactors(25.0, 18.0),   // 虾 (养殖碳排较高)
    'prawn': const ImpactFactors(25.0, 18.0),
    'fish': const ImpactFactors(15.0, 8.0),

    // --- 乳制品 & 蛋 ---
    'cheese': const ImpactFactors(12.0, 21.0),   // 奶酪碳排很高
    'cheddar': const ImpactFactors(12.0, 21.0),
    'mozzarella': const ImpactFactors(11.0, 19.0),
    'butter': const ImpactFactors(10.0, 12.0),
    'milk': const ImpactFactors(1.5, 3.0),
    'yogurt': const ImpactFactors(3.0, 2.5),
    'cream': const ImpactFactors(6.0, 4.0),
    'egg': const ImpactFactors(4.5, 4.5),        // 蛋

    // --- 植物蛋白 (低碳排替代品) ---
    'tofu': const ImpactFactors(4.0, 3.0),       // 豆腐
    'tempeh': const ImpactFactors(5.0, 2.5),
    'beans': const ImpactFactors(2.5, 1.0),      // 豆类
    'lentil': const ImpactFactors(3.0, 0.9),
    'chickpea': const ImpactFactors(3.0, 0.8),
    'hummus': const ImpactFactors(6.0, 1.5),
    'nut': const ImpactFactors(15.0, 0.5),       // 坚果 (极低碳，甚至负碳)
    'almond': const ImpactFactors(12.0, 0.7),

    // --- 主食/碳水 ---
    'rice': const ImpactFactors(2.5, 4.0),       // 大米 (有甲烷排放)
    'pasta': const ImpactFactors(2.0, 1.5),
    'noodle': const ImpactFactors(2.5, 1.5),
    'bread': const ImpactFactors(3.0, 0.8),
    'toast': const ImpactFactors(3.0, 0.8),
    'bagel': const ImpactFactors(4.0, 0.9),
    'potato': const ImpactFactors(1.5, 0.4),     // 土豆 (极其环保)
    'oat': const ImpactFactors(2.0, 0.9),
    'cereal': const ImpactFactors(5.0, 2.0),
    'flour': const ImpactFactors(1.5, 0.6),

    // --- 水果 ---
    'avocado': const ImpactFactors(8.0, 2.5),    // 牛油果 (耗水/运输)
    'apple': const ImpactFactors(2.5, 0.4),
    'banana': const ImpactFactors(1.8, 0.8),
    'orange': const ImpactFactors(2.0, 0.5),
    'grape': const ImpactFactors(4.0, 1.0),
    'berry': const ImpactFactors(10.0, 1.5),     // 浆果较贵
    'strawberry': const ImpactFactors(8.0, 1.5),
    'blueberry': const ImpactFactors(12.0, 1.5),
    'lemon': const ImpactFactors(3.0, 0.5),
    'lime': const ImpactFactors(3.0, 0.5),
    'melon': const ImpactFactors(2.0, 0.5),
    'watermelon': const ImpactFactors(1.5, 0.4),

    // --- 蔬菜 ---
    'tomato': const ImpactFactors(3.0, 1.4),     // 温室番茄碳排稍高
    'lettuce': const ImpactFactors(3.0, 0.5),
    'spinach': const ImpactFactors(4.0, 0.5),
    'kale': const ImpactFactors(4.0, 0.5),
    'carrot': const ImpactFactors(1.5, 0.4),     // 根茎类很环保
    'onion': const ImpactFactors(1.5, 0.4),
    'garlic': const ImpactFactors(6.0, 0.6),
    'pepper': const ImpactFactors(4.0, 1.0),
    'broccoli': const ImpactFactors(3.0, 0.5),
    'cucumber': const ImpactFactors(2.0, 0.8),
    'mushroom': const ImpactFactors(6.0, 1.5),

    // --- 饮品 & 零食 ---
    'coffee': const ImpactFactors(20.0, 17.0),   // 咖啡碳排很高
    'tea': const ImpactFactors(10.0, 2.0),
    'chocolate': const ImpactFactors(15.0, 19.0),// 巧克力碳排很高 (土地利用)
    'beer': const ImpactFactors(3.0, 1.0),
    'wine': const ImpactFactors(8.0, 1.5),
    'juice': const ImpactFactors(3.0, 1.0),
    'soda': const ImpactFactors(1.5, 0.5),
    'chip': const ImpactFactors(8.0, 2.5),
    'cookie': const ImpactFactors(6.0, 2.0),
    'cake': const ImpactFactors(8.0, 2.0),
    'oil': const ImpactFactors(4.0, 3.5),        // 植物油
    'olive oil': const ImpactFactors(8.0, 4.5),
  };

  // === 3. 核心计算方法 ===
  static ImpactFactors calculate(String name, String? category, double quantity, String unit) {
    // 步骤 A: 归一化重量 (统一转为 kg)
    double weightInKg = _normalizeToKg(quantity, unit, name);

    // 步骤 B: 查找匹配因子
    ImpactFactors factors = _findBestMatch(name, category);

    // 步骤 C: 计算总额
    return ImpactFactors(
      weightInKg * factors.pricePerKg,
      weightInKg * factors.co2PerKg,
    );
  }

  // 内部：查找最佳匹配系数
  static ImpactFactors _findBestMatch(String name, String? category) {
    final lowerName = name.toLowerCase();
    
    // 1. 优先匹配名字中的关键词
    for (final key in _keywordFactors.keys) {
      if (lowerName.contains(key)) {
        return _keywordFactors[key]!;
      }
    }

    // 2. 其次匹配分类
    if (category != null) {
      final lowerCat = category.toLowerCase();
      for (final key in _categoryFactors.keys) {
        if (lowerCat.contains(key)) {
          return _categoryFactors[key]!;
        }
      }
    }

    // 3. 最后用默认值
    return _categoryFactors['general']!;
  }

  // 内部：单位换算 (智能估重)
  static double _normalizeToKg(double qty, String unit, String name) {
    final u = unit.toLowerCase().trim();
    final n = name.toLowerCase();

    // 标准重量单位
    if (u == 'kg') return qty;
    if (u == 'g') return qty / 1000.0;
    if (u == 'mg') return qty / 1000000.0;
    if (u == 'lb' || u == 'lbs') return qty * 0.453592;
    if (u == 'oz') return qty * 0.0283495;

    // 容积单位 (假设密度为 1, 水)
    if (u == 'l') return qty;
    if (u == 'ml') return qty / 1000.0;
    if (u == 'cl') return qty / 100.0;
    if (u == 'cup' || u == 'cups') return qty * 0.24; // ~240ml
    if (u == 'tbsp') return qty * 0.015;
    if (u == 'tsp') return qty * 0.005;
    
    // 数量单位 (pcs, item, pack) -> 需要猜测重量
    if (u == 'pcs' || u == 'item' || u == 'unit' || u == '') {
      // 巨型
      if (n.contains('watermelon') || n.contains('pumpkin')) return qty * 4.0;
      if (n.contains('melon') || n.contains('chicken')) return qty * 1.5;
      
      // 大型
      if (n.contains('cabbage') || n.contains('lettuce') || n.contains('cauliflower') || n.contains('pineapple')) return qty * 0.8;
      if (n.contains('milk') || n.contains('juice') || n.contains('wine') || n.contains('bottle')) return qty * 1.0; 

      // 中型
      if (n.contains('apple') || n.contains('orange') || n.contains('pear') || n.contains('peach') || n.contains('potato') || n.contains('onion')) return qty * 0.15;
      if (n.contains('banana') || n.contains('cucumber') || n.contains('carrot')) return qty * 0.12;
      if (n.contains('steak') || n.contains('breast') || n.contains('chop')) return qty * 0.2; // 肉排约200g
      if (n.contains('can') || n.contains('tin')) return qty * 0.4; // 罐头约400g

      // 小型
      if (n.contains('egg')) return qty * 0.06;
      if (n.contains('kiwi') || n.contains('lemon') || n.contains('lime') || n.contains('plum')) return qty * 0.08;
      if (n.contains('garlic') || n.contains('ginger')) return qty * 0.05;
      if (n.contains('slice') || n.contains('toast')) return qty * 0.03; // 面包片 ~30g

      // 默认 "1个" = 100g
      return qty * 0.1;
    }

    // 包装单位
    if (u == 'pack' || u == 'bag' || u == 'box') {
      if (n.contains('rice') || n.contains('flour') || n.contains('sugar')) return qty * 1.0; // 1kg装
      if (n.contains('chip') || n.contains('snack')) return qty * 0.15; // 薯片 ~150g
      if (n.contains('tea') || n.contains('coffee')) return qty * 0.25; // 250g
      return qty * 0.5; // 默认一包 500g
    }

    return qty * 0.1; // 最后的兜底
  }
}