import 'package:uuid/uuid.dart';

class RecipeSuggestion {
  final String id;
  final String title;
  final String timeLabel;
  final int expiringCount;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> appliances;
  final int? ovenTempC;
  final String? description;
  final String? imageUrl;

  RecipeSuggestion({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.expiringCount,
    required this.ingredients,
    required this.steps,
    this.appliances = const [],
    this.ovenTempC,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timeLabel': timeLabel,
        'expiringCount': expiringCount,
        'ingredients': ingredients,
        'steps': steps,
        'appliances': appliances,
        'ovenTempC': ovenTempC,
        'description': description,
        'imageUrl': imageUrl,
      };

  static RecipeSuggestion fromJson(Map<String, dynamic> m) {
    final appliancesRaw = m['appliances'] ?? m['tools'];
    List<String> appliances = (appliancesRaw is List)
        ? appliancesRaw.map((x) => x.toString()).toList()
        : const <String>[];
    if (appliances.isEmpty && m['toolPill'] is String) {
      final pill = (m['toolPill'] as String).trim();
      if (pill.isNotEmpty) appliances = [pill];
    }
    int? ovenTempC;
    final v = m['ovenTempC'];
    if (v is int) {
      ovenTempC = v;
    } else if (v is num) {
      ovenTempC = v.round();
    } else if (v != null) {
      ovenTempC = int.tryParse(v.toString());
    }

    return RecipeSuggestion(
      id: m['id']?.toString() ?? const Uuid().v4(),
      title: (m['title'] ?? 'Untitled').toString(),
      timeLabel: (m['timeLabel'] ?? '20 min').toString(),
      expiringCount: int.tryParse(m['expiringCount']?.toString() ?? '0') ?? 0,
      ingredients:
          (m['ingredients'] as List? ?? []).map((x) => x.toString()).toList(),
      steps: (m['steps'] as List? ?? []).map((x) => x.toString()).toList(),
      appliances: appliances,
      ovenTempC: ovenTempC,
      description: m['description']?.toString(),
      imageUrl: m['imageUrl']?.toString(),
    );
  }

  bool get usesOven {
    final a = appliances.map((x) => x.toLowerCase()).toList();
    if (a.any(_containsOvenKeyword)) return true;
    final text = ('$title\n${steps.join('\n')}').toLowerCase();
    return _containsOvenKeyword(text);
  }

  int? inferOvenTempFromText() {
    if (ovenTempC != null) return ovenTempC;

    final raw = '$title\n${steps.join('\n')}';
    final text = raw.toLowerCase();

    final celsiusPatterns = <RegExp>[
      RegExp(r'(\d{2,3})\s*(?:\u00B0|\u00BA)?\s*(?:c|celsius)\b', caseSensitive: false),
      RegExp(r'(\d{2,3})\s*(?:\u00B0|\u00BA)?\s*(?:grad\s*c|grad)\b', caseSensitive: false),
      RegExp(r'(\d{2,3})\s*(?:\u2103|\u00b0c|\u6444\u6c0f|\u6444\u6c0f\u5ea6)', caseSensitive: false),
      RegExp(r'(?:preheat|vorheizen|auf|\u9884\u70ed)[^\d]{0,16}(\d{2,3})', caseSensitive: false),
      RegExp(r'(\d{2,3})[^\n]{0,24}(?:oven|backofen|ofen|\u70e4\u7bb1)', caseSensitive: false),
    ];

    for (final reg in celsiusPatterns) {
      final m = reg.firstMatch(raw);
      if (m == null) continue;
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null && v >= 50 && v <= 300) return v;
    }

    final fahrenheitReg =
        RegExp(r'(\d{2,3})\s*(?:\u00B0|\u00BA)?\s*f\b', caseSensitive: false);
    final mf = fahrenheitReg.firstMatch(text);
    if (mf != null) {
      final f = int.tryParse(mf.group(1) ?? '');
      if (f != null && f >= 120 && f <= 575) {
        final c = ((f - 32) * 5 / 9).round();
        if (c >= 50 && c <= 300) return c;
      }
    }

    return null;
  }

  String get appliancesLabel {
    final normalized = _normalizedTools(appliances);
    if (normalized.isNotEmpty) {
      if (normalized.length == 1) return normalized.first;
      return '${normalized.first} +${normalized.length - 1}';
    }
    final inferred = _inferToolsFromText();
    if (inferred.isNotEmpty) {
      if (inferred.length == 1) return inferred.first;
      return '${inferred.first} +${inferred.length - 1}';
    }
    return 'Basic tools';
  }

  List<String> _normalizedTools(List<String> tools) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in tools) {
      final label = _formatToolName(t);
      if (label.isEmpty || seen.contains(label)) continue;
      seen.add(label);
      out.add(label);
    }
    return out;
  }

  String _formatToolName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final k = v.toLowerCase();
    if (_containsOvenKeyword(k)) return 'Oven';
    if (k.contains('microwave')) return 'Microwave';
    if (k.contains('airfryer') || k.contains('air fryer')) return 'Air fryer';
    if (k.contains('ricecooker') || k.contains('rice cooker')) {
      return 'Rice cooker';
    }
    if (k.contains('blender')) return 'Blender';
    if (k.contains('pan') || k.contains('skillet')) return 'Pan';
    if (k.contains('pot')) return 'Pot';
    if (k.contains('knife')) return 'Knife';
    if (k.contains('stove') || k.contains('stovetop')) return 'Stovetop';
    return v;
  }

  List<String> _inferToolsFromText() {
    final text = ('$title\n${steps.join('\n')}').toLowerCase();
    final tools = <String>[];
    if (_containsOvenKeyword(text)) {
      tools.add('Oven');
    }
    if (text.contains('microwave')) {
      tools.add('Microwave');
    }
    if (text.contains('air fryer') || text.contains('airfryer')) {
      tools.add('Air fryer');
    }
    if (text.contains('rice cooker') || text.contains('ricecooker')) {
      tools.add('Rice cooker');
    }
    if (text.contains('blender')) {
      tools.add('Blender');
    }
    if (text.contains('pan') || text.contains('skillet') || text.contains('fry')) {
      tools.add('Pan');
    }
    if (text.contains('pot') || text.contains('boil') || text.contains('simmer')) {
      tools.add('Pot');
    }
    return tools;
  }

  bool _containsOvenKeyword(String text) {
    return text.contains('oven') ||
        text.contains('preheat') ||
        text.contains('bake') ||
        text.contains('backofen') ||
        text.contains('vorheiz') ||
        text.contains('backen') ||
        text.contains('\u70e4\u7bb1') ||
        text.contains('\u9884\u70ed') ||
        text.contains('\u70e4');
  }
}

