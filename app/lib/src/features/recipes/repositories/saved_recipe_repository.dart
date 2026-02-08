import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/recipe_suggestion.dart';

class SavedRecipeRepository {
  SavedRecipeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _recipes(String uid) {
    return _db.collection('users').doc(uid).collection('recipes');
  }

  Stream<List<RecipeSuggestion>> watchSavedRecipes(String uid) {
    return _recipes(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RecipeSuggestion.fromFirestore(doc.data()))
          .toList(growable: false);
    });
  }

  Stream<bool> watchIsSaved(String uid, String recipeId) {
    return _recipes(uid).doc(recipeId).snapshots().map((doc) => doc.exists);
  }

  Future<void> saveRecipe(String uid, RecipeSuggestion recipe) async {
    final now = FieldValue.serverTimestamp();
    final id = recipeSaveId(recipe);
    await _recipes(uid).doc(id).set(<String, dynamic>{
      ...recipe.toFirestore(),
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> removeRecipe(String uid, RecipeSuggestion recipe) async {
    final id = recipeSaveId(recipe);
    await _recipes(uid).doc(id).delete();
  }
}

String recipeSaveId(RecipeSuggestion recipe) {
  final canonical = [
    recipe.title.trim().toLowerCase(),
    ...recipe.ingredients.map((e) => e.trim().toLowerCase()),
    ...recipe.steps.map((e) => e.trim().toLowerCase()),
  ].join('|');
  return _fnv1a32(canonical);
}

String _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

final savedRecipeRepositoryProvider = Provider<SavedRecipeRepository>((ref) {
  return SavedRecipeRepository(FirebaseFirestore.instance);
});

final savedRecipesProvider = StreamProvider.autoDispose<List<RecipeSuggestion>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return const Stream<List<RecipeSuggestion>>.empty();
  }
  return ref.watch(savedRecipeRepositoryProvider).watchSavedRecipes(uid);
});

final isRecipeSavedProvider = StreamProvider.autoDispose
    .family<bool, ({String uid, String recipeId})>((ref, key) {
  return ref.watch(savedRecipeRepositoryProvider).watchIsSaved(key.uid, key.recipeId);
});
