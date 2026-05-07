// lib/utils/food_icon_mapping.dart
import '../models/food_item.dart';

String foodIconAssetForItem(FoodItem item) => foodIconAssetForName(
  item.name,
  category: item.category,
);

String foodIconAssetForName(String foodName, {String? category}) {
  final normalized = _normalizeInput(foodName);
  if (normalized.normalized.isEmpty) {
    return _buildAssetPath(_defaultIconName);
  }

  final aliasMatch = _matchAlias(normalized);
  if (aliasMatch != null) {
    final resolved = _resolveAvailableIcon(aliasMatch);
    if (resolved != null) return _buildAssetPath(resolved);
  }

  final coreTokens = _filterModifierStopwords(normalized.tokens);
  final candidates = _buildCandidates(coreTokens, normalized.tokens);
  for (final candidate in candidates) {
    final resolved = _resolveAvailableIcon(candidate);
    if (resolved != null) return _buildAssetPath(resolved);
  }

  final generalMatch = _matchGeneralFallback(normalized, category);
  if (generalMatch != null) {
    final resolved = _resolveAvailableIcon(generalMatch);
    if (resolved != null) return _buildAssetPath(resolved);
  }

  return _buildAssetPath(_defaultIconName);
}

const String _baseIconPath = 'assets/food_icons';
const String _defaultIconName = 'default';

String _buildAssetPath(String baseName) => '$_baseIconPath/$baseName.png';

class _NormalizedInput {
  const _NormalizedInput(this.normalized, this.tokens);

  final String normalized;
  final List<String> tokens;
}

