// lib/services/archive_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ArchivedRecipe {
  final String archiveId; // unique per archive entry
  final String recipeId;  // original recipe id
  final int addedAtMs;

  final String title;
  final String timeLabel;
  final int expiringCount;

  final List<String> ingredients;
  final List<String> steps;

  final List<String> appliances;
  final int? ovenTempC;

  final String? description;
  final String? imageUrl;

  ArchivedRecipe({
    required this.archiveId,
    required this.recipeId,
    required this.addedAtMs,
    required this.title,
    required this.timeLabel,
    required this.expiringCount,
    required this.ingredients,
    required this.steps,
    required this.appliances,
    this.ovenTempC,
    this.description,
    this.imageUrl,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMs);

  Map<String, dynamic> toJson() => {
        'archiveId': archiveId,
        'recipeId': recipeId,
        'addedAtMs': addedAtMs,
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

  factory ArchivedRecipe.fromJson(Map<String, dynamic> j) {
    return ArchivedRecipe(
      archiveId: (j['archiveId'] ?? '').toString(),
      recipeId: (j['recipeId'] ?? '').toString(),
      addedAtMs: (j['addedAtMs'] is int)
          ? j['addedAtMs'] as int
          : int.tryParse((j['addedAtMs'] ?? '0').toString()) ?? 0,
      title: (j['title'] ?? 'Untitled').toString(),
      timeLabel: (j['timeLabel'] ?? '20 min').toString(),
      expiringCount: (j['expiringCount'] is int)
          ? j['expiringCount'] as int
          : int.tryParse((j['expiringCount'] ?? '0').toString()) ?? 0,
      ingredients: (j['ingredients'] is List)
          ? (j['ingredients'] as List).map((x) => x.toString()).toList()
          : const <String>[],
      steps: (j['steps'] is List)
          ? (j['steps'] as List).map((x) => x.toString()).toList()
          : const <String>[],
      appliances: (j['appliances'] is List)
          ? (j['appliances'] as List).map((x) => x.toString()).toList()
          : const <String>[],
      ovenTempC: j['ovenTempC'] == null
          ? null
          : (j['ovenTempC'] is int)
              ? j['ovenTempC'] as int
              : int.tryParse(j['ovenTempC'].toString()),
      description: j['description']?.toString(),
      imageUrl: j['imageUrl']?.toString(),
    );
  }

  String get appliancesLabel {
    if (appliances.isEmpty) return 'No tools';
    if (appliances.length == 1) return appliances.first;
    return '${appliances.first} +${appliances.length - 1}';
  }
}

class ArchiveService {
  ArchiveService._();
  static final ArchiveService instance = ArchiveService._();

  static const String _kKey = 'recipe_archive_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<ArchivedRecipe>> getAll() async {
    final p = await _prefs();
    final raw = p.getStringList(_kKey) ?? const <String>[];
    final list = <ArchivedRecipe>[];

    for (final s in raw) {
      try {
        final obj = jsonDecode(s);
        if (obj is Map<String, dynamic>) {
          list.add(ArchivedRecipe.fromJson(obj));
        } else if (obj is Map) {
          list.add(ArchivedRecipe.fromJson(obj.cast<String, dynamic>()));
        }
      } catch (_) {
        // skip broken entry
      }
    }

    list.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return list;
  }

  Future<int> count() async {
    final list = await getAll();
    return list.length;
  }

  Future<bool> containsRecipeId(String recipeId) async {
    final list = await getAll();
    return list.any((x) => x.recipeId == recipeId);
  }

  Future<void> add(ArchivedRecipe recipe) async {
    final p = await _prefs();
    final list = await getAll();

    // 防止重复：同 recipeId 的就先删掉，再插入最新（更符合“按添加时间排序”的直觉）
    final filtered = list.where((x) => x.recipeId != recipe.recipeId).toList();
    filtered.insert(0, recipe);

    final raw = filtered.map((x) => jsonEncode(x.toJson())).toList();
    await p.setStringList(_kKey, raw);
  }

  Future<void> removeByArchiveId(String archiveId) async {
    final p = await _prefs();
    final list = await getAll();
    final filtered = list.where((x) => x.archiveId != archiveId).toList();
    final raw = filtered.map((x) => jsonEncode(x.toJson())).toList();
    await p.setStringList(_kKey, raw);
  }

  Future<void> clear() async {
    final p = await _prefs();
    await p.remove(_kKey);
  }
}
