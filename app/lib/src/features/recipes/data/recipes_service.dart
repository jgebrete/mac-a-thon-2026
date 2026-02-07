import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/domain/pantry_item.dart';
import '../domain/recipe_suggestion.dart';

class RecipesService {
  RecipesService(this._functions);

  final FirebaseFunctions _functions;

  Future<List<RecipeSuggestion>> generateRecipes(List<PantryItem> items) async {
    final callable = _functions.httpsCallable('generateRecipeFromPantry');
    final result = await callable.call(<String, dynamic>{
      'pantryItems': items
          .map(
            (item) => <String, dynamic>{
              'name': item.name,
              'category': item.category,
              'expiryDateISO': item.expiryDate.toIso8601String(),
              'quantityValue': item.quantityValue,
              'quantityUnit': item.quantityUnit,
              'quantityNote': item.quantityNote,
            },
          )
          .toList(growable: false),
      'maxItems': 8,
    });

    final data = Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
    final rawRecipes = (data['recipes'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList(growable: false);

    return rawRecipes
        .map(RecipeSuggestion.fromJson)
        .toList(growable: false);
  }
}

final recipesServiceProvider = Provider<RecipesService>((ref) {
  return RecipesService(FirebaseFunctions.instance);
});