_NormalizedInput _normalizeInput(String raw) {
  final lowered = raw.trim().toLowerCase();
  if (lowered.isEmpty) return const _NormalizedInput('', <String>[]);

  final spacedNumbers = lowered
      .replaceAll(RegExp(r'(?<=\d)(?=[a-z])'), ' ')
      .replaceAll(RegExp(r'(?<=[a-z])(?=\d)'), ' ');

  final cleaned = spacedNumbers
      .replaceAll(RegExp(r'[_\-]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return const _NormalizedInput('', <String>[]);

  final tokens = cleaned
      .split(' ')
      .where((t) => t.isNotEmpty)
      .where((t) => !_noiseWords.contains(t))
      .where((t) => !_isPureNumber(t))
      .toList();

  return _NormalizedInput(tokens.join(' '), tokens);
}

String? _matchAlias(_NormalizedInput input) {
  if (input.tokens.isEmpty && input.normalized.isEmpty) return null;

  final candidates = <String>[];
  final seen = <String>{};

  void addCandidate(String value) {
    final key = _normalizeAliasKey(value);
    if (key.isEmpty || !seen.add(key)) return;
    candidates.add(key);
  }

  addCandidate(input.normalized);
  if (input.normalized.contains(' ')) {
    addCandidate(input.normalized.replaceAll(' ', '_'));
  }

  final tokenCount = input.tokens.length;
  for (int size = tokenCount; size >= 1; size--) {
    for (int start = 0; start <= tokenCount - size; start++) {
      final gram = input.tokens.sublist(start, start + size).join(' ');
      addCandidate(gram);
      if (gram.contains(' ')) addCandidate(gram.replaceAll(' ', '_'));
    }
  }

  for (final key in candidates) {
    final match = _aliasLookup[key];
    if (match != null) return match;
  }

  return null;
}

String? _matchGeneralFallback(_NormalizedInput input, String? category) {
  final fromName = _matchKeywordMap(input, _generalKeywordLookup);
  if (fromName != null) return fromName;

  final rawCategory = category?.trim() ?? '';
  if (rawCategory.isEmpty) return null;
  final normalizedCategory = _normalizeInput(rawCategory);
  return _matchKeywordMap(normalizedCategory, _generalKeywordLookup);
}

String? _matchKeywordMap(_NormalizedInput input, Map<String, String> keywordLookup) {
  if (input.tokens.isEmpty && input.normalized.isEmpty) return null;

  final candidates = <String>[];
  final seen = <String>{};

  void addCandidate(String value) {
    final key = _normalizeAliasKey(value);
    if (key.isEmpty || !seen.add(key)) return;
    candidates.add(key);
  }

  addCandidate(input.normalized);
  if (input.normalized.contains(' ')) {
    addCandidate(input.normalized.replaceAll(' ', '_'));
  }

  final tokenCount = input.tokens.length;
  for (int size = tokenCount; size >= 1; size--) {
    for (int start = 0; start <= tokenCount - size; start++) {
      final gram = input.tokens.sublist(start, start + size).join(' ');
      addCandidate(gram);
      if (gram.contains(' ')) addCandidate(gram.replaceAll(' ', '_'));
    }
  }

  for (final key in candidates) {
    final match = keywordLookup[key];
    if (match != null) return match;
  }

  return null;
}

List<String> _filterModifierStopwords(List<String> tokens) {
  if (tokens.isEmpty) return tokens;
  final filtered = tokens.where((t) => !_modifierStopwords.contains(t)).toList();
  return filtered.isEmpty ? tokens : filtered;
}

List<String> _buildCandidates(List<String> coreTokens, List<String> originalTokens) {
  final results = <String>[];
  final seen = <String>{};

  void addCandidate(String value) {
    if (value.isEmpty) return;
    final key = _normalizeIconKey(value);
    if (key.isEmpty || !seen.add(key)) return;
    results.add(value);
  }

  final baseTokens = coreTokens.isNotEmpty ? coreTokens : originalTokens;
  if (baseTokens.isNotEmpty) {
    final joinedSpace = baseTokens.join(' ');
    final joinedUnderscore = baseTokens.join('_');
    addCandidate(joinedSpace);
    addCandidate(joinedUnderscore);

    final first = baseTokens.first;
    addCandidate(first);
    addCandidate(_singularize(first));

    final last = baseTokens.last;
    addCandidate(last);
    addCandidate(_singularize(last));

    if (baseTokens.length > 1) {
      for (int i = baseTokens.length - 2; i >= 0; i--) {
        final suffix = baseTokens.sublist(i).join(' ');
        addCandidate(suffix);
        addCandidate(baseTokens.sublist(i).join('_'));
      }

      for (int i = 1; i < baseTokens.length; i++) {
        final prefix = baseTokens.sublist(0, i + 1).join(' ');
        addCandidate(prefix);
        addCandidate(baseTokens.sublist(0, i + 1).join('_'));
      }
    }
  }

  if (originalTokens.isNotEmpty && originalTokens != baseTokens) {
    final last = originalTokens.last;
    addCandidate(last);
    addCandidate(_singularize(last));
  }

  return results;
}

String? _resolveAvailableIcon(String candidate) {
  final key = _normalizeIconKey(candidate);
  if (key.isEmpty) return null;
  return _availableIconLookup[key];
}

String _normalizeAliasKey(String raw) {
  final cleaned = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned;
}

String _normalizeIconKey(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _singularize(String word) {
  final cleaned = _normalizeIconKey(word);
  if (cleaned.isEmpty) return cleaned;
  final irregular = _irregularPlurals[cleaned];
  if (irregular != null) return irregular;

  if (cleaned.endsWith('ies') && cleaned.length > 3) {
    return '${cleaned.substring(0, cleaned.length - 3)}y';
  }

  if (cleaned.endsWith('oes') && cleaned.length > 3) {
    return cleaned.substring(0, cleaned.length - 2);
  }

  if (cleaned.endsWith('es') && cleaned.length > 2) {
    if (RegExp(r'(ses|xes|zes|ches|shes|sses)$').hasMatch(cleaned)) {
      return cleaned.substring(0, cleaned.length - 2);
    }
  }

  if (cleaned.endsWith('s') && !cleaned.endsWith('ss') && cleaned.length > 1) {
    return cleaned.substring(0, cleaned.length - 1);
  }

  return cleaned;
}

final Map<String, String> _availableIconLookup = {
  for (final name in _availableIconNames) _normalizeIconKey(name): name,
};

const List<String> _availableIconNames = [
  'apple',
  'avocado',
  'bakery',
  'banana',
  'basil',
  'beef',
  'bell_pepper',
  'beverage',
  'biscuit',
  'blueberry',
  'broccoli',
  'coffee',
  'carrot',
  'cereal',
  'cheese',
  'chilli',
  'chips',
  'chocolate',
  'coriander',
  'daily_necessities',
  'dairy',
  'eggs',
  'flour',
  'frozen',
  'garlic',
  'ginger',
  'grape',
  'household',
  'lamb',
  'lemon',
  'lime',
  'lychee',
  'meat',
  'milk',
  'mushroom',
  'noodle',
  'oat',
  'onion',
  'orange',
  'pantry',
  'pasta',
  'pet',
  'pizza',
  'pork',
  'rice',
  'salad',
  'seafood',
  'sweet_potato',
  'tofu',
  'tomato',
  'yogurt',
  'zucchini',
];

const Map<String, String> _rawAliases = {
  // English synonyms
  'capsicum': 'bell_pepper',
  'bell pepper': 'bell_pepper',
  'bellpepper': 'bell_pepper',
  'pepper': 'bell_pepper',
  'sweet pepper': 'bell_pepper',
  'sweet-pepper': 'bell_pepper',
  'basil': 'basil',
  'basil leaf': 'basil',
  'basil leaves': 'basil',
  'avocado': 'avocado',
  'chili': 'chilli',
  'chilli': 'chilli',
  'chile': 'chilli',
  'crisps': 'chips',
  'chips': 'chips',
  'coffee': 'coffee',
  'espresso': 'coffee',
  'cappuccino': 'coffee',
  'cookies': 'biscuit',
  'cookie': 'biscuit',
  'biscuits': 'biscuit',
  'coriander': 'coriander',
  'cilantro': 'coriander',
  'garlic': 'garlic',
  'garlic clove': 'garlic',
  'garlic cloves': 'garlic',
  'ginger': 'ginger',
  'household': 'daily_necessities',
  'daily necessities': 'daily_necessities',
  'detergent': 'daily_necessities',
  'cleaning': 'daily_necessities',
  'oatmeal': 'oat',
  'oats': 'oat',
  'oat': 'oat',
  'lychee': 'lychee',
  'blood orange': 'orange',
  'mandarin': 'orange',
  'tangerine': 'orange',
  'citrus': 'orange',
  'lemon': 'lemon',
  'lime': 'lime',
  'sweet potato': 'sweet_potato',
  'sweet_potato': 'sweet_potato',
  'sweet-potato': 'sweet_potato',
  'yam': 'sweet_potato',
  'mushroom': 'mushroom',
  'mushrooms': 'mushroom',
  'noodle': 'noodle',
  'noodles': 'noodle',
  'pasta': 'pasta',
  'rice': 'rice',
  'zucchini': 'zucchini',
  'courgette': 'zucchini',
  'tofu': 'tofu',
  'yoghurt': 'yogurt',
  'sea food': 'seafood',
  'sea-food': 'seafood',
  'fish': 'seafood',
  'shrimp': 'seafood',
  'prawn': 'seafood',
  'prawns': 'seafood',
  'salmon': 'seafood',
  'tuna': 'seafood',
  'crab': 'seafood',
  'lobster': 'seafood',

  // Chinese aliases
  '苹果': 'apple',
  '香蕉': 'banana',
  '牛肉': 'beef',
  '甜椒': 'bell_pepper',
  '彩椒': 'bell_pepper',
  '青椒': 'bell_pepper',
  '饼干': 'biscuit',
  '蓝莓': 'blueberry',
  '西兰花': 'broccoli',
  '胡萝卜': 'carrot',
  '麦片': 'cereal',
  '奶酪': 'cheese',
  '辣椒': 'chilli',
  '薯片': 'chips',
  '巧克力': 'chocolate',
  '香菜': 'coriander',
  '日用品': 'daily_necessities',
  '大蒜': 'garlic',
  '蒜': 'garlic',
  '鸡蛋': 'eggs',
  '面粉': 'flour',
  '生姜': 'ginger',
  '姜': 'ginger',
  '葡萄': 'grape',
  '羊肉': 'lamb',
  '荔枝': 'lychee',
  '牛奶': 'milk',
  '燕麦': 'oat',
  '洋葱': 'onion',
  '大葱': 'onion',
  '葱': 'onion',
  '橙子': 'orange',
  '柳橙': 'orange',
  '血橙': 'orange',
  '披萨': 'pizza',
  '猪肉': 'pork',
  '沙拉': 'salad',
  '海鲜': 'seafood',
  '鱼': 'seafood',
  '虾': 'seafood',
  '螃蟹': 'seafood',
  '红薯': 'sweet_potato',
  '地瓜': 'sweet_potato',
  '山药': 'sweet_potato',
  '豆腐': 'tofu',
  '番茄': 'tomato',
  '西红柿': 'tomato',
  '酸奶': 'yogurt',
};

final Map<String, String> _aliasLookup = _buildAliasLookup();
final Map<String, String> _generalKeywordLookup = _buildKeywordLookup(_generalKeywordFallbacks);

Map<String, String> _buildAliasLookup() {
  final result = <String, String>{};
  for (final entry in _rawAliases.entries) {
    final key = _normalizeAliasKey(entry.key);
    if (key.isEmpty || result.containsKey(key)) continue;
    result[key] = entry.value;
  }
  return result;
}

Map<String, String> _buildKeywordLookup(Map<String, String> raw) {
  final result = <String, String>{};
  for (final entry in raw.entries) {
    final key = _normalizeAliasKey(entry.key);
    if (key.isEmpty || result.containsKey(key)) continue;
    result[key] = entry.value;
  }
  return result;
}

const Set<String> _modifierStopwords = {
  'bio',
  'organic',
  'fresh',
  'small',
  'large',
  'medium',
  'big',
  'new',
  'premium',
  'mini',
  'jumbo',
  'family',
  'veggie',
  'vegetable',
  'vegetarian',
  'vegan',
  'g',
  'kg',
  'mg',
  'lb',
  'lbs',
  'oz',
  'ml',
  'l',
  'liter',
  'litre',
  'pack',
  'packs',
  'bag',
  'bags',
  'bottle',
  'bottles',
  'box',
  'boxes',
  'can',
  'cans',
  'jar',
  'jars',
  'pcs',
  'pc',
  'piece',
  'pieces',
  'sliced',
  'diced',
  'minced',
  'chopped',
  'shredded',
  'ground',
  'frozen',
  'canned',
  'dried',
  'smoked',
  'cooked',
  'raw',
};

const Map<String, String> _irregularPlurals = {
  'people': 'person',
  'men': 'man',
  'women': 'woman',
  'children': 'child',
  'teeth': 'tooth',
  'feet': 'foot',
  'geese': 'goose',
  'mice': 'mouse',
  'oxen': 'ox',
};

const Map<String, String> _generalKeywordFallbacks = {
  // Produce / vegetables / fruits
  'produce': 'salad',
  'vegetable': 'salad',
  'vegetables': 'salad',
  'veggie': 'salad',
  'veg': 'salad',
  'greens': 'salad',
  'fruit': 'salad',
  'fruits': 'salad',
  'salad': 'salad',
  'lettuce': 'salad',
  'spinach': 'salad',
  'cabbage': 'salad',
  'celery': 'salad',
  'cucumber': 'salad',
  'zucchini': 'salad',
  'mushroom': 'salad',
  'mushrooms': 'salad',

  // Meat / seafood
  'meat': 'meat',
  'poultry': 'meat',
  'chicken': 'meat',
  'turkey': 'meat',
  'bacon': 'meat',
  'ham': 'meat',
  'seafood': 'seafood',
  'fish': 'seafood',
  'shrimp': 'seafood',
  'prawn': 'seafood',
  'salmon': 'seafood',
  'tuna': 'seafood',
  'crab': 'seafood',
  'lobster': 'seafood',
  'clam': 'seafood',
  'oyster': 'seafood',
  'mussel': 'seafood',
  'squid': 'seafood',
  'octopus': 'seafood',

  // Dairy / bakery
  'dairy': 'dairy',
  'milk': 'dairy',
  'cheese': 'dairy',
  'yogurt': 'dairy',
  'butter': 'dairy',
  'cream': 'dairy',
  'bakery': 'bakery',
  'bread': 'bakery',
  'pastry': 'bakery',
  'cake': 'bakery',
  'cookie': 'bakery',
  'cookies': 'bakery',

  // Pantry / snacks / beverages
  'pantry': 'pantry',
  'grain': 'pantry',
  'grains': 'pantry',
  'rice': 'pantry',
  'pasta': 'pantry',
  'noodle': 'pantry',
  'noodles': 'pantry',
  'flour': 'pantry',
  'oat': 'pantry',
  'oats': 'pantry',
  'spice': 'pantry',
  'spices': 'pantry',
  'sauce': 'pantry',
  'condiment': 'pantry',
  'condiments': 'pantry',
  'oil': 'pantry',
  'sugar': 'pantry',
  'salt': 'pantry',
  'snack': 'chips',
  'snacks': 'chips',
  'chips': 'chips',
  'chocolate': 'chips',
  'biscuit': 'chips',
  'beverage': 'beverage',
  'drink': 'beverage',
  'drinks': 'beverage',
  'juice': 'beverage',
  'coffee': 'beverage',
  'tea': 'beverage',
  'water': 'beverage',
  'soda': 'beverage',

  // Household / frozen / pet
  'household': 'household',
  'cleaning': 'household',
  'detergent': 'household',
  'soap': 'household',
  'tissue': 'household',
  'paper': 'household',
  'frozen': 'frozen',
  'ice': 'frozen',
  'ice cream': 'frozen',
  'pet': 'pet',
  'dog': 'pet',
  'cat': 'pet',
};

const Set<String> _noiseWords = {
  ..._modifierStopwords,
  'packaged',
  'package',
  'vacuum',
  'vacuumed',
  'freshly',
  'size',
  'value',
};

bool _isPureNumber(String token) {
  return RegExp(r'^\d+([.,]\d+)?$').hasMatch(token);
}

// Examples:
// "Blood Orange" -> assets/food_icons/orange.png
// "oats 500g" -> assets/food_icons/oat.png
// "Basil leaves" -> assets/food_icons/basil.png
// "daily necessities" / "household detergent" -> assets/food_icons/daily_necessities.png
// NOTE: legacy comment cleaned.

