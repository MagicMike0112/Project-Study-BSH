// lib/utils/impact_calculator.dart

class ImpactFactors {
  final double pricePerKg; // NOTE: legacy comment cleaned.
  final double co2PerKg;   // NOTE: legacy comment cleaned.

  const ImpactFactors(this.pricePerKg, this.co2PerKg);
}

class ImpactCalculator {
  // NOTE: legacy comment cleaned.
  // NOTE: legacy comment cleaned.
  static final Map<String, ImpactFactors> _categoryFactors = {
    'meat': const ImpactFactors(15.0, 20.0),    // NOTE: legacy comment cleaned.
    'dairy': const ImpactFactors(5.0, 3.0),     // NOTE: legacy comment cleaned.
    'produce': const ImpactFactors(3.0, 0.5),   // NOTE: legacy comment cleaned.
    'fruit': const ImpactFactors(3.0, 0.4),
    'vegetable': const ImpactFactors(2.5, 0.4),
    'pantry': const ImpactFactors(2.0, 1.5),    // NOTE: legacy comment cleaned.
    'bakery': const ImpactFactors(4.0, 0.8),
    'seafood': const ImpactFactors(20.0, 10.0),
    'beverage': const ImpactFactors(2.0, 0.5),
    'general': const ImpactFactors(4.0, 2.5),   // NOTE: legacy comment cleaned.
  };

