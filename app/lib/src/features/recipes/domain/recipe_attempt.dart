import 'package:cloud_firestore/cloud_firestore.dart';

enum RecipeAttemptStatus { trying, completed, cancelled }

class RecipeAttempt {
  const RecipeAttempt({
    required this.id,
    required this.status,
    required this.recipeTitle,
    required this.createdAt,
    required this.updatedAt,
    required this.usedIngredientNames,
    required this.missingIngredientNames,
    required this.selectedPantryItemIds,
    required this.consumptionEntries,
    required this.sourceRecipePayload,
  });

  final String id;
  final RecipeAttemptStatus status;
  final String recipeTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> usedIngredientNames;
  final List<String> missingIngredientNames;
  final List<String> selectedPantryItemIds;
  final List<RecipeConsumptionEntry> consumptionEntries;
  final Map<String, dynamic> sourceRecipePayload;

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'status': status.name,
      'recipeTitle': recipeTitle,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'usedIngredientNames': usedIngredientNames,
      'missingIngredientNames': missingIngredientNames,
      'selectedPantryItemIds': selectedPantryItemIds,
      'consumptionEntries': consumptionEntries.map((e) => e.toJson()).toList(growable: false),
      'sourceRecipePayload': sourceRecipePayload,
    };
  }

  RecipeAttempt copyWith({
    String? id,
    RecipeAttemptStatus? status,
    String? recipeTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? usedIngredientNames,
    List<String>? missingIngredientNames,
    List<String>? selectedPantryItemIds,
    List<RecipeConsumptionEntry>? consumptionEntries,
    Map<String, dynamic>? sourceRecipePayload,
  }) {
    return RecipeAttempt(
      id: id ?? this.id,
      status: status ?? this.status,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usedIngredientNames: usedIngredientNames ?? this.usedIngredientNames,
      missingIngredientNames: missingIngredientNames ?? this.missingIngredientNames,
      selectedPantryItemIds: selectedPantryItemIds ?? this.selectedPantryItemIds,
      consumptionEntries: consumptionEntries ?? this.consumptionEntries,
      sourceRecipePayload: sourceRecipePayload ?? this.sourceRecipePayload,
    );
  }

  static RecipeAttempt fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RecipeAttempt(
      id: doc.id,
      status: _statusFromString(data['status'] as String?),
      recipeTitle: (data['recipeTitle'] as String?) ?? 'Untitled Recipe',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedIngredientNames: (data['usedIngredientNames'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      missingIngredientNames: (data['missingIngredientNames'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      selectedPantryItemIds: (data['selectedPantryItemIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      consumptionEntries: (data['consumptionEntries'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => RecipeConsumptionEntry.fromJson(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
          .toList(growable: false),
      sourceRecipePayload: Map<String, dynamic>.from(
        data['sourceRecipePayload'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{},
      ),
    );
  }

  static RecipeAttemptStatus _statusFromString(String? value) {
    switch (value) {
      case 'completed':
        return RecipeAttemptStatus.completed;
      case 'cancelled':
        return RecipeAttemptStatus.cancelled;
      default:
        return RecipeAttemptStatus.trying;
    }
  }
}

class RecipeConsumptionEntry {
  const RecipeConsumptionEntry({
    required this.pantryItemId,
    required this.consumedValue,
    this.consumedUnit,
  });

  final String pantryItemId;
  final double consumedValue;
  final String? consumedUnit;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pantryItemId': pantryItemId,
      'consumedValue': consumedValue,
      'consumedUnit': consumedUnit,
    };
  }

  factory RecipeConsumptionEntry.fromJson(Map<String, dynamic> json) {
    return RecipeConsumptionEntry(
      pantryItemId: (json['pantryItemId'] as String?) ?? '',
      consumedValue: (json['consumedValue'] as num?)?.toDouble() ?? 0,
      consumedUnit: json['consumedUnit'] as String?,
    );
  }
}
