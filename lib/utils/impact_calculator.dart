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
    'meat': const ImpactFactors(12.0, 15.0),    // 肉类平均
    'dairy': const ImpactFactors(4.0, 3.0),     // 乳制品平均
    'produce': const ImpactFactors(2.5, 0.5),   // 蔬果平均
    'fruit': const ImpactFactors(3.0, 0.4),
    'vegetable': const ImpactFactors(2.0, 0.4),
    'pantry': const ImpactFactors(1.5, 1.2),    // 谷物/干货
    'bakery': const ImpactFactors(3.5, 0.8),
    'seafood': const ImpactFactors(18.0, 8.0),
    'beverage': const ImpactFactors(1.5, 0.3),
    'general': const ImpactFactors(4.0, 2.5),   // 默认兜底
  };

  // === 2. 关键词匹配表 (高优先级) ===
  // 即使分类选错了，名字对也能算准
  static final Map<String, ImpactFactors> _keywordFactors = {
    // 高碳排/高价食物
    'beef': const ImpactFactors(18.0, 60.0), // 牛肉碳排极高
    'steak': const ImpactFactors(25.0, 60.0),
    'lamb': const ImpactFactors(16.0, 24.0),
    'pork': const ImpactFactors(8.0, 7.0),
    'chicken': const ImpactFactors(7.0, 6.0),
    'cheese': const ImpactFactors(10.0, 21.0), // 奶酪碳排其实很高
    'butter': const ImpactFactors(8.0, 12.0),
    'coffee': const ImpactFactors(15.0, 17.0),
    'chocolate': const ImpactFactors(12.0, 19.0),
    
    // 低碳排/日常食物
    'milk': const ImpactFactors(1.2, 2.8),
    'egg': const ImpactFactors(4.0, 4.5),
    'rice': const ImpactFactors(2.0, 4.0), // 大米有甲烷排放
    'bread': const ImpactFactors(2.5, 0.6),
    'potato': const ImpactFactors(1.0, 0.3),
    'apple': const ImpactFactors(2.0, 0.3),
    'banana': const ImpactFactors(1.5, 0.8),
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
      // 处理 'dairy', 'produce' 等
      for (final key in _categoryFactors.keys) {
        if (lowerCat.contains(key)) {
          return _categoryFactors[key]!;
        }
      }
    }

    // 3. 最后用默认值
    return _categoryFactors['general']!;
  }

  // 内部：单位换算
  static double _normalizeToKg(double qty, String unit, String name) {
    final u = unit.toLowerCase().trim();

    if (u == 'kg' || u == 'l') return qty;
    if (u == 'g' || u == 'ml') return qty / 1000.0;
    
    if (u == 'pcs' || u == 'item') {
      // 估算 "个" 的重量
      final n = name.toLowerCase();
      if (n.contains('egg')) return qty * 0.06; // 鸡蛋 ~60g
      if (n.contains('apple') || n.contains('orange')) return qty * 0.15; // 水果 ~150g
      if (n.contains('banana')) return qty * 0.12;
      if (n.contains('water') || n.contains('bottle')) return qty * 0.5; // 瓶装水 ~500g
      if (n.contains('chicken') && n.contains('breast')) return qty * 0.2; // 鸡胸 ~200g
      return qty * 0.1; // 默认 1个 = 100g
    }

    // 其他未知单位 (如 pack, box)，默认按 500g 算
    return qty * 0.5; 
  }
}