  // NOTE: legacy comment cleaned.
  // NOTE: legacy comment cleaned.
  static final Map<String, ImpactFactors> _keywordFactors = {
    // NOTE: legacy comment cleaned.
    'beef': const ImpactFactors(20.0, 60.0),     // NOTE: legacy comment cleaned.
    'steak': const ImpactFactors(30.0, 60.0),
    'burger': const ImpactFactors(15.0, 40.0),
    'lamb': const ImpactFactors(18.0, 24.0),     // NOTE: legacy comment cleaned.
    'pork': const ImpactFactors(9.0, 7.0),       // NOTE: legacy comment cleaned.
    'bacon': const ImpactFactors(12.0, 8.0),
    'ham': const ImpactFactors(12.0, 7.0),
    'chicken': const ImpactFactors(8.0, 6.0),    // NOTE: legacy comment cleaned.
    'turkey': const ImpactFactors(9.0, 6.0),
    'duck': const ImpactFactors(12.0, 7.0),
    'sausage': const ImpactFactors(10.0, 6.5),

    // NOTE: legacy comment cleaned.
    'salmon': const ImpactFactors(22.0, 12.0),
    'tuna': const ImpactFactors(18.0, 10.0),
    'shrimp': const ImpactFactors(25.0, 18.0),   // NOTE: legacy comment cleaned.
    'prawn': const ImpactFactors(25.0, 18.0),
    'fish': const ImpactFactors(15.0, 8.0),

    // NOTE: legacy comment cleaned.
    'cheese': const ImpactFactors(12.0, 21.0),   // NOTE: legacy comment cleaned.
    'cheddar': const ImpactFactors(12.0, 21.0),
    'mozzarella': const ImpactFactors(11.0, 19.0),
    'butter': const ImpactFactors(10.0, 12.0),
    'milk': const ImpactFactors(1.5, 3.0),
    'yogurt': const ImpactFactors(3.0, 2.5),
    'cream': const ImpactFactors(6.0, 4.0),
    'egg': const ImpactFactors(4.5, 4.5),        // NOTE: legacy comment cleaned.

    // NOTE: legacy comment cleaned.
    'tofu': const ImpactFactors(4.0, 3.0),       // NOTE: legacy comment cleaned.
    'tempeh': const ImpactFactors(5.0, 2.5),
    'beans': const ImpactFactors(2.5, 1.0),      // NOTE: legacy comment cleaned.
    'lentil': const ImpactFactors(3.0, 0.9),
    'chickpea': const ImpactFactors(3.0, 0.8),
    'hummus': const ImpactFactors(6.0, 1.5),
    'nut': const ImpactFactors(15.0, 0.5),       // NOTE: legacy comment cleaned.
    'almond': const ImpactFactors(12.0, 0.7),

    // NOTE: legacy comment cleaned.
    'rice': const ImpactFactors(2.5, 4.0),       // NOTE: legacy comment cleaned.
    'pasta': const ImpactFactors(2.0, 1.5),
    'noodle': const ImpactFactors(2.5, 1.5),
    'bread': const ImpactFactors(3.0, 0.8),
    'toast': const ImpactFactors(3.0, 0.8),
    'bagel': const ImpactFactors(4.0, 0.9),
    'potato': const ImpactFactors(1.5, 0.4),     // NOTE: legacy comment cleaned.
    'oat': const ImpactFactors(2.0, 0.9),
    'cereal': const ImpactFactors(5.0, 2.0),
    'flour': const ImpactFactors(1.5, 0.6),

    // NOTE: legacy comment cleaned.
    'avocado': const ImpactFactors(8.0, 2.5),    // NOTE: legacy comment cleaned.
    'apple': const ImpactFactors(2.5, 0.4),
    'banana': const ImpactFactors(1.8, 0.8),
    'orange': const ImpactFactors(2.0, 0.5),
    'grape': const ImpactFactors(4.0, 1.0),
    'berry': const ImpactFactors(10.0, 1.5),     // NOTE: legacy comment cleaned.
    'strawberry': const ImpactFactors(8.0, 1.5),
    'blueberry': const ImpactFactors(12.0, 1.5),
    'lemon': const ImpactFactors(3.0, 0.5),
    'lime': const ImpactFactors(3.0, 0.5),
    'melon': const ImpactFactors(2.0, 0.5),
    'watermelon': const ImpactFactors(1.5, 0.4),

    // NOTE: legacy comment cleaned.
    'tomato': const ImpactFactors(3.0, 1.4),     // NOTE: legacy comment cleaned.
    'lettuce': const ImpactFactors(3.0, 0.5),
    'spinach': const ImpactFactors(4.0, 0.5),
    'kale': const ImpactFactors(4.0, 0.5),
    'carrot': const ImpactFactors(1.5, 0.4),     // NOTE: legacy comment cleaned.
    'onion': const ImpactFactors(1.5, 0.4),
    'garlic': const ImpactFactors(6.0, 0.6),
    'pepper': const ImpactFactors(4.0, 1.0),
    'broccoli': const ImpactFactors(3.0, 0.5),
    'cucumber': const ImpactFactors(2.0, 0.8),
    'mushroom': const ImpactFactors(6.0, 1.5),

    // NOTE: legacy comment cleaned.
    'coffee': const ImpactFactors(20.0, 17.0),   // NOTE: legacy comment cleaned.
    'tea': const ImpactFactors(10.0, 2.0),
    'chocolate': const ImpactFactors(15.0, 19.0),// NOTE: legacy comment cleaned.
    'beer': const ImpactFactors(3.0, 1.0),
    'wine': const ImpactFactors(8.0, 1.5),
    'juice': const ImpactFactors(3.0, 1.0),
    'soda': const ImpactFactors(1.5, 0.5),
    'chip': const ImpactFactors(8.0, 2.5),
    'cookie': const ImpactFactors(6.0, 2.0),
    'cake': const ImpactFactors(8.0, 2.0),
    'oil': const ImpactFactors(4.0, 3.5),        // NOTE: legacy comment cleaned.
    'olive oil': const ImpactFactors(8.0, 4.5),
  };

  // NOTE: legacy comment cleaned.
  static ImpactFactors calculate(String name, String? category, double quantity, String unit) {
    // NOTE: legacy comment cleaned.
    double weightInKg = _normalizeToKg(quantity, unit, name);

    // NOTE: legacy comment cleaned.
    ImpactFactors factors = _findBestMatch(name, category);

    // NOTE: legacy comment cleaned.
    return ImpactFactors(
      weightInKg * factors.pricePerKg,
      weightInKg * factors.co2PerKg,
    );
  }

