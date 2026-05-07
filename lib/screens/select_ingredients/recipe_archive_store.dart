import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../services/archive_service.dart';
import 'recipe_suggestion.dart';

const String _kRecipeArchiveKey = 'recipe_archive_v1';

class RecipeArchiveEntry {
  final RecipeSuggestion recipe;
  final DateTime addedAt;

  RecipeArchiveEntry({
    required this.recipe,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'recipe': recipe.toJson(),
    'addedAt': addedAt.toIso8601String(),
  };

  static RecipeArchiveEntry fromJson(Map<String, dynamic> json) {
    final r = (json['recipe'] as Map).cast<String, dynamic>();
    return RecipeArchiveEntry(
      recipe: RecipeSuggestion.fromJson(r),
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class RecipeArchiveStore {
  static Future<List<RecipeArchiveEntry>> load() async {
    await _maybeMigrateLegacy();
    final list = await ArchiveService.instance.getAll();
    return list
        .map((e) => RecipeArchiveEntry(
      recipe: _fromArchived(e),
      addedAt: e.addedAt,
    ))
        .toList();
  }

  static Future<void> add(RecipeSuggestion recipe) async {
    final archived = ArchivedRecipe(
      archiveId: const Uuid().v4(),
      recipeId: recipe.id,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
      title: recipe.title,
      timeLabel: recipe.timeLabel,
      expiringCount: recipe.expiringCount,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      appliances: recipe.appliances,
      ovenTempC: recipe.ovenTempC,
      description: recipe.description,
      imageUrl: recipe.imageUrl,
    );
    await ArchiveService.instance.add(archived);
  }

  static Future<void> remove(String recipeId) async {
    final list = await ArchiveService.instance.getAll();
    final match = list.firstWhere(
          (e) => e.recipeId == recipeId,
      orElse: () => ArchivedRecipe(
        archiveId: '',
        recipeId: '',
        addedAtMs: 0,
        title: '',
        timeLabel: '',
        expiringCount: 0,
        ingredients: const [],
        steps: const [],
        appliances: const [],
      ),
    );
    if (match.archiveId.isNotEmpty) {
      await ArchiveService.instance.removeByArchiveId(match.archiveId);
    }
  }

  static Future<bool> hasRecipe(String recipeId) async {
    return ArchiveService.instance.containsRecipeId(recipeId);
  }

  static Future<void> clear() async {
    await ArchiveService.instance.clear();
  }

  static Future<void> _maybeMigrateLegacy() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.get(_kRecipeArchiveKey);
    if (raw == null) return;

    try {
      final List<RecipeArchiveEntry> legacy;
      if (raw is String) {
        if (raw.trim().isEmpty) return;
        legacy = (jsonDecode(raw) as List<dynamic>)
            .map((e) => (e as Map).cast<String, dynamic>())
            .map(RecipeArchiveEntry.fromJson)
            .toList();
      } else if (raw is List) {
        legacy = raw
            .whereType<String>()
            .map((e) => jsonDecode(e))
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .map(RecipeArchiveEntry.fromJson)
            .toList();
      } else {
        return;
      }
      for (final entry in legacy) {
        final r = entry.recipe;
        final archived = ArchivedRecipe(
          archiveId: const Uuid().v4(),
          recipeId: r.id,
          addedAtMs: entry.addedAt.millisecondsSinceEpoch,
          title: r.title,
          timeLabel: r.timeLabel,
          expiringCount: r.expiringCount,
          ingredients: r.ingredients,
          steps: r.steps,
          appliances: r.appliances,
          ovenTempC: r.ovenTempC,
          description: r.description,
          imageUrl: r.imageUrl,
        );
        await ArchiveService.instance.add(archived);
      }
      await sp.remove(_kRecipeArchiveKey);
    } catch (_) {
      // ignore legacy parse errors
    }
  }

  static RecipeSuggestion _fromArchived(ArchivedRecipe recipe) {
    return RecipeSuggestion(
      id: recipe.recipeId,
      title: recipe.title,
      timeLabel: recipe.timeLabel,
      expiringCount: recipe.expiringCount,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      appliances: recipe.appliances,
      ovenTempC: recipe.ovenTempC,
      description: recipe.description,
      imageUrl: recipe.imageUrl,
    );
  }
}