  // NOTE: legacy comment cleaned.
  static ImpactFactors _findBestMatch(String name, String? category) {
    final lowerName = name.toLowerCase();
    
    // NOTE: legacy comment cleaned.
    for (final key in _keywordFactors.keys) {
      if (lowerName.contains(key)) {
        return _keywordFactors[key]!;
      }
    }

    // NOTE: legacy comment cleaned.
    if (category != null) {
      final lowerCat = category.toLowerCase();
      for (final key in _categoryFactors.keys) {
        if (lowerCat.contains(key)) {
          return _categoryFactors[key]!;
        }
      }
    }

    // NOTE: legacy comment cleaned.
    return _categoryFactors['general']!;
  }

  // NOTE: legacy comment cleaned.
  static double _normalizeToKg(double qty, String unit, String name) {
    final u = unit.toLowerCase().trim();
    final n = name.toLowerCase();

    // NOTE: legacy comment cleaned.
    if (u == 'kg') return qty;
    if (u == 'g') return qty / 1000.0;
    if (u == 'mg') return qty / 1000000.0;
    if (u == 'lb' || u == 'lbs') return qty * 0.453592;
    if (u == 'oz') return qty * 0.0283495;

    // NOTE: legacy comment cleaned.
    if (u == 'l') return qty;
    if (u == 'ml') return qty / 1000.0;
    if (u == 'cl') return qty / 100.0;
    if (u == 'cup' || u == 'cups') return qty * 0.24; // ~240ml
    if (u == 'tbsp') return qty * 0.015;
    if (u == 'tsp') return qty * 0.005;
    
    // NOTE: legacy comment cleaned.
    if (u == 'pcs' || u == 'item' || u == 'unit' || u == '') {
      // NOTE: legacy comment cleaned.
      if (n.contains('watermelon') || n.contains('pumpkin')) return qty * 4.0;
      if (n.contains('melon') || n.contains('chicken')) return qty * 1.5;
      
      // NOTE: legacy comment cleaned.
      if (n.contains('cabbage') || n.contains('lettuce') || n.contains('cauliflower') || n.contains('pineapple')) return qty * 0.8;
      if (n.contains('milk') || n.contains('juice') || n.contains('wine') || n.contains('bottle')) return qty * 1.0; 

      // NOTE: legacy comment cleaned.
      if (n.contains('apple') || n.contains('orange') || n.contains('pear') || n.contains('peach') || n.contains('potato') || n.contains('onion')) return qty * 0.15;
      if (n.contains('banana') || n.contains('cucumber') || n.contains('carrot')) return qty * 0.12;
      if (n.contains('steak') || n.contains('breast') || n.contains('chop')) return qty * 0.2; // NOTE: legacy comment cleaned.
      if (n.contains('can') || n.contains('tin')) return qty * 0.4; // NOTE: legacy comment cleaned.

      // NOTE: legacy comment cleaned.
      if (n.contains('egg')) return qty * 0.06;
      if (n.contains('kiwi') || n.contains('lemon') || n.contains('lime') || n.contains('plum')) return qty * 0.08;
      if (n.contains('garlic') || n.contains('ginger')) return qty * 0.05;
      if (n.contains('slice') || n.contains('toast')) return qty * 0.03; // NOTE: legacy comment cleaned.

      // NOTE: legacy comment cleaned.
      return qty * 0.1;
    }

    // NOTE: legacy comment cleaned.
    if (u == 'pack' || u == 'bag' || u == 'box') {
      if (n.contains('rice') || n.contains('flour') || n.contains('sugar')) return qty * 1.0; // NOTE: legacy comment cleaned.
      if (n.contains('chip') || n.contains('snack')) return qty * 0.15; // NOTE: legacy comment cleaned.
      if (n.contains('tea') || n.contains('coffee')) return qty * 0.25; // 250g
      return qty * 0.5; // NOTE: legacy comment cleaned.
    }

    return qty * 0.1; // NOTE: legacy comment cleaned.
  }
}